import Metal
import PageBehavior
import PopupBookCore
import SceneKit

final class UnderwaterTheaterScene {
    private let renderer: SCNRenderer
    private var colorTarget: MTLTexture?
    private var depthTarget: MTLTexture?
    private var coralFolds: [SCNNode] = []
    private var seaweedFolds: [SCNNode] = []
    private var fishNodes: [SCNNode] = []
    private var fishTails: [SCNNode] = []
    private var currentMarkers: [SCNNode] = []
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
        folding: UnderwaterTheaterFolding, gameplay: UnderwaterTheaterGameplay, clock: Double
    ) throws {
        update(folding, gameplay: gameplay, clock: clock)
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
        let layers: [(Double, Double, Double, NSColor)] = [
            (3.94, 2.42, -0.08, color(0.16, 0.43, 0.44)),
            (3.86, 2.35, -0.052, color(0.80, 0.80, 0.61)),
            (3.78, 2.29, -0.025, color(0.91, 0.84, 0.64)),
        ]
        for (width, depth, y, tint) in layers {
            let page = box(width: width, height: 0.025, depth: depth, color: tint)
            page.position = SCNVector3(0, y, 0.03)
            scene.rootNode.addChildNode(page)
        }
        let spine = box(width: 0.018, height: 0.004, depth: 2.22, color: color(0.65, 0.59, 0.41))
        scene.rootNode.addChildNode(spine)
        for (index, z) in [-0.83, -0.63, -0.45].enumerated() {
            let depth = box(
                width: 2.75 + Double(index) * 0.18, height: 0.03, depth: 0.22,
                color: color(0.36 + Double(index) * 0.085, 0.66, 0.61))
            depth.position = SCNVector3(0, 0.001, z)
            scene.rootNode.addChildNode(depth)
        }
        for index in 0..<36 {
            let x = Double((index * 47) % 131) / 42 - 1.55
            let z = Double((index * 31) % 77) / 66 - 0.17
            let grain = SCNNode(geometry: SCNSphere(radius: 0.009 + Double(index % 3) * 0.003))
            grain.scale = SCNVector3(1.5, 0.16, 0.9)
            grain.position = SCNVector3(x, 0, z)
            grain.geometry?.firstMaterial?.diffuse.contents = color(0.67, 0.61, 0.44).withAlphaComponent(0.65)
            scene.rootNode.addChildNode(grain)
        }
    }

    private func buildCoralArch(into scene: SCNScene) {
        let arch = NSBezierPath()
        arch.move(to: CGPoint(x: -0.49, y: 0))
        arch.curve(
            to: CGPoint(x: 0.46, y: 0),
            controlPoint1: CGPoint(x: -0.64, y: 1.02), controlPoint2: CGPoint(x: 0.62, y: 1.02))
        arch.line(to: CGPoint(x: 0.30, y: 0))
        arch.curve(
            to: CGPoint(x: -0.29, y: 0),
            controlPoint1: CGPoint(x: 0.41, y: 0.74), controlPoint2: CGPoint(x: -0.40, y: 0.74))
        arch.close()
        for (index, tint) in [color(0.69, 0.31, 0.34), color(0.91, 0.48, 0.39)].enumerated() {
            let coral = paperCut(arch, thickness: 0.045, tint: tint)
            coral.position = SCNVector3(0, 0.013, 0.025 + Double(index) * 0.052)
            coralFolds.append(coral)
            scene.rootNode.addChildNode(coral)
            if index == 1 {
                for i in 0..<9 {
                    let angle = Double(i) / 8 * .pi
                    let dot = SCNNode(geometry: SCNSphere(radius: 0.019 + Double(i % 3) * 0.006))
                    dot.scale.z = 0.26
                    dot.position = SCNVector3(0.37 * cos(angle), 0.072 + 0.59 * sin(angle), 0.029)
                    dot.geometry?.firstMaterial?.diffuse.contents = color(0.98, 0.73, 0.56)
                    coral.addChildNode(dot)
                }
            }
        }
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
        let outline = NSBezierPath()
        outline.move(to: .zero)
        outline.curve(
            to: CGPoint(x: 0.048, y: height),
            controlPoint1: CGPoint(x: -0.13, y: height * 0.33),
            controlPoint2: CGPoint(x: 0.1, y: height * 0.68))
        outline.curve(
            to: .zero, controlPoint1: CGPoint(x: 0.24, y: height * 0.63),
            controlPoint2: CGPoint(x: 0.015, y: height * 0.30))
        outline.close()
        let blade = paperCut(outline, thickness: 0.012, tint: color(0.18, 0.56, 0.44))
        blade.opacity = 0.86
        return blade
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
            let fish = SCNNode()
            let body = NSBezierPath()
            body.move(to: CGPoint(x: -0.062, y: 0))
            body.curve(
                to: CGPoint(x: 0.077, y: 0),
                controlPoint1: CGPoint(x: -0.02, y: 0.074), controlPoint2: CGPoint(x: 0.058, y: 0.055))
            body.curve(
                to: CGPoint(x: -0.062, y: 0),
                controlPoint1: CGPoint(x: 0.052, y: -0.046), controlPoint2: CGPoint(x: -0.025, y: -0.04))
            body.close()
            fish.addChildNode(paperCut(body, thickness: 0.015, tint: tint))
            let fin = NSBezierPath()
            fin.move(to: .zero)
            fin.line(to: CGPoint(x: -0.052, y: 0.042))
            fin.line(to: CGPoint(x: -0.042, y: 0))
            fin.line(to: CGPoint(x: -0.052, y: -0.033))
            fin.close()
            let tail = paperCut(
                fin, thickness: 0.01, tint: tint.blended(withFraction: 0.28, of: .black) ?? tint)
            tail.position.x = -0.051
            fish.addChildNode(tail)
            for side in [-1.0, 1.0] {
                let eye = SCNNode(geometry: SCNSphere(radius: 0.008))
                eye.position = SCNVector3(0.048, 0.012, side * 0.01)
                eye.geometry?.firstMaterial?.diffuse.contents = color(0.10, 0.19, 0.22)
                fish.addChildNode(eye)
            }
            fish.scale = SCNVector3(1 - Double(index % 3) * 0.09, 1, 1)
            scene.rootNode.addChildNode(fish)
            fishNodes.append(fish)
            fishTails.append(tail)
        }
    }

    private func paperCut(_ path: NSBezierPath, thickness: Double, tint: NSColor) -> SCNNode {
        path.flatness = 0.001
        let geometry = SCNShape(path: path.flattened, extrusionDepth: thickness)
        geometry.firstMaterial?.diffuse.contents = tint
        return SCNNode(geometry: geometry)
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
            let ring = SCNTorus(ringRadius: 0.086, pipeRadius: 0.007)
            ring.firstMaterial?.diffuse.contents = color(0.22, 0.64, 0.68)
            let marker = SCNNode(geometry: ring)
            marker.position = SCNVector3(point.x, 0.052, point.y)
            currentMarkers.append(marker)
            scene.rootNode.addChildNode(marker)
        }
    }

    private func buildShimmer(into scene: SCNScene) {
        for i in 0..<12 {
            let glint = box(
                width: 0.11 + Double(i % 3) * 0.067, height: 0.001, depth: 0.014,
                color: color(0.98, 0.99, 0.79))
            glint.position = SCNVector3(Double(i % 4) * 0.64 - 1, 0.018, Double(i / 4) * 0.41 - 0.65)
            glint.eulerAngles.y = 0.32
            shimmerPlanes.append(glint)
            scene.rootNode.addChildNode(glint)
        }
    }

    private func buildCameraAndLights(into scene: SCNScene) {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 1.73
        camera.zNear = 0.1
        camera.zFar = 20
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(1.12, 3.65, 6.8)
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

    private func update(
        _ folding: UnderwaterTheaterFolding, gameplay: UnderwaterTheaterGameplay, clock: Double
    ) {
        for node in coralFolds { setFold(node, amount: folding.coral) }

        let sway = CGFloat(gameplay.flowStrength * 0.22)
        for (index, blade) in seaweedFolds.enumerated() {
            setFold(blade, amount: folding.seaweed)
            blade.eulerAngles.z =
                CGFloat(sin(clock * 1.6 + Double(index) * 0.8) * 0.08 * folding.seaweed) + sway
                * (index.isMultiple(of: 2) ? 1 : -1)
        }

        for (index, plane) in shimmerPlanes.enumerated() {
            plane.opacity = CGFloat((0.18 + 0.16 * sin(clock * 1.45 + Double(index))) * folding.shimmer)
            plane.position.x = CGFloat(Double(index % 4) * 0.64 - 1 + 0.12 * sin(clock * 0.7 + Double(index)))
        }

        let flowScene = gameplay.flowPoint
        let showFlow = gameplay.canInteract && gameplay.flowStrength > 0.04
        flowBead.isHidden = !gameplay.canInteract
        flowBead.position = SCNVector3(flowScene.x, Self.flowPlaneHeight, flowScene.y)
        flowBead.opacity = CGFloat(0.55 + 0.45 * gameplay.flowStrength)

        let school = gameplay.schoolCenter()
        let blend = min(1, gameplay.flowStrength * 0.85)
        let heading = sampleHeading(base: school.heading, steer: school.steerHeading, blend: blend)
        let fishHide = folding.fish < 0.2 || gameplay.fishProgress < 0.02 && folding.fish < 0.55
        for (index, fish) in fishNodes.enumerated() {
            let offset = fishFormationOffset(index: index, heading: heading)
            let flutter = sin(clock * 7.3 + Double(index) * 0.83)
            fishTails[index].eulerAngles.y = CGFloat(flutter * (0.32 + 0.22 * blend))
            fish.position = SCNVector3(
                school.position.x + offset.x, 0.11 + Double(index % 3) * 0.034 + flutter * 0.012,
                school.position.y + offset.y)
            fish.eulerAngles.y = CGFloat(-heading)
            let behindVeil = school.position.x < -0.2 && gameplay.fishProgress < 0.12
            fish.isHidden = fishHide || (behindVeil && folding.fish < 0.65)
            fish.opacity = CGFloat(min(1, folding.fish * 1.1))
        }

        updateFlowStreaks(origin: flowScene, strength: gameplay.flowStrength, active: showFlow)
        updateShell(fishNear: school.position, folding: folding)
        for hit in tapHits { hit.isHidden = !gameplay.canInteract }
        for marker in currentMarkers { marker.isHidden = !gameplay.canInteract }
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

    private func box(width: Double, height: Double, depth: Double, color: NSColor) -> SCNNode {
        let geometry = SCNBox(width: width, height: height, length: depth, chamferRadius: 0.006)
        geometry.firstMaterial?.diffuse.contents = color
        return SCNNode(geometry: geometry)
    }

    private func color(_ red: Double, _ green: Double, _ blue: Double) -> NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }
}
