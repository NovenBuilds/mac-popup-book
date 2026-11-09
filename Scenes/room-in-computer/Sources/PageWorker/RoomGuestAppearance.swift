import PageBehavior
import SceneKit

final class RoomGuestAppearance {
    let root = SCNNode()
    private let torso = SCNNode()
    private let head = SCNNode()
    private let leftArm = SCNNode()
    private let rightArm = SCNNode()
    private let leftLeg = SCNNode()
    private let rightLeg = SCNNode()
    private let book = SCNNode()
    private var activityBlend: Double = 0
    private(set) var seatBlend = 0.0
    private var readingBlend = 0.0

    init() {
        let coat = tint(0.25, 0.53, 0.52)
        let cuff = tint(0.93, 0.63, 0.29)
        let skin = tint(0.95, 0.77, 0.57)
        let hair = tint(0.32, 0.19, 0.17)
        let shoes = tint(0.35, 0.26, 0.24)

        root.addChildNode(torso)
        addCard(to: torso, size: SCNVector3(0.102, 0.135, 0.045), at: SCNVector3(0, 0.18, 0), color: coat)
        addCard(
            to: torso, size: SCNVector3(0.109, 0.025, 0.049), at: SCNVector3(0, 0.142, 0.001), color: cuff)

        head.position.y = 0.257
        torso.addChildNode(head)
        let face = SCNNode(geometry: SCNSphere(radius: 0.049))
        face.scale = SCNVector3(1, 1.06, 0.65)
        face.geometry?.firstMaterial?.diffuse.contents = skin
        head.addChildNode(face)
        addCard(
            to: head, size: SCNVector3(0.092, 0.026, 0.054), at: SCNVector3(0, 0.031, -0.008), color: hair)
        for x in [-0.017, 0.017] {
            addCard(to: head, size: SCNVector3(0.007, 0.009, 0.003), at: SCNVector3(x, 0, 0.031), color: hair)
        }

        for (sign, arm, leg) in [(-1.0, leftArm, leftLeg), (1.0, rightArm, rightLeg)] {
            arm.position = SCNVector3(sign * 0.059, 0.224, 0)
            torso.addChildNode(arm)
            addCard(to: arm, size: SCNVector3(0.026, 0.085, 0.024), at: SCNVector3(0, -0.038, 0), color: coat)
            addCard(to: arm, size: SCNVector3(0.024, 0.026, 0.024), at: SCNVector3(0, -0.083, 0), color: skin)
            leg.position = SCNVector3(sign * 0.024, 0.119, 0)
            torso.addChildNode(leg)
            addCard(to: leg, size: SCNVector3(0.03, 0.102, 0.027), at: SCNVector3(0, -0.047, 0), color: shoes)
            addCard(
                to: leg, size: SCNVector3(0.035, 0.023, 0.052), at: SCNVector3(0, -0.105, 0.014), color: shoes
            )
        }
        book.position = SCNVector3(0, 0.225, 0.073)
        for sign in [-1.0, 1.0] {
            let page = addCard(
                to: book, size: SCNVector3(0.047, 0.065, 0.006),
                at: SCNVector3(sign * 0.022, 0, 0), color: tint(0.98, 0.91, 0.69))
            page.eulerAngles.y = sign * 0.32
        }
        torso.addChildNode(book)
    }

    func update(activity: RoomTimePhase, walk: Double, clock: Double, delta: Double) {
        let settled = walk >= 1
        let targetBlend = settled ? 1.0 : 0.0
        let travel = max(0, min(0.05, delta)) * 7
        activityBlend += max(-travel, min(travel, targetBlend - activityBlend))
        let step = sin(walk * 6 * .pi) * 0.53 * (1 - activityBlend)
        let breath = sin(clock * 2.1) * 0.014
        let readTarget = activity == .afternoon && settled ? 1.0 : 0.0
        let restTarget = activity == .evening && settled ? 1.0 : 0.0
        readingBlend += max(-travel, min(travel, readTarget - readingBlend))
        seatBlend += max(-travel, min(travel, restTarget - seatBlend))
        let read = readingBlend
        let rest = seatBlend
        let stretch = activity == .morning ? max(0, sin(clock * 1.3)) * activityBlend : 0

        leftLeg.eulerAngles.x = step - rest * 1.38
        rightLeg.eulerAngles.x = -step - rest * 1.38
        leftArm.eulerAngles.x = -step - read * 1.02 - stretch * 0.52
        rightArm.eulerAngles.x = step - read * 1.02 - stretch * 0.84
        head.eulerAngles.x = read * 0.30 + rest * 0.09 + breath
        torso.position.y = -rest * 0.055 + abs(step) * 0.026
        book.opacity = CGFloat(read)
        book.isHidden = read < 0.02
    }

    @discardableResult
    private func addCard(to parent: SCNNode, size: SCNVector3, at position: SCNVector3, color: NSColor)
        -> SCNNode
    {
        let card = SCNBox(width: size.x, height: size.y, length: size.z, chamferRadius: 0.003)
        card.firstMaterial?.diffuse.contents = color
        let node = SCNNode(geometry: card)
        node.position = position
        parent.addChildNode(node)
        return node
    }

    private func tint(_ red: Double, _ green: Double, _ blue: Double) -> NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }
}
