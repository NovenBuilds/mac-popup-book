import Metal
import PageBehavior
import PopupBookCore
import SceneKit

final class LLMEvolutionScene {
    private let renderer: SCNRenderer
    private var colorTarget: MTLTexture?
    private var depthTarget: MTLTexture?
    private var viewport = CGSize(width: 1, height: 1)
    private let zh: Bool
    private let stage = SCNNode()
    private let rail = SCNNode()
    private let press = SCNNode()
    private let platen = SCNNode()
    private let seal = SCNNode()
    private let attention = SCNNode()
    private let gallery = SCNNode()
    private let notes = SCNNode()
    private let noteLines = SCNNode()
    private var notesAct: Int?
    private var inputs: [SCNNode] = []
    private var results: [SCNNode] = []
    private var imageCard = SCNNode()
    private var links: [SCNNode] = []
    private var cues: [SCNNode] = []

    init(zh: Bool) throws {
        self.zh = zh
        guard let device = MTLCreateSystemDefaultDevice() else { throw PageError.missingResources }
        renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = SCNScene()
        renderer.autoenablesDefaultLighting = false
        buildScene()
    }

    func setViewport(_ size: CGSize) { viewport = size }

    func pickedSource(x: Double, y: Double) -> Bool {
        let point = CGPoint(x: x * viewport.width, y: y * viewport.height)
        var node = renderer.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue])
            .first?.node
        while let current = node {
            if current.name == "source-card" { return true }
            node = current.parent
        }
        return false
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
        guard let root = renderer.scene?.rootNode else { return }
        renderer.scene?.background.contents = color(0.92, 0.89, 0.82)
        let jade = color(0.17, 0.37, 0.35)
        let coral = color(0.67, 0.31, 0.22)
        let gold = color(0.88, 0.68, 0.35)
        let cream = color(0.98, 0.91, 0.73)
        block(in: root, at: SCNVector3(0, -0.074, 0), 3.84, 0.036, 2.31, jade)
        block(in: root, at: SCNVector3(0, -0.045, 0), 3.76, 0.026, 2.23, gold)
        block(in: root, at: SCNVector3(0, -0.018, 0), 3.69, 0.033, 2.17, cream)
        root.addChildNode(stage)
        stage.addChildNode(rail)
        stage.addChildNode(press)
        stage.addChildNode(attention)
        stage.addChildNode(gallery)
        stage.addChildNode(notes)
        notes.name = "source-card"
        notes.position = SCNVector3(0, 0.57, 0.65)
        notes.eulerAngles.x = -0.36
        block(in: notes, at: SCNVector3Zero, 3.06, 1.06, 0.038, jade)
        block(in: notes, at: SCNVector3(0, 0, 0.022), 2.98, 0.98, 0.012, cream)
        notes.addChildNode(noteLines)

        let back = SCNNode()
        back.position.z = -0.92
        press.addChildNode(back)
        block(in: back, at: SCNVector3(0, 0.30, 0), 3.17, 0.60, 0.045, jade)
        block(in: back, at: SCNVector3(0, 0.575, 0.029), 3.10, 0.036, 0.02, gold)
        for x in [-1.54, 1.54] {
            block(in: back, at: SCNVector3(x, 0.30, 0.033), 0.045, 0.55, 0.022, gold)
        }
        let masthead = exampleLabel(word("字 间 工 坊", "LETTER WORKSHOP"), height: 0.17, width: 1.82)
        masthead.eulerAngles.x = 0
        masthead.position = SCNVector3(0, 0.35, 0.031)
        masthead.geometry?.firstMaterial?.diffuse.contents = cream
        back.addChildNode(masthead)

        press.position.z = -0.02
        block(in: press, at: SCNVector3(0, 0.055, -0.01), 0.80, 0.11, 0.51, jade)
        for x in [-0.33, 0.33] {
            for z in [-0.22, 0.18] {
                block(in: press, at: SCNVector3(x, 0.28, z), 0.075, 0.46, 0.077, coral)
            }
        }
        block(in: press, at: SCNVector3(0, 0.54, -0.02), 0.82, 0.11, 0.53, coral)
        block(in: press, at: SCNVector3(0, 0.60, -0.02), 0.74, 0.02, 0.47, gold)
        for x in [-0.27, 0.27] {
            let fastener = SCNNode(geometry: SCNCylinder(radius: 0.039, height: 0.018))
            fastener.eulerAngles.x = .pi / 2
            fastener.position = SCNVector3(x, 0.535, 0.257)
            fastener.geometry?.firstMaterial?.diffuse.contents = gold
            press.addChildNode(fastener)
        }
        for z in [-0.05, 0.07] {
            let roller = SCNNode(geometry: SCNCylinder(radius: 0.029, height: 0.61))
            roller.eulerAngles.z = .pi / 2
            roller.position = SCNVector3(0, 0.127, z)
            roller.geometry?.firstMaterial?.diffuse.contents = jade
            press.addChildNode(roller)
        }
        press.addChildNode(platen)
        block(in: platen, at: SCNVector3(0, 0, 0), 0.55, 0.075, 0.31, gold)
        block(in: platen, at: SCNVector3(0, 0.105, 0), 0.047, 0.21, 0.047, gold)
        let maker = exampleLabel(word("印 机", "PRESS"), height: 0.066, width: 0.44)
        maker.eulerAngles.x = 0
        maker.position = SCNVector3(0, 0.54, 0.251)
        maker.geometry?.firstMaterial?.diffuse.contents = cream
        press.addChildNode(maker)
        press.addChildNode(seal)
        seal.position = SCNVector3(0, 0.68, -0.04)
        block(in: seal, at: SCNVector3(0, 0, 0), 0.32, 0.039, 0.045, gold)
        block(in: seal, at: SCNVector3(0.153, 0.044, 0), 0.04, 0.11, 0.045, coral)

        for (start, end) in [
            (SIMD2(-1.55, 0.0), SIMD2(0.44, 0.0)),
            (SIMD2(0.44, 0.0), SIMD2(1.47, -0.43)),
            (SIMD2(0.44, 0.0), SIMD2(1.47, 0.43)),
            (SIMD2(-1.25, 0.75), SIMD2(-0.37, 0.10)),
        ] {
            route(in: rail, from: start, to: end, y: 0.032, width: 0.20, tint: gold)
            route(in: rail, from: start, to: end, y: 0.042, width: 0.018, tint: coral)
        }

        let source = card(word("说明与来源", "Notes & sources"), tint: cream)
        source.name = "source-card"
        source.position = SCNVector3(-1.33, 0.055, -0.70)
        source.scale = SCNVector3(0.75, 0.75, 0.75)
        stage.addChildNode(source)
        inputs = [
            card(word("清晨，小镇车站里…", "At dawn, the station…"), tint: cream),
            card(word("把东西给我。", "Give it to me."), tint: cream),
            card(word("图中有红伞吗？", "Is there a red umbrella?"), tint: cream),
        ]
        results = [
            card(word("小火车轻轻靠站", "A train eases in"), tint: color(0.94, 0.72, 0.38)),
            card(word("树下传来哨声", "A whistle under the tree"), tint: color(0.60, 0.79, 0.73)),
            card(word("请问可以递给我吗？", "Could you pass it, please?"), tint: color(0.89, 0.66, 0.53)),
            card(word("有一把红伞", "Yes, a red umbrella"), tint: color(0.68, 0.75, 0.91)),
        ]
        for node in inputs + results { stage.addChildNode(node) }

        imageCard = card(word("图 像", "PICTURE"), tint: color(0.68, 0.75, 0.91), width: 0.55, depth: 0.33)
        let umbrella = SCNNode(geometry: SCNSphere(radius: 0.098))
        umbrella.geometry?.firstMaterial?.diffuse.contents = coral
        umbrella.scale = SCNVector3(1, 0.26, 0.57)
        umbrella.position = SCNVector3(-0.16, 0.038, -0.032)
        imageCard.addChildNode(umbrella)
        block(in: imageCard, at: SCNVector3(-0.16, 0.033, 0.035), 0.014, 0.015, 0.093, jade)
        stage.addChildNode(imageCard)

        let cuePositions = [-1.08, -0.31, 0.47]
        for (index, label) in [word("更礼貌", "Politer"), word("请问", "Could you"), word("谢谢", "Thank you")]
            .enumerated()
        {
            let cue = card(label, tint: gold, width: 0.51, depth: 0.20)
            cue.position = SCNVector3(cuePositions[index], 0.17, 0.77)
            attention.addChildNode(cue)
            cues.append(cue)
            if index > 0 {
                let connection = route(
                    in: attention, from: SIMD2(cuePositions[0], 0.77),
                    to: SIMD2(cuePositions[index], 0.68), y: 0.181, width: 0.035, tint: gold)
                connection.geometry?.firstMaterial?.emission.contents = gold
                links.append(connection)
            }
        }
        let galleryTitle = exampleLabel(word("成 品 陈 列", "PRINT GALLERY"), height: 0.12, width: 1.55)
        galleryTitle.position = SCNVector3(0, 0.042, 0.79)
        gallery.addChildNode(galleryTitle)
        buildCameraAndLights()
    }

    private func update(folding: LLMEvolutionFolding, gameplay: LLMEvolutionGameplay) {
        stage.isHidden = folding.booths <= 0
        stage.scale.y = max(0.001, folding.booths)
        rail.scale.y = max(0.001, folding.tape)
        let act = gameplay.act
        updateNotes(gameplay)
        let time = gameplay.actTime
        let feeding = ease(time, 0.4, 3.0)
        let pressing = ease(time, 2.8, 4.35) * (1 - ease(time, 4.6, 5.6))
        platen.position.y = 0.40 - 0.24 * pressing
        seal.eulerAngles.y = feeding * .pi + pressing * .pi
        gallery.isHidden = !gameplay.finished
        rail.isHidden = gameplay.finished
        for (index, input) in inputs.enumerated() {
            input.isHidden = gameplay.finished || index != act || time >= 3.1
            input.position = SCNVector3(-1.36 + 1.37 * feeding, 0.13, 0)
        }
        attention.isHidden = gameplay.finished || act != 1 || time < 0.5 || time > 6.5
        for (index, cue) in cues.enumerated() {
            let start = 0.5 + Double(index) * 0.8
            cue.isHidden = time < start
            cue.eulerAngles.x = -.pi / 2 * (1 - ease(time, start, start + 0.52))
        }
        for (index, link) in links.enumerated() {
            link.isHidden = time < 1.65 + Double(index) * 0.75
        }
        let imageFeed = ease(time, 0.6, 3.25)
        imageCard.isHidden = gameplay.finished || act != 2 || time > 3.35
        imageCard.position = SCNVector3(-1.29 + 1.26 * imageFeed, 0.195, 0.80 * (1 - imageFeed))

        let assignedActs = [0, 0, 1, 2]
        let destinations = [-0.44, 0.43, 0.42, -0.44]
        for (index, result) in results.enumerated() {
            if gameplay.finished {
                result.isHidden = false
                let x = index.isMultiple(of: 2) ? -1.01 : 1.01
                result.position = SCNVector3(x, 0.16, index < 2 ? -0.44 : 0.51)
                result.eulerAngles.x = -.pi / 9
                continue
            }
            let start = index == 1 ? 5.9 : 5.05
            let emergence = ease(time, start, start + 0.8)
            let branch = ease(time, start + 0.45, start + 2.65)
            result.isHidden = act != assignedActs[index] || time < start
            result.position = SCNVector3(
                0.10 + 0.37 * emergence + 0.90 * branch,
                0.132 + 0.1 * sin(.pi * branch) + 0.06 * branch,
                destinations[index] * branch)
            result.eulerAngles.x = -.pi / 9 * branch
        }
    }

    private func updateNotes(_ gameplay: LLMEvolutionGameplay) {
        notes.isHidden = !gameplay.showSource || !gameplay.canInteract
        guard !notes.isHidden, notesAct != gameplay.act else { return }
        notesAct = gameplay.act
        for line in noteLines.childNodes { line.removeFromParentNode() }
        let heading = exampleLabel(word("说明与来源", "Notes and sources"), height: 0.115, width: 2.65)
        heading.position = SCNVector3(0, 0.36, 0.032)
        heading.eulerAngles.x = 0
        noteLines.addChildNode(heading)

        let detail = gameplay.detail(zh: zh)
        var lines: [String] = []
        if zh {
            var remaining = detail[...]
            while !remaining.isEmpty {
                lines.append(String(remaining.prefix(30)))
                remaining = remaining.dropFirst(30)
            }
        } else {
            var line = ""
            for word in detail.split(separator: " ") {
                if line.count + word.count + 1 > 63 {
                    lines.append(line)
                    line = ""
                }
                line += (line.isEmpty ? "" : " ") + word
            }
            if !line.isEmpty { lines.append(line) }
        }
        let spacing = min(0.107, 0.64 / Double(max(1, lines.count)))
        for (index, line) in lines.enumerated() {
            let text = exampleLabel(line, height: spacing * 0.69, width: 2.70)
            text.eulerAngles.x = 0
            text.position = SCNVector3(0, 0.225 - Double(index) * spacing, 0.033)
            noteLines.addChildNode(text)
        }
    }

    private func ease(_ time: Double, _ start: Double, _ end: Double) -> Double {
        let value = min(1, max(0, (time - start) / (end - start)))
        return value * value * (3 - 2 * value)
    }

    private func word(_ chinese: String, _ english: String) -> String { zh ? chinese : english }

    private func card(_ title: String, tint: NSColor, width: Double = 0.79, depth: Double = 0.27) -> SCNNode {
        let node = SCNNode()
        block(in: node, at: SCNVector3Zero, width, 0.033, depth, tint)
        block(
            in: node, at: SCNVector3(0, 0.019, depth * 0.37), width * 0.88, 0.005, 0.012,
            color(0.40, 0.31, 0.23))
        let label = exampleLabel(title, height: min(depth * 0.36, 0.083), width: width * 0.84)
        label.position.y = 0.019
        node.addChildNode(label)
        return node
    }

    @discardableResult
    private func block(
        in parent: SCNNode, at position: SCNVector3, _ width: Double, _ height: Double,
        _ depth: Double, _ tint: NSColor
    ) -> SCNNode {
        let node = box(width: width, height: height, depth: depth, color: tint)
        node.position = position
        parent.addChildNode(node)
        return node
    }

    @discardableResult
    private func route(
        in parent: SCNNode, from start: SIMD2<Double>, to end: SIMD2<Double>,
        y: Double, width: Double, tint: NSColor
    ) -> SCNNode {
        let delta = end - start
        let middle = (start + end) / 2
        let length = (delta.x * delta.x + delta.y * delta.y).squareRoot()
        let strip = block(in: parent, at: SCNVector3(middle.x, y, middle.y), width, 0.012, length, tint)
        strip.eulerAngles.y = atan2(delta.x, delta.y)
        return strip
    }

    private func buildCameraAndLights() {
        guard let scene = renderer.scene else { return }
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 1.67
        camera.zNear = 0.1
        camera.zFar = 20
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0.16, 5.8, 6.7)
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

}
