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
        piece.isHidden = amount < 0.004
        let extent = length * max(0.001, min(1, amount))
        piece.scale.z = extent
        piece.position.z = extent / 2
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
    private var spineSegments: [TrackSegment] = []
    private var riversideSegments: [TrackSegment] = []
    private var clockSegments: [TrackSegment] = []
    private let trainNode = SCNNode()
    private var wheels: [SCNNode] = []
    private let clockHand = SCNNode()
    private let riverFlag = SCNNode()
    private let signalLamp = SCNNode()
    private var switchNode = SCNNode()
    private var switchBlade = SCNNode()
    private var viewport = CGSize(width: 1, height: 1)

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

    func pickTarget(x: Double, y: Double) -> PocketTownTapTarget? {
        let point = CGPoint(x: x * viewport.width, y: y * viewport.height)
        let options: [SCNHitTestOption: Any] = [
            .searchMode: SCNHitTestSearchMode.closest.rawValue,
            .boundingBoxOnly: true,
        ]
        guard let hit = renderer.hitTest(point, options: options).first else { return nil }
        switch hit.node.name ?? hit.node.parent?.name {
        case "hit-station": return .station
        case "hit-switch": return .switchRail
        default: return nil
        }
    }

    func render(
        into texture: MTLTexture, command: MTLCommandBuffer,
        folding: PocketTownFolding, gameplay: PocketTownGameplay
    ) throws {
        update(folding, gameplay: gameplay)
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

        let cover = box(width: 3.93, height: 0.035, depth: 2.49, color: color(0.27, 0.39, 0.36))
        cover.position.y = -0.079
        scene.rootNode.addChildNode(cover)
        let pageEdges = box(width: 3.86, height: 0.029, depth: 2.44, color: color(0.78, 0.68, 0.48))
        pageEdges.position.y = -0.052
        scene.rootNode.addChildNode(pageEdges)
        let ground = box(width: 3.8, height: 0.04, depth: 2.4, color: color(0.91, 0.84, 0.67))
        ground.position.y = -0.03
        scene.rootNode.addChildNode(ground)
        let spine = box(width: 0.018, height: 0.045, depth: 2.4, color: color(0.48, 0.45, 0.38))
        scene.rootNode.addChildNode(spine)

        addRoute(
            pocketPoints(PocketTownTracks.approachSpine), width: 0.028, height: 0.018,
            color: color(0.4, 0.54, 0.61), bucket: .spine)
        addRoute(
            pocketPoints(PocketTownTracks.riversideLoop), width: 0.025, height: 0.022,
            color: color(0.28, 0.26, 0.23), bucket: .riverside)
        addRoute(
            pocketPoints(PocketTownTracks.loopLinks(route: .riverside)), width: 0.025, height: 0.022,
            color: color(0.28, 0.26, 0.23), bucket: .riverside)
        addRoute(
            pocketPoints(PocketTownTracks.clockLoop), width: 0.025, height: 0.024,
            color: color(0.6, 0.43, 0.17), bucket: .clock)
        addRoute(
            pocketPoints(PocketTownTracks.loopLinks(route: .clockTower)), width: 0.025, height: 0.024,
            color: color(0.6, 0.43, 0.17), bucket: .clock)

        let platform = box(width: 0.68, height: 0.035, depth: 0.26, color: color(0.36, 0.33, 0.28))
        platform.position = SCNVector3(-1.33, 0.02, -0.25)
        scene.rootNode.addChildNode(platform)
        let towerFoot = box(width: 0.46, height: 0.03, depth: 0.32, color: color(0.36, 0.33, 0.28))
        towerFoot.position = SCNVector3(0.1, 0.02, -0.15)
        scene.rootNode.addChildNode(towerFoot)

        buildRiver()
        buildBridge()
        buildStation()
        buildTower()
        buildHouses()
        buildTrainAndSwitch()
        buildCameraAndLights()
    }

    private enum RouteBucket { case spine, riverside, clock }

    private func addRoute(
        _ points: [SIMD2<Double>], width: Double, height: Double, color: NSColor, bucket: RouteBucket
    ) {
        guard let scene = renderer.scene else { return }
        for index in points.indices.dropLast() {
            let segment = TrackSegment(
                from: points[index], to: points[index + 1], width: width, height: height,
                color: color)
            segment.update(0)
            switch bucket {
            case .spine: spineSegments.append(segment)
            case .riverside: riversideSegments.append(segment)
            case .clock: clockSegments.append(segment)
            }
            scene.rootNode.addChildNode(segment.pivot)
        }
    }

    private func buildRiver() {
        guard let scene = renderer.scene else { return }
        let paper = box(width: 0.34, height: 0.004, depth: 2.32, color: color(0.23, 0.57, 0.63))
        paper.position = SCNVector3(-0.25, -0.007, 0)
        scene.rootNode.addChildNode(paper)
        for index in 0..<11 {
            let ripple = box(
                width: 0.05 + Double(index % 3) * 0.025, height: 0.001, depth: 0.009,
                color: color(0.65, 0.82, 0.78))
            ripple.position = SCNVector3(
                -0.27 + Double(index % 3) * 0.045, -0.003,
                -0.99 + Double(index) * 0.19)
            scene.rootNode.addChildNode(ripple)
        }
        let flagPole = box(width: 0.013, height: 0.23, depth: 0.013, color: color(0.46, 0.32, 0.19))
        flagPole.position = SCNVector3(0.18, 0.20, 0.18)
        riverFlag.position = SCNVector3(0, 0.09, 0)
        let pennant = box(width: 0.12, height: 0.058, depth: 0.008, color: color(0.83, 0.29, 0.18))
        pennant.position.x = 0.06
        riverFlag.addChildNode(pennant)
        flagPole.addChildNode(riverFlag)
        bridgeFolds.append(flagPole)
        scene.rootNode.addChildNode(flagPole)
    }

    private func buildBridge() {
        guard let scene = renderer.scene else { return }
        let deck = box(width: 0.58, height: 0.021, depth: 0.20, color: color(0.73, 0.51, 0.30))
        deck.position = SCNVector3(-0.25, 0.001, 0.05)
        scene.rootNode.addChildNode(deck)
        for z in [-0.045, 0.145] {
            let rail = SCNNode()
            rail.position = SCNVector3(-0.25, 0.015, z)
            let cap = box(width: 0.56, height: 0.014, depth: 0.014, color: color(0.61, 0.40, 0.22))
            cap.position.y = 0.069
            rail.addChildNode(cap)
            for x in [-0.27, -0.12, 0.12, 0.27] {
                let post = box(width: 0.014, height: 0.078, depth: 0.014, color: color(0.61, 0.40, 0.22))
                post.position = SCNVector3(x, 0.034, 0)
                rail.addChildNode(post)
            }
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
        canopy.position = SCNVector3(0, 0.39, 0.055)
        let roof = box(width: 0.72, height: 0.035, depth: 0.42, color: color(0.58, 0.43, 0.18))
        roof.position.z = 0.2
        canopy.addChildNode(roof)
        canopyFolds.append(canopy)
        body.addChildNode(canopy)

        let stationHit = box(width: 0.62, height: 0.28, depth: 0.55, color: .clear)
        stationHit.name = "hit-station"
        stationHit.opacity = 0.001
        stationHit.position = SCNVector3(-1.34, 0.16, -0.15)
        scene.rootNode.addChildNode(stationHit)
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
        clockHand.position = SCNVector3(0, 0.19, 0.082)
        let hand = box(width: 0.012, height: 0.079, depth: 0.006, color: color(0.27, 0.24, 0.19))
        hand.position.y = 0.028
        clockHand.addChildNode(hand)
        wall.addChildNode(clockHand)
        towerFolds.append(tower)
        scene.rootNode.addChildNode(tower)
    }

    private func buildTrainAndSwitch() {
        guard let scene = renderer.scene else { return }
        buildLocomotive()
        scene.rootNode.addChildNode(trainNode)

        switchNode = SCNNode()
        switchNode.position = SCNVector3(
            PocketTownTracks.switchCenter.x, 0.08, PocketTownTracks.switchCenter.y)
        let base = box(width: 0.16, height: 0.03, depth: 0.2, color: color(0.42, 0.35, 0.28))
        switchNode.addChildNode(base)
        switchBlade = box(width: 0.06, height: 0.015, depth: 0.22, color: color(0.76, 0.58, 0.2))
        switchBlade.position.y = 0.03
        switchNode.addChildNode(switchBlade)
        signalLamp.position = SCNVector3(0.10, 0.04, 0.04)
        let lens = SCNSphere(radius: 0.024)
        lens.firstMaterial?.lightingModel = .constant
        signalLamp.geometry = lens
        switchNode.addChildNode(signalLamp)
        let switchHit = box(width: 0.34, height: 0.22, depth: 0.34, color: .clear)
        switchHit.name = "hit-switch"
        switchHit.opacity = 0.001
        switchHit.position.y = 0.08
        switchNode.addChildNode(switchHit)
        scene.rootNode.addChildNode(switchNode)
    }

    private func buildLocomotive() {
        func add(_ part: SCNNode, at x: Double = 0, _ y: Double, _ z: Double) {
            part.position = SCNVector3(x, y, z)
            trainNode.addChildNode(part)
        }
        let crimson = color(0.70, 0.23, 0.17)
        let charcoal = color(0.23, 0.28, 0.26)
        let brass = color(0.93, 0.66, 0.26)
        add(box(width: 0.105, height: 0.022, depth: 0.24, color: charcoal), at: 0, 0.023, 0)
        let boiler = SCNNode(geometry: SCNCylinder(radius: 0.036, height: 0.145))
        boiler.geometry?.firstMaterial?.diffuse.contents = crimson
        boiler.eulerAngles.x = .pi / 2
        add(boiler, at: 0, 0.065, 0.036)
        add(box(width: 0.10, height: 0.086, depth: 0.079, color: crimson), at: 0, 0.083, -0.066)
        add(box(width: 0.121, height: 0.015, depth: 0.092, color: charcoal), at: 0, 0.134, -0.066)
        let chimney = SCNNode(geometry: SCNCylinder(radius: 0.015, height: 0.061))
        chimney.geometry?.firstMaterial?.diffuse.contents = charcoal
        add(chimney, at: 0, 0.112, 0.077)
        let headlight = SCNNode(geometry: SCNSphere(radius: 0.015))
        headlight.geometry?.firstMaterial?.diffuse.contents = brass
        headlight.geometry?.firstMaterial?.lightingModel = .constant
        add(headlight, at: 0, 0.067, 0.111)
        for side in [-1.0, 1.0] {
            add(box(width: 0.004, height: 0.037, depth: 0.043, color: brass), at: side * 0.052, 0.098, -0.066)
            for z in [-0.071, 0.008, 0.082] {
                let axle = SCNNode()
                let wheel = SCNNode(geometry: SCNCylinder(radius: 0.027, height: 0.012))
                wheel.geometry?.firstMaterial?.diffuse.contents = charcoal
                wheel.eulerAngles.z = .pi / 2
                axle.addChildNode(wheel)
                let spoke = box(width: 0.006, height: 0.04, depth: 0.006, color: brass)
                spoke.position.x = side * 0.008
                axle.addChildNode(spoke)
                add(axle, at: side * 0.055, 0.013, z)
                wheels.append(axle)
            }
        }
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
        for (x, z, height) in [
            (-1.57, 0.67, 0.37), (-1.33, 0.83, 0.25), (1.50, -0.74, 0.44), (1.56, 0.66, 0.32),
        ] {
            let tree = SCNNode()
            tree.position = SCNVector3(x, 0.02, z)
            let trunk = box(width: 0.032, height: height * 0.65, depth: 0.021, color: color(0.58, 0.37, 0.24))
            trunk.position.y = height * 0.3
            tree.addChildNode(trunk)
            for yaw in [0.0, .pi / 2] {
                let leaf = SCNNode(geometry: SCNSphere(radius: height * 0.31))
                leaf.position.y = height * 0.74
                leaf.scale = SCNVector3(0.72, 1.07, 0.095)
                leaf.eulerAngles.y = yaw
                leaf.geometry?.firstMaterial?.diffuse.contents = color(0.37, 0.58, 0.42)
                tree.addChildNode(leaf)
            }
            houseFolds.append(tree)
            scene.rootNode.addChildNode(tree)
        }
    }

    private func buildCameraAndLights() {
        guard let scene = renderer.scene else { return }
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 1.88
        camera.zNear = 0.1
        camera.zFar = 20
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(1.65, 4.3, 7.2)
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
        key.light?.intensity = 590
        key.light?.castsShadow = true
        key.light?.shadowMode = .deferred
        key.light?.shadowRadius = 4
        key.light?.shadowColor = color(0.21, 0.16, 0.13).withAlphaComponent(0.30)
        key.eulerAngles = SCNVector3(-0.8, -0.45, 0)
        scene.rootNode.addChildNode(key)
    }

    private func update(_ folding: PocketTownFolding, gameplay: PocketTownGameplay) {
        for segment in spineSegments { segment.update(folding.routes) }
        for segment in riversideSegments { segment.update(folding.routes) }
        for segment in clockSegments { segment.update(folding.routes) }
        for node in houseFolds { setFold(node, amount: folding.houses) }
        for node in bridgeFolds { setFold(node, amount: folding.bridge) }
        for node in towerFolds { setFold(node, amount: folding.tower) }
        for node in canopyFolds {
            let wallRotation = -(1 - folding.houses) * .pi / 2
            let deployedFlap = -folding.houses * (1 - folding.stationCanopy) * .pi / 2
            node.eulerAngles.x = CGFloat(deployedFlap - wallRotation)
        }

        let highlight = gameplay.canInteract
        let trackRoute = gameplay.displayRoute
        for segment in riversideSegments {
            segment.pivot.opacity = highlight && trackRoute == .clockTower ? 0.42 : 1
        }
        for segment in clockSegments {
            segment.pivot.opacity = highlight && trackRoute == .riverside ? 0.42 : 1
        }
        switchBlade.eulerAngles.y = gameplay.selectedRoute == .riverside ? 0.38 : -0.42

        let sampler = gameplay.sampler()
        let sample = sampler.sample(gameplay.routeProgress)
        let distance = gameplay.routeProgress * sampler.totalLength
        for wheel in wheels { wheel.eulerAngles.x = CGFloat(distance / 0.027) }
        let riverNear = max(0, 1 - hypot(sample.position.x - 0.5, sample.position.y - 0.6) / 0.62)
        let clockNear = max(0, 1 - hypot(sample.position.x - 0.1, sample.position.y + 0.3) / 0.54)
        riverFlag.eulerAngles.y =
            gameplay.trainIsRunning && trackRoute == .riverside
            ? CGFloat(riverNear * sin(distance * 15) * 0.8) : 0
        clockHand.eulerAngles.z =
            gameplay.trainIsRunning && trackRoute == .clockTower
            ? CGFloat(-clockNear * 1.8) : 0
        signalLamp.geometry?.firstMaterial?.diffuse.contents =
            gameplay.trainIsRunning
            ? color(0.98, 0.58, 0.19) : color(0.37, 0.78, 0.59)
        trainNode.position = SCNVector3(sample.position.x, 0.048, sample.position.y)
        trainNode.eulerAngles.y = sample.heading
        trainNode.isHidden = folding.routes < 0.18
        switchNode.isHidden = folding.routes < 0.35
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

    private func pocketPoints(_ points: [PocketTownPoint]) -> [SIMD2<Double>] {
        points.map { SIMD2($0.x, $0.y) }
    }
}
