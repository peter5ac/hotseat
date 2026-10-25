import Foundation
import Observation

struct TargetItem: Identifiable {
    let id = UUID()
    var position: CGPoint
    var health: Int
    var isDestroyed: Bool = false
    var size: CGFloat = 70
}

enum LaserEyesState: Equatable {
    case idle
    case countdown(Int)
    case playing
    case gameOver
}

@Observable
final class LaserEyesViewModel {
    var gameState: LaserEyesState = .idle
    var targets: [TargetItem] = []
    var score: Int = 0
    var gazePoint: CGPoint? = nil
    var isFiring: Bool = false
    var lockedTargetIDs: Set<UUID> = []
    var lockedEyeChoice: [UUID: Bool] = [:]  // true = left eye, false = right eye
    var lockedDwellTime: [UUID: TimeInterval] = [:]

    private(set) var roundNumber: Int = 0
    private var dwellAccumulator: [UUID: TimeInterval] = [:]
    private var spawnTimer: TimeInterval = 0
    private var countdownTimer: TimeInterval = 0
    private var gameDuration: TimeInterval = 0
    private let maxGameTime: TimeInterval = 30.0
    private let dwellThreshold: TimeInterval = 0.4
    private let spawnInterval: TimeInterval = 1.8
    private let maxTargetsOnScreen = 6
    private(set) var canvasSize: CGSize = CGSize(width: 390, height: 844)

    var canvasWidth: CGFloat { canvasSize.width }
    var canvasHeight: CGFloat { canvasSize.height }

    var timeRemaining: TimeInterval {
        max(0, maxGameTime - gameDuration)
    }

    func setCanvasSize(_ size: CGSize) {
        canvasSize = size
    }

    func startGame() {
        targets = []
        score = 0
        roundNumber += 1
        dwellAccumulator = [:]
        spawnTimer = 0
        gameDuration = 0
        gameState = .countdown(3)
        countdownTimer = 0
    }

    func updateGaze(noseTip: CGPoint?, yaw: CGFloat?, pitch: CGFloat?) {
        guard let nose = noseTip else {
            gazePoint = nil
            isFiring = false
            return
        }
        // Amplify nose displacement from screen center to cover the full canvas.
        // The nose moves ~100-150pt when turning your head; targets span the screen.
        let gain: CGFloat = 2.5
        let centerX = canvasSize.width / 2
        let centerY = canvasSize.height / 2
        let offsetX = (nose.x - centerX) * gain
        let offsetY = (nose.y - centerY) * gain
        let projectedX = min(max(centerX + offsetX, 0), canvasSize.width)
        let projectedY = min(max(centerY + offsetY, 0), canvasSize.height)
        gazePoint = CGPoint(x: projectedX, y: projectedY)
        isFiring = true
    }

    func tick(delta: TimeInterval) {
        switch gameState {
        case .countdown(let n):
            countdownTimer += delta
            if countdownTimer >= 1.0 {
                countdownTimer -= 1.0
                let next = n - 1
                if next <= 0 {
                    gameState = .playing
                    spawnTargets(count: 3)
                } else {
                    gameState = .countdown(next)
                }
            }
        case .playing:
            gameDuration += delta
            if gameDuration >= maxGameTime {
                gameState = .gameOver
                return
            }
            spawnTimer += delta
            if spawnTimer >= spawnInterval && activeTargetCount < maxTargetsOnScreen {
                spawnTimer -= spawnInterval
                spawnTargets(count: 1)
            }
            checkCollisions(delta: delta)
        default:
            break
        }
    }

    // MARK: - Private

    private var activeTargetCount: Int {
        targets.filter { !$0.isDestroyed }.count
    }

    private func spawnTargets(count: Int) {
        let margin: CGFloat = 60
        for _ in 0..<count {
            let x = CGFloat.random(in: margin...(canvasSize.width - margin))
            let y = CGFloat.random(in: margin...(canvasSize.height - margin))
            let target = TargetItem(position: CGPoint(x: x, y: y), health: 3)
            targets.append(target)
        }
    }

    private func checkCollisions(delta: TimeInterval) {
        guard let gaze = gazePoint else {
            dwellAccumulator.removeAll()
            lockedTargetIDs = []
            lockedEyeChoice.removeAll()
            lockedDwellTime.removeAll()
            return
        }

        var currentlyLocked: Set<UUID> = []

        for i in targets.indices where !targets[i].isDestroyed {
            let target = targets[i]
            let hitRadius = target.size / 2
            let dx = gaze.x - target.position.x
            let dy = gaze.y - target.position.y
            let dist = sqrt(dx * dx + dy * dy)

            if dist <= hitRadius {
                currentlyLocked.insert(target.id)
                // Assign a random eye on first lock
                if lockedEyeChoice[target.id] == nil {
                    lockedEyeChoice[target.id] = Bool.random()
                }
                let accumulated = (dwellAccumulator[target.id] ?? 0) + delta
                dwellAccumulator[target.id] = accumulated
                lockedDwellTime[target.id] = accumulated
                if accumulated >= dwellThreshold {
                    dwellAccumulator[target.id] = 0
                    lockedDwellTime[target.id] = 0
                    targets[i].health -= 1
                    if targets[i].health <= 0 {
                        targets[i].isDestroyed = true
                        score += 10
                        dwellAccumulator.removeValue(forKey: target.id)
                        lockedEyeChoice.removeValue(forKey: target.id)
                        lockedDwellTime.removeValue(forKey: target.id)
                        currentlyLocked.remove(target.id)
                    }
                }
            } else {
                dwellAccumulator.removeValue(forKey: target.id)
                lockedEyeChoice.removeValue(forKey: target.id)
                lockedDwellTime.removeValue(forKey: target.id)
            }
        }

        lockedTargetIDs = currentlyLocked
    }
}
