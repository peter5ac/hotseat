import Foundation
import Observation

enum TTTMark: Equatable {
    case o, x

    var glyph: String {
        switch self {
        case .o: return "O"
        case .x: return "X"
        }
    }

    var playerNumber: Int {
        switch self {
        case .o: return 1
        case .x: return 2
        }
    }
}

@Observable
final class TicTacToeViewModel {
    // Tuning. confirmDuration: how long the open mouth must stay over one empty
    // cell before the mark drops. placementLockout: dead time after a placement
    // so a still-open mouth can't immediately fill another cell.
    private let confirmDuration: Double = 1.0
    private let placementLockout: Double = 0.5

    // The 8 winning lines (row-major indices).
    private let lines: [[Int]] = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],   // rows
        [0, 3, 6], [1, 4, 7], [2, 5, 8],   // cols
        [0, 4, 8], [2, 4, 6]               // diagonals
    ]

    var board: [TTTMark?] = Array(repeating: nil, count: 9)
    var currentPlayer: TTTMark = .o
    var winner: TTTMark?
    var isDraw: Bool = false
    var winningLine: [Int]?

    // Confirm progress for the currently targeted cell.
    var pendingCell: Int?
    var confirmProgress: Double = 0   // 0...1

    private var lockoutRemaining: Double = 0

    var isGameOver: Bool { winner != nil || isDraw }

    /// Per-frame driver. `targetedCell` = the empty cell the mouth is over (or nil).
    func tick(delta: Double, targetedCell: Int?, mouthOpen: Bool) {
        guard !isGameOver else { resetPending(); return }

        if lockoutRemaining > 0 {
            lockoutRemaining = max(0, lockoutRemaining - delta)
            resetPending()
            return
        }

        // A valid hold requires an open mouth over an empty, in-grid cell.
        guard mouthOpen,
              let cell = targetedCell,
              board.indices.contains(cell),
              board[cell] == nil
        else {
            resetPending()
            return
        }

        if pendingCell == cell {
            confirmProgress += delta / confirmDuration
            if confirmProgress >= 1.0 {
                place(at: cell)
            }
        } else {
            // New / different cell: start a fresh hold (cancel-on-move).
            pendingCell = cell
            confirmProgress = 0
        }
    }

    private func resetPending() {
        pendingCell = nil
        confirmProgress = 0
    }

    private func place(at cell: Int) {
        board[cell] = currentPlayer
        resetPending()

        if let line = winningLine(for: currentPlayer) {
            winner = currentPlayer
            winningLine = line
        } else if board.allSatisfy({ $0 != nil }) {
            isDraw = true
        } else {
            currentPlayer = (currentPlayer == .o) ? .x : .o
            lockoutRemaining = placementLockout
        }
    }

    private func winningLine(for mark: TTTMark) -> [Int]? {
        lines.first { line in line.allSatisfy { board[$0] == mark } }
    }

    /// Reset for a new round with the same two players. O goes first again.
    func playAgain() {
        board = Array(repeating: nil, count: 9)
        currentPlayer = .o
        winner = nil
        isDraw = false
        winningLine = nil
        resetPending()
        lockoutRemaining = 0
    }
}
