import SwiftUI

struct ChoiceGateView: View {
    @State private var viewModel = ChoiceGateViewModel()
    let faceTracker: FaceTracker
    let onExit: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }

    @State private var lastTimestamp: CFTimeInterval = 0
    @State private var explosionOrigin: CGPoint?
    @State private var explosionColor: Color = .white
    @State private var pulseLeft = false
    @State private var pulseRight = false

    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Category tag
                if let scenario = viewModel.currentScenario, !viewModel.showPassPhone {
                    categoryTag(scenario.category)
                }

                // Choice cards
                if let scenario = viewModel.currentScenario, !viewModel.showPassPhone {
                    choiceCards(scenario: scenario, in: geo.size)
                }

                // Directional arrows
                if viewModel.phase == .idle && !viewModel.showPassPhone && viewModel.currentScenario != nil {
                    directionalIndicators(in: geo.size)
                }

                // Explosion particles
                if let origin = explosionOrigin {
                    ExplosionView(origin: origin, color: explosionColor)
                        .allowsHitTesting(false)
                }

                // Pass the phone overlay
                if viewModel.showPassPhone {
                    passPhoneOverlay
                }

                // Top bar
                topBar
            }
        }
        .onAppear {
            viewModel.startGame()
            haptic.prepare()
            lastTimestamp = 0
        }
        .onChange(of: faceTracker.roll) { oldRoll, newRoll in
            viewModel.updateRoll(newRoll)
        }
        .onChange(of: viewModel.isAnimatingTransition) { wasAnimating, isAnimating in
            if isAnimating && !wasAnimating {
                haptic.impactOccurred()
                haptic.prepare()
            }
        }
        .modifier(ChoiceGateDisplayLinkModifier { timestamp in
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

// MARK: - Category Tag

private extension ChoiceGateView {
    func categoryTag(_ category: String) -> some View {
        VStack {
            Text("[ \(category.uppercased()) ]")
                .font(.system(size: isCompact ? 14 : 18, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, isCompact ? 70 : 90)
            Spacer()
        }
    }
}

// MARK: - Choice Cards

private extension ChoiceGateView {
    @ViewBuilder
    func choiceCards(scenario: ChoiceScenario, in size: CGSize) -> some View {
        let cardWidth = size.width * 0.44
        let centerY = size.height * 0.48

        // Left card
        choiceCard(
            text: scenario.leftOption,
            side: .left,
            cardWidth: cardWidth,
            size: size,
            centerY: centerY
        )

        // Right card
        choiceCard(
            text: scenario.rightOption,
            side: .right,
            cardWidth: cardWidth,
            size: size,
            centerY: centerY
        )
    }

    @ViewBuilder
    func choiceCard(text: String, side: ChosenSide, cardWidth: CGFloat, size: CGSize, centerY: CGFloat) -> some View {
        let isChosen = viewModel.chosenSide == side
        let isDiscarded = viewModel.chosenSide != nil && viewModel.chosenSide != side
        let xPos = side == .left ? size.width * 0.25 : size.width * 0.75

        Text(text)
            .font(.system(size: isCompact ? 18 : 24, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
            .lineLimit(6)
            .padding(isCompact ? 16 : 24)
            .frame(width: cardWidth, height: size.height * 0.35)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                side == .left ? Color.cyan.opacity(0.6) : Color.orange.opacity(0.6),
                                lineWidth: 2
                            )
                    )
            )
            .scaleEffect(isChosen ? 1.3 : (isDiscarded ? 0.7 : 1.0))
            .opacity(isDiscarded ? 0.0 : 1.0)
            .offset(x: isDiscarded ? (side == .left ? -200 : 200) : 0)
            .position(x: xPos, y: centerY)
            .animation(.spring(duration: 0.4, bounce: 0.2), value: viewModel.chosenSide)
            .onChange(of: isChosen) { _, chosen in
                if chosen {
                    explosionOrigin = CGPoint(x: xPos, y: centerY)
                    explosionColor = side == .left ? .cyan : .orange
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        explosionOrigin = nil
                    }
                }
            }
    }
}

// MARK: - Directional Indicators

private extension ChoiceGateView {
    func directionalIndicators(in size: CGSize) -> some View {
        ZStack {
            // Left arrow
            Image(systemName: "chevron.left")
                .font(.system(size: isCompact ? 28 : 40, weight: .bold))
                .foregroundStyle(.cyan.opacity(pulseLeft ? 0.8 : 0.3))
                .position(x: size.width * 0.06, y: size.height * 0.48)

            // Right arrow
            Image(systemName: "chevron.right")
                .font(.system(size: isCompact ? 28 : 40, weight: .bold))
                .foregroundStyle(.orange.opacity(pulseRight ? 0.8 : 0.3))
                .position(x: size.width * 0.94, y: size.height * 0.48)

            // "Tilt to choose" hint at bottom
            VStack {
                Spacer()
                Text("Tilt your head to choose")
                    .font(.system(size: isCompact ? 14 : 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, isCompact ? 50 : 60)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseLeft = true
                pulseRight = true
            }
        }
    }
}

// MARK: - Pass Phone Overlay

private extension ChoiceGateView {
    var passPhoneOverlay: some View {
        VStack(spacing: 20) {
            Text("📱")
                .font(.system(size: 64))
            Text("Pass the Phone!")
                .font(.system(size: isCompact ? 32 : 44, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("Next player's turn")
                .font(.system(size: isCompact ? 16 : 20, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            Button {
                viewModel.dismissPassPhone()
            } label: {
                Text("Ready!")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 14)
                    .background(.white, in: Capsule())
            }
            .padding(.top, 8)
        }
        .padding(isCompact ? 28 : 40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Top Bar

private extension ChoiceGateView {
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
                Text("\(viewModel.scenariosPlayed)")
                    .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(.horizontal, isCompact ? 16 : 40)
            .padding(.top, isCompact ? 12 : 20)
            Spacer()
        }
    }
}

// MARK: - Display Link

private struct ChoiceGateDisplayLinkModifier: ViewModifier {
    let onFrame: (CFTimeInterval) -> Void

    func body(content: Content) -> some View {
        content.background(ChoiceGateDisplayLinkView(onFrame: onFrame))
    }
}

private struct ChoiceGateDisplayLinkView: UIViewRepresentable {
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
