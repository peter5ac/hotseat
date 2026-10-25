import SwiftUI

enum LaneDodgeState {
    case calibrating
    case playing
    case gameOver
}

struct Obstacle: Identifiable {
    let id = UUID()
    let lane: Int
    var progress: CGFloat   // 0 = far (top), 1 = player line (bottom)
    let emoji: String
}

@Observable
final class LaneDodgeViewModel {
    // MARK: Config
    let laneCount = 3
    private let startingLives = 3

    /// Tilt past this many radians from neutral selects a side lane (~11°).
    private let laneThreshold: CGFloat = 0.20
    /// If true, positive roll maps to the right lane. Flipped on-device if needed.
    private let positiveRollIsRightLane = false

    /// Obstacle approach speed (progress units per second) at run start.
    private let baseSpeed: CGFloat = 0.45
    /// Added to speed per second survived (difficulty ramp).
    private let speedRampPerSecond: CGFloat = 0.03
    /// Seconds between spawns at run start.
    private let baseSpawnInterval: CGFloat = 1.3
    /// Spawn interval never drops below this (seconds).
    private let minSpawnInterval: CGFloat = 0.45
    /// How fast the spawn interval shrinks per second survived.
    private let spawnRampPerSecond: CGFloat = 0.04
    /// Progress at which an obstacle is at the player line.
    private let hitZone: CGFloat = 1.0
    private let obstacleEmojis = ["🪨", "🚧", "💥", "🛢️", "🚙"]

    // MARK: State
    var state: LaneDodgeState = .calibrating
    var lives: Int = 3
    var distance: Int = 0
    var playerLane: Int = 1
    var obstacles: [Obstacle] = []

    // MARK: Calibration
    private var calibrationSamples: [CGFloat] = []
    private var neutralRoll: CGFloat = 0

    // MARK: Runtime
    private var elapsed: CGFloat = 0
    private var timeSinceSpawn: CGFloat = 0
    /// Deterministic-ish spawn lane cursor; avoids Math.random (unavailable in
    /// some sandboxes and untestable). Uses a simple LCG seeded by spawn count.
    private var spawnCount: Int = 0

    func startCalibration() {
        state = .calibrating
        lives = startingLives
        distance = 0
        playerLane = 1
        obstacles = []
        calibrationSamples = []
        neutralRoll = 0
        elapsed = 0
        timeSinceSpawn = 0
        spawnCount = 0
    }

    /// Collect a roll reading during the calibration phase.
    func addCalibrationSample(roll: CGFloat?) {
        guard state == .calibrating, let roll else { return }
        calibrationSamples.append(roll)
    }

    /// Lock in the neutral roll and begin play. Falls back to 0 if no samples.
    func finishCalibration() {
        if !calibrationSamples.isEmpty {
            neutralRoll = calibrationSamples.reduce(0, +) / CGFloat(calibrationSamples.count)
        } else {
            neutralRoll = 0
        }
        state = .playing
    }

    /// Map a smoothed roll reading to a lane. No face → keep current lane.
    func updatePlayerLane(roll: CGFloat?) {
        guard state == .playing, let roll else { return }
        let delta = roll - neutralRoll
        let leftLane = 0
        let rightLane = laneCount - 1
        let centerLane = laneCount / 2

        if delta > laneThreshold {
            playerLane = positiveRollIsRightLane ? rightLane : leftLane
        } else if delta < -laneThreshold {
            playerLane = positiveRollIsRightLane ? leftLane : rightLane
        } else {
            playerLane = centerLane
        }
    }

    /// Linear-congruential lane picker — avoids Math.random, spreads lanes.
    private func nextSpawnLane() -> Int {
        spawnCount &+= 1
        let pseudo = (spawnCount &* 1103515245 &+ 12345) & 0x7fffffff
        return pseudo % laneCount
    }

    private func spawnObstacle() {
        let lane = nextSpawnLane()
        let emoji = obstacleEmojis[(spawnCount - 1) % obstacleEmojis.count]
        obstacles.append(Obstacle(lane: lane, progress: 0, emoji: emoji))
    }

    /// Advance the simulation by `delta` seconds.
    func tick(delta: CGFloat) {
        guard state == .playing else { return }
        elapsed += delta
        distance += 1

        // Difficulty ramp.
        let speed = baseSpeed + speedRampPerSecond * elapsed
        let spawnInterval = max(minSpawnInterval, baseSpawnInterval - spawnRampPerSecond * elapsed)

        // Advance obstacles.
        for i in obstacles.indices {
            obstacles[i].progress += speed * delta
        }

        // Resolve obstacles that reached the player line.
        var survivors: [Obstacle] = []
        for obstacle in obstacles {
            if obstacle.progress >= hitZone {
                if obstacle.lane == playerLane {
                    lives -= 1
                }
                // Either way the obstacle is consumed (dodged or hit).
            } else {
                survivors.append(obstacle)
            }
        }
        obstacles = survivors

        // Spawn.
        timeSinceSpawn += delta
        if timeSinceSpawn >= spawnInterval {
            timeSinceSpawn = 0
            spawnObstacle()
        }

        // Fail state.
        if lives <= 0 {
            lives = 0
            state = .gameOver
        }
    }

    /// Restart a fresh run from calibration.
    func reset() {
        startCalibration()
    }
}
