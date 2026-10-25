import CoreMotion
import Foundation

/// Wraps CMMotionManager to publish a landscape-oriented pitch angle and a
/// coarse landscape flag. Kept separate from the game view model so the model
/// stays free of CoreMotion and testable with plain numbers.
@Observable
final class MotionTracker {
    /// Signed tilt in degrees. Near 0 when the phone is held vertically at
    /// forehead level in landscape. Sign distinguishes tilt-up from tilt-down;
    /// the absolute sign is only required to be *consistent* because consumers
    /// compare against a captured neutral.
    var pitch: Double = 0

    /// True when the device's long axis is roughly horizontal (landscape).
    var isLandscape: Bool = false

    /// False on the simulator or any device without device-motion support.
    var isAvailable: Bool = false

    private let manager = CMMotionManager()

    init() {
        isAvailable = manager.isDeviceMotionAvailable
    }

    func start() {
        guard manager.isDeviceMotionAvailable else {
            isAvailable = false
            return
        }
        isAvailable = true
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let g = motion.gravity   // unit vector pointing "down" in device space

            // Landscape when the long axis (x) carries more gravity than the
            // short axis (y).
            self.isLandscape = abs(g.x) > abs(g.y)

            // Pitch from the long axis vs the screen-normal axis. atan2 keeps it
            // continuous and avoids gimbal flips near vertical. Result in degrees.
            let radians = atan2(g.z, g.x)
            self.pitch = radians * 180.0 / .pi
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    deinit {
        manager.stopDeviceMotionUpdates()
    }
}
