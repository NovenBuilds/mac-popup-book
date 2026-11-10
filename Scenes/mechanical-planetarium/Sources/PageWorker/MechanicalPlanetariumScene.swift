import Metal
import PageBehavior
import PopupBookCore
import SceneKit
import simd

final class MechanicalPlanetariumScene {
    private let renderer: SCNRenderer
    private var colorTarget: MTLTexture?
    private var depthTarget: MTLTexture?
    private var viewport = CGSize(width: 1, height: 1)

    private var bracketFolds: [SCNNode] = []
    private var orbitFolds: [SCNNode] = []
    private var bodyFolds: [SCNNode] = []
    private var crankPivot = SCNNode()
    private var sunNode = SCNNode()
    private var earthPivot = SCNNode()
    private var earthSphere = SCNNode()
    private var moonPivot = SCNNode()
    private var moonSphere = SCNNode()
    private var starNodes: [SCNNode] = []
    private let skyCard = SCNNode()
    private let phaseDial = SCNNode()
    private let phaseLight = SCNNode()
    private var phaseBucket = -1
    private var crossbar = SCNNode()
    private var gears: [SCNNode] = []
    private let driveShaft = SCNNode()
    private let earthArm = SCNNode()
    private let moonArm = SCNNode()
    private let phaseSight = SCNNode()
    private var controlButtons: [SCNNode] = []
    private var pauseMark = SCNNode()
    private var resumeMark = SCNNode()
    private var sunLight = SCNNode()

