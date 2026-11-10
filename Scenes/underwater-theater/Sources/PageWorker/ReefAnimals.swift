import PageBehavior
import SceneKit

/// Cut-paper wildlife on separate floor, grass and distant-water planes.
final class ReefAnimals {
    private let stars = [SCNNode(), SCNNode()]
    private let crab = SCNNode()
    private let claws = [SCNNode(), SCNNode()]
    private let legs = [SCNNode(), SCNNode(), SCNNode(), SCNNode(), SCNNode(), SCNNode()]
    private let seahorse = SCNNode()
    private let butterfly = SCNNode()
    private let butterflyTail = SCNNode()
    private let shark = SCNNode()
    private let sharkTail = SCNNode()
    private let pink = NSColor(srgbRed: 0.91, green: 0.34, blue: 0.29, alpha: 1)
    private let sand = NSColor(srgbRed: 1, green: 0.85, blue: 0.52, alpha: 1)
    private let ink = NSColor(srgbRed: 0.05, green: 0.19, blue: 0.23, alpha: 1)

    init(root: SCNNode) {
        for (index, star) in stars.enumerated() {
            let points = (0..<10).map { i -> (Double, Double) in
                let angle = Double(i) * .pi / 5 + .pi / 2
                let r = i.isMultiple(of: 2) ? 0.135 : 0.053
                return (r * cos(angle), r * sin(angle))
            }
            star.addChildNode(cut(points, tint: index == 0 ? pink : sand))
            for arm in 0..<5 {
                let angle = Double(arm) * 2 * .pi / 5 + .pi / 2
                dot(
                    on: star, at: SCNVector3(0.059 * cos(angle), 0.059 * sin(angle), 0.013), radius: 0.012,
                    tint: index == 0 ? sand : pink)
            }
            let card = SCNNode()
            for part in star.childNodes { card.addChildNode(part) }
            card.eulerAngles.x = -.pi / 2
            star.addChildNode(card)
            star.position = SCNVector3(index == 0 ? -1.53 : 1.15, 0.021, index == 0 ? 1.01 : 0.98)
            root.addChildNode(star)
        }

        crab.addChildNode(
            cut(
                [
                    (-0.14, 0.015), (-0.11, 0.095), (-0.052, 0.122), (0.052, 0.122),
                    (0.11, 0.095), (0.14, 0.015), (0.10, -0.034), (-0.10, -0.034),
                ], tint: pink))
        for (sideIndex, side) in [-1.0, 1.0].enumerated() {
            dot(on: crab, at: SCNVector3(side * 0.064, 0.105, 0.021), radius: 0.016, tint: ink)
            let claw = claws[sideIndex]
            claw.position = SCNVector3(side * 0.11, 0.057, 0)
            claw.scale.x = CGFloat(side)
            claw.addChildNode(
                cut(
                    [
                        (0, 0), (0.045, 0.027), (0.059, 0.097), (0.112, 0.123),
                        (0.13, 0.089), (0.097, 0.067), (0.127, 0.062),
                        (0.111, 0.024), (0.068, 0.013),
                    ], tint: pink))
            crab.addChildNode(claw)
            for legIndex in 0..<3 {
                let leg = legs[sideIndex * 3 + legIndex]
                leg.position = SCNVector3(
                    side * (0.075 + Double(legIndex) * 0.018), -0.014, Double(legIndex - 1) * 0.026)
                leg.scale.x = CGFloat(side)
                leg.addChildNode(
                    cut(
                        [
                            (0, 0.015), (0.060, 0.009), (0.093, -0.048), (0.079, -0.053), (0.047, -0.009),
                            (0, -0.008),
                        ], tint: pink))
                crab.addChildNode(leg)
            }
        }
        root.addChildNode(crab)

        seahorse.addChildNode(
            cut(
                [
                    (-0.03, 0.21), (-0.075, 0.161), (-0.065, 0.095), (-0.111, 0.026),
                    (-0.095, -0.065), (-0.04, -0.10), (0.017, -0.078),
                    (0.029, -0.034), (-0.004, -0.004), (-0.035, -0.031),
                    (-0.016, -0.038), (-0.024, -0.062), (-0.052, -0.052),
                    (-0.059, -0.002), (0.027, 0.05), (0.038, 0.126), (0.122, 0.126),
                    (0.133, 0.158), (0.064, 0.171), (0.047, 0.206), (0.012, 0.23),
                ], tint: sand))
        let fin = cut([(-0.07, 0.115), (-0.143, 0.12), (-0.104, 0.05), (-0.06, 0.057)], tint: pink)
        fin.position.z = 0.011
        seahorse.addChildNode(fin)
        dot(on: seahorse, at: SCNVector3(0.035, 0.17, 0.02), radius: 0.014, tint: ink)
        root.addChildNode(seahorse)

        butterfly.addChildNode(
            cut(
                [
                    (-0.11, 0), (-0.075, 0.079), (0, 0.112), (0.058, 0.083),
                    (0.094, 0.029), (0.154, 0.008), (0.093, -0.020), (0.053, -0.085),
                    (-0.024, -0.103), (-0.083, -0.065),
                ], tint: sand))
        for side in [-1.0, 1.0] {
            let band = cut([(-0.054, 0.086), (-0.015, 0.105), (-0.041, -0.092), (-0.076, -0.069)], tint: ink)
            band.position.z = CGFloat(side * 0.015)
            butterfly.addChildNode(band)
            dot(on: butterfly, at: SCNVector3(0.061, 0.037, side * 0.019), radius: 0.013, tint: ink)
        }
        butterflyTail.addChildNode(cut([(0, 0), (-0.084, 0.052), (-0.075, -0.055)], tint: pink))
        butterflyTail.position.x = -0.098
        butterfly.addChildNode(butterflyTail)
        root.addChildNode(butterfly)

        let slate = NSColor(srgbRed: 0.27, green: 0.48, blue: 0.61, alpha: 1)
        shark.addChildNode(
            cut(
                [
                    (-0.27, 0.018), (-0.135, 0.065), (-0.06, 0.073), (-0.098, 0.208),
                    (0.041, 0.085), (0.169, 0.061), (0.30, 0.004), (0.25, -0.045),
                    (0.118, -0.066), (-0.021, -0.156), (-0.004, -0.067), (-0.17, -0.049),
                ], tint: slate))
        sharkTail.addChildNode(
            cut([(0, 0.023), (-0.12, 0.132), (-0.086, 0.002), (-0.117, -0.104), (0, -0.029)], tint: slate))
        sharkTail.position.x = -0.25
        shark.addChildNode(sharkTail)
        for side in [-1.0, 1.0] {
            let belly = cut(
                [
                    (-0.21, -0.024), (0.119, -0.018), (0.255, -0.018),
                    (0.196, -0.053), (0.097, -0.061), (-0.02, -0.068), (-0.171, -0.047),
                ],
                tint: NSColor(srgbRed: 0.74, green: 0.86, blue: 0.85, alpha: 1))
            belly.position.z = CGFloat(side * 0.015)
            shark.addChildNode(belly)
            dot(on: shark, at: SCNVector3(0.196, 0.025, side * 0.018), radius: 0.013, tint: ink)
        }
        root.addChildNode(shark)
    }

