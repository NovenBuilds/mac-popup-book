import Metal
import PageBehavior
import PopupBookCore
import SceneKit

private final class TapeSegment {
    let length: Double
    let pivot: SCNNode
    let piece: SCNNode

    init(from start: SIMD2<Double>, to end: SIMD2<Double>, width: Double, height: Double, color: NSColor) {
        let delta = end - start
        length = (delta.x * delta.x + delta.y * delta.y).squareRoot()
        let geometry = SCNBox(width: width, height: height, length: 1, chamferRadius: 0.002)
        geometry.firstMaterial?.diffuse.contents = color
        piece = SCNNode(geometry: geometry)
        pivot = SCNNode()
        pivot.position = SCNVector3(start.x, 0.028, start.y)
        pivot.eulerAngles.y = atan2(delta.x, delta.y)
        pivot.addChildNode(piece)
        piece.position.z = 0.5
        piece.name = "tape-piece"
        pivot.name = "tape-segment"
    }

    func update(_ amount: Double) {
        let amount = max(0.001, min(1, amount))
        let extent = length * amount
        piece.scale.z = extent
        piece.position.z = extent / 2
    }

    func setHighlight(_ on: Bool) {
        let base =
            on
            ? NSColor(calibratedRed: 0.92, green: 0.72, blue: 0.32, alpha: 1)
            : NSColor(calibratedRed: 0.86, green: 0.82, blue: 0.74, alpha: 1)
        piece.geometry?.firstMaterial?.diffuse.contents = base
        piece.geometry?.firstMaterial?.emission.contents =
            on ? NSColor(calibratedRed: 0.35, green: 0.22, blue: 0.05, alpha: 1) : NSColor.black
    }
}

final class LLMEvolutionScene {
    private let renderer: SCNRenderer
    private var colorTarget: MTLTexture?
    private var depthTarget: MTLTexture?
    private var viewport = CGSize(width: 1, height: 1)
    private var tapeSegments: [TapeSegment] = []
    private var branchSegments: [TapeSegment] = []
    private var boothRoots: [LLMEvolutionBooth: SCNNode] = [:]
    private var exampleChips: [SCNNode] = []
    private var bridgeNodes: [SCNNode] = []
    private var sourcePlaque = SCNNode()
    private var deskFold = SCNNode()
    private let zh: Bool
    private var candidateCards: [SCNNode] = []
    private var trainingPages: [SCNNode] = []
    private var inputCards: [SCNNode] = []
    private var demonstrationStart = 0.0
    private var lastBooth: LLMEvolutionBooth?
    private var lastExample: LLMEvolutionExample?
    private var lastNoticeTime = 0.0
    private var selectionApplies = true

    init(zh: Bool) throws {
        self.zh = zh
        guard let device = MTLCreateSystemDefaultDevice() else { throw PageError.missingResources }
        renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = SCNScene()
        renderer.autoenablesDefaultLighting = false
        buildScene()
    }

    func setViewport(_ size: CGSize) { viewport = size }

    func pickTarget(x: Double, y: Double) -> LLMEvolutionTapTarget? {
        let point = CGPoint(x: x * viewport.width, y: y * viewport.height)
        let options: [SCNHitTestOption: Any] = [
            .searchMode: SCNHitTestSearchMode.closest.rawValue
        ]
        var node = renderer.hitTest(point, options: options).first?.node
        while let current = node {
            if let name = current.name, let target = LLMEvolutionLayout.parseHit(name) {
                return target
            }
            node = current.parent
        }
        return nil
    }

