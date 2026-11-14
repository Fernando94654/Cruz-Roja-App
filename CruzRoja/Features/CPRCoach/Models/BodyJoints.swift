import Foundation

/// One arm and its hip, in pixels of the upright camera image, with the lowest confidence of its joints.
struct Arm: Equatable, Sendable {
    let shoulder: CGPoint
    let elbow: CGPoint
    let wrist: CGPoint
    let hip: CGPoint
    let visibility: Double
}

/// The joints the coach needs from the detected person.
struct BodyJoints: Equatable, Sendable {
    let left: Arm
    let right: Arm

    /// Arm facing the camera, used for the elbow angle.
    var bestArm: Arm {
        left.visibility >= right.visibility ? left : right
    }

    /// Shoulder height weighted by visibility; shoulders move with the compressions and jitter less than the wrists.
    var shouldersY: Double {
        // The 4th power lets the clearly visible shoulder dominate while still changing smoothly
        let weights = [left, right].map { (y: Double($0.shoulder.y), w: pow($0.visibility, 4)) }
        let total = weights.reduce(0) { $0 + $1.w }
        guard total > 0 else { return Double(bestArm.shoulder.y) }
        return weights.reduce(0) { $0 + $1.y * $1.w } / total
    }

    /// Shoulder-to-hip distance of the most visible side, used to normalize movement.
    var torsoLength: Double {
        let arm = bestArm
        return max(1, hypot(Double(arm.shoulder.x - arm.hip.x), Double(arm.shoulder.y - arm.hip.y)))
    }
}
