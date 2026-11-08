import Metal
import PageBehavior
import PopupBookCore
import SceneKit

final class UnderwaterTheaterScene {
    private let renderer: SCNRenderer
    private var colorTarget: MTLTexture?
    private var depthTarget: MTLTexture?
    private var seabedLayers: [SCNNode] = []
    private var coralFolds: [SCNNode] = []
    private var seaweedFolds: [SCNNode] = []
    private var fishNodes: [SCNNode] = []
    private var flowBead = SCNNode()
    private var flowStreaks: [SCNNode] = []
    private var shellLid = SCNNode()
    private var shimmerPlanes: [SCNNode] = []
    private var tapHits: [SCNNode] = []
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

    private static let flowPlaneHeight = 0.38

    func flowPoint(x: Double, y: Double) -> TheaterPoint? {
        guard viewport.width > 1, viewport.height > 1 else { return nil }
        let near = renderer.unprojectPoint(SCNVector3(x * viewport.width, y * viewport.height, 0))
        let far = renderer.unprojectPoint(SCNVector3(x * viewport.width, y * viewport.height, 1))
        let vertical = Double(far.y - near.y)
        guard abs(vertical) > 1e-6 else { return nil }
        let distance = (Self.flowPlaneHeight - Double(near.y)) / vertical
        let worldX = Double(near.x) + Double(far.x - near.x) * distance
        let worldZ = Double(near.z) + Double(far.z - near.z) * distance
        guard worldX.isFinite, worldZ.isFinite else { return nil }
        return TheaterPoint(worldX, worldZ)
    }

    func pickTarget(x: Double, y: Double) -> UnderwaterTheaterTapTarget? {
        let point = CGPoint(x: x * viewport.width, y: y * viewport.height)
        let options: [SCNHitTestOption: Any] = [
            .searchMode: SCNHitTestSearchMode.closest.rawValue,
            .boundingBoxOnly: true,
        ]
        guard let hit = renderer.hitTest(point, options: options).first else { return nil }
        switch hit.node.name ?? hit.node.parent?.name {
        case "hit-west": return .westSeaweed
        case "hit-arch": return .archRise
        case "hit-shell": return .shellLedge
        default: return nil
        }
    }

    func render(
        into texture: MTLTexture, command: MTLCommandBuffer,
        folding: UnderwaterTheaterFolding, gameplay: UnderwaterTheaterGameplay
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
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0.74, green: 0.9, blue: 0.95, alpha: 1)
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
        scene.background.contents = NSColor(calibratedRed: 0.76, green: 0.91, blue: 0.95, alpha: 1)

