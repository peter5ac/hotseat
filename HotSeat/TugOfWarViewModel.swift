import SwiftUI

enum TugOfWarState: Equatable {
    case waitingForFaces
    case countdown
    case playing
    case gameOver
}

enum RoundPhase: Equatable {
    case showingPrompt   // prompt just appeared, brief delay before detection starts
    case racing          // actively checking expressions
    case scored          // someone won the round, brief pause
}

enum ExpressionType: CaseIterable {
    case mouthOpen
    case turnLeft
    case turnRight
    case tiltLeft
    case tiltRight
    case leaveFrame

    var label: String {
        switch self {
        case .mouthOpen:  "Open your mouth!"
        case .turnLeft:   "Turn left!"
        case .turnRight:  "Turn right!"
        case .tiltLeft:   "Tilt left!"
        case .tiltRight:  "Tilt right!"
        case .leaveFrame: "Leave the frame!"
        }
    }

    var emoji: String {
        switch self {
        case .mouthOpen:  "😮"
        case .turnLeft:   "👈"
        case .turnRight:  "👉"
        case .tiltLeft:   "↩️"
        case .tiltRight:  "↪️"
        case .leaveFrame: "🏃"
        }
    }
}

@Observable
final class TugOfWarViewModel {
    // MARK: - Config
    private let notchSize: CGFloat = 0.2        // rope moves this much per round
    private let promptDelay: CGFloat = 0.6      // seconds before detection starts
    private let scoredPause: CGFloat = 0.8      // seconds between rounds
    private let roundTimeout: CGFloat = 5.0     // seconds before a pass (no one matched)
    private let yawThreshold: CGFloat = 0.3     // radians
    private let rollThreshold: CGFloat = 0.3    // radians

    // MARK: - Public state
    var state: TugOfWarState = .waitingForFaces
    var roundPhase: RoundPhase = .showingPrompt
    var ropeProgress: CGFloat = 0.0             // -1...+1
    var currentPrompt: ExpressionType = .mouthOpen
    var winnerName: String?
    var roundWinner: Int?                        // 1 or 2, briefly non-nil after a score
    var countdownValue: Int = 3

    var isGameOver: Bool { state == .gameOver }
    var hasBothFaces: Bool { latestExpressions.count >= 2 }

    // MARK: - Private
    private var latestExpressions: [PerFaceExpression] = []
    private var latestFaceCentersX: [CGFloat] = []
    private var phaseTimer: CGFloat = 0
    private var racingTimer: CGFloat = 0
    private var usedPrompts: [ExpressionType] = []
    private var hadTwoFaces: Bool = false

    // MARK: - Public methods

    func startGame() {
        state = .waitingForFaces
        ropeProgress = 0.0
        winnerName = nil
        roundWinner = nil
        countdownValue = 3
        phaseTimer = 0
        usedPrompts = []
        pickNextPrompt()
    }

    func updateFaces(_ expressions: [PerFaceExpression], centersX: [CGFloat]) {
        hadTwoFaces = latestExpressions.count >= 2
        latestExpressions = expressions
        latestFaceCentersX = centersX

        if state == .waitingForFaces && expressions.count >= 2 {
            state = .countdown
            countdownValue = 3
            phaseTimer = 0
        }
    }

    /// Called every frame by the display link. Drives countdown, prompt timing, and detection.
    func tick(delta: CGFloat) {
        switch state {
        case .waitingForFaces:
            break

        case .countdown:
            guard latestExpressions.count >= 2 else {
                state = .waitingForFaces
                return
            }
            phaseTimer += delta
            if phaseTimer >= 1.0 {
                phaseTimer = 0
                countdownValue -= 1
                if countdownValue <= 0 {
                    state = .playing
                    roundPhase = .showingPrompt
                    phaseTimer = 0
                }
            }

        case .playing:
            switch roundPhase {
            case .showingPrompt:
                phaseTimer += delta
                if phaseTimer >= promptDelay {
                    roundPhase = .racing
                    racingTimer = 0
                }

            case .racing:
                racingTimer += delta
                if racingTimer >= roundTimeout {
                    roundPhase = .scored
                    phaseTimer = 0
                    roundWinner = nil
                } else if currentPrompt == .leaveFrame {
                    checkLeaveFrame()
                } else if latestExpressions.count >= 2 {
                    checkExpressions()
                }

            case .scored:
                phaseTimer += delta
                if phaseTimer >= scoredPause {
                    roundWinner = nil
                    roundPhase = .showingPrompt
                    phaseTimer = 0
                    pickNextPrompt()
                }
            }

        case .gameOver:
            break
        }
    }

    func reset() {
        startGame()
    }

    // MARK: - Private

    private func checkExpressions() {
        guard latestExpressions.count >= 2 else { return }
        let p1 = latestExpressions[0]
        let p2 = latestExpressions[1]

        let p1Matches = matches(expression: p1, prompt: currentPrompt)
        let p2Matches = matches(expression: p2, prompt: currentPrompt)

        if p1Matches && !p2Matches {
            scoreRound(winner: 1)
        } else if p2Matches && !p1Matches {
            scoreRound(winner: 2)
        } else if p1Matches && p2Matches {
            // Tie — both matched same frame. No score, pick new prompt.
            roundPhase = .scored
            phaseTimer = 0
            roundWinner = nil
        }
    }

    private func matches(expression: PerFaceExpression, prompt: ExpressionType) -> Bool {
        switch prompt {
        case .mouthOpen:  return expression.mouthOpen
        case .turnLeft:   return expression.yaw < -yawThreshold
        case .turnRight:  return expression.yaw > yawThreshold
        case .tiltLeft:   return expression.roll < -rollThreshold
        case .tiltRight:  return expression.roll > rollThreshold
        case .leaveFrame: return false // handled separately in checkLeaveFrame
        }
    }

    private func checkLeaveFrame() {
        // Score when face count drops from 2 to 1. The remaining face's X tells us who stayed.
        guard hadTwoFaces, latestFaceCentersX.count == 1 else { return }
        let remainingX = latestFaceCentersX[0]
        // Remaining face is on the left half → P1 stayed → P2 left → P2 scores
        if remainingX < 0.5 {
            scoreRound(winner: 2)
        } else {
            scoreRound(winner: 1)
        }
    }

    private func scoreRound(winner: Int) {
        roundWinner = winner
        if winner == 1 {
            ropeProgress -= notchSize
        } else {
            ropeProgress += notchSize
        }
        ropeProgress = min(1.0, max(-1.0, ropeProgress))

        if ropeProgress <= -1.0 {
            winnerName = "Player 1"
            state = .gameOver
        } else if ropeProgress >= 1.0 {
            winnerName = "Player 2"
            state = .gameOver
        } else {
            roundPhase = .scored
            phaseTimer = 0
        }
    }

    private func pickNextPrompt() {
        // Avoid repeating the same prompt twice in a row. Cycle through all before repeating.
        var available = ExpressionType.allCases.filter { !usedPrompts.contains($0) }
        if available.isEmpty {
            usedPrompts = []
            available = ExpressionType.allCases
        }
        // Remove current to avoid immediate repeat
        available = available.filter { $0 != currentPrompt }
        if available.isEmpty { available = ExpressionType.allCases }
        currentPrompt = available.randomElement() ?? .mouthOpen
        usedPrompts.append(currentPrompt)
    }
}
