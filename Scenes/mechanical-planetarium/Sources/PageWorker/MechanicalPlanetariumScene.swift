import Metal
import PageBehavior
import PopupBookCore
import SceneKit

final class MechanicalPlanetariumScene {
    private let renderer: SCNRenderer
    private var colorTarget: MTLTexture?
    private var depthTarget: MTLTexture?
    private var viewport = CGSize(width: 1, height: 1)

    private var bracketFolds: [SCNNode] = []
    private var orbitFolds: [SCNNode] = []
    private var bodyFolds: [SCNNode] = []
    private var crankPivot = SCNNode()
    private var crankHandle = SCNNode()
    private var sunNode = SCNNode()
    private var earthPivot = SCNNode()
    private var earthSphere = SCNNode()
    private var moonPivot = SCNNode()
    private var moonSphere = SCNNode()
    private var starNodes: [SCNNode] = []
    private var skyCard = SCNNode()
    private var sunLight = SCNNode()

    private static let externalBackground = (red: 0.86, green: 0.89, blue: 0.93)
    private static let skyCardColor = (red: 0.06, green: 0.08, blue: 0.18)

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
        buildCameraAndLights(into: scene)
    }

    private func buildSkyCard(into scene: SCNScene) {
        let tint = Self.skyCardColor
        skyCard = box(
            width: 3.55, height: 1.5, depth: 0.02, color: color(tint.red, tint.green, tint.blue))
        skyCard.position = SCNVector3(0, 0.44, -0.62)
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
        let crossbar = foldedBar(width: 2.7, color: color(0.68, 0.53, 0.26))
        crossbar.position = SCNVector3(0, 0.64, 0)
        bracketFolds.append(crossbar)
        scene.rootNode.addChildNode(crossbar)
    }

    private func buildOrbits(into scene: SCNScene) {
        let earthRing = orbitRing(
            radius: MechanicalPlanetariumMechanism.earthOrbitRadius, tint: color(0.58, 0.44, 0.22))
        earthRing.position = SCNVector3(0, 0.36, 0)
        orbitFolds.append(earthRing)
        scene.rootNode.addChildNode(earthRing)

        moonPivot.position = SCNVector3(0, 0.36, 0)
        let moonRing = orbitRing(
            radius: MechanicalPlanetariumMechanism.moonOrbitRadius, tint: color(0.72, 0.56, 0.28))
        moonPivot.addChildNode(moonRing)
        orbitFolds.append(moonPivot)
        scene.rootNode.addChildNode(moonPivot)
    }

    private func buildBodies(into scene: SCNScene) {
        let sun = SCNSphere(radius: 0.09)
        sun.firstMaterial?.diffuse.contents = color(0.98, 0.82, 0.34)
        sun.firstMaterial?.emission.contents = color(0.95, 0.72, 0.2)
        sunNode = SCNNode(geometry: sun)
        sunNode.position = SCNVector3(0, 0.36, 0)
        bodyFolds.append(sunNode)
        scene.rootNode.addChildNode(sunNode)

        let earth = SCNSphere(radius: 0.055)
        earth.firstMaterial?.diffuse.contents = color(0.28, 0.5, 0.72)
        earthSphere = SCNNode(geometry: earth)
        earthPivot.position = SCNVector3(0, 0.36, 0)
        earthPivot.addChildNode(earthSphere)
        bodyFolds.append(earthPivot)
        scene.rootNode.addChildNode(earthPivot)

        let moon = SCNSphere(radius: 0.028)
        moon.firstMaterial?.diffuse.contents = color(0.78, 0.8, 0.84)
        moon.firstMaterial?.lightingModel = .physicallyBased
        moonSphere = SCNNode(geometry: moon)
        moonPivot.addChildNode(moonSphere)
        bodyFolds.append(moonPivot)
    }

    private func buildCrank(into scene: SCNScene) {
        crankPivot.position = SCNVector3(1.1, 0.1, 0.68)
        let axle = SCNCylinder(radius: 0.035, height: 0.12)
        axle.firstMaterial?.diffuse.contents = color(0.62, 0.48, 0.24)
        let axleNode = SCNNode(geometry: axle)
        axleNode.eulerAngles.z = .pi / 2
        crankPivot.addChildNode(axleNode)

        let rod = box(width: 0.18, height: 0.02, depth: 0.02, color: color(0.72, 0.56, 0.28))
        rod.position = SCNVector3(0.09, 0, 0)
        crankHandle = rod
        crankPivot.addChildNode(rod)

        let knobGeometry = SCNSphere(radius: 0.04)
        knobGeometry.firstMaterial?.diffuse.contents = color(0.78, 0.6, 0.3)
        let knob = SCNNode(geometry: knobGeometry)
        knob.position = SCNVector3(0.18, 0, 0)
        rod.addChildNode(knob)

        let hit = box(width: 0.5, height: 0.22, depth: 0.28, color: .clear)
        hit.opacity = 0.001
        hit.name = "hit-crank"
        hit.position = SCNVector3(0.08, 0.05, 0)
        crankPivot.addChildNode(hit)
        bodyFolds.append(crankPivot)
        scene.rootNode.addChildNode(crankPivot)
    }

    private func buildControls(into scene: SCNScene) {
        let back = controlHit(
            name: "hit-step-back", position: SCNVector3(-1.2, 0.12, 0.82), tint: color(0.42, 0.34, 0.22))
        let forward = controlHit(
            name: "hit-step-forward", position: SCNVector3(-0.62, 0.12, 0.82), tint: color(0.42, 0.34, 0.22))
        let pause = controlHit(
            name: "hit-pause", position: SCNVector3(-0.91, 0.12, 0.82), tint: color(0.5, 0.38, 0.2))
        scene.rootNode.addChildNode(back)
        scene.rootNode.addChildNode(forward)
        scene.rootNode.addChildNode(pause)

        let markers: [(String, SCNVector3)] = [
            ("hit-observe-0", SCNVector3(0.95, 0.14, 0.82)),
            ("hit-observe-1", SCNVector3(1.28, 0.14, 0.82)),
            ("hit-observe-2", SCNVector3(1.61, 0.14, 0.82)),
        ]
        for (name, position) in markers {
            let marker = controlHit(name: name, position: position, tint: color(0.55, 0.42, 0.2))
            scene.rootNode.addChildNode(marker)
        }
    }

    private func controlHit(name: String, position: SCNVector3, tint: NSColor) -> SCNNode {
        let base = box(width: 0.26, height: 0.06, depth: 0.2, color: tint)
        base.position = position
        let hit = box(width: 0.3, height: 0.16, depth: 0.24, color: .clear)
        hit.opacity = 0.001
        hit.name = name
        hit.position = SCNVector3(0, 0.06, 0)
        base.addChildNode(hit)
        return base
    }

    private func buildCameraAndLights(into scene: SCNScene) {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 2.35
        camera.zNear = 0.05
        camera.zFar = 20
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 2.35, 7.4)
        cameraNode.look(at: SCNVector3(0, 0.3, 0))
        scene.rootNode.addChildNode(cameraNode)
        renderer.pointOfView = cameraNode

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 180
        ambient.light?.color = color(0.5, 0.58, 0.85)
        scene.rootNode.addChildNode(ambient)

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
        for node in orbitFolds {
            setFold(node, amount: folding.orbits)
            node.isHidden = folding.orbits < 0.08
        }
        for node in bodyFolds {
            let amount = node === crankPivot ? folding.crank : folding.bodies
            if node === crankPivot {
                node.isHidden = folding.crank < 0.12
            } else {
                setFold(node, amount: folding.bodies)
                node.isHidden = folding.bodies < 0.12
            }
            _ = amount
        }

        setFold(skyCard, amount: folding.backdrop)
        skyCard.isHidden = folding.backdrop < 0.04

        for (index, star) in starNodes.enumerated() {
            let twinkle = 0.35 + 0.25 * sin(mechanism.turns * 4 + Double(index))
            star.opacity = CGFloat(folding.backdrop * twinkle)
        }

        crankPivot.eulerAngles.x = CGFloat(mechanism.crankAngle)

        let earth = mechanism.earthPosition()
        earthSphere.position = SCNVector3(
            earth.x - earthPivot.position.x, earth.y - earthPivot.position.y, earth.z - earthPivot.position.z)
        earthSphere.eulerAngles.y = CGFloat(mechanism.earthSpinAngle)

        let moon = mechanism.moonPosition()
        moonPivot.position = SCNVector3(earth.x, earth.y, earth.z)
        moonSphere.position = SCNVector3(
            moon.x - moonPivot.position.x, moon.y - moonPivot.position.y, moon.z - moonPivot.position.z)

        sunLight.position = SCNVector3(0, 0, 0)

        let highlight = gameplay.canInteract
        crankPivot.opacity = highlight ? 1 : 0.55
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
        let torus = SCNTorus(ringRadius: radius, pipeRadius: 0.004)
        torus.firstMaterial?.diffuse.contents = tint
        torus.firstMaterial?.metalness.contents = 0.75
        let node = SCNNode(geometry: torus)
        node.eulerAngles.x = .pi / 2
        return node
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