    func update(layer: Int, clock: Double) {
        for (index, star) in stars.enumerated() {
            star.isHidden = layer < 1
            star.eulerAngles.y = CGFloat(0.19 * sin(clock * 0.54 + Double(index) * 2))
        }
        crab.isHidden = layer < 2
        let crabCenter = ReefWildlifeMotion.crab(at: clock)
        crab.position = SCNVector3(crabCenter.x, crabCenter.y, crabCenter.z)
        for (index, leg) in legs.enumerated() {
            leg.eulerAngles.z = CGFloat(sin(clock * 9 + Double(index) * 1.6) * 0.25)
        }
        for (index, claw) in claws.enumerated() {
            claw.eulerAngles.z = CGFloat(0.16 * sin(clock * 2.7 + Double(index)))
        }
        seahorse.isHidden = layer < 2
        let seahorseCenter = ReefWildlifeMotion.seahorse(at: clock)
        seahorse.position = SCNVector3(seahorseCenter.x, seahorseCenter.y, seahorseCenter.z)
        seahorse.eulerAngles.z = CGFloat(0.13 * sin(clock * 1.4))
        seahorse.eulerAngles.y = CGFloat(0.26 * sin(clock * 0.7))

        let reefFish = ReefWildlifeMotion.butterfly(at: clock)
        butterfly.isHidden = layer < 3
        butterfly.position = SCNVector3(reefFish.position.x, reefFish.position.y, reefFish.position.z)
        butterfly.eulerAngles.y = CGFloat(reefFish.heading)
        butterflyTail.eulerAngles.y = CGFloat(0.44 * sin(clock * 8))

        let distantShark = ReefWildlifeMotion.shark(at: clock)
        shark.isHidden = layer < 4
        shark.opacity = CGFloat(0.46 + 0.54 * max(0, 1 - abs(distantShark.position.x) / 1.18))
        shark.position = SCNVector3(distantShark.position.x, distantShark.position.y, distantShark.position.z)
        shark.eulerAngles.y = CGFloat(distantShark.heading)
        sharkTail.eulerAngles.y = CGFloat(0.34 * sin(clock * 4.9))
    }

    private func cut(_ outline: [(Double, Double)], tint: NSColor) -> SCNNode {
        let path = NSBezierPath()
        let scale = 500.0
        path.move(to: CGPoint(x: outline[0].0 * scale, y: outline[0].1 * scale))
        for (x, y) in outline.dropFirst() { path.line(to: CGPoint(x: x * scale, y: y * scale)) }
        path.close()
        let geometry = SCNShape(path: path, extrusionDepth: 6)
        geometry.firstMaterial?.diffuse.contents = tint
        let piece = SCNNode(geometry: geometry)
        piece.scale = SCNVector3(1 / scale, 1 / scale, 1 / scale)
        return piece
    }

    private func dot(on parent: SCNNode, at position: SCNVector3, radius: Double, tint: NSColor) {
        let eye = SCNNode(geometry: SCNSphere(radius: radius))
        eye.geometry?.firstMaterial?.diffuse.contents = tint
        eye.position = position
        parent.addChildNode(eye)
    }
}
