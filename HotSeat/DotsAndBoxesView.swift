import SwiftUI
import UIKit

struct DotsAndBoxesView: View {
    @State private var viewModel = DotsAndBoxesViewModel()
    let onExit: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }

    @State private var lineHaptic = UIImpactFeedbackGenerator(style: .rigid)
    @State private var boxHaptic = UINotificationFeedbackGenerator()

    private let emojiOptions: [String] = [
        "😀", "😎", "🤩", "😈", "👻", "🤖", "👽", "🦄",
        "🐶", "🐱", "🦊", "🐸", "🐵", "🦁", "🐷", "🐰",
        "🔥", "⭐", "💎", "🌈", "🍕", "🎸", "⚽", "🎮",
        "💀", "🎃", "🧠", "👑", "🦋", "🌺", "🍩", "🚀"
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                switch viewModel.phase {
                case .pickDifficulty:
                    difficultyPicker
                case .pickEmoji(let player):
                    emojiPicker(for: player)
                case .playing, .gameOver:
                    gameBoardSection
                }
            }

            if viewModel.phase == .gameOver {
                gameOverOverlay
            }
        }
        .onAppear {
            lineHaptic.prepare()
            boxHaptic.prepare()
        }
        .onChange(of: viewModel.moveCount) { _, _ in
            lineHaptic.impactOccurred()
            lineHaptic.prepare()
        }
        .onChange(of: viewModel.player1Score + viewModel.player2Score) { old, new in
            if new > old {
                boxHaptic.notificationOccurred(.success)
                boxHaptic.prepare()
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { onExit() } label: {
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

    // MARK: - Difficulty Picker

    private var difficultyPicker: some View {
        VStack(spacing: isCompact ? 20 : 32) {
            Spacer()

            Text("Dots & Boxes")
                .font(.system(size: isCompact ? 32 : 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Pick a size")
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))

            VStack(spacing: isCompact ? 12 : 16) {
                ForEach(DBDifficulty.allCases, id: \.label) { diff in
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            viewModel.selectDifficulty(diff)
                        }
                    } label: {
                        HStack {
                            Text(diff.label)
                                .font(.title2.weight(.semibold))
                            Spacer()
                            Text(diff.desc)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, isCompact ? 16 : 20)
                        .padding(.horizontal, isCompact ? 20 : 28)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.08))
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, isCompact ? 40 : 100)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Emoji Picker

    private func emojiPicker(for player: DBPlayer) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: isCompact ? 4 : 8)
        let taken = player == .two ? viewModel.player1Emoji : ""

        return VStack(spacing: isCompact ? 16 : 24) {
            Spacer()

            HStack(spacing: 8) {
                if player == .two {
                    Text(viewModel.player1Emoji)
                        .font(.system(size: isCompact ? 24 : 32))
                        .padding(6)
                        .background(Circle().fill(Color.cyan.opacity(0.2)))
                    Text("vs")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.4))
                }
                Text(player == .one ? "Player 1" : "Player 2")
                    .font(.system(size: isCompact ? 28 : 38, weight: .bold, design: .rounded))
                    .foregroundStyle(colorForPlayer(player))
            }

            Text("Pick your emoji")
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))

            ScrollView {
                LazyVGrid(columns: columns, spacing: isCompact ? 8 : 12) {
                    ForEach(emojiOptions, id: \.self) { emoji in
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                viewModel.selectEmoji(emoji)
                            }
                        } label: {
                            Text(emoji)
                                .font(.system(size: isCompact ? 32 : 40))
                                .frame(width: isCompact ? 56 : 64, height: isCompact ? 56 : 64)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.08))
                                )
                                .opacity(emoji == taken ? 0.3 : 1.0)
                        }
                        .disabled(emoji == taken)
                    }
                }
                .padding(.horizontal, isCompact ? 24 : 60)
            }

            Spacer()
        }
    }

    // MARK: - Game Board Section

    private var gameBoardSection: some View {
        VStack(spacing: 0) {
            turnIndicator
                .padding(.top, isCompact ? 8 : 12)

            Spacer(minLength: 8)

            GeometryReader { geo in
                boardContent(in: geo.size)
            }
            .padding(.horizontal, isCompact ? 8 : 24)

            Spacer(minLength: 8)

            scoreBar
                .padding(.horizontal, isCompact ? 16 : 40)
                .padding(.bottom, isCompact ? 16 : 28)
        }
    }

    // MARK: - Turn Indicator

    private var turnIndicator: some View {
        HStack(spacing: 8) {
            Text(viewModel.emojiForPlayer(viewModel.currentPlayer))
                .font(.title2)
            Text("\(viewModel.currentPlayer == .one ? "Player 1" : "Player 2")'s turn")
                .font(.title3.weight(.semibold))
                .foregroundStyle(colorForPlayer(viewModel.currentPlayer))
        }
    }

    // MARK: - Board

    @ViewBuilder
    private func boardContent(in size: CGSize) -> some View {
        let n = viewModel.gridSize
        let maxSide = min(size.width, size.height)
        let inset: CGFloat = isCompact ? 12 : 20
        let usable = max(maxSide - inset * 2, 0)
        let spacing = n > 1 ? usable / CGFloat(n - 1) : usable
        let boardSide = spacing * CGFloat(n - 1)
        let ox = (size.width - boardSide) / 2
        let oy = (size.height - boardSide) / 2
        let dotR: CGFloat = isCompact ? 5 : 7
        let lineW: CGFloat = isCompact ? 4 : 6

        ZStack {
            // Completed boxes
            ForEach(0..<(n - 1), id: \.self) { r in
                ForEach(0..<(n - 1), id: \.self) { c in
                    if let owner = viewModel.boxes[r][c] {
                        Text(viewModel.emojiForPlayer(owner))
                            .font(.system(size: spacing * 0.45))
                            .frame(width: spacing * 0.75, height: spacing * 0.75)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(colorForPlayer(owner).opacity(0.15))
                            )
                            .position(
                                x: ox + (CGFloat(c) + 0.5) * spacing,
                                y: oy + (CGFloat(r) + 0.5) * spacing
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }

            // Horizontal lines
            ForEach(0..<n, id: \.self) { r in
                ForEach(0..<(n - 1), id: \.self) { c in
                    Capsule()
                        .fill(viewModel.hOwners[r][c].map(colorForPlayer) ?? Color.white.opacity(0.12))
                        .frame(width: spacing - dotR * 2 - 4, height: lineW)
                        .position(
                            x: ox + (CGFloat(c) + 0.5) * spacing,
                            y: oy + CGFloat(r) * spacing
                        )
                }
            }

            // Vertical lines
            ForEach(0..<(n - 1), id: \.self) { r in
                ForEach(0..<n, id: \.self) { c in
                    Capsule()
                        .fill(viewModel.vOwners[r][c].map(colorForPlayer) ?? Color.white.opacity(0.12))
                        .frame(width: lineW, height: spacing - dotR * 2 - 4)
                        .position(
                            x: ox + CGFloat(c) * spacing,
                            y: oy + (CGFloat(r) + 0.5) * spacing
                        )
                }
            }

            // Dots
            ForEach(0..<n, id: \.self) { r in
                ForEach(0..<n, id: \.self) { c in
                    Circle()
                        .fill(Color.white)
                        .frame(width: dotR * 2, height: dotR * 2)
                        .position(
                            x: ox + CGFloat(c) * spacing,
                            y: oy + CGFloat(r) * spacing
                        )
                }
            }

            // Tap handler
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            handleTap(at: value.location, ox: ox, oy: oy, spacing: spacing)
                        }
                )
        }
    }

    private func handleTap(at point: CGPoint, ox: CGFloat, oy: CGFloat, spacing: CGFloat) {
        guard viewModel.phase == .playing, spacing > 0 else { return }
        let n = viewModel.gridSize
        let gx = (point.x - ox) / spacing
        let gy = (point.y - oy) / spacing

        var bestDist = CGFloat.greatestFiniteMagnitude
        var bestIsH = true
        var bestRow = 0
        var bestCol = 0

        for r in 0..<n {
            for c in 0..<(n - 1) {
                guard !viewModel.hLines[r][c] else { continue }
                let d = hypot(gx - (CGFloat(c) + 0.5), gy - CGFloat(r))
                if d < bestDist { bestDist = d; bestIsH = true; bestRow = r; bestCol = c }
            }
        }
        for r in 0..<(n - 1) {
            for c in 0..<n {
                guard !viewModel.vLines[r][c] else { continue }
                let d = hypot(gx - CGFloat(c), gy - (CGFloat(r) + 0.5))
                if d < bestDist { bestDist = d; bestIsH = false; bestRow = r; bestCol = c }
            }
        }

        guard bestDist < 0.6 else { return }

        withAnimation(.easeInOut(duration: 0.15)) {
            if bestIsH {
                viewModel.drawHLine(row: bestRow, col: bestCol)
            } else {
                viewModel.drawVLine(row: bestRow, col: bestCol)
            }
        }
    }

    // MARK: - Score Bar

    private var scoreBar: some View {
        HStack {
            scoreItem(player: .one)
            Spacer()
            scoreItem(player: .two)
        }
    }

    private func scoreItem(player: DBPlayer) -> some View {
        let active = viewModel.currentPlayer == player && viewModel.phase == .playing
        let score = player == .one ? viewModel.player1Score : viewModel.player2Score
        return HStack(spacing: 8) {
            Text(viewModel.emojiForPlayer(player))
                .font(.title2)
            Text("\(score)")
                .font(.system(size: isCompact ? 28 : 36, weight: .bold, design: .rounded))
                .foregroundStyle(colorForPlayer(player))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(active ? 0.12 : 0.06))
                .stroke(active ? colorForPlayer(player).opacity(0.5) : Color.white.opacity(0.15),
                        lineWidth: active ? 2 : 1)
        )
    }

    // MARK: - Game Over

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: isCompact ? 14 : 20) {
                if let winner = viewModel.winner {
                    Text(viewModel.emojiForPlayer(winner))
                        .font(.system(size: isCompact ? 48 : 64))
                    Text("\(winner == .one ? "Player 1" : "Player 2") wins!")
                        .font(.system(size: isCompact ? 28 : 36, weight: .bold, design: .rounded))
                        .foregroundStyle(colorForPlayer(winner))
                } else {
                    Text("It's a tie!")
                        .font(.system(size: isCompact ? 28 : 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text("\(viewModel.player1Emoji) \(viewModel.player1Score) – \(viewModel.player2Score) \(viewModel.player2Emoji)")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: isCompact ? 12 : 16) {
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            viewModel.playAgain()
                        }
                    } label: {
                        Text("Play Again")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 36)
                            .padding(.vertical, 12)
                            .background(.white, in: Capsule())
                    }

                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            onExit()
                        }
                    } label: {
                        Text("Games")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.2), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                    }
                }
                .padding(.top, 8)
            }
            .padding(isCompact ? 24 : 32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    // MARK: - Helpers

    private func colorForPlayer(_ player: DBPlayer) -> Color {
        player == .one ? .cyan : .orange
    }
}
