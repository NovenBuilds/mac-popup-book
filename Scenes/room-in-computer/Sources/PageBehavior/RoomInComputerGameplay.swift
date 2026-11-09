import Foundation
import PopupBookCore

public enum RoomTimePhase: String, Equatable, Sendable {
    case morning
    case afternoon
    case evening
}

public enum RoomStripTarget: Equatable, Sendable {
    case dragX(Double)
    case dockMorning
    case dockAfternoon
    case dockEvening
}

public struct RoomGuestPose: Equatable, Sendable {
    public var x: Double
    public var z: Double
    public var activity: RoomTimePhase

    public init(x: Double, z: Double, activity: RoomTimePhase) {
        self.x = x
        self.z = z
        self.activity = activity
    }
}

public struct RoomInComputerSnapshot: Codable, Equatable, Sendable {
    public static let formatVersion = 1
    public var version: Int
    public var roomTime: Double

    public init(roomTime: Double) {
        version = Self.formatVersion
        self.roomTime = RoomInComputerGameplay.clamp(roomTime)
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        guard version == Self.formatVersion else {
            throw StateRestoreError.unsupportedVersion(version)
        }
        let raw = try values.decode(Double.self, forKey: .roomTime)
        guard raw.isFinite else { throw StateRestoreError.invalidState }
        roomTime = RoomInComputerGameplay.clamp(raw)
    }

    public static func decoded(_ data: Data) throws -> Self {
        struct VersionProbe: Decodable { let version: Int }
        let version = try JSONDecoder().decode(VersionProbe.self, from: data).version
        guard version == formatVersion else { throw StateRestoreError.unsupportedVersion(version) }
        let snapshot = try JSONDecoder().decode(Self.self, from: data)
        guard snapshot.roomTime.isFinite else { throw StateRestoreError.invalidState }
        return snapshot
    }
}

public struct RoomInComputerGameplay: Equatable, Sendable {
    public private(set) var roomTime: Double
    public private(set) var guestGoal: RoomTimePhase
    public private(set) var guestFrom: RoomGuestPose
    public private(set) var guestTo: RoomGuestPose
    public private(set) var guestMove: Double
    public private(set) var guestPath: [RoomGuestWaypoint] = []
    public var draggingStrip: Bool
    public static let paperSlot: RoomGuestWaypoint = {
        let bedside = RoomFurnitureLayout.pose(for: .morning)
        return RoomGuestWaypoint(x: bedside.x, z: bedside.z)
    }()
    private var entrancePath: [RoomGuestWaypoint] = []
    private var entranceDestination: RoomGuestPose?

    public static let morningDock = 0.0
    public static let afternoonDock = 0.5
    public static let eveningDock = 1.0
    public static let walkDuration = 0.85

    public init() {
        self.init(restoredTime: Self.afternoonDock)
    }

    public init(restoredTime: Double) {
        roomTime = Self.clamp(restoredTime)
        guestGoal = Self.phase(for: roomTime)
        let pose = Self.pose(for: guestGoal)
        guestFrom = pose
        guestTo = pose
        guestMove = 1
        guestPath = [RoomGuestWaypoint(x: pose.x, z: pose.z)]
        draggingStrip = false
    }

    public static func clamp(_ value: Double) -> Double {
        if value.isNaN { return 0 }
        guard value.isFinite else { return value.sign == .minus ? 0 : 1 }
        return min(1, max(0, value))
    }

    public static func phase(for time: Double) -> RoomTimePhase {
        let t = clamp(time)
        if t < 0.34 { return .morning }
        if t < 0.67 { return .afternoon }
        return .evening
    }

    public static func pose(for phase: RoomTimePhase) -> RoomGuestPose {
        RoomFurnitureLayout.pose(for: phase)
    }