    func render(
        into texture: MTLTexture, command: MTLCommandBuffer, folding: LLMEvolutionFolding,
        gameplay: LLMEvolutionGameplay, clock: Double
    ) throws {
        update(folding: folding, gameplay: gameplay, clock: clock)
        let size = CGSize(width: texture.width, height: texture.height)
        if colorTarget?.width != texture.width || colorTarget?.height != texture.height {
            let color = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm_srgb, width: texture.width, height: texture.height,
                mipmapped: false)
            color.textureType = .type2DMultisample
            color.sampleCount = 4
            color.storageMode = .private
            color.usage = .renderTarget
            colorTarget = texture.device.makeTexture(descriptor: color)
            let depth = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .depth32Float_stencil8, width: texture.width, height: texture.height,
                mipmapped: false)
            depth.textureType = .type2DMultisample
            depth.sampleCount = 4
            depth.storageMode = .private
            depth.usage = .renderTarget
            depthTarget = texture.device.makeTexture(descriptor: depth)
        }
        guard let colorTarget, let depthTarget else { throw PageError.missingResources }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = colorTarget
        pass.colorAttachments[0].resolveTexture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .multisampleResolve
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0.9, green: 0.92, blue: 0.94, alpha: 1)
        pass.depthAttachment.texture = depthTarget
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.storeAction = .dontCare
        pass.depthAttachment.clearDepth = 1
        pass.stencilAttachment.texture = depthTarget
        pass.stencilAttachment.loadAction = .clear
        pass.stencilAttachment.storeAction = .dontCare
        renderer.render(
            atTime: 0, viewport: CGRect(origin: .zero, size: size), commandBuffer: command,
            passDescriptor: pass)
    }

    private func buildScene() {
        guard let scene = renderer.scene else { return }
        scene.background.contents = NSColor(calibratedRed: 0.9, green: 0.92, blue: 0.94, alpha: 1)

        let cover = box(width: 3.81, height: 0.025, depth: 2.31, color: color(0.25, 0.35, 0.48))
        cover.position.y = -0.076
        scene.rootNode.addChildNode(cover)
        let edges = box(width: 3.74, height: 0.025, depth: 2.24, color: color(0.77, 0.72, 0.61))
        edges.position.y = -0.052
        scene.rootNode.addChildNode(edges)
        let desk = box(width: 3.66, height: 0.034, depth: 2.18, color: color(0.89, 0.84, 0.73))
        desk.position.y = -0.023
        let spine = box(width: 0.015, height: 0.004, depth: 2.17, color: color(0.57, 0.47, 0.38))
        scene.rootNode.addChildNode(spine)
        deskFold = desk
        scene.rootNode.addChildNode(desk)

        addTapeRoute(LLMEvolutionLayout.tape, bucket: .main)
        addTapeRoute(LLMEvolutionLayout.branch, bucket: .branch)

        buildExampleSelectors(in: scene)
        buildBooths(in: scene)
        buildAttentionBridges(in: scene)
        buildSourcePlaque(in: scene)
        buildCameraAndLights()
    }

    private enum TapeBucket { case main, branch }

    private func addTapeRoute(_ points: [LLMEvolutionPoint], bucket: TapeBucket) {
        guard let scene = renderer.scene else { return }
        let mapped = points.map { SIMD2($0.x, $0.z) }
        for index in mapped.indices.dropLast() {
            let segment = TapeSegment(
                from: mapped[index], to: mapped[index + 1], width: 0.22, height: 0.012,
                color: color(0.86, 0.82, 0.74))
            segment.update(0)
            switch bucket {
            case .main: tapeSegments.append(segment)
            case .branch: branchSegments.append(segment)
            }
            scene.rootNode.addChildNode(segment.pivot)
        }
    }

    private func buildExampleSelectors(in scene: SCNScene) {
        let labels = zh ? ["续写", "改写", "图文"] : ["Continue", "Rewrite", "Image"]
        for (index, example) in LLMEvolutionExample.allCases.enumerated() {
            let chip = box(width: 0.34, height: 0.05, depth: 0.2, color: color(0.94, 0.9, 0.82))
            chip.position = SCNVector3(-1.46, 0.029, 0.25 + Double(index) * 0.25)
            chip.name = LLMEvolutionLayout.HitNames.example(example)
            scene.rootNode.addChildNode(chip)
            exampleChips.append(chip)

            let tag = exampleLabel(labels[index], height: 0.082, width: 0.27)
            tag.position = SCNVector3(0, 0.027, 0)
            chip.addChildNode(tag)
        }
    }

    private func buildBooths(in scene: SCNScene) {
        for booth in LLMEvolutionBooth.allCases {
            let anchor = LLMEvolutionLayout.boothAnchor(booth)
            let root = SCNNode()
            root.name = LLMEvolutionLayout.HitNames.booth(booth)
            root.position = SCNVector3(anchor.x, 0, anchor.z)
            let pedestal = box(width: 0.26, height: 0.04, depth: 0.2, color: color(0.55, 0.58, 0.62))
            pedestal.position.y = 0.02
            root.addChildNode(pedestal)

            let module = boothGeometry(booth)
            module.position.y = 0.08
            root.addChildNode(module)
            let plaque = box(width: 0.28, height: 0.014, depth: 0.095, color: color(0.91, 0.84, 0.65))
            plaque.position = SCNVector3(0, 0.016, 0.14)
            let labels =
                zh
                ? ["接续", "注意力", "预训练", "反馈", "图文", "研究"]
                : ["Continue", "Attention", "Training", "Feedback", "Image", "Research"]
            let tag = exampleLabel(labels[booth.rawValue], height: 0.043, width: 0.23)
            tag.position.y = 0.009
            plaque.addChildNode(tag)
            root.addChildNode(plaque)

            boothRoots[booth] = root
            scene.rootNode.addChildNode(root)
        }

    }

    private func boothGeometry(_ booth: LLMEvolutionBooth) -> SCNNode {
        switch booth {
        case .nextToken:
            let node = SCNNode()
            for (index, offset) in [-0.08, 0.08].enumerated() {
                let card = box(width: 0.11, height: 0.19, depth: 0.017, color: color(0.92, 0.79, 0.54))
                card.position.x = offset
                let glyph = exampleLabel(index == 0 ? "A" : "B", height: 0.078, width: 0.075)
                glyph.position.z = 0.011
                glyph.eulerAngles.x = 0
                card.addChildNode(glyph)
                node.addChildNode(card)
                candidateCards.append(card)
            }
            return node
        case .attention:
            let frame = box(
                width: 0.2, height: 0.16, depth: 0.02, color: color(0.7, 0.82, 0.9), transparency: 0.55)
            return frame
        case .pretrain:
            let stack = SCNNode()
            for i in 0..<4 {
                let page = box(width: 0.16, height: 0.02, depth: 0.12, color: color(0.84, 0.86, 0.78))
                page.position = SCNVector3(0, Double(i) * 0.025, -Double(i) * 0.02)
                stack.addChildNode(page)
                trainingPages.append(page)
            }
            let press = box(width: 0.19, height: 0.021, depth: 0.13, color: color(0.37, 0.58, 0.53))
            press.position = SCNVector3(0, 0.13, -0.018)
            stack.addChildNode(press)
            return stack
        case .instructionFeedback:
            let desk = box(width: 0.22, height: 0.08, depth: 0.14, color: color(0.58, 0.45, 0.38))
            let card = box(width: 0.08, height: 0.1, depth: 0.01, color: color(0.92, 0.86, 0.72))
            card.position = SCNVector3(0, 0.1, 0)
            desk.addChildNode(card)
            return desk
        case .multimodal:
            let node = SCNNode()
            let image = box(width: 0.12, height: 0.1, depth: 0.02, color: color(0.52, 0.62, 0.72))
            image.position.x = -0.06
            let strip = box(width: 0.12, height: 0.04, depth: 0.02, color: color(0.9, 0.86, 0.76))
            strip.position = SCNVector3(0.06, -0.02, 0)
            node.addChildNode(image)
            node.addChildNode(strip)
            let frame = box(width: 0.16, height: 0.11, depth: 0.009, color: color(0.23, 0.48, 0.50))
            frame.position = SCNVector3(0, 0.023, -0.056)
            node.addChildNode(frame)
            inputCards = [image, strip]
            return node
        case .researchBranch:
            let drawer = box(width: 0.18, height: 0.06, depth: 0.16, color: color(0.46, 0.5, 0.54))
            let card = box(width: 0.06, height: 0.08, depth: 0.01, color: color(0.88, 0.76, 0.52))
            card.position = SCNVector3(0, 0.08, 0.05)
            drawer.addChildNode(card)
            return drawer
        }
    }

    private func buildAttentionBridges(in scene: SCNScene) {
        let pairs: [(SIMD3<Double>, SIMD3<Double>)] = [
            (SIMD3(-0.62, 0.14, 0.02), SIMD3(-0.42, 0.1, -0.12)),
            (SIMD3(-0.52, 0.16, 0.05), SIMD3(-0.18, 0.12, 0.08)),
            (SIMD3(0.9, 0.14, 0.02), SIMD3(1.02, 0.11, -0.08)),
        ]
        for (start, end) in pairs {
            let bridge = cylinderBridge(from: start, to: end)
            bridgeNodes.append(bridge)
            scene.rootNode.addChildNode(bridge)
        }
    }

    private func buildSourcePlaque(in scene: SCNScene) {
        let plaque = box(width: 0.32, height: 0.06, depth: 0.18, color: color(0.62, 0.56, 0.48))
        plaque.position = SCNVector3(1.38, 0.026, -0.52)
        let tag = exampleLabel(zh ? "来源" : "Sources", height: 0.061, width: 0.24)
        tag.position.y = 0.031
        plaque.addChildNode(tag)
        sourcePlaque = plaque
        scene.rootNode.addChildNode(plaque)
    }

    private func buildCameraAndLights() {
        guard let scene = renderer.scene else { return }
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 1.70
        camera.zNear = 0.1
        camera.zFar = 20
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0.3, 4.9, 6.8)
        cameraNode.look(at: SCNVector3(0, 0, 0.08))
        scene.rootNode.addChildNode(cameraNode)
        renderer.pointOfView = cameraNode

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 480
        scene.rootNode.addChildNode(ambient)
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 560
        key.eulerAngles = SCNVector3(-0.75, -0.35, 0)
        scene.rootNode.addChildNode(key)
    }

    private func update(folding: LLMEvolutionFolding, gameplay: LLMEvolutionGameplay, clock: Double) {
        for segment in tapeSegments { segment.update(folding.tape) }
        for segment in branchSegments { segment.update(folding.branch) }

        deskFold.opacity = CGFloat(0.88 + 0.12 * folding.desk)
        updateDemonstration(gameplay, clock: clock)

        for booth in LLMEvolutionBooth.allCases {
            guard let root = boothRoots[booth] else { continue }
            let amount = booth == .researchBranch ? folding.branch : folding.booths
            setFold(root, amount: amount)
            let selected = booth == gameplay.selectedBooth
            root.isHidden = amount < 0.05
            root.opacity = selected ? 1 : CGFloat(0.55 + 0.35 * amount)
            if let pedestal = root.childNodes.first {
                pedestal.geometry?.firstMaterial?.emission.contents =
                    selected
                    ? NSColor(calibratedRed: 0.2, green: 0.28, blue: 0.38, alpha: 1) : NSColor.black
            }
        }

        for (index, exampleNode) in exampleChips.enumerated() {
            exampleNode.isHidden = folding.booths < 0.08
            let selected = index == gameplay.selectedExample.rawValue
            exampleNode.geometry?.firstMaterial?.diffuse.contents =
                selected ? color(0.98, 0.92, 0.72) : color(0.94, 0.9, 0.82)
        }

        let lit = Set(gameplay.highlightedTapeSegmentIndices())
        for (index, segment) in tapeSegments.enumerated() {
            segment.setHighlight(lit.contains(index) && gameplay.canInteract)
        }
        for segment in branchSegments {
            segment.setHighlight(gameplay.highlightsBranch() && gameplay.canInteract)
        }

        let showBridges = gameplay.selectedBooth == .attention && folding.bridges > 0.2
        for node in bridgeNodes {
            node.isHidden = !showBridges
            node.opacity = CGFloat(folding.bridges)
        }

        sourcePlaque.isHidden = folding.booths < 0.4
        sourcePlaque.name = LLMEvolutionLayout.HitNames.source
    }

    private func updateDemonstration(_ gameplay: LLMEvolutionGameplay, clock: Double) {
        if !gameplay.canInteract { lastBooth = nil }
        if gameplay.canInteract
            && (lastBooth != gameplay.selectedBooth || lastExample != gameplay.selectedExample
                || (gameplay.notice != nil && lastNoticeTime != gameplay.noticeUntil))
        {
            demonstrationStart = clock
            lastBooth = gameplay.selectedBooth
            lastExample = gameplay.selectedExample
            lastNoticeTime = gameplay.noticeUntil
            selectionApplies =
                LLMEvolutionExhibit.panel(
                    example: gameplay.selectedExample, booth: gameplay.selectedBooth, zh: zh
                ).kind != .notApplicable
        }
        let elapsed = max(0, clock - demonstrationStart)
        func travel(_ start: Double, _ end: Double) -> Double {
            let t = max(0, min(1, (elapsed - start) / (end - start)))
            return t * t * (3 - 2 * t)
        }
        let usable = gameplay.canInteract && selectionApplies
        for (index, card) in candidateCards.enumerated() {
            let progress =
                usable && gameplay.selectedBooth == .nextToken ? travel(0, 0.5 + Double(index) * 0.16) : 0
            let side = index == 0 ? -1.0 : 1.0
            card.position = SCNVector3(side * (0.065 + 0.045 * progress), 0.072 + 0.028 * progress, 0)
            card.eulerAngles.z = side * progress * 0.32
        }
        for (index, page) in trainingPages.enumerated() {
            let progress =
                usable && gameplay.selectedBooth == .pretrain
                ? travel(Double(index) * 0.13, Double(index) * 0.13 + 0.58) : 0
            page.position = SCNVector3(
                (1 - progress) * (Double(index) - 1.5) * 0.047,
                Double(index) * 0.025, -Double(index) * 0.02 + (1 - progress) * 0.086)
        }
        for (index, card) in inputCards.enumerated() {
            let progress = usable && gameplay.selectedBooth == .multimodal ? travel(0, 0.82) : 0
            let side = index == 0 ? -1.0 : 1.0
            card.position = SCNVector3(
                side * (0.092 - progress * 0.054), index == 0 ? 0.035 : -0.017, -0.035 * progress)
        }
    }

    private func setFold(_ node: SCNNode, amount: Double) {
        node.eulerAngles.x = -CGFloat((1 - amount) * .pi / 2.2)
    }

    private func box(
        width: Double, height: Double, depth: Double, color: NSColor, transparency: Double = 1
    ) -> SCNNode {
        let geometry = SCNBox(width: width, height: height, length: depth, chamferRadius: 0.003)
        geometry.firstMaterial?.diffuse.contents = color
        geometry.firstMaterial?.transparency = transparency
        return SCNNode(geometry: geometry)
    }

    private func color(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) -> NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }

    private func exampleLabel(_ label: String, height: Double, width: Double) -> SCNNode {
        let text = SCNText(string: label, extrusionDepth: 0)
        text.font = .systemFont(ofSize: 20, weight: .semibold)
        text.flatness = 0.15
        text.firstMaterial?.diffuse.contents = color(0.18, 0.20, 0.25)
        text.firstMaterial?.lightingModel = .constant
        let node = SCNNode(geometry: text)
        let (min, max) = node.boundingBox
        let scale = Swift.min(height / Double(max.y - min.y), width / Double(max.x - min.x))
        node.pivot = SCNMatrix4MakeTranslation((min.x + max.x) / 2, (min.y + max.y) / 2, 0)
        node.scale = SCNVector3(scale, scale, scale)
        node.eulerAngles.x = -.pi / 2
        return node
    }

    private func cylinderBridge(from start: SIMD3<Double>, to end: SIMD3<Double>) -> SCNNode {
        let delta = end - start
        let length = (delta.x * delta.x + delta.y * delta.y + delta.z * delta.z).squareRoot()
        let tube = SCNCylinder(radius: 0.004, height: length)
        tube.firstMaterial?.diffuse.contents = color(0.42, 0.68, 0.82, 0.7)
        tube.firstMaterial?.transparency = 0.55
        let node = SCNNode(geometry: tube)
        node.position = SCNVector3((start.x + end.x) / 2, (start.y + end.y) / 2, (start.z + end.z) / 2)
        node.look(at: SCNVector3(end.x, end.y, end.z))
        node.eulerAngles.x += .pi / 2
        return node
    }
}
