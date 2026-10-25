import Foundation
import Observation

enum UTTTPlayer: Equatable {
    case x, o

    var next: UTTTPlayer {
        self == .x ? .o : .x
    }

    var label: String {
        self == .x ? "X" : "O"
    }
}

enum UTTTCellState: Equatable {
    case empty, taken(UTTTPlayer)
}

enum UTTTBoardState: Equatable {
    case open, won(UTTTPlayer), drawn
}

enum UTTTGameResult: Equatable {
    case win(UTTTPlayer)
    case draw
}

struct BoardCoord: Equatable {
    let row: Int
    let col: Int
}

@Observable
final class UltimateTTTViewModel {
    var cells: [[[[UTTTCellState]]]] = makeEmptyBoard()
    var bigBoard: [[UTTTBoardState]] = Array(repeating: Array(repeating: UTTTBoardState.open, count: 3), count: 3)
    var currentPlayer: UTTTPlayer = .x
    var activeBoard: BoardCoord? = nil
    var gameResult: UTTTGameResult? = nil

    static func makeEmptyBoard() -> [[[[UTTTCellState]]]] {
        Array(repeating:
            Array(repeating:
                Array(repeating:
                    Array(repeating: UTTTCellState.empty, count: 3),
                count: 3),
            count: 3),
        count: 3)
    }

    func canPlay(bigRow: Int, bigCol: Int, row: Int, col: Int) -> Bool {
        guard gameResult == nil else { return false }
        guard bigBoard[bigRow][bigCol] == .open else { return false }
        guard cells[bigRow][bigCol][row][col] == .empty else { return false }
        if let active = activeBoard {
            return active.row == bigRow && active.col == bigCol
        }
        return true
    }

    func isBoardPlayable(bigRow: Int, bigCol: Int) -> Bool {
        guard gameResult == nil else { return false }
        guard bigBoard[bigRow][bigCol] == .open else { return false }
        if let active = activeBoard {
            return active.row == bigRow && active.col == bigCol
        }
        return true
    }

    func makeMove(bigRow: Int, bigCol: Int, row: Int, col: Int) {
        guard canPlay(bigRow: bigRow, bigCol: bigCol, row: row, col: col) else { return }

        cells[bigRow][bigCol][row][col] = .taken(currentPlayer)

        if checkMiniWin(bigRow: bigRow, bigCol: bigCol, player: currentPlayer) {
            bigBoard[bigRow][bigCol] = .won(currentPlayer)
            if checkBigWin(player: currentPlayer) {
                gameResult = .win(currentPlayer)
                return
            }
        } else if isBoardFull(bigRow: bigRow, bigCol: bigCol) {
            bigBoard[bigRow][bigCol] = .drawn
        }

        if bigBoard[row][col] == .open {
            activeBoard = BoardCoord(row: row, col: col)
        } else {
            activeBoard = nil
        }

        if isDrawState() {
            gameResult = .draw
            return
        }

        currentPlayer = currentPlayer.next
    }

    func reset() {
        cells = Self.makeEmptyBoard()
        bigBoard = Array(repeating: Array(repeating: UTTTBoardState.open, count: 3), count: 3)
        currentPlayer = .x
        activeBoard = nil
        gameResult = nil
    }

    private func checkMiniWin(bigRow: Int, bigCol: Int, player: UTTTPlayer) -> Bool {
        let board = cells[bigRow][bigCol]
        return checkWin(grid: board, player: player)
    }

    private func checkBigWin(player: UTTTPlayer) -> Bool {
        let target = UTTTBoardState.won(player)
        for i in 0..<3 {
            if bigBoard[i][0] == target && bigBoard[i][1] == target && bigBoard[i][2] == target { return true }
            if bigBoard[0][i] == target && bigBoard[1][i] == target && bigBoard[2][i] == target { return true }
        }
        if bigBoard[0][0] == target && bigBoard[1][1] == target && bigBoard[2][2] == target { return true }
        if bigBoard[0][2] == target && bigBoard[1][1] == target && bigBoard[2][0] == target { return true }
        return false
    }

    private func checkWin(grid: [[UTTTCellState]], player: UTTTPlayer) -> Bool {
        let target = UTTTCellState.taken(player)
        for i in 0..<3 {
            if grid[i][0] == target && grid[i][1] == target && grid[i][2] == target { return true }
            if grid[0][i] == target && grid[1][i] == target && grid[2][i] == target { return true }
        }
        if grid[0][0] == target && grid[1][1] == target && grid[2][2] == target { return true }
        if grid[0][2] == target && grid[1][1] == target && grid[2][0] == target { return true }
        return false
    }

    private func isBoardFull(bigRow: Int, bigCol: Int) -> Bool {
        for r in 0..<3 {
            for c in 0..<3 {
                if cells[bigRow][bigCol][r][c] == .empty { return false }
            }
        }
        return true
    }

    private func isDrawState() -> Bool {
        for br in 0..<3 {
            for bc in 0..<3 {
                if bigBoard[br][bc] == .open { return false }
            }
        }
        return true
    }
}
