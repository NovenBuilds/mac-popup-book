import Metal
import PageBehavior
import PopupBookCore
import SceneKit

private final class TrackSegment {
    let length: Double
    let piece: SCNNode

    init(from start: SIMD2<Double>, to end: SIMD2<Double>, width: Double, height: Double, color: NSColor) {
        let delta = end - start
        length = (delta.x * delta.x + delta.y * delta.y).squareRoot()
        let geometry = SCNBox(width: width, height: height, length: 1, chamferRadius: 0)
        geometry.firstMaterial?.diffuse.contents = color
        piece = SCNNode(geometry: geometry)
        let pivot = SCNNode()
        pivot.position = SCNVector3(start.x, 0.025, start.y)
        pivot.eulerAngles.y = atan2(delta.x, delta.y)
        pivot.addChildNode(piece)
        piece.name = "track-piece"
        pivot.name = "track-segment"
        self.pivot = pivot
    }

    let pivot: SCNNode

    func update(_ amount: Double) {
        let amount = max(0.001, min(1, amount))
        piece.scale.z = amount
        piece.position.z = length * amount / 2
    }
}

final class PocketTownScene {
    private let renderer: SCNRenderer
    private var colorTarget: MTLTexture?
    private var depthTarget: MTLTexture?
    private var houseFolds: [SCNNode] = []
    private var bridgeFolds: [SCNNode] = []
    private var towerFolds: [SCNNode] = []
    private var canopyFolds: [SCNNode] = []
    private var routeSegments: [TrackSegment] = []

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw PageError.missingResources }
        renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = SCNScene()
        renderer.autoenablesDefaultLighting = false
        buildScene()
    }

    func render(into texture: MTLTexture, command: MTLCommandBuffer, folding: PocketTownFolding) throws {
        update(folding)
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
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0.93, green: 0.89, blue: 0.8, alpha: 1)
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
        scene.background.contents = NSColor(calibratedRed: 0.93, green: 0.89, blue: 0.8, alpha: 1)

        let ground = box(width: 3.8, height: 0.04, depth: 2.4, color: color(0.72, 0.69, 0.6))
        ground.position.y = -0.03
        scene.rootNode.addChildNode(ground)
        let spine = box(width: 0.018, height: 0.045, depth: 2.4, color: color(0.48, 0.45, 0.38))
        scene.rootNode.addChildNode(spine)

        addRoute(
            [
                SIMD2(-0.32, -1.12), SIMD2(-0.43, -0.63), SIMD2(-0.28, -0.2),
                SIMD2(-0.05, 0.22), SIMD2(-0.15, 0.7), SIMD2(-0.06, 1.12),
            ], width: 0.28, height: 0.018, color: color(0.4, 0.54, 0.61))
        addRoute(
            [
                SIMD2(-1.48, -0.58), SIMD2(-1.0, -0.9), SIMD2(-0.34, -0.98),
                SIMD2(0.35, -0.9), SIMD2(0.94, -0.63), SIMD2(1.28, -0.16),
                SIMD2(1.08, 0.43), SIMD2(0.5, 0.6), SIMD2(-0.12, 0.37),
                SIMD2(-0.52, -0.12), SIMD2(-1.0, -0.18), SIMD2(-1.48, -0.58),
            ], width: 0.025, height: 0.022, color: color(0.28, 0.26, 0.23))
        addRoute(
            [
                SIMD2(-1.52, -0.38), SIMD2(-1.18, 0.18), SIMD2(-0.63, 0.48),
                SIMD2(-0.08, 0.74), SIMD2(0.42, 0.75), SIMD2(0.88, 0.52),
                SIMD2(1.14, 0.13), SIMD2(0.88, -0.24), SIMD2(0.42, -0.38),
                SIMD2(-0.1, -0.3), SIMD2(-0.68, -0.13), SIMD2(-1.52, -0.38),
            ], width: 0.025, height: 0.024, color: color(0.6, 0.43, 0.17))

        let platform = box(width: 0.68, height: 0.035, depth: 0.26, color: color(0.36, 0.33, 0.28))
        platform.position = SCNVector3(-1.33, 0.02, -0.25)
        scene.rootNode.addChildNode(platform)
        let towerFoot = box(width: 0.46, height: 0.03, depth: 0.32, color: color(0.36, 0.33, 0.28))
        towerFoot.position = SCNVector3(0.1, 0.02, -0.15)
        scene.rootNode.addChildNode(towerFoot)

        buildBridge()
        buildStation()
        buildTower()
        buildHouses()
        buildCameraAndLights()
    }

    private func addRoute(_ points: [SIMD2<Double>], width: Double, height: Double, color: NSColor) {
        guard let scene = renderer.scene else { return }
        for index in points.indices.dropLast() {
            let segment = TrackSegment(
                from: points[index], to: points[index + 1], width: width, height: height,
                color: color)
            segment.update(0)
            routeSegments.append(segment)
            scene.rootNode.addChildNode(segment.pivot)
        }
    }

    private func buildBridge() {
        guard let scene = renderer.scene else { return }
        let deck = box(width: 1.0, height: 0.04, depth: 0.22, color: color(0.5, 0.37, 0.22))
        deck.position = SCNVector3(-0.17, 0.06, 0.02)
        scene.rootNode.addChildNode(deck)
        for z in [-0.09, 0.13] {
            let rail = foldedBox(
                width: 1.0, height: 0.16, depth: 0.035, color: color(0.31, 0.24, 0.17))
            rail.position = SCNVector3(-0.17, 0.08, z)
            bridgeFolds.append(rail)
            scene.rootNode.addChildNode(rail)
        }
    }

    private func buildStation() {
        guard let scene = renderer.scene else { return }
        let body = foldedBuilding(
            x: -1.38, z: -0.12, width: 0.48, height: 0.38, depth: 0.1,
            wall: color(0.48, 0.47, 0.43), roof: color(0.3, 0.27, 0.23))
        houseFolds.append(body)
        scene.rootNode.addChildNode(body)

        let canopy = SCNNode()
        canopy.position = SCNVector3(-1.38, 0.41, -0.12)
        let roof = box(width: 0.72, height: 0.035, depth: 0.42, color: color(0.58, 0.43, 0.18))
        roof.position.z = 0.2
        canopy.addChildNode(roof)
        canopyFolds.append(canopy)
        scene.rootNode.addChildNode(canopy)
    }

    private func buildTower() {
        guard let scene = renderer.scene else { return }
        let tower = foldedBuilding(
            x: 0.1, z: -0.08, width: 0.34, height: 0.82, depth: 0.1,
            wall: color(0.46, 0.41, 0.35), roof: color(0.32, 0.25, 0.19))
        guard let wall = tower.childNodes.first else { return }
        let face = SCNNode(geometry: SCNCylinder(radius: 0.105, height: 0.025))
        face.geometry?.firstMaterial?.diffuse.contents = color(0.84, 0.78, 0.58)
        face.eulerAngles.x = .pi / 2
        face.position = SCNVector3(0, 0.19, 0.065)
        wall.addChildNode(face)
        let hand = box(width: 0.018, height: 0.12, depth: 0.012, color: color(0.25, 0.22, 0.18))
        hand.position = SCNVector3(0, 0.19, 0.085)
        wall.addChildNode(hand)
        towerFolds.append(tower)
        scene.rootNode.addChildNode(tower)
    }

    private func buildHouses() {
        guard let scene = renderer.scene else { return }
        let houses = [
            foldedBuilding(
                x: 0.88, z: 0.28, width: 0.34, height: 0.34, depth: 0.1,
                wall: color(0.58, 0.36, 0.3), roof: color(0.35, 0.24, 0.2)),
            foldedBuilding(
                x: 1.24, z: 0.12, width: 0.3, height: 0.44, depth: 0.1,
                wall: color(0.39, 0.5, 0.54), roof: color(0.25, 0.31, 0.34)),
            foldedBuilding(
                x: 1.04, z: -0.44, width: 0.4, height: 0.28, depth: 0.1,
                wall: color(0.58, 0.53, 0.38), roof: color(0.37, 0.31, 0.2)),
        ]
        houseFolds += houses
        for house in houses { scene.rootNode.addChildNode(house) }
    }

    private func buildCameraAndLights() {
        guard let scene = renderer.scene else { return }
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 2.45
        camera.zNear = 0.1
        camera.zFar = 20
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 2.2, 7.2)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        renderer.pointOfView = cameraNode

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 420
        scene.rootNode.addChildNode(ambient)
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 520
        key.eulerAngles = SCNVector3(-0.8, -0.45, 0)
        scene.rootNode.addChildNode(key)
    }

    private func update(_ folding: PocketTownFolding) {
        for segment in routeSegments { segment.update(folding.routes) }
        for node in houseFolds { setFold(node, amount: folding.houses) }
        for node in bridgeFolds { setFold(node, amount: folding.bridge) }
        for node in towerFolds { setFold(node, amount: folding.tower) }
        for node in canopyFolds { setFold(node, amount: folding.stationCanopy) }
    }

    private func setFold(_ node: SCNNode, amount: Double) {
        node.eulerAngles.x = -CGFloat((1 - amount) * .pi / 2)
    }

    private func foldedBuilding(
        x: Double, z: Double, width: Double, height: Double, depth: Double, wall: NSColor,
        roof: NSColor
    ) -> SCNNode {
        let pivot = foldedBox(width: width, height: height, depth: depth, color: wall)
        pivot.position = SCNVector3(x, 0.02, z)
        guard let wallNode = pivot.childNodes.first else { return pivot }
        let roofNode = box(width: width + 0.08, height: 0.045, depth: depth + 0.08, color: roof)
        roofNode.position.y = height / 2 + 0.03
        wallNode.addChildNode(roofNode)
        for xOffset in [-width * 0.22, width * 0.22] {
            let window = box(width: 0.055, height: 0.075, depth: 0.012, color: color(0.82, 0.78, 0.6))
            window.position = SCNVector3(xOffset, -height * 0.05, depth / 2 + 0.008)
            wallNode.addChildNode(window)
        }
        return pivot
    }

    private func foldedBox(width: Double, height: Double, depth: Double, color: NSColor) -> SCNNode {
        let pivot = SCNNode()
        let wall = box(width: width, height: height, depth: depth, color: color)
        wall.position.y = height / 2
        pivot.addChildNode(wall)
        return pivot
    }

    private func box(width: Double, height: Double, depth: Double, color: NSColor) -> SCNNode {
        let geometry = SCNBox(width: width, height: height, length: depth, chamferRadius: 0.004)
        geometry.firstMaterial?.diffuse.contents = color
        return SCNNode(geometry: geometry)
    }

    private func color(_ red: Double, _ green: Double, _ blue: Double) -> NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }
}
