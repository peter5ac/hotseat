import SwiftUI

struct ChocolateItem: Identifiable {
    let id = UUID()
    var position: CGPoint
    let emoji: String
    let size: CGFloat
    let isTrap: Bool
}

enum ChocolateGameState: Equatable {
    case idle
    case countdown(Int)
    case playing
    case gameOver
}

enum CatchResult {
    case treat
    case trap
}

enum ChocolateDifficulty: String, CaseIterable {
    case easy
    case normal

    var fallSpeed: CGFloat {
        switch self {
        case .easy: return 80
        case .normal: return 130
        }
    }

    var spawnInterval: Double {
        switch self {
        case .easy: return 1.6
        case .normal: return 1.0
        }
    }

    var trapChance: Double {
        switch self {
        case .easy: return 0.15
        case .normal: return 0.3
        }
    }

    var label: String {
        switch self {
        case .easy: return "Easy"
        case .normal: return "Normal"
        }
    }
}

@Observable
final class ChocolateRainViewModel {
    var activeChocolates: [ChocolateItem] = []
    var score: Int = 0
    var timeRemaining: Double = 60
    var gameState: ChocolateGameState = .idle
    var difficulty: ChocolateDifficulty = .easy

    private(set) var canvasSize: CGSize = .zero
    private var mouthRect: CGRect?
    private var faceBBoxWidth: CGFloat?
    private var mouthOpen: Bool = false
    private var timeSinceLastSpawn: Double = 0
    private let maxChocolates = 5
    private let treatEmojis = ["🍫", "🍬", "🍩", "🧁"]
    private let trapEmojis = ["🪨", "🗑️", "🧱", "🪵", "🔩", "💩"]

    func setCanvasSize(_ size: CGSize) {
        canvasSize = size
    }

    func updateMouth(rect: CGRect?, faceBBoxWidth: CGFloat?, mouthOpen: Bool) {
        self.mouthRect = rect
        self.faceBBoxWidth = faceBBoxWidth
        self.mouthOpen = mouthOpen
    }

    func startGame() {
        score = 0
        timeRemaining = 60
        activeChocolates = []
        timeSinceLastSpawn = 0
        gameState = .countdown(3)
        startCountdown()
    }

    func reset() {
        gameState = .idle
        activeChocolates = []
        score = 0
        timeRemaining = 60
    }

    func tick(delta: Double) -> CatchResult? {
        guard gameState == .playing else { return nil }

        // Timer
        timeRemaining -= delta
        if timeRemaining <= 0 {
            timeRemaining = 0
            gameState = .gameOver
            return nil
        }

        // Spawn
        timeSinceLastSpawn += delta
        if timeSinceLastSpawn >= difficulty.spawnInterval && activeChocolates.count < maxChocolates {
            spawnChocolate()
            timeSinceLastSpawn = 0
        }

        // Move
        for i in activeChocolates.indices {
            activeChocolates[i].position.y += difficulty.fallSpeed * delta
        }

        // Remove off-screen
        activeChocolates.removeAll { $0.position.y > canvasSize.height + 50 }

        // Collision — only when mouth is open
        guard mouthOpen, let hitbox = paddedMouthRect() else { return nil }
        if let idx = activeChocolates.firstIndex(where: { hitbox.contains($0.position) }) {
            let item = activeChocolates.remove(at: idx)
            if item.isTrap {
                return .trap
            } else {
                score += 1
                return .treat
            }
        }

        return nil
    }

    private func paddedMouthRect() -> CGRect? {
        guard let rect = mouthRect else { return nil }
        let padding = (faceBBoxWidth ?? 100) * 0.15
        return rect.insetBy(dx: -padding, dy: -padding)
    }

    private func spawnChocolate() {
        let insetX = canvasSize.width * 0.1
        let x = CGFloat.random(in: insetX...(canvasSize.width - insetX))
        let isTrap = Double.random(in: 0..<1) < difficulty.trapChance
        let emoji = isTrap ? trapEmojis.randomElement()! : treatEmojis.randomElement()!
        let size = CGFloat.random(in: 48...64)
        let item = ChocolateItem(position: CGPoint(x: x, y: -50), emoji: emoji, size: size, isTrap: isTrap)
        activeChocolates.append(item)
    }

    private func startCountdown() {
        guard case .countdown(let n) = gameState, n > 0 else {
            gameState = .playing
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            if n > 1 {
                self.gameState = .countdown(n - 1)
                self.startCountdown()
            } else {
                self.gameState = .playing
            }
        }
    }
}