    private static let externalBackground = (red: 0.86, green: 0.89, blue: 0.93)
    private static let skyCardColor = (red: 0.10, green: 0.13, blue: 0.25)

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw PageError.missingResources }
        renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = SCNScene()
        renderer.autoenablesDefaultLighting = false
        buildScene()
    }

    func setViewport(_ size: CGSize) {
        viewport = size
    }

    func pickTarget(x: Double, y: Double) -> MechanicalPlanetariumTapTarget? {
        let point = CGPoint(x: x * viewport.width, y: y * viewport.height)
        let options: [SCNHitTestOption: Any] = [
            .searchMode: SCNHitTestSearchMode.closest.rawValue,
            .boundingBoxOnly: true,
        ]
        guard let hit = renderer.hitTest(point, options: options).first else { return nil }
        let name = hit.node.name ?? hit.node.parent?.name
        switch name {
        case "hit-crank": return .crank
        case "hit-step-back": return .stepBack
        case "hit-step-forward": return .stepForward
        case "hit-pause": return .pauseToggle
        case "hit-observe-0": return .observeNewMoon
        case "hit-observe-1": return .observeFirstQuarter
        case "hit-observe-2": return .observeFullMoon
        default: return nil
        }
    }

    func render(
        into texture: MTLTexture, command: MTLCommandBuffer,
        folding: MechanicalPlanetariumFolding, gameplay: MechanicalPlanetariumGameplay
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
        let backdrop = Self.externalBackground
        pass.colorAttachments[0].clearColor = MTLClearColor(
            red: backdrop.red, green: backdrop.green, blue: backdrop.blue, alpha: 1)
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
        let backdrop = Self.externalBackground
        scene.background.contents = color(backdrop.red, backdrop.green, backdrop.blue)

        buildSkyCard(into: scene)
        buildStars(into: scene)
        buildBase(into: scene)
        buildBrackets(into: scene)
        buildOrbits(into: scene)
        buildBodies(into: scene)
        buildCrank(into: scene)
        buildControls(into: scene)
        buildPhaseDial(into: scene)
        buildDriveGears(into: scene)
        buildTransmission(into: scene)
        buildCameraAndLights(into: scene)
    }

    private func buildSkyCard(into scene: SCNScene) {
        let tint = Self.skyCardColor
        let card = box(
            width: 3.55, height: 1.24, depth: 0.02, color: color(tint.red, tint.green, tint.blue))
        card.position.y = 0.62
        skyCard.position = SCNVector3(0, 0.012, -0.69)
        skyCard.addChildNode(card)
        scene.rootNode.addChildNode(skyCard)
    }

    private func buildStars(into scene: SCNScene) {
        for index in 0..<48 {
            let star = SCNSphere(radius: 0.008 + Double(index % 3) * 0.003)
            star.firstMaterial?.diffuse.contents = color(0.86, 0.9, 1)
            star.firstMaterial?.emission.contents = color(0.4, 0.5, 0.85)
            let node = SCNNode(geometry: star)
            let angle = Double(index) * 0.83
            let radius = 1.6 + Double(index % 5) * 0.08
            node.position = SCNVector3(
                cos(angle) * radius, 0.62 + Double(index % 4) * 0.04, sin(angle) * radius - 0.6)
            node.opacity = 0.45
            starNodes.append(node)
            scene.rootNode.addChildNode(node)
        }
    }

    private func buildBase(into scene: SCNScene) {
        let cover = box(width: 3.72, height: 0.033, depth: 2.32, color: color(0.17, 0.23, 0.33))
        cover.position.y = -0.103
        scene.rootNode.addChildNode(cover)
        let edge = box(width: 3.65, height: 0.022, depth: 2.25, color: color(0.63, 0.50, 0.34))
        edge.position.y = -0.077
        scene.rootNode.addChildNode(edge)
        let plinth = box(width: 3.6, height: 0.06, depth: 2.2, color: color(0.12, 0.14, 0.28))
        plinth.position = SCNVector3(0, -0.04, 0)
        scene.rootNode.addChildNode(plinth)
        let labelPlane = box(width: 1.35, height: 0.02, depth: 0.26, color: color(0.55, 0.42, 0.2))
        labelPlane.position = SCNVector3(0, 0.01, 0.92)
        scene.rootNode.addChildNode(labelPlane)
    }

    private func buildBrackets(into scene: SCNScene) {
        for x in [-1.35, 1.35] {
            let bracket = foldedColumn(height: 0.72, color: color(0.62, 0.48, 0.24))
            bracket.position = SCNVector3(x, 0.02, 0)
            bracketFolds.append(bracket)
            scene.rootNode.addChildNode(bracket)
        }
        crossbar = foldedBar(width: 2.7, color: color(0.68, 0.53, 0.26))
        crossbar.position = SCNVector3(0, 0.64, 0)
        bracketFolds.append(crossbar)
        scene.rootNode.addChildNode(crossbar)
    }

    private func buildOrbits(into scene: SCNScene) {
        let earthRing = orbitRing(
            radius: MechanicalPlanetariumMechanism.earthOrbitRadius, tint: color(0.82, 0.63, 0.31))
        earthRing.position = SCNVector3(0, 0.36, 0)
        orbitFolds.append(earthRing)
        scene.rootNode.addChildNode(earthRing)

        moonPivot.position = SCNVector3(0, 0.36, 0)
        let moonRing = orbitRing(
            radius: MechanicalPlanetariumMechanism.moonOrbitRadius, tint: color(0.91, 0.72, 0.39))
        moonPivot.addChildNode(moonRing)
        orbitFolds.append(moonPivot)
        scene.rootNode.addChildNode(moonPivot)
    }

    private func buildBodies(into scene: SCNScene) {
        let sun = SCNSphere(radius: 0.12)
        sun.firstMaterial?.diffuse.contents = color(0.98, 0.82, 0.34)
        sun.firstMaterial?.emission.contents = color(0.95, 0.72, 0.2)
        sunNode = SCNNode(geometry: sun)
        sunNode.position = SCNVector3(0, 0.36, 0)
        bodyFolds.append(sunNode)
        scene.rootNode.addChildNode(sunNode)

        let earth = SCNSphere(radius: 0.078)
        earth.firstMaterial?.diffuse.contents = enamelMap()
        earthSphere = SCNNode(geometry: earth)
        earthPivot.position = SCNVector3(0, 0.36, 0)
        earthPivot.addChildNode(earthSphere)
        bodyFolds.append(earthPivot)
        scene.rootNode.addChildNode(earthPivot)

        let moon = SCNSphere(radius: 0.037)
        moon.firstMaterial?.diffuse.contents = color(0.78, 0.8, 0.84)
        moon.firstMaterial?.lightingModel = .physicallyBased
        moonSphere = SCNNode(geometry: moon)
        moonPivot.addChildNode(moonSphere)
        bodyFolds.append(moonSphere)
    }

    private func enamelMap() -> NSImage {
        let size = NSSize(width: 384, height: 192)
        let ocean = color(0.09, 0.31, 0.54)
        let land = color(0.37, 0.68, 0.49)
        let ice = color(0.76, 0.87, 0.86)
        return NSImage(size: size, flipped: false) { _ in
            ocean.setFill()
            NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
            let shapes: [[CGPoint]] = [
                [(36, 137), (58, 157), (102, 148), (124, 130), (103, 113), (86, 118), (77, 98), (60, 106)].map
                { CGPoint(x: $0.0, y: $0.1) },
                [(91, 91), (114, 93), (133, 79), (126, 55), (113, 35), (101, 24), (99, 56)].map {
                    CGPoint(x: $0.0, y: $0.1)
                },
                [
                    (173, 127), (192, 147), (228, 138), (250, 150), (303, 141), (329, 120), (296, 107),
                    (270, 112), (246, 94), (229, 117), (204, 116),
                ].map { CGPoint(x: $0.0, y: $0.1) },
                [(183, 108), (208, 112), (232, 89), (214, 66), (198, 49), (189, 66)].map {
                    CGPoint(x: $0.0, y: $0.1)
                },
                [(279, 58), (310, 69), (334, 52), (323, 35), (286, 38)].map { CGPoint(x: $0.0, y: $0.1) },
            ]
            land.setFill()
            for points in shapes {
                let path = NSBezierPath()
                path.move(to: points[0])
                for point in points.dropFirst() { path.line(to: point) }
                path.close()
                path.fill()
            }
            ice.setFill()
            NSBezierPath(rect: NSRect(x: 0, y: 181, width: 384, height: 11)).fill()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: 384, height: 9)).fill()
            return true
        }
    }

    private func buildDriveGears(into scene: SCNScene) {
        for (index, radius) in [0.17, 0.115].enumerated() {
            let gear = SCNNode()
            gear.position = SCNVector3(0.83 + Double(index) * 0.29, 0.20, 0.56)
            let brass = color(0.81, 0.54, 0.25)
            let ring = SCNNode(geometry: SCNTorus(ringRadius: radius * 0.77, pipeRadius: radius * 0.16))
            ring.geometry?.firstMaterial?.diffuse.contents = brass
            ring.eulerAngles.x = .pi / 2
            gear.addChildNode(ring)
            let teeth = index == 0 ? 18 : 12
            for tooth in 0..<teeth {
                let a = Double(tooth) / Double(teeth) * 2 * .pi
                let block = box(width: radius * 0.27, height: radius * 0.23, depth: 0.031, color: brass)
                block.position = SCNVector3(radius * 0.91 * cos(a), radius * 0.91 * sin(a), 0)
                block.eulerAngles.z = CGFloat(a)
                gear.addChildNode(block)
            }
            for spoke in 0..<3 {
                let bar = box(width: 1.52 * radius, height: 0.015, depth: 0.024, color: brass)
                bar.eulerAngles.z = CGFloat(Double(spoke) * .pi / 3)
                gear.addChildNode(bar)
            }
            scene.rootNode.addChildNode(gear)
            gears.append(gear)
        }
    }

    private func buildTransmission(into scene: SCNScene) {
        let brass = color(0.89, 0.65, 0.34)
        let dark = color(0.41, 0.31, 0.18)
        let rail = box(width: 1.94, height: 0.029, depth: 0.062, color: dark)
        rail.position = SCNVector3(0.03, 0.076, 0.46)
        driveShaft.addChildNode(rail)
        for x in [-0.90, 0.0, 0.83] {
            let bearing = box(width: 0.081, height: 0.108, depth: 0.071, color: brass)
            bearing.position = SCNVector3(x, 0.061, 0.46)
            driveShaft.addChildNode(bearing)
        }
        let centralPost = SCNNode(geometry: SCNCylinder(radius: 0.024, height: 0.29))
        centralPost.geometry?.firstMaterial?.diffuse.contents = brass
        centralPost.position = SCNVector3(0, 0.154, 0)
        driveShaft.addChildNode(centralPost)
        for node in [driveShaft, earthArm, moonArm, phaseSight] { scene.rootNode.addChildNode(node) }
        for (node, tint) in [(earthArm, brass), (moonArm, brass), (phaseSight, color(0.91, 0.75, 0.43))] {
            let rod = box(width: node === phaseSight ? 0.008 : 0.018, height: 0.012, depth: 1, color: tint)
            rod.geometry?.firstMaterial?.emission.contents = color(0.13, 0.08, 0.03)
            node.addChildNode(rod)
        }
    }

    private func connect(_ node: SCNNode, from: SIMD3<Double>, to: SIMD3<Double>, inset: Double) {
        let difference = to - from
        let span = simd_length(difference)
        guard span > inset else {
            node.isHidden = true
            return
        }
        let center = (from + to) / 2
        node.position = SCNVector3(center.x, center.y, center.z)
        node.look(at: SCNVector3(to.x, to.y, to.z))
        node.childNodes.first?.scale.z = span - inset
    }

    private func buildCrank(into scene: SCNScene) {
        crankPivot.position = SCNVector3(1.12, 0.19, 0.64)
        let axle = SCNCylinder(radius: 0.035, height: 0.12)
        axle.firstMaterial?.diffuse.contents = color(0.62, 0.48, 0.24)
        let axleNode = SCNNode(geometry: axle)
        axleNode.eulerAngles.x = .pi / 2
        crankPivot.addChildNode(axleNode)

        let rod = box(width: 0.02, height: 0.18, depth: 0.02, color: color(0.91, 0.72, 0.39))
        rod.position = SCNVector3(0, 0.09, 0.062)
        crankPivot.addChildNode(rod)

        let knobGeometry = SCNSphere(radius: 0.04)
        knobGeometry.firstMaterial?.diffuse.contents = color(0.78, 0.6, 0.3)
        let knob = SCNNode(geometry: knobGeometry)
        knob.position = SCNVector3(0, 0.09, 0.025)
        rod.addChildNode(knob)

        let hit = box(width: 0.32, height: 0.44, depth: 0.44, color: .clear)
        hit.opacity = 0.001
        hit.name = "hit-crank"
        hit.position = SCNVector3(0.065, 0, 0)
        crankPivot.addChildNode(hit)
        bodyFolds.append(crankPivot)
        scene.rootNode.addChildNode(crankPivot)
    }

    private func buildControls(into scene: SCNScene) {
        let entries: [(String, String, Double)] = [
            ("hit-step-back", "‹", -1.30), ("hit-pause", "Ⅱ", -1.00), ("hit-step-forward", "›", -0.70),
            ("hit-observe-0", "○", 0.94), ("hit-observe-1", "◐", 1.24), ("hit-observe-2", "●", 1.54),
        ]
        for (name, glyph, x) in entries {
            let button = box(width: 0.25, height: 0.035, depth: 0.19, color: color(0.74, 0.52, 0.26))
            button.name = name
            button.position = SCNVector3(x, 0.022, 0.87)
            let inset = box(width: 0.218, height: 0.008, depth: 0.157, color: color(0.86, 0.69, 0.43))
            inset.position.y = 0.019
            inset.name = name
            button.addChildNode(inset)
            let mark = controlGlyph(glyph)
            button.addChildNode(mark)
            if name == "hit-pause" {
                pauseMark = mark
                resumeMark = controlGlyph("›")
                button.addChildNode(resumeMark)
            }
            controlButtons.append(button)
            scene.rootNode.addChildNode(button)
        }
    }

    private func controlGlyph(_ glyph: String) -> SCNNode {
        let text = SCNText(string: glyph, extrusionDepth: 0)
        text.font = .systemFont(ofSize: 20, weight: .semibold)
        text.flatness = 0.1
        text.firstMaterial?.diffuse.contents = color(0.16, 0.20, 0.27)
        text.firstMaterial?.lightingModel = .constant
        let node = SCNNode(geometry: text)
        let (min, max) = node.boundingBox
        let scale = 0.076 / Swift.max(1, max.y - min.y)
        node.pivot = SCNMatrix4MakeTranslation((min.x + max.x) / 2, (min.y + max.y) / 2, 0)
        node.scale = SCNVector3(scale, scale, scale)
        node.position.y = 0.025
        node.eulerAngles.x = -.pi / 2
        return node
    }

    private func buildPhaseDial(into scene: SCNScene) {
        phaseDial.position = SCNVector3(-1.06, 0.36, 0.63)
        phaseDial.scale = SCNVector3(1.17, 1.17, 1.17)
        let hinge = box(width: 0.45, height: 0.035, depth: 0.12, color: color(0.72, 0.54, 0.29))
        hinge.position = SCNVector3(-1.02, 0.023, 0.63)
        scene.rootNode.addChildNode(hinge)
        let support = box(width: 0.038, height: 0.35, depth: 0.028, color: color(0.78, 0.58, 0.31))
        support.position.y = -0.17
        phaseDial.addChildNode(support)
        let disk = SCNCylinder(radius: 0.234, height: 0.021)
        disk.firstMaterial?.lightingModel = .constant
        disk.firstMaterial?.diffuse.contents = color(0.73, 0.54, 0.29)
        let rim = SCNNode(geometry: disk)
        rim.eulerAngles.x = .pi / 2
        phaseDial.addChildNode(rim)
        let shade = SCNCylinder(radius: 0.195, height: 0.013)
        shade.firstMaterial?.lightingModel = .constant
        shade.firstMaterial?.diffuse.contents = color(0.105, 0.13, 0.20)
        let face = SCNNode(geometry: shade)
        face.position.z = 0.014
        face.eulerAngles.x = .pi / 2
        phaseDial.addChildNode(face)
        phaseLight.position.z = 0.025
        phaseDial.addChildNode(phaseLight)
        scene.rootNode.addChildNode(phaseDial)
    }

    private func updatePhaseDial(_ mechanism: MechanicalPlanetariumMechanism, folding: Double) {
        phaseDial.isHidden = folding < 0.13
        phaseDial.position.y = CGFloat(0.035 + 0.325 * folding)
        phaseDial.eulerAngles.x = CGFloat(0.25 - (1 - folding) * .pi / 2)
        let cycle = mechanism.moonElongation.truncatingRemainder(dividingBy: 2 * .pi)
        let angle = cycle < 0 ? cycle + 2 * .pi : cycle
        let bucket = Int((angle / (2 * .pi) * 96).rounded()) % 96
        guard bucket != phaseBucket else { return }
        phaseBucket = bucket
        let phase = Double(bucket) / 96 * 2 * .pi
        phaseLight.isHidden = bucket == 0
        guard bucket != 0 else { return }

        // 在地球看到的月盘，右亮为盈、左亮为亏。终止线为随相位变化的半椭圆。
        let outline = NSBezierPath()
        let radius = 0.195
        let side = bucket <= 48 ? 1.0 : -1.0
        outline.move(to: CGPoint(x: 0, y: radius))
        for i in 1...32 {
            let theta = Double(i) / 32 * .pi
            outline.line(to: CGPoint(x: side * radius * sin(theta), y: radius * cos(theta)))
        }
        for i in 1...32 {
            let theta = Double(i) / 32 * .pi
            outline.line(to: CGPoint(x: side * radius * sin(theta) * cos(phase), y: -radius * cos(theta)))
        }
        outline.close()
        let face = SCNShape(path: outline, extrusionDepth: 0)
        face.firstMaterial?.lightingModel = .constant
        face.firstMaterial?.diffuse.contents = color(0.97, 0.89, 0.69)
        face.firstMaterial?.isDoubleSided = true
        phaseLight.geometry = face
    }

    private func buildCameraAndLights(into scene: SCNScene) {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 1.74
        camera.zNear = 0.05
        camera.zFar = 20
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0.48, 3.35, 7.4)
        cameraNode.look(at: SCNVector3(0, 0.3, 0))
        scene.rootNode.addChildNode(cameraNode)
        renderer.pointOfView = cameraNode

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 385
        ambient.light?.color = color(0.78, 0.83, 0.95)
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 290
        key.light?.castsShadow = true
        key.light?.shadowMode = .deferred
        key.light?.shadowRadius = 3
        key.light?.shadowColor = color(0.04, 0.05, 0.08).withAlphaComponent(0.20)
        key.light?.color = color(1, 0.89, 0.71)
        key.eulerAngles = SCNVector3(-0.48, -0.40, 0)
        scene.rootNode.addChildNode(key)

        sunLight.light = SCNLight()
        sunLight.light?.type = .omni
        sunLight.light?.intensity = 1100
        sunLight.light?.attenuationStartDistance = 0.1
        sunLight.light?.attenuationEndDistance = 4
        sunNode.addChildNode(sunLight)
    }

    private func update(folding: MechanicalPlanetariumFolding, gameplay: MechanicalPlanetariumGameplay) {
        let mechanism = gameplay.mechanism
        for node in bracketFolds { setFold(node, amount: folding.brackets) }
        crossbar.position.y = CGFloat(0.02 + 0.62 * folding.brackets)
        updatePhaseDial(mechanism, folding: folding.bodies)
        for (index, gear) in gears.enumerated() {
            gear.isHidden = folding.brackets < 0.14
            gear.position.y = CGFloat(0.07 + (index == 0 ? 0.17 : 0.12) * folding.brackets)
            gear.eulerAngles.z = CGFloat(mechanism.crankAngle * (index == 0 ? 1 : -1.5))
        }
        for button in controlButtons { button.isHidden = !gameplay.canInteract }
        pauseMark.isHidden = gameplay.isPaused
        resumeMark.isHidden = !gameplay.isPaused
        for node in orbitFolds {
            setFold(node, amount: folding.orbits)
            node.isHidden = folding.orbits < 0.08
        }
        for node in bodyFolds {
            if node === crankPivot {
                node.isHidden = folding.crank < 0.12
            } else {
                setFold(node, amount: folding.bodies)
                node.isHidden = folding.bodies < 0.12
            }
        }

        setFold(skyCard, amount: folding.backdrop)
        skyCard.isHidden = folding.backdrop < 0.04

        for (index, star) in starNodes.enumerated() {
            let twinkle = 0.35 + 0.25 * sin(mechanism.turns * 4 + Double(index))
            star.opacity = CGFloat(folding.backdrop * twinkle)
        }

        crankPivot.eulerAngles.z = CGFloat(-1.5 * mechanism.crankAngle)

        let earth = mechanism.earthPosition()
        earthSphere.position = SCNVector3(
            earth.x - earthPivot.position.x, earth.y - earthPivot.position.y, earth.z - earthPivot.position.z)
        earthSphere.eulerAngles.y = CGFloat(mechanism.earthSpinAngle)

        let moon = mechanism.moonPosition()
        moonPivot.position = SCNVector3(earth.x, earth.y, earth.z)
        moonSphere.position = SCNVector3(
            moon.x - moonPivot.position.x, moon.y - moonPivot.position.y, moon.z - moonPivot.position.z)

        let earthFoot = SIMD3(earth.x, earth.y - 0.093, earth.z)
        let moonFoot = SIMD3(moon.x, moon.y - 0.053, moon.z)
        driveShaft.scale.y = max(0.001, folding.brackets)
        driveShaft.isHidden = folding.brackets < 0.08
        earthArm.isHidden = folding.bodies < 0.92
        moonArm.isHidden = folding.bodies < 0.92
        phaseSight.isHidden = folding.bodies < 0.92 || !gameplay.isPaused
        connect(earthArm, from: SIMD3(0, 0.267, 0), to: earthFoot, inset: 0)
        connect(moonArm, from: earthFoot, to: moonFoot, inset: 0)
        connect(phaseSight, from: SIMD3(-0.82, 0.31, 0.58), to: moonFoot, inset: 0.06)
        sunLight.position = SCNVector3(0, 0, 0)

        let highlight = gameplay.canInteract
        if !highlight {
            crankPivot.opacity = 0.55
        } else if gameplay.isPaused {
            crankPivot.opacity = 0.62
        } else {
            crankPivot.opacity = 1
        }
    }

    private func setFold(_ node: SCNNode, amount: Double) {
        node.eulerAngles.x = -CGFloat((1 - amount) * .pi / 2)
    }

    private func foldedColumn(height: Double, color: NSColor) -> SCNNode {
        let pivot = SCNNode()
        let column = box(width: 0.08, height: height, depth: 0.08, color: color)
        column.position.y = height / 2
        pivot.addChildNode(column)
        return pivot
    }

    private func foldedBar(width: Double, color: NSColor) -> SCNNode {
        let pivot = SCNNode()
        let bar = box(width: width, height: 0.05, depth: 0.05, color: color)
        bar.position.y = 0.025
        pivot.addChildNode(bar)
        return pivot
    }

    private func orbitRing(radius: Double, tint: NSColor) -> SCNNode {
        let torus = SCNTorus(ringRadius: radius, pipeRadius: 0.009)
        torus.firstMaterial?.diffuse.contents = tint
        torus.firstMaterial?.metalness.contents = 0.22
        torus.firstMaterial?.emission.contents = color(0.16, 0.11, 0.04)
        return SCNNode(geometry: torus)
    }

    private func box(width: Double, height: Double, depth: Double, color: NSColor) -> SCNNode {
        let geometry = SCNBox(width: width, height: height, length: depth, chamferRadius: 0.003)
        geometry.firstMaterial?.diffuse.contents = color
        return SCNNode(geometry: geometry)
    }

    private func color(_ red: Double, _ green: Double, _ blue: Double) -> NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }
}
