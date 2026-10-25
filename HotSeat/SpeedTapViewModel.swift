import SwiftUI

struct EmojiTheme: Identifiable {
    let id: String
    let name: String
    let emojis: [String]
}

let emojiThemes: [EmojiTheme] = [
    EmojiTheme(id: "fruits", name: "Fruits", emojis: ["🍎", "🍌", "🍇", "🍊", "🍓", "🍒"]),
    EmojiTheme(id: "animals", name: "Animals", emojis: ["🐶", "🐱", "🐸", "🦊", "🐼", "🐵"]),
    EmojiTheme(id: "sports", name: "Sports", emojis: ["⚽", "🏀", "🏈", "🎾", "⚾", "🏐"]),
    EmojiTheme(id: "weather", name: "Weather", emojis: ["☀️", "🌧️", "⛈️", "🌈", "❄️", "🌪️"]),
    EmojiTheme(id: "space", name: "Space", emojis: ["🚀", "🌙", "⭐", "🪐", "☄️", "👽"]),
    EmojiTheme(id: "ocean", name: "Ocean", emojis: ["🐙", "🦈", "🐠", "🐚", "🦀", "🐳"]),
    EmojiTheme(id: "food", name: "Food", emojis: ["🍕", "🍔", "🌮", "🍩", "🍿", "🧁"]),
]

enum SpeedTapState: Equatable {
    case ready
    case playing
    case success
    case gameOver
}

@Observable
final class SpeedTapViewModel {
    var currentRound: Int = 1
    var sequence: [String] = []
    var tappedCount: Int = 0
    var grid: [String] = []
    var theme: EmojiTheme = emojiThemes[0]
    var timerProgress: Double = 1.0
    var gameState: SpeedTapState = .ready
    var showNice: Bool = false

    var roundsCompleted: Int { currentRound - 1 }

    private var timerDuration: Double {
        if currentRound <= 3 { return 7.0 }
        let reductions = (currentRound - 3) / 2
        return max(2.5, 7.0 - Double(reductions) * 0.5)
    }

    private var sequenceLength: Int {
        currentRound + 2
    }

    private var timer: Timer?

    var currentTarget: String? {
        guard tappedCount < sequence.count else { return nil }
        return sequence[tappedCount]
    }

    func startGame() {
        theme = emojiThemes.randomElement()!
        grid = theme.emojis
        currentRound = 1
        startRound()
    }

    func tap(_ emoji: String) {
        guard gameState == .playing else { return }
        guard let target = currentTarget else { return }

        if emoji == target {
            tappedCount += 1
            if tappedCount >= sequence.count {
                roundSuccess()
            }
        }
    }

    func playAgain() {
        currentRound = 1
        startRound()
    }

    func newRound() {
        gameState = .ready
        stopTimer()
    }

    private func startRound() {
        sequence = (0..<sequenceLength).map { _ in grid.randomElement()! }
        tappedCount = 0
        timerProgress = 1.0
        gameState = .playing
        startTimer()
    }

    private func roundSuccess() {
        stopTimer()
        gameState = .success
        showNice = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.gameState == .success else { return }
            self.showNice = false
            self.currentRound += 1
            self.startRound()
        }
    }

    private func startTimer() {
        stopTimer()
        let duration = timerDuration
        let interval: Double = 0.016
        let decrement = interval / duration

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.timerProgress -= decrement
                if self.timerProgress <= 0 {
                    self.timerProgress = 0
                    self.timeUp()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func timeUp() {
        stopTimer()
        gameState = .gameOver
    }
}
