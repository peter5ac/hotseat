import SwiftUI

struct UltimateTTTView: View {
    @State private var viewModel = UltimateTTTViewModel()
    let onExit: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                turnIndicator
                    .padding(.top, isCompact ? 8 : 12)
                Spacer()
                bigGrid
                    .padding(isCompact ? 12 : 24)
                Spacer()
            }

            if viewModel.gameResult != nil {
                gameOverOverlay
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                onExit()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Games")
                }
                .font(.body.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, isCompact ? 12 : 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, isCompact ? 16 : 40)
        .padding(.top, isCompact ? 12 : 20)
    }

    // MARK: - Turn Indicator

    private var turnIndicator: some View {
        HStack(spacing: 8) {
            Text(viewModel.currentPlayer.label)
                .font(.title2.weight(.bold).monospaced())
                .foregroundStyle(colorForPlayer(viewModel.currentPlayer))
            Text("'s turn")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Big Grid (3x3 of mini boards)

    private var bigGrid: some View {
        GeometryReader { geo in
            let maxSide = min(geo.size.width, geo.size.height)
            let boardSize = maxSide
            let miniSize = (boardSize - 8) / 3

            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { bigRow in
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { bigCol in
                            miniBoard(bigRow: bigRow, bigCol: bigCol, size: miniSize)
                        }
                    }
                }
            }
            .frame(width: boardSize, height: boardSize)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    // MARK: - Mini Board

    @ViewBuilder
    private func miniBoard(bigRow: Int, bigCol: Int, size: CGFloat) -> some View {
        let boardState = viewModel.bigBoard[bigRow][bigCol]
        let playable = viewModel.isBoardPlayable(bigRow: bigRow, bigCol: bigCol)

        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(playable ? Color.white.opacity(0.08) : Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(playable ? Color.white.opacity(0.35) : Color.white.opacity(0.18), lineWidth: playable ? 2 : 1)
                )

            switch boardState {
            case .open:
                miniGrid(bigRow: bigRow, bigCol: bigCol, size: size)
            case .won(let player):
                Text(player.label)
                    .font(.system(size: size * 0.55, weight: .heavy, design: .rounded))
                    .foregroundStyle(colorForPlayer(player))
            case .drawn:
                Text("=")
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.2), value: playable)
    }

    private func miniGrid(bigRow: Int, bigCol: Int, size: CGFloat) -> some View {
        let cellSize = (size - 16) / 3
        return VStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { col in
                        cellButton(bigRow: bigRow, bigCol: bigCol, row: row, col: col, size: cellSize)
                    }
                }
            }
        }
        .padding(4)
    }

    @ViewBuilder
    private func cellButton(bigRow: Int, bigCol: Int, row: Int, col: Int, size: CGFloat) -> some View {
        let state = viewModel.cells[bigRow][bigCol][row][col]
        let canTap = viewModel.canPlay(bigRow: bigRow, bigCol: bigCol, row: row, col: col)

        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.makeMove(bigRow: bigRow, bigCol: bigCol, row: row, col: col)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(canTap ? Color.white.opacity(0.12) : Color.white.opacity(0.04))

                switch state {
                case .empty:
                    EmptyView()
                case .taken(let player):
                    Text(player.label)
                        .font(.system(size: size * 0.55, weight: .bold, design: .rounded))
                        .foregroundStyle(colorForPlayer(player))
                }
            }
            .frame(width: size, height: size)
        }
        .disabled(!canTap)
    }

    // MARK: - Game Over

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 16) {
                switch viewModel.gameResult {
                case .win(let player):
                    Text(player.label)
                        .font(.system(size: isCompact ? 48 : 64, weight: .heavy, design: .rounded))
                        .foregroundStyle(colorForPlayer(player))
                    Text("wins!")
                        .font(.system(size: isCompact ? 28 : 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                case .draw:
                    Text("Draw")
                        .font(.system(size: isCompact ? 36 : 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                case nil:
                    EmptyView()
                }

                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        viewModel.reset()
                    }
                } label: {
                    Text("Play Again")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 12)
                        .background(.white, in: Capsule())
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    // MARK: - Helpers

    private func colorForPlayer(_ player: UTTTPlayer) -> Color {
        player == .x ? .cyan : .orange
    }
}
