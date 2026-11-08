import SceneKit

struct RoomGuestAppearance {
    let root: SCNNode

    static func make() -> RoomGuestAppearance {
        let root = SCNNode()
        let body = box(width: 0.08, height: 0.18, depth: 0.05, color: color(0.58, 0.62, 0.7))
        body.position = SCNVector3(0, 0.1, 0)
        root.addChildNode(body)
        let head = box(width: 0.07, height: 0.07, depth: 0.05, color: color(0.9, 0.82, 0.72))
        head.position = SCNVector3(0, 0.24, 0)
        root.addChildNode(head)
        return RoomGuestAppearance(root: root)
    }

    private static func box(width: Double, height: Double, depth: Double, color: NSColor) -> SCNNode {
        let geometry = SCNBox(width: width, height: height, length: depth, chamferRadius: 0.003)
        geometry.firstMaterial?.diffuse.contents = color
        return SCNNode(geometry: geometry)
    }

    private static func color(_ red: Double, _ green: Double, _ blue: Double) -> NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }
}
