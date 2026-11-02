import Foundation
import Observation

enum DBDifficulty: CaseIterable {
    case easy, medium, hard

    var label: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    var gridSize: Int {
        switch self {
        case .easy: return 4
        case .medium: return 5
        case .hard: return 6
        }
    }

    var desc: String {
        let b = gridSize - 1
        return "\(b)×\(b)"
    }
}

enum DBPlayer: Int, Equatable {
    case one = 1, two = 2
    var next: DBPlayer { self == .one ? .two : .one }
}

enum DBGamePhase: Equatable {
    case pickDifficulty
    case pickEmoji(DBPlayer)
    case playing
    case gameOver
}

@Observable
final class DotsAndBoxesViewModel {
    var phase: DBGamePhase = .pickDifficulty
    var difficulty: DBDifficulty = .medium
    var gridSize: Int = 5

    var player1Emoji: String = ""
    var player2Emoji: String = ""
    var currentPlayer: DBPlayer = .one

    var hLines: [[Bool]] = []
    var vLines: [[Bool]] = []
    var boxes: [[DBPlayer?]] = []

    var player1Score: Int = 0
    var player2Score: Int = 0
    var moveCount: Int = 0

    var totalBoxes: Int { (gridSize - 1) * (gridSize - 1) }
    var isGameOver: Bool { player1Score + player2Score == totalBoxes }

    var winner: DBPlayer? {
        guard isGameOver else { return nil }
        if player1Score > player2Score { return .one }
        if player2Score > player1Score { return .two }
        return nil
    }

    func selectDifficulty(_ diff: DBDifficulty) {
        difficulty = diff
        gridSize = diff.gridSize
        phase = .pickEmoji(.one)
    }

    func selectEmoji(_ emoji: String) {
        switch phase {
        case .pickEmoji(.one):
            player1Emoji = emoji
            phase = .pickEmoji(.two)
        case .pickEmoji(.two):
            player2Emoji = emoji
            beginPlay()
        default:
            break
        }
    }

    private func beginPlay() {
        hLines = Array(repeating: Array(repeating: false, count: gridSize - 1), count: gridSize)
        vLines = Array(repeating: Array(repeating: false, count: gridSize), count: gridSize - 1)
        boxes = Array(repeating: Array(repeating: nil, count: gridSize - 1), count: gridSize - 1)
        player1Score = 0
        player2Score = 0
        moveCount = 0
        currentPlayer = .one
        phase = .playing
    }

    func drawHLine(row: Int, col: Int) {
        guard phase == .playing else { return }
        guard row >= 0, row < gridSize, col >= 0, col < gridSize - 1 else { return }
        guard !hLines[row][col] else { return }
        hLines[row][col] = true
        moveCount += 1
        let completed = checkBoxesForHLine(row: row, col: col)
        if completed == 0 { currentPlayer = currentPlayer.next }
        if isGameOver { phase = .gameOver }
    }

    func drawVLine(row: Int, col: Int) {
        guard phase == .playing else { return }
        guard row >= 0, row < gridSize - 1, col >= 0, col < gridSize else { return }
        guard !vLines[row][col] else { return }
        vLines[row][col] = true
        moveCount += 1
        let completed = checkBoxesForVLine(row: row, col: col)
        if completed == 0 { currentPlayer = currentPlayer.next }
        if isGameOver { phase = .gameOver }
    }

    private func checkBoxesForHLine(row: Int, col: Int) -> Int {
        var count = 0
        if row > 0, boxes[row - 1][col] == nil, boxComplete(row: row - 1, col: col) {
            boxes[row - 1][col] = currentPlayer
            count += 1
        }
        if row < gridSize - 1, boxes[row][col] == nil, boxComplete(row: row, col: col) {
            boxes[row][col] = currentPlayer
            count += 1
        }
        if count > 0 { recount() }
        return count
    }

    private func checkBoxesForVLine(row: Int, col: Int) -> Int {
        var count = 0
        if col < gridSize - 1, boxes[row][col] == nil, boxComplete(row: row, col: col) {
            boxes[row][col] = currentPlayer
            count += 1
        }
        if col > 0, boxes[row][col - 1] == nil, boxComplete(row: row, col: col - 1) {
            boxes[row][col - 1] = currentPlayer
            count += 1
        }
        if count > 0 { recount() }
        return count
    }

    private func boxComplete(row: Int, col: Int) -> Bool {
        hLines[row][col] &&
        hLines[row + 1][col] &&
        vLines[row][col] &&
        vLines[row][col + 1]
    }

    private func recount() {
        player1Score = boxes.flatMap { $0 }.filter { $0 == .one }.count
        player2Score = boxes.flatMap { $0 }.filter { $0 == .two }.count
    }

    func emojiForPlayer(_ player: DBPlayer) -> String {
        player == .one ? player1Emoji : player2Emoji
    }

    func playAgain() {
        phase = .pickDifficulty
        player1Emoji = ""
        player2Emoji = ""
    }
}