        buildSeabed(into: scene)
        buildCoralArch(into: scene)
        buildSeaweed(into: scene)
        buildShell(into: scene)
        buildFishSchool(into: scene)
        buildFlowVisuals(into: scene)
        buildTapHits(into: scene)
        buildShimmer(into: scene)
        buildCameraAndLights(into: scene)
    }

    private func buildSeabed(into scene: SCNScene) {
        let layers: [(Double, NSColor)] = [
            (3.9, color(0.72, 0.62, 0.48)),
            (3.5, color(0.62, 0.52, 0.4)),
            (3.0, color(0.54, 0.44, 0.34)),
        ]
        for (width, tint) in layers {
            let bed = foldedPlane(width: width, depth: 2.5, color: tint)
            bed.position = SCNVector3(0, -0.02, 0.08)
            seabedLayers.append(bed)
            scene.rootNode.addChildNode(bed)
        }
        let ridge = box(width: 2.6, height: 0.03, depth: 0.18, color: color(0.48, 0.4, 0.32))
        ridge.position = SCNVector3(0, 0.01, 0.22)
        scene.rootNode.addChildNode(ridge)
    }

    private func buildCoralArch(into scene: SCNScene) {
        let leftPillar = coralColumn(x: -0.26, z: 0.1, height: 0.62, tint: color(0.86, 0.42, 0.36))
        let rightPillar = coralColumn(x: 0.3, z: 0.08, height: 0.58, tint: color(0.78, 0.48, 0.4))
        let arch = foldedBox(width: 0.72, height: 0.12, depth: 0.14, color: color(0.9, 0.5, 0.42))
        arch.position = SCNVector3(0.02, 0.58, 0.12)
        coralFolds += [leftPillar, rightPillar, arch]
        scene.rootNode.addChildNode(leftPillar)
        scene.rootNode.addChildNode(rightPillar)
        scene.rootNode.addChildNode(arch)

        let backVeil = box(width: 0.5, height: 0.42, depth: 0.05, color: color(0.32, 0.38, 0.48))
        backVeil.opacity = 0.55
        backVeil.position = SCNVector3(-0.35, 0.22, -0.08)
        backVeil.name = "coral-veil"
        coralFolds.append(backVeil)
        scene.rootNode.addChildNode(backVeil)
    }

    private func coralColumn(x: Double, z: Double, height: Double, tint: NSColor) -> SCNNode {
        let pivot = SCNNode()
        pivot.position = SCNVector3(x, 0.02, z)
        let base = box(width: 0.2, height: height * 0.55, depth: 0.16, color: tint)
        base.position.y = height * 0.28
        let branch = box(width: 0.14, height: height * 0.35, depth: 0.1, color: color(0.92, 0.52, 0.44))
        branch.position = SCNVector3(0.05, height * 0.62, 0.02)
        branch.eulerAngles.z = 0.18
        pivot.addChildNode(base)
        pivot.addChildNode(branch)
        return pivot
    }

    private func buildSeaweed(into scene: SCNScene) {
        let specs: [(Double, Double, Double)] = [
            (-0.78, 0.16, 0.46), (-0.66, 0.12, 0.52), (-0.9, 0.08, 0.4),
            (0.82, 0.06, 0.44), (0.68, 0.1, 0.5),
        ]
        for (x, z, h) in specs {
            let blade = seaweedBlade(height: h)
            blade.position = SCNVector3(x, 0.02, z)
            seaweedFolds.append(blade)
            scene.rootNode.addChildNode(blade)
        }
    }

    private func seaweedBlade(height: Double) -> SCNNode {
        let pivot = SCNNode()
        let stem = box(width: 0.04, height: height, depth: 0.025, color: color(0.22, 0.58, 0.42))
        stem.opacity = 0.62
        stem.position.y = height / 2
        let tip = box(width: 0.06, height: height * 0.22, depth: 0.03, color: color(0.3, 0.66, 0.48))
        tip.opacity = 0.48
        tip.position.y = height * 0.9
        pivot.addChildNode(stem)
        pivot.addChildNode(tip)
        return pivot
    }

    private func buildShell(into scene: SCNScene) {
        let base = box(width: 0.32, height: 0.05, depth: 0.22, color: color(0.88, 0.78, 0.62))
        base.position = SCNVector3(0.74, 0.04, 0.02)
        scene.rootNode.addChildNode(base)
        shellLid = box(width: 0.34, height: 0.06, depth: 0.24, color: color(0.94, 0.86, 0.72))
        shellLid.position = SCNVector3(0.74, 0.1, 0.02)
        scene.rootNode.addChildNode(shellLid)
    }

    private func buildFishSchool(into scene: SCNScene) {
        let tints = [
            color(0.95, 0.72, 0.28), color(0.42, 0.78, 0.88), color(0.92, 0.52, 0.36),
            color(0.58, 0.82, 0.62), color(0.88, 0.64, 0.78), color(0.38, 0.62, 0.92),
        ]
        for (index, tint) in tints.enumerated() {
            let fish = box(width: 0.08, height: 0.03, depth: 0.05, color: tint)
            fish.name = "fish-\(index)"
            let tail = box(width: 0.03, height: 0.02, depth: 0.02, color: color(0.28, 0.48, 0.58))
            tail.position = SCNVector3(-0.05, 0, 0)
            fish.addChildNode(tail)
            scene.rootNode.addChildNode(fish)
            fishNodes.append(fish)
        }
    }

    private func buildFlowVisuals(into scene: SCNScene) {
        flowBead = SCNNode(geometry: SCNSphere(radius: 0.055))
        flowBead.geometry?.firstMaterial?.diffuse.contents = color(0.62, 0.9, 0.95)
        flowBead.geometry?.firstMaterial?.transparency = 0.55
        flowBead.geometry?.firstMaterial?.lightingModel = .constant
        scene.rootNode.addChildNode(flowBead)

        for index in 0..<4 {
            let streak = box(width: 0.04, height: 0.01, depth: 0.22, color: color(0.58, 0.86, 0.92))
            streak.opacity = 0.35
            streak.name = "flow-streak-\(index)"
            scene.rootNode.addChildNode(streak)
            flowStreaks.append(streak)
        }
    }

    private func buildTapHits(into scene: SCNScene) {
        let specs: [(String, TheaterPoint)] = [
            ("hit-west", UnderwaterTheaterTracks.TapCurrent.westSeaweed.sceneHint),
            ("hit-arch", UnderwaterTheaterTracks.TapCurrent.archRise.sceneHint),
            ("hit-shell", UnderwaterTheaterTracks.TapCurrent.shellLedge.sceneHint),
        ]
        for (name, point) in specs {
            let hit = box(width: 0.38, height: 0.28, depth: 0.38, color: .clear)
            hit.name = name
            hit.opacity = 0.001
            hit.position = SCNVector3(point.x, 0.2, point.y)
            tapHits.append(hit)
            scene.rootNode.addChildNode(hit)
        }
    }

    private func buildShimmer(into scene: SCNScene) {
        for offset in [-0.9, 0.0, 0.85] {
            let plane = foldedPlane(width: 1.1, depth: 1.6, color: color(0.72, 0.9, 0.95))
            plane.opacity = 0.14
            plane.position = SCNVector3(offset, 0.55, -0.15)
            shimmerPlanes.append(plane)
            scene.rootNode.addChildNode(plane)
        }
    }

    private func buildCameraAndLights(into scene: SCNScene) {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 2.35
        camera.zNear = 0.1
        camera.zFar = 20
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 2.1, 6.8)
        cameraNode.look(at: SCNVector3(0, 0.15, 0))
        scene.rootNode.addChildNode(cameraNode)
        renderer.pointOfView = cameraNode

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 380
        ambient.light?.color = color(0.68, 0.82, 0.92)
        scene.rootNode.addChildNode(ambient)

        let caustic = SCNNode()
        caustic.light = SCNLight()
        caustic.light?.type = .directional
        caustic.light?.intensity = 620
        caustic.light?.color = color(0.78, 0.92, 0.98)
        caustic.eulerAngles = SCNVector3(-0.65, -0.35, 0)
        scene.rootNode.addChildNode(caustic)
    }

    private func update(_ folding: UnderwaterTheaterFolding, gameplay: UnderwaterTheaterGameplay) {
        let seabedLift = folding.seabed
        for (index, layer) in seabedLayers.enumerated() {
            setFold(layer, amount: seabedLift)
            let lift = -0.04 + seabedLift * (0.02 + Double(index) * 0.01)
            layer.position.y = CGFloat(lift)
        }

        for node in coralFolds {
            if node.name == "coral-veil" {
                setFold(node, amount: folding.coral * 0.7)
                node.opacity = CGFloat(0.3 + folding.fish * 0.35)
            } else {
                setFold(node, amount: folding.coral)
            }
        }

        let sway = CGFloat(gameplay.flowStrength * 0.22)
        for (index, blade) in seaweedFolds.enumerated() {
            setFold(blade, amount: folding.seaweed)
            blade.eulerAngles.z = sway * (index.isMultiple(of: 2) ? 1 : -1)
        }

        for (index, plane) in shimmerPlanes.enumerated() {
            plane.opacity = CGFloat(0.08 + folding.shimmer * 0.18)
            let height = 0.35 + folding.shimmer * 0.35 + Double(index) * 0.04
            plane.position.y = CGFloat(height)
        }

        let flowScene = gameplay.flowPoint
        let showFlow = gameplay.canInteract && gameplay.flowStrength > 0.04
        flowBead.isHidden = !showFlow
        flowBead.position = SCNVector3(flowScene.x, Self.flowPlaneHeight, flowScene.y)
        flowBead.opacity = CGFloat(min(1, gameplay.flowStrength * (gameplay.dragging ? 1 : 0.75)))

        let school = gameplay.schoolCenter()
        let blend = min(1, gameplay.flowStrength * 0.85)
        let heading = sampleHeading(base: school.heading, steer: school.steerHeading, blend: blend)
        let fishHide = folding.fish < 0.2 || gameplay.fishProgress < 0.02 && folding.fish < 0.55
        for (index, fish) in fishNodes.enumerated() {
            let offset = fishFormationOffset(index: index, heading: heading)
            fish.position = SCNVector3(
                school.position.x + offset.x, 0.08 + Double(index % 3) * 0.02,
                school.position.y + offset.y)
            fish.eulerAngles.y = CGFloat(-heading)
            let behindVeil = school.position.x < -0.2 && gameplay.fishProgress < 0.12
            fish.isHidden = fishHide || (behindVeil && folding.fish < 0.65)
            fish.opacity = CGFloat(min(1, folding.fish * 1.1))
        }

        updateFlowStreaks(origin: flowScene, strength: gameplay.flowStrength, active: showFlow)
        updateShell(fishNear: school.position, folding: folding)
        for hit in tapHits { hit.isHidden = folding.coral < 0.45 }
    }

    private func sampleHeading(base: Double, steer: Double, blend: Double) -> Double {
        let delta = atan2(sin(steer - base), cos(steer - base))
        return base + delta * blend
    }

    private func fishFormationOffset(index: Int, heading: Double) -> TheaterPoint {
        let side = Double(index % 3 - 1) * 0.07
        let lag = Double(index / 3) * -0.06
        return TheaterPoint(
            cos(heading + .pi / 2) * side + cos(heading) * lag,
            sin(heading + .pi / 2) * side + sin(heading) * lag)
    }

    private func updateFlowStreaks(origin: TheaterPoint, strength: Double, active: Bool) {
        let target = UnderwaterTheaterTracks.archCenter
        let delta = target - origin
        let heading = atan2(delta.x, delta.y)
        for (index, streak) in flowStreaks.enumerated() {
            streak.isHidden = !active
            let t = Double(index + 1) / Double(flowStreaks.count + 1)
            streak.position = SCNVector3(
                origin.x + delta.x * t, 0.28 + t * 0.08, origin.y + delta.y * t)
            streak.eulerAngles.y = CGFloat(heading)
            streak.scale.z = CGFloat(0.5 + strength * 0.8)
            streak.opacity = CGFloat(0.2 + strength * 0.4)
        }
    }

    private func updateShell(fishNear: TheaterPoint, folding: UnderwaterTheaterFolding) {
        let dx = fishNear.x - 0.74
        let dy = fishNear.y - 0.02
        let near = dx * dx + dy * dy < 0.12
        let open = near && folding.fish > 0.6 ? 0.42 : 0.05
        shellLid.eulerAngles.x = -CGFloat(open)
    }

    private func setFold(_ node: SCNNode, amount: Double) {
        node.eulerAngles.x = -CGFloat((1 - amount) * .pi / 2)
    }

    private func foldedPlane(width: Double, depth: Double, color: NSColor) -> SCNNode {
        let pivot = SCNNode()
        let plane = box(width: width, height: 0.02, depth: depth, color: color)
        plane.position.y = 0.01
        pivot.addChildNode(plane)
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
        let geometry = SCNBox(width: width, height: height, length: depth, chamferRadius: 0.006)
        geometry.firstMaterial?.diffuse.contents = color
        return SCNNode(geometry: geometry)
    }

    private func color(_ red: Double, _ green: Double, _ blue: Double) -> NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }
}
