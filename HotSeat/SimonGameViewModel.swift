import Foundation
import Observation

enum SimonDifficulty: String, CaseIterable, Identifiable {
    case easy, medium, hard

    var id: String { rawValue }

    var buttonCount: Int {
        switch self {
        case .easy: return 3
        case .medium: return 4
        case .hard: return 6
        }
    }

    var startingSequenceCount: Int {
        switch self {
        case .easy: return 1
        case .medium: return 2
        case .hard: return 3
        }
    }

    var totalRoundTime: TimeInterval { 15.0 }

    var label: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
}

enum SimonGameState: Equatable {
    case idle
    case displaying
    case accepting
    case success
    case failure
    case freePlay
}

@Observable
final class SimonGameViewModel {
    var currentDifficulty: SimonDifficulty = .easy
    var simonSequence: [Int] = []
    var userSequence: [Int] = []
    var isDisplayingPattern: Bool = false
    var timeRemaining: Double = 0
    var gameState: SimonGameState = .idle
    var currentDisplayIndex: Int = 0
    var litQuadrant: Int? = nil
    var round: Int = 0
    var lastPressCorrect: Bool? = nil
    var maxSequenceReached: Int = 0

    private var displayStepTimer: Double = 0
    private let displayStepDuration: Double = 0.6
    private let displayPauseDuration: Double = 0.25

    func startGame() {
        simonSequence = []
        userSequence = []
        round = 0
        maxSequenceReached = 0
        lastPressCorrect = nil
        let range = 0..<currentDifficulty.buttonCount
        for _ in 0..<currentDifficulty.startingSequenceCount {
            simonSequence.append(Int.random(in: range))
        }
        maxSequenceReached = simonSequence.count
        beginDisplayPhase()
    }

    func startFreePlay() {
        gameState = .freePlay
        simonSequence = []
        userSequence = []
        litQuadrant = nil
        round = 0
    }

    func resetWithDifficulty(_ difficulty: SimonDifficulty) {
        currentDifficulty = difficulty
        gameState = .idle
        simonSequence = []
        userSequence = []
        litQuadrant = nil
        round = 0
        lastPressCorrect = nil
    }

    func generateNextSequence() {
        simonSequence.append(Int.random(in: 0..<currentDifficulty.buttonCount))
    }

    func checkUserPress(quadrant: Int) -> Bool {
        guard gameState == .accepting else { return false }
        let expectedIndex = userSequence.count
        guard expectedIndex < simonSequence.count else { return false }

        userSequence.append(quadrant)

        if quadrant == simonSequence[expectedIndex] {
            lastPressCorrect = true
            if userSequence.count == simonSequence.count {
                advanceRound()
            }
            return true
        } else {
            lastPressCorrect = false
            gameState = .failure
            litQuadrant = nil
            return false
        }
    }

    func tick(delta: Double) {
        switch gameState {
        case .displaying:
            tickDisplay(delta: delta)
        case .accepting:
            tickAccepting(delta: delta)
        default:
            break
        }
    }

    // MARK: - Private

    private func beginDisplayPhase() {
        gameState = .displaying
        isDisplayingPattern = true
        currentDisplayIndex = 0
        displayStepTimer = 0
        litQuadrant = simonSequence.isEmpty ? nil : simonSequence[0]
        userSequence = []
        lastPressCorrect = nil
    }

    private func tickDisplay(delta: Double) {
        displayStepTimer += delta

        let totalStep = displayStepDuration + displayPauseDuration
        if displayStepTimer >= totalStep {
            displayStepTimer -= totalStep
            currentDisplayIndex += 1
            if currentDisplayIndex >= simonSequence.count {
                isDisplayingPattern = false
                litQuadrant = nil
                beginAcceptingPhase()
            } else {
                litQuadrant = simonSequence[currentDisplayIndex]
            }
        } else if displayStepTimer >= displayStepDuration {
            litQuadrant = nil
        }
    }

    private func beginAcceptingPhase() {
        gameState = .accepting
        timeRemaining = currentDifficulty.totalRoundTime
    }

    private func tickAccepting(delta: Double) {
        timeRemaining -= delta
        if timeRemaining <= 0 {
            gameState = .failure
            litQuadrant = nil
        }
    }

    private func advanceRound() {
        round += 1
        gameState = .success
        litQuadrant = nil
        generateNextSequence()
        maxSequenceReached = simonSequence.count
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.gameState == .success else { return }
            self.beginDisplayPhase()
        }
    }
}
