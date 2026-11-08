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
    private var exampleHits: [SCNNode] = []
    private var bridgeNodes: [SCNNode] = []
    private var sourceHit = SCNNode()
    private var deskFold = SCNNode()
    private var shelfFold = SCNNode()

    init() throws {
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
            .searchMode: SCNHitTestSearchMode.closest.rawValue,
            .boundingBoxOnly: true,
        ]
        guard let hit = renderer.hitTest(point, options: options).first else { return nil }
        let name = hit.node.name ?? hit.node.parent?.name ?? ""
        return LLMEvolutionLayout.parseHit(name)
    }

    func render(
        into texture: MTLTexture, command: MTLCommandBuffer, folding: LLMEvolutionFolding,
        gameplay: LLMEvolutionGameplay
    ) throws {
        update(folding: folding, gameplay: gameplay)
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

        let desk = box(width: 3.6, height: 0.05, depth: 2.2, color: color(0.72, 0.74, 0.76))
        desk.position.y = -0.04
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
        let labels = ["续写", "改写", "图文"]
        for (index, example) in LLMEvolutionExample.allCases.enumerated() {
            let chip = box(width: 0.34, height: 0.05, depth: 0.2, color: color(0.94, 0.9, 0.82))
            chip.position = SCNVector3(-1.55, 0.12 + Double(index) * 0.22, 0.42)
            scene.rootNode.addChildNode(chip)
            let hit = box(width: 0.4, height: 0.18, depth: 0.26, color: .clear)
            hit.name = LLMEvolutionLayout.HitNames.example(example)
            hit.opacity = 0.001
            hit.position = chip.position
            hit.position.y = 0.18
            exampleHits.append(chip)
            scene.rootNode.addChildNode(hit)

            let tag = textPlane(labels[index], size: 0.08)
            tag.position = SCNVector3(0, 0.03, 0)
            chip.addChildNode(tag)
        }
    }

    private func buildBooths(in scene: SCNScene) {
        for booth in LLMEvolutionBooth.allCases {
            let anchor = LLMEvolutionLayout.boothAnchor(booth)
            let root = SCNNode()
            root.position = SCNVector3(anchor.x, 0, anchor.z)
            let pedestal = box(width: 0.26, height: 0.04, depth: 0.2, color: color(0.55, 0.58, 0.62))
            pedestal.position.y = 0.02
            root.addChildNode(pedestal)

            let module = boothGeometry(booth)
            module.position.y = 0.08
            root.addChildNode(module)

            let hitDepth: Double = booth == .researchBranch ? 0.42 : 0.34
            let hit = box(width: 0.38, height: 0.34, depth: hitDepth, color: .clear)
            hit.name = LLMEvolutionLayout.HitNames.booth(booth)
            hit.opacity = 0.001
            hit.position.y = 0.16
            root.addChildNode(hit)

            boothRoots[booth] = root
            scene.rootNode.addChildNode(root)
        }

        shelfFold = boothRoots[.pretrain] ?? SCNNode()
    }

    private func boothGeometry(_ booth: LLMEvolutionBooth) -> SCNNode {
        switch booth {
        case .nextToken:
            let node = SCNNode()
            for offset in [-0.08, 0.08] {
                let card = box(width: 0.1, height: 0.14, depth: 0.02, color: color(0.93, 0.88, 0.78))
                card.position.x = offset
                node.addChildNode(card)
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
            }
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
        plaque.position = SCNVector3(1.38, 0.06, -0.72)
        scene.rootNode.addChildNode(plaque)
        sourceHit = box(width: 0.4, height: 0.2, depth: 0.26, color: .clear)
        sourceHit.name = LLMEvolutionLayout.HitNames.source
        sourceHit.opacity = 0.001
        sourceHit.position = plaque.position
        sourceHit.position.y = 0.14
        scene.rootNode.addChildNode(sourceHit)
    }

    private func buildCameraAndLights() {
        guard let scene = renderer.scene else { return }
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 2.55
        camera.zNear = 0.1
        camera.zFar = 20
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 2.4, 6.8)
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

    private func update(folding: LLMEvolutionFolding, gameplay: LLMEvolutionGameplay) {
        for segment in tapeSegments { segment.update(folding.tape) }
        for segment in branchSegments { segment.update(folding.branch) }

        deskFold.opacity = CGFloat(0.4 + 0.6 * folding.desk)
        setFold(shelfFold, amount: folding.booths)

        for booth in LLMEvolutionBooth.allCases {
            guard let root = boothRoots[booth] else { continue }
            let amount = booth == .researchBranch ? folding.branch : folding.booths
            setFold(root, amount: amount)
            let selected = booth == gameplay.selectedBooth
            root.opacity = selected ? 1 : CGFloat(0.55 + 0.35 * amount)
            if let pedestal = root.childNodes.first {
                pedestal.geometry?.firstMaterial?.emission.contents =
                    selected
                    ? NSColor(calibratedRed: 0.2, green: 0.28, blue: 0.38, alpha: 1) : NSColor.black
            }
        }

        for (index, exampleNode) in exampleHits.enumerated() {
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

        sourceHit.isHidden = folding.booths < 0.4
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

    private func textPlane(_ text: String, size: Double) -> SCNNode {
        let plane = SCNPlane(width: size * 2.2, height: size)
        plane.firstMaterial?.diffuse.contents = color(0.25, 0.28, 0.32)
        plane.firstMaterial?.isDoubleSided = true
        let node = SCNNode(geometry: plane)
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