    public mutating func handleStrip(_ target: RoomStripTarget) {
        switch target {
        case .dragX(let x):
            draggingStrip = true
            roomTime = Self.clamp(x)
            retargetGuestIfNeeded()
        case .dockMorning:
            draggingStrip = false
            roomTime = Self.morningDock
            retargetGuestIfNeeded()
        case .dockAfternoon:
            draggingStrip = false
            roomTime = Self.afternoonDock
            retargetGuestIfNeeded()
        case .dockEvening:
            draggingStrip = false
            roomTime = Self.eveningDock
            retargetGuestIfNeeded()
        }
    }

    public mutating func endStripDrag() {
        draggingStrip = false
    }

    public mutating func cancelPointer() {
        draggingStrip = false
    }

    public func snapshot() -> RoomInComputerSnapshot {
        RoomInComputerSnapshot(roomTime: roomTime)
    }

    public mutating func advance(deltaTime: Double, folding: RoomInComputerFolding) {
        let delta = max(0, deltaTime)
        if !folding.canChangeTime {
            if entranceDestination == nil {
                let pose = guestDisplay
                entranceDestination = pose
                entrancePath = RoomGuestRouter.path(
                    from: Self.paperSlot, to: RoomGuestWaypoint(x: pose.x, z: pose.z))
            }
            return
        }
        entranceDestination = nil
        if guestMove < 1 {
            guestMove = min(1, guestMove + delta / Self.walkDuration)
        }
    }

    public var guestDisplay: RoomGuestPose {
        if guestMove >= 1 { return guestTo }
        let eased = guestMove * guestMove * (3 - 2 * guestMove)
        let sample = RoomGuestRouter.point(along: guestPath, progress: eased)
        return RoomGuestPose(x: sample.x, z: sample.z, activity: guestTo.activity)
    }

    public var lightForTime: Double { Self.clamp(roomTime) }

    public func caption(zh: Bool) -> String {
        let phase = Self.phase(for: roomTime)
        switch phase {
        case .morning:
            return zh ? "清晨：拖动纸拉条，让光掠过床边。" : "Morning: drag the time strip past the bed."
        case .afternoon:
            return zh ? "午后：房客在桌边阅读，光线柔和。" : "Afternoon: reading at the desk in soft daylight."
        case .evening:
            return zh ? "夜晚：台灯亮起，房客坐在扶手椅。" : "Evening: the lamp glows; guest in the armchair."
        }
    }

    public func stripLabel(zh: Bool) -> String {
        zh ? "房间时光" : "Room time"
    }

    public func entrancePoint(at progress: Double) -> RoomGuestWaypoint {
        let pose = entranceDestination ?? guestDisplay
        let path =
            entrancePath.isEmpty
            ? RoomGuestRouter.path(from: Self.paperSlot, to: RoomGuestWaypoint(x: pose.x, z: pose.z))
            : entrancePath
        let point = RoomGuestRouter.point(along: path, progress: progress)
        return RoomGuestWaypoint(x: point.x, z: point.z)
    }

    private mutating func retargetGuestIfNeeded() {
        let next = Self.phase(for: roomTime)
        guard next != guestGoal || guestMove >= 1 else { return }
        if guestMove < 1 {
            guestFrom = guestDisplay
        } else {
            guestFrom = guestTo
        }
        guestGoal = next
        guestTo = Self.pose(for: next)
        let alreadyThere =
            guestGoal == guestFrom.activity && guestFrom.x == guestTo.x && guestFrom.z == guestTo.z
        if alreadyThere || (guestFrom.x == guestTo.x && guestFrom.z == guestTo.z) {
            guestPath = [RoomGuestWaypoint(x: guestTo.x, z: guestTo.z)]
            guestMove = 1
            return
        }
        guestPath = RoomGuestRouter.path(
            from: RoomGuestWaypoint(x: guestFrom.x, z: guestFrom.z),
            to: RoomGuestWaypoint(x: guestTo.x, z: guestTo.z))
        guestMove = 0
    }
}
