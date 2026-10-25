import SwiftUI

struct LaneDodgeView: View {
    @State private var viewModel = LaneDodgeViewModel()
    let faceTracker: FaceTracker
    let onExit: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }

    // Calibration countdown (seconds).
    @State private var calibrationRemaining: CGFloat = 2.0
    // Display-link timing.
    @State private var lastTimestamp: CFTimeInterval = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                lanes(in: geo.size)
                obstacleLayer(in: geo.size)
                topBar
                if viewModel.state == .calibrating {
                    calibrationOverlay
                } else if viewModel.state == .gameOver {
                    gameOverCard
                }
                if viewModel.state == .playing && faceTracker.roll == nil {
                    noFaceHint
                }
            }
        }
        .onAppear {
            viewModel.startCalibration()
            calibrationRemaining = 2.0
            lastTimestamp = 0
        }
        .onChange(of: faceTracker.roll) { _, newRoll in
            if viewModel.state == .calibrating {
                viewModel.addCalibrationSample(roll: newRoll)
            } else {
                viewModel.updatePlayerLane(roll: newRoll)
            }
        }
        .modifier(DisplayLinkModifier { timestamp in
            advance(to: timestamp)
        })
    }

    // MARK: - Tick driver

    private func advance(to timestamp: CFTimeInterval) {
        guard lastTimestamp != 0 else { lastTimestamp = timestamp; return }
        let delta = CGFloat(timestamp - lastTimestamp)
        lastTimestamp = timestamp

        switch viewModel.state {
        case .calibrating:
            calibrationRemaining -= delta
            if calibrationRemaining <= 0 {
                viewModel.finishCalibration()
            }
        case .playing:
            viewModel.tick(delta: delta)
        case .gameOver:
            break
        }
    }
}

/// Drives a per-frame callback using CADisplayLink for smooth animation.
private struct DisplayLinkModifier: ViewModifier {
    let onFrame: (CFTimeInterval) -> Void

    func body(content: Content) -> some View {
        content.background(DisplayLinkView(onFrame: onFrame))
    }
}

private struct DisplayLinkView: UIViewRepresentable {
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

private extension LaneDodgeView {
    func laneWidth(in size: CGSize) -> CGFloat {
        size.width / CGFloat(viewModel.laneCount)
    }

    func laneCenterX(_ lane: Int, in size: CGSize) -> CGFloat {
        laneWidth(in: size) * (CGFloat(lane) + 0.5)
    }

    @ViewBuilder
    func lanes(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<viewModel.laneCount, id: \.self) { lane in
                let isPlayer = lane == viewModel.playerLane && viewModel.state == .playing
                Rectangle()
                    .fill(isPlayer ? Color.white.opacity(0.18) : Color.white.opacity(0.04))
                    .overlay(
                        Rectangle().stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .frame(width: laneWidth(in: size))
                    .position(x: laneCenterX(lane, in: size), y: size.height / 2)
                    .animation(.easeOut(duration: 0.12), value: viewModel.playerLane)
            }

            // Player line near the bottom — where obstacles must be dodged.
            if viewModel.state == .playing {
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 22, height: 22)
                    .shadow(color: .white.opacity(0.6), radius: 8)
                    .position(
                        x: laneCenterX(viewModel.playerLane, in: size),
                        y: size.height * 0.82
                    )
                    .animation(.easeOut(duration: 0.12), value: viewModel.playerLane)
            }
        }
    }

    @ViewBuilder
    func obstacleLayer(in size: CGSize) -> some View {
        ForEach(viewModel.obstacles) { obstacle in
            let y = size.height * 0.82 * obstacle.progress
            let scale = 0.6 + 0.6 * obstacle.progress
            Text(obstacle.emoji)
                .font(.system(size: isCompact ? 44 : 64))
                .scaleEffect(scale)
                .position(x: laneCenterX(obstacle.lane, in: size), y: y)
        }
    }
}

private extension LaneDodgeView {
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

                if viewModel.state == .playing {
                    Text("\(viewModel.distance)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Spacer()

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < viewModel.lives ? "heart.fill" : "heart")
                            .foregroundStyle(i < viewModel.lives ? .red : .white.opacity(0.4))
                    }
                }
                .font(.title3)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(.horizontal, isCompact ? 16 : 40)
            .padding(.top, isCompact ? 12 : 20)

            Spacer()
        }
    }

    var calibrationOverlay: some View {
        VStack(spacing: 16) {
            Text("Hold your head still")
                .font(.system(size: isCompact ? 28 : 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Tilt left or right to change lanes")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
            Text("\(max(1, Int(calibrationRemaining.rounded(.up))))")
                .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(isCompact ? 24 : 40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    var gameOverCard: some View {
        VStack(spacing: 16) {
            Text("Crashed!")
                .font(.system(size: isCompact ? 28 : 38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Distance: \(viewModel.distance)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))

            HStack(spacing: isCompact ? 12 : 16) {
                Button("Play again") {
                    viewModel.reset()
                    calibrationRemaining = 2.0
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
        .padding(isCompact ? 24 : 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    var noFaceHint: some View {
        VStack {
            Spacer()
            Text("Show your face to steer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 40)
        }
    }
}
