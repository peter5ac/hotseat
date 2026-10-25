import SwiftUI

struct SpeedTapView: View {
    @State private var viewModel = SpeedTapViewModel()
    let onExit: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer()
            switch viewModel.gameState {
            case .ready:
                readyView
            case .playing, .success:
                gamePlayView
            case .gameOver:
                gameOverView
            }
            Spacer()
        }
        .onAppear {
            viewModel.startGame()
        }
    }

    // MARK: - Header

    private var header: some View {
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

            if viewModel.gameState == .playing || viewModel.gameState == .success {
                Text("Round \(viewModel.currentRound)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, isCompact ? 16 : 40)
        .padding(.top, isCompact ? 12 : 20)
    }

    // MARK: - Sequence Display

    private var sequenceDisplay: some View {
        HStack(spacing: isCompact ? 8 : 12) {
            ForEach(Array(viewModel.sequence.enumerated()), id: \.offset) { index, emoji in
                Text(emoji)
                    .font(.system(size: isCompact ? 28 : 36))
                    .opacity(index < viewModel.tappedCount ? 0.3 : 1.0)
                    .scaleEffect(index == viewModel.tappedCount ? 1.15 : 1.0)
                    .overlay {
                        if index < viewModel.tappedCount {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .animation(.spring(duration: 0.2), value: viewModel.tappedCount)
            }
        }
        .padding(.vertical, isCompact ? 16 : 24)
        .padding(.horizontal, isCompact ? 20 : 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Timer Bar

    private var timerBar: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 4)
                .fill(timerColor)
                .frame(width: geo.size.width * viewModel.timerProgress)
                .animation(.linear(duration: 0.016), value: viewModel.timerProgress)
        }
        .frame(height: 8)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
        .padding(.horizontal, isCompact ? 16 : 40)
    }

    private var timerColor: Color {
        if viewModel.timerProgress > 0.5 {
            return .white
        } else if viewModel.timerProgress > 0.25 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Emoji Grid

    private var emojiGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: isCompact ? 12 : 16),
            GridItem(.flexible(), spacing: isCompact ? 12 : 16),
            GridItem(.flexible(), spacing: isCompact ? 12 : 16),
        ]

        return LazyVGrid(columns: columns, spacing: isCompact ? 12 : 16) {
            ForEach(viewModel.grid, id: \.self) { emoji in
                Button {
                    withAnimation(.spring(duration: 0.15)) {
                        viewModel.tap(emoji)
                    }
                } label: {
                    Text(emoji)
                        .font(.system(size: isCompact ? 40 : 52))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isCompact ? 20 : 28)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.ultraThinMaterial)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, isCompact ? 16 : 40)
    }

    // MARK: - Composite Views

    private var gamePlayView: some View {
        VStack(spacing: isCompact ? 20 : 32) {
            sequenceDisplay
            timerBar

            if viewModel.showNice {
                Text("Nice!")
                    .font(.system(size: isCompact ? 28 : 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            }

            emojiGrid
        }
    }

    private var readyView: some View {
        VStack(spacing: 16) {
            Text("⚡ Speed Tap")
                .font(.system(size: isCompact ? 32 : 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Tap the sequence before time runs out!")
                .font(.body.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(isCompact ? 20 : 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Game Over

    private var gameOverView: some View {
        VStack(spacing: 16) {
            Text("Time's up!")
                .font(.system(size: isCompact ? 28 : 38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("You made it \(viewModel.roundsCompleted) round\(viewModel.roundsCompleted == 1 ? "" : "s")")
                .font(.body.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: isCompact ? 12 : 16) {
                Button("Again") {
                    withAnimation(.spring(duration: 0.3)) {
                        viewModel.playAgain()
                    }
                }
                .font(isCompact ? .body.weight(.semibold) : .title2.weight(.semibold))
                .padding(.horizontal, isCompact ? 20 : 32)
                .padding(.vertical, 14)
                .background(.white)
                .foregroundStyle(.black)
                .clipShape(Capsule())

                Button("New round") {
                    withAnimation(.spring(duration: 0.3)) {
                        onExit()
                    }
                }
                .font(isCompact ? .body.weight(.semibold) : .title2.weight(.semibold))
                .padding(.horizontal, isCompact ? 20 : 32)
                .padding(.vertical, 14)
                .background(.white.opacity(0.2))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
            }
        }
        .padding(isCompact ? 20 : 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
