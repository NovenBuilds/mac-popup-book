import Metal
import PageBehavior
import PopupBookCore
import SceneKit

final class RoomInComputerScene {
    private static let stripWidth = 1.04
    private static let stripHalfWidth = stripWidth / 2

    private let renderer: SCNRenderer
    private var colorTarget: MTLTexture?
    private var depthTarget: MTLTexture?
    private var viewport = CGSize(width: 1, height: 1)

    private var floorNode = SCNNode()
    private var backWallFold = SCNNode()
    private var sideWallFold = SCNNode()
    private var bedFold = SCNNode()
    private var deskFold = SCNNode()
    private var chairFold = SCNNode()
    private var lampFold = SCNNode()
    private var guestNode = SCNNode()
    private var windowGlow = SCNNode()
    private var lampLight = SCNNode()
    private var ambientNode = SCNNode()
    private var keyLight = SCNNode()

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw PageError.missingResources }
        renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = SCNScene()
        renderer.autoenablesDefaultLighting = false
        buildScene()
    }

    func setViewport(_ size: CGSize) { viewport = size }

    func pickStrip(x: Double, y: Double) -> RoomStripTarget? {
        let point = CGPoint(x: x * viewport.width, y: y * viewport.height)
        let options: [SCNHitTestOption: Any] = [
            .searchMode: SCNHitTestSearchMode.closest.rawValue,
            .boundingBoxOnly: true,
        ]
        guard let hit = renderer.hitTest(point, options: options).first else { return nil }
        let name = hit.node.name ?? hit.node.parent?.name ?? ""
        switch name {
        case "hit-strip-drag":
            let localX = Double(hit.localCoordinates.x)
            let mapped = (localX + Self.stripHalfWidth) / Self.stripWidth
            return .dragX(max(0, min(1, mapped)))
        case "hit-dock-morning":
            return .dockMorning
        case "hit-dock-afternoon":
            return .dockAfternoon
        case "hit-dock-evening":
            return .dockEvening
        default:
            return nil
        }
    }

    func render(
        into texture: MTLTexture, command: MTLCommandBuffer,
        folding: RoomInComputerFolding, gameplay: RoomInComputerGameplay
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
        let sky = skyTint(time: gameplay.lightForTime)
        pass.colorAttachments[0].clearColor = MTLClearColor(red: sky.r, green: sky.g, blue: sky.b, alpha: 1)
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
        scene.background.contents = color(0.88, 0.84, 0.78)

        floorNode = box(width: 2.2, height: 0.03, depth: 1.35, color: color(0.62, 0.52, 0.4))
        floorNode.position = SCNVector3(0, -0.01, 0.05)
        scene.rootNode.addChildNode(floorNode)

        backWallFold = foldedPanel(
            width: 2.2, height: 0.9, depth: 0.04, color: color(0.78, 0.74, 0.66),
            anchorZ: -0.62)
        scene.rootNode.addChildNode(backWallFold)

        sideWallFold = foldedSideWall(
            thickness: 0.04, height: 0.9, depth: 1.35, color: color(0.72, 0.68, 0.6))
        sideWallFold.position = SCNVector3(-1.1, 0, 0.05)
        scene.rootNode.addChildNode(sideWallFold)

        buildWindow(on: backWallFold)
        bedFold = buildBed()
        scene.rootNode.addChildNode(bedFold)
        deskFold = buildDesk()
        scene.rootNode.addChildNode(deskFold)
        chairFold = buildChair()
        scene.rootNode.addChildNode(chairFold)
        lampFold = buildLamp()
        scene.rootNode.addChildNode(lampFold)
        guestNode = buildGuest()
        scene.rootNode.addChildNode(guestNode)
        buildTimeStrip(on: scene)
        buildCameraAndLights(on: scene)
    }

    private func buildWindow(on wall: SCNNode) {
        guard let panel = wall.childNodes.first else { return }
        let frame = box(width: 0.42, height: 0.36, depth: 0.02, color: color(0.55, 0.48, 0.38))
        frame.position = SCNVector3(0.52, 0.12, 0.03)
        panel.addChildNode(frame)
        windowGlow = box(width: 0.34, height: 0.28, depth: 0.008, color: color(0.82, 0.88, 0.95))
        windowGlow.position = SCNVector3(0.52, 0.12, 0.045)
        panel.addChildNode(windowGlow)
    }

    private func buildBed() -> SCNNode {
        let pivot = foldedBox(width: 0.72, height: 0.16, depth: 0.48, color: color(0.68, 0.62, 0.82))
        pivot.position = SCNVector3(-0.42, 0, -0.35)
        guard let base = pivot.childNodes.first else { return pivot }
        let pillow = box(width: 0.22, height: 0.06, depth: 0.18, color: color(0.92, 0.9, 0.84))
        pillow.position = SCNVector3(-0.2, 0.1, -0.14)
        base.addChildNode(pillow)
        let blanket = box(width: 0.5, height: 0.04, depth: 0.38, color: color(0.52, 0.58, 0.72))
        blanket.position = SCNVector3(0.08, 0.1, 0.02)
        base.addChildNode(blanket)
        return pivot
    }

    private func buildDesk() -> SCNNode {
        let legHeight = 0.22
        let topThickness = 0.05
        let totalHeight = legHeight + topThickness
        let pivot = SCNNode()
        pivot.position = SCNVector3(0.38, 0, 0.02)
        let group = SCNNode()
        group.position.y = CGFloat(totalHeight / 2)
        let top = box(width: 0.58, height: topThickness, depth: 0.32, color: color(0.48, 0.4, 0.32))
        top.position.y = CGFloat(legHeight + topThickness / 2 - totalHeight / 2)
        group.addChildNode(top)
        for xLeg: Double in [-0.22, 0.22] {
            for zLeg: Double in [-0.12, 0.12] {
                let leg = box(width: 0.04, height: legHeight, depth: 0.04, color: color(0.42, 0.36, 0.28))
                leg.position = SCNVector3(xLeg, legHeight / 2 - totalHeight / 2, zLeg)
                group.addChildNode(leg)
            }
        }
        let book = box(width: 0.14, height: 0.03, depth: 0.1, color: color(0.58, 0.32, 0.28))
        book.position = SCNVector3(0, legHeight + topThickness / 2 + 0.015 - totalHeight / 2, 0)
        group.addChildNode(book)
        pivot.addChildNode(group)
        return pivot
    }

    private func buildChair() -> SCNNode {
        let seatHeight = 0.06
        let backHeight = 0.28
        let totalHeight = seatHeight + backHeight
        let pivot = SCNNode()
        pivot.position = SCNVector3(0.12, 0, 0.32)
        let group = SCNNode()
        group.position.y = CGFloat(totalHeight / 2)
        let seat = box(width: 0.28, height: seatHeight, depth: 0.28, color: color(0.5, 0.38, 0.3))
        seat.position.y = CGFloat(seatHeight / 2 - totalHeight / 2)
        group.addChildNode(seat)
        let back = box(width: 0.28, height: backHeight, depth: 0.04, color: color(0.48, 0.36, 0.28))
        back.position = SCNVector3(0, seatHeight + backHeight / 2 - totalHeight / 2, -0.12)
        group.addChildNode(back)
        pivot.addChildNode(group)
        return pivot
    }

    private func buildLamp() -> SCNNode {
        let pivot = SCNNode()
        pivot.position = SCNVector3(-0.15, 0, 0.18)
        let cord = box(width: 0.01, height: 0.22, depth: 0.01, color: color(0.3, 0.28, 0.26))
        cord.position = SCNVector3(0, 0.1, 0)
        pivot.addChildNode(cord)
        let shade = box(width: 0.2, height: 0.12, depth: 0.2, color: color(0.92, 0.85, 0.62))
        shade.position = SCNVector3(0, -0.06, 0)
        pivot.addChildNode(shade)
        lampLight = SCNNode()
        lampLight.light = SCNLight()
        lampLight.light?.type = .omni
        lampLight.light?.color = color(1.0, 0.88, 0.62)
        lampLight.position = SCNVector3(0, -0.14, 0)
        shade.addChildNode(lampLight)
        return pivot
    }

    private func buildGuest() -> SCNNode {
        let root = SCNNode()
        let body = box(width: 0.08, height: 0.18, depth: 0.05, color: color(0.58, 0.62, 0.7))
        body.position = SCNVector3(0, 0.1, 0)
        root.addChildNode(body)
        let head = box(width: 0.07, height: 0.07, depth: 0.05, color: color(0.9, 0.82, 0.72))
        head.position = SCNVector3(0, 0.24, 0)
        root.addChildNode(head)
        return root
    }

    private func buildTimeStrip(on scene: SCNScene) {
        let stripRoot = SCNNode()
        stripRoot.position = SCNVector3(0, 0.02, 0.72)
        let paper = box(width: 1.04, height: 0.002, depth: 0.14, color: color(0.94, 0.9, 0.82))
        stripRoot.addChildNode(paper)
        for (name, x, label) in [
            ("hit-dock-morning", -0.38, "晨"),
            ("hit-dock-afternoon", 0, "午"),
            ("hit-dock-evening", 0.38, "夜"),
        ] {
            let tick = box(width: 0.08, height: 0.04, depth: 0.04, color: color(0.72, 0.66, 0.5))
            tick.position = SCNVector3(x, 0.03, 0)
            let hit = box(width: 0.16, height: 0.12, depth: 0.16, color: .clear)
            hit.name = name
            hit.opacity = 0.001
            hit.position = SCNVector3(0, 0.04, 0)
            tick.addChildNode(hit)
            stripRoot.addChildNode(tick)
            _ = label
        }
        let dragHit = box(width: 1.04, height: 0.12, depth: 0.14, color: .clear)
        dragHit.name = "hit-strip-drag"
        dragHit.opacity = 0.001
        dragHit.position = SCNVector3(0, 0.04, 0)
        stripRoot.addChildNode(dragHit)
        scene.rootNode.addChildNode(stripRoot)
    }

    private func buildCameraAndLights(on scene: SCNScene) {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 1.55
        camera.zNear = 0.1
        camera.zFar = 20
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0.15, 1.35, 2.45)
        cameraNode.look(at: SCNVector3(0.05, 0.25, -0.05))
        scene.rootNode.addChildNode(cameraNode)
        renderer.pointOfView = cameraNode

        ambientNode = SCNNode()
        ambientNode.light = SCNLight()
        ambientNode.light?.type = .ambient
        scene.rootNode.addChildNode(ambientNode)

        keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.eulerAngles = SCNVector3(-0.75, -0.35, 0)
        scene.rootNode.addChildNode(keyLight)
    }

    private func update(folding: RoomInComputerFolding, gameplay: RoomInComputerGameplay) {
        floorNode.scale = SCNVector3(1, max(0.001, folding.floor), 1)
        setFold(backWallFold, amount: folding.walls)
        setFold(sideWallFold, amount: folding.walls, axisX: true)
        setFold(bedFold, amount: folding.bed)
        setFold(deskFold, amount: folding.desk)
        setFold(chairFold, amount: folding.chair)
        lampFold.position.y = folding.lamp * 0.75
        lampFold.isHidden = folding.lamp < 0.05

        let guest = gameplay.guestDisplay
        guestNode.position = SCNVector3(guest.x, 0, guest.z)
        guestNode.eulerAngles.y = guestHeading(guest.activity)
        guestNode.isHidden = folding.bed < 0.2

        applyLighting(time: gameplay.lightForTime, folding: folding)
    }

    private func guestHeading(_ phase: RoomTimePhase) -> CGFloat {
        switch phase {
        case .morning: return 0.35
        case .afternoon: return -0.5
        case .evening: return 2.1
        }
    }

    private func applyLighting(time: Double, folding: RoomInComputerFolding) {
        let morning = max(0, 1 - abs(time - 0) / 0.34)
        let afternoon = max(0, 1 - abs(time - 0.5) / 0.34)
        let evening = max(0, 1 - abs(time - 1) / 0.34)
        let open = folding.walls

        windowGlow.opacity = CGFloat(0.25 + 0.65 * max(morning, afternoon) * open)
        let windowColor = blend(
            color(0.95, 0.88, 0.55), color(0.75, 0.85, 0.95), t: afternoon / (morning + afternoon + 0.001))
        windowGlow.geometry?.firstMaterial?.diffuse.contents = windowColor

        ambientNode.light?.intensity = CGFloat(180 + 220 * open * (0.35 + afternoon * 0.5 + morning * 0.4))
        keyLight.light?.intensity = CGFloat(320 * open * (0.4 + morning * 0.45 + afternoon * 0.55))
        keyLight.light?.color = blend(color(1, 0.95, 0.82), color(0.82, 0.88, 1), t: afternoon)

        let lampOn = evening * folding.lamp
        lampLight.light?.intensity = CGFloat(420 * lampOn)
        lampLight.isHidden = lampOn < 0.08
    }

    private func skyTint(time: Double) -> (r: Double, g: Double, b: Double) {
        let morning = (r: 0.92, g: 0.88, b: 0.82)
        let afternoon = (r: 0.88, g: 0.9, b: 0.94)
        let evening = (r: 0.22, g: 0.24, b: 0.32)
        if time < 0.34 {
            let t = time / 0.34
            return mix(morning, afternoon, t: t * 0.35)
        }
        if time < 0.67 {
            let t = (time - 0.34) / 0.33
            return mix(morning, afternoon, t: 0.35 + t * 0.65)
        }
        let t = (time - 0.67) / 0.33
        return mix(afternoon, evening, t: t)
    }

    private func setFold(_ node: SCNNode, amount: Double, axisX: Bool = false) {
        if axisX {
            node.eulerAngles.z = CGFloat((1 - amount) * .pi / 2)
        } else {
            node.eulerAngles.x = CGFloat((1 - amount) * .pi / 2)
        }
    }

    private func foldedPanel(
        width: Double, height: Double, depth: Double, color: NSColor, anchorZ: Double
    ) -> SCNNode {
        let pivot = SCNNode()
        pivot.position = SCNVector3(0, 0, anchorZ)
        let panel = box(width: width, height: height, depth: depth, color: color)
        panel.position = SCNVector3(0, height / 2, 0)
        pivot.addChildNode(panel)
        return pivot
    }

    private func foldedSideWall(
        thickness: Double, height: Double, depth: Double, color: NSColor
    ) -> SCNNode {
        let pivot = SCNNode()
        let panel = box(width: thickness, height: height, depth: depth, color: color)
        panel.position = SCNVector3(thickness / 2, height / 2, 0)
        pivot.addChildNode(panel)
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
        let geometry = SCNBox(width: width, height: height, length: depth, chamferRadius: 0.003)
        geometry.firstMaterial?.diffuse.contents = color
        return SCNNode(geometry: geometry)
    }

    private func color(_ red: Double, _ green: Double, _ blue: Double) -> NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }

    private func blend(_ a: NSColor, _ b: NSColor, t: Double) -> NSColor {
        let t = max(0, min(1, t))
        return color(
            a.redComponent + (b.redComponent - a.redComponent) * t,
            a.greenComponent + (b.greenComponent - a.greenComponent) * t,
            a.blueComponent + (b.blueComponent - a.blueComponent) * t)
    }

    private func mix(
        _ a: (r: Double, g: Double, b: Double),
        _ b: (r: Double, g: Double, b: Double),
        t: Double
    ) -> (r: Double, g: Double, b: Double) {
        let t = max(0, min(1, t))
        return (a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t)
    }
}
