import Foundation

public struct RoomAxisBounds: Equatable, Sendable {
    public var minX: Double
    public var maxX: Double
    public var minZ: Double
    public var maxZ: Double

    public init(minX: Double, maxX: Double, minZ: Double, maxZ: Double) {
        self.minX = minX
        self.maxX = maxX
        self.minZ = minZ
        self.maxZ = maxZ
    }

    public func expanded(by margin: Double) -> RoomAxisBounds {
        RoomAxisBounds(
            minX: minX - margin, maxX: maxX + margin, minZ: minZ - margin, maxZ: maxZ + margin)
    }

    public func contains(x: Double, z: Double) -> Bool {
        (minX...maxX).contains(x) && (minZ...maxZ).contains(z)
    }
}

/// 全开家具占地与房客停靠点；与 SceneKit 摆位一致，供玩法与测试共用。
public enum RoomFurnitureLayout {
    public static let guestClearance = 0.08

    public static let bed = RoomAxisBounds(minX: -0.78, maxX: -0.06, minZ: -0.59, maxZ: -0.11)
    public static let desk = RoomAxisBounds(minX: 0.09, maxX: 0.67, minZ: -0.14, maxZ: 0.18)
    public static let chair = RoomAxisBounds(minX: -0.02, maxX: 0.26, minZ: 0.04, maxZ: 0.46)

    public static func pose(for phase: RoomTimePhase) -> RoomGuestPose {
        switch phase {
        case .morning:
            return RoomGuestPose(x: 0.08, z: -0.35, activity: .morning)
        case .afternoon:
            return RoomGuestPose(x: 0.38, z: 0.32, activity: .afternoon)
        case .evening:
            return RoomGuestPose(x: 0.36, z: 0.5, activity: .evening)
        }
    }

    public static func overlapsFurniture(x: Double, z: Double) -> Bool {
        let margin = guestClearance
        return bed.expanded(by: margin).contains(x: x, z: z)
            || desk.expanded(by: margin).contains(x: x, z: z)
            || chair.expanded(by: margin).contains(x: x, z: z)
    }

    public static var furniturePieces: [RoomAxisBounds] { [bed, desk, chair] }
}
