import SwiftUI

struct TugOfWarView: View {
    @State private var viewModel = TugOfWarViewModel()
    let faceTracker: FaceTracker
    let onExit: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }

    @State private var lastTimestamp: CFTimeInterval = 0
    @State private var flashPlayer: Int? = nil  // 1 or 2, briefly set for score flash

    private var hasBothFaces: Bool { faceTracker.perFaceExpressions.count >= 2 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Territory tints
                territoryBackground

                // Rope track
                ropeTrack(in: geo.size)

                // Center prompt (during play)
                if viewModel.state == .playing {
                    promptDisplay
                }

                // Countdown
                if viewModel.state == .countdown {
                    countdownOverlay
                }

                // Waiting for faces
                if viewModel.state == .waitingForFaces {
                    waitingOverlay
                }

                // Win screen
                if viewModel.state == .gameOver {
                    winOverlay
                }

                // Face hint (during play, not game over)
                if !hasBothFaces && viewModel.state == .playing {
                    twoFaceHint
                }

                // Score flash
                if let player = flashPlayer {
                    scoreFlash(player: player, in: geo.size)
                }

                // Top bar
                topBar
            }
        }
        .onAppear {
            viewModel.startGame()
            lastTimestamp = 0
        }
        .onChange(of: faceTracker.perFaceExpressions) { _, newValue in
            viewModel.updateFaces(newValue, centersX: faceTracker.faceCentersX)
        }
        .onChange(of: viewModel.roundWinner) { _, newValue in
            if let winner = newValue {
                flashPlayer = winner
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    flashPlayer = nil
                }
            }
        }
        .modifier(TugDisplayLinkModifier { timestamp in
            advance(to: timestamp)
        })
    }

    private func advance(to timestamp: CFTimeInterval) {
        guard lastTimestamp != 0 else { lastTimestamp = timestamp; return }
        let delta = CGFloat(timestamp - lastTimestamp)
        lastTimestamp = timestamp
        viewModel.tick(delta: delta)
    }
}

// MARK: - Prompt display

private extension TugOfWarView {
    var promptDisplay: some View {
        VStack(spacing: 12) {
            if viewModel.roundPhase == .racing || viewModel.roundPhase == .showingPrompt {
                Text(viewModel.currentPrompt.emoji)
                    .font(.system(size: isCompact ? 80 : 120))
                Text(viewModel.currentPrompt.label)
                    .font(.system(size: isCompact ? 24 : 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else if viewModel.roundPhase == .scored {
                if let winner = viewModel.roundWinner {
                    Text("Player \(winner) scores!")
                        .font(.system(size: isCompact ? 22 : 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Text("Pass!")
                        .font(.system(size: isCompact ? 22 : 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(isCompact ? 20 : 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Rope track

private extension TugOfWarView {
    private var player1Color: Color { .cyan }
    private var player2Color: Color { .orange }

    var territoryBackground: some View {
        HStack(spacing: 0) {
            player1Color.opacity(0.08)
            player2Color.opacity(0.08)
        }
    }

    @ViewBuilder
    func ropeTrack(in size: CGSize) -> some View {
        let halfWidth = size.width / 2
        let centerY = size.height * 0.82  // lower on screen to not overlap prompt
        VStack(spacing: 8) {
            // Notch markers
            HStack(spacing: 0) {
                ForEach(-5..<6, id: \.self) { notch in
                    Circle()
                        .fill(notch < 0 ? player1Color.opacity(0.5) :
                              notch > 0 ? player2Color.opacity(0.5) :
                              Color.white.opacity(0.7))
                        .frame(width: notch == 0 ? 10 : 6, height: notch == 0 ? 10 : 6)
                    if notch < 5 { Spacer() }
                }
            }
            .frame(width: size.width * 0.85)

            // Track bar
            ZStack {
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(width: size.width * 0.85, height: 8)

                // Indicator node
                Circle()
                    .fill(viewModel.ropeProgress < 0 ? player1Color : player2Color)
                    .frame(width: isCompact ? 40 : 52, height: isCompact ? 40 : 52)
                    .shadow(color: .white.opacity(0.6), radius: 8)
                    .offset(x: viewModel.ropeProgress * (size.width * 0.85 / 2))
                    .animation(.spring(duration: 0.3), value: viewModel.ropeProgress)
            }
        }
        .position(x: size.width / 2, y: centerY)
    }

    @ViewBuilder
    func scoreFlash(player: Int, in size: CGSize) -> some View {
        let color = player == 1 ? player1Color : player2Color
        color.opacity(0.2)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .transition(.opacity)
    }
}

// MARK: - Overlays

private extension TugOfWarView {
    var topBar: some View {
        VStack {
            HStack {
                Button(action: onExit) {
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
                // Player labels
                HStack(spacing: 12) {
                    Text("P1")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                    Text("P2")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.horizontal, isCompact ? 16 : 40)
            .padding(.top, isCompact ? 12 : 20)
            Spacer()
        }
    }

    var countdownOverlay: some View {
        VStack(spacing: 16) {
            Text("Get ready!")
                .font(.system(size: isCompact ? 28 : 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("\(viewModel.countdownValue)")
                .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: viewModel.countdownValue)
        }
        .padding(isCompact ? 24 : 40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    var waitingOverlay: some View {
        VStack(spacing: 16) {
            Text("🪢")
                .font(.system(size: 60))
            Text("Tug-of-War")
                .font(.system(size: isCompact ? 28 : 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Two players face the camera")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(isCompact ? 24 : 40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    var winOverlay: some View {
        VStack(spacing: 20) {
            Text("\(viewModel.winnerName ?? "Player") WINS!")
                .font(.system(size: isCompact ? 36 : 56, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)

            HStack(spacing: isCompact ? 12 : 16) {
                Button("Rematch") {
                    viewModel.reset()
                    lastTimestamp = 0
                }
                .font(.title2.weight(.semibold))
                .padding(.horizontal, isCompact ? 20 : 32)
                .padding(.vertical, 14)
                .background(.white)
                .foregroundStyle(.black)
                .clipShape(Capsule())

                Button("Games", action: onExit)
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal, isCompact ? 20 : 32)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.2))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
            }
        }
        .padding(isCompact ? 28 : 40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
    }

    var twoFaceHint: some View {
        VStack {
            Spacer()
            Text("Show both faces")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 40)
        }
    }
}

// MARK: - Display Link

private struct TugDisplayLinkModifier: ViewModifier {
    let onFrame: (CFTimeInterval) -> Void

    func body(content: Content) -> some View {
        content.background(TugDisplayLinkView(onFrame: onFrame))
    }
}

private struct TugDisplayLinkView: UIViewRepresentable {
    let onFrame: (CFTimeInterval) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        context.coordinator.start()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onFrame = onFrame
    }

    func makeCoordinator() -> Coordinator { Coordinator(onFrame: onFrame) }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        var onFrame: (CFTimeInterval) -> Void
        private var link: CADisplayLink?

        init(onFrame: @escaping (CFTimeInterval) -> Void) {
            self.onFrame = onFrame
        }

        func start() {
            let link = CADisplayLink(target: self, selector: #selector(step(_:)))
            link.add(to: .main, forMode: .common)
            self.link = link
        }

        func stop() {
            link?.invalidate()
            link = nil
        }

        @objc private func step(_ link: CADisplayLink) {
            onFrame(link.timestamp)
        }
    }
}
