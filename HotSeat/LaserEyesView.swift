import SwiftUI

struct LaserEyesView: View {
    let faceTracker: FaceTracker
    let onExit: () -> Void

    @State private var viewModel = LaserEyesViewModel()
    @State private var explosions: [(id: UUID, position: CGPoint, color: Color)] = []
    @State private var hitFlashTargets: Set<UUID> = []
    @State private var canvasOriginInScreen: CGPoint = .zero
    @State private var audioEngine = LaserAudioEngine()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool { horizontalSizeClass == .compact }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                targetLayer
                laserBeamCanvas(size: geo.size)
                explosionLayer
                reticleLayer
                uiLayer
                if case .countdown(let n) = viewModel.gameState {
                    countdownOverlay(n)
                }
                if viewModel.gameState == .idle {
                    startOverlay
                }
                if viewModel.gameState == .gameOver {
                    gameOverOverlay
                }
            }
            .onAppear {
                viewModel.setCanvasSize(geo.size)
                canvasOriginInScreen = geo.frame(in: .global).origin
            }
            .onChange(of: geo.size) { _, newSize in
                viewModel.setCanvasSize(newSize)
                canvasOriginInScreen = geo.frame(in: .global).origin
            }
        }
        .modifier(LaserDisplayLinkModifier { delta in
            beamTick &+= 1
            let prevTargets = viewModel.targets
            viewModel.updateGaze(
                noseTip: faceTracker.noseTip,
                yaw: faceTracker.yaw,
                pitch: faceTracker.pitch
            )
            viewModel.tick(delta: delta)
            detectHitsAndDestructions(prev: prevTargets)

            // Drive charge-up audio from max dwell across locked targets
            if viewModel.lockedTargetIDs.isEmpty {
                audioEngine.setChargeProgress(0)
            } else {
                let maxDwell = viewModel.lockedDwellTime.values.max() ?? 0
                audioEngine.setChargeProgress(min(maxDwell / 0.4, 1.0))
            }
        })
    }

    // MARK: - Target Layer

    private var targetLayer: some View {
        ForEach(viewModel.targets) { target in
            if !target.isDestroyed {
                targetView(target)
                    .position(target.position)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.targets.map(\.isDestroyed))
    }

    private func targetView(_ target: TargetItem) -> some View {
        ZStack {
            Circle()
                .fill(targetColor(health: target.health).opacity(0.8))
                .frame(width: target.size, height: target.size)

            Circle()
                .stroke(.white.opacity(0.5), lineWidth: 2)
                .frame(width: target.size, height: target.size)

            Circle()
                .fill(targetColor(health: target.health))
                .frame(width: target.size * 0.6, height: target.size * 0.6)

            Text("\(target.health)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .modifier(DamageFlashModifier(isHit: hitFlashTargets.contains(target.id)))
    }

    private func targetColor(health: Int) -> Color {
        switch health {
        case 3: return .green
        case 2: return .yellow
        case 1: return .red
        default: return .gray
        }
    }

    // MARK: - Explosion Layer

    private var explosionLayer: some View {
        ForEach(explosions, id: \.id) { explosion in
            ExplosionView(origin: explosion.position, color: explosion.color)
        }
    }

    // MARK: - Laser Beams

    private func eyeOrigin(for targetID: UUID) -> CGPoint? {
        let useLeft = viewModel.lockedEyeChoice[targetID] ?? true
        let eyeScreen = useLeft ? faceTracker.leftEyeCenter : faceTracker.rightEyeCenter
        guard let pt = eyeScreen ?? faceTracker.noseTip else { return nil }
        // Convert from full-screen coordinates to local GeometryReader/Canvas space
        return CGPoint(x: pt.x - canvasOriginInScreen.x, y: pt.y - canvasOriginInScreen.y)
    }

    @State private var beamTick: UInt64 = 0

    private func laserBeamCanvas(size: CGSize) -> some View {
        Canvas { context, _ in
            let tick = Double(beamTick)
            for target in viewModel.targets where viewModel.lockedTargetIDs.contains(target.id) {
                guard let origin = eyeOrigin(for: target.id) else { continue }
                let dwell = viewModel.lockedDwellTime[target.id] ?? 0
                let progress = min(dwell / 0.4, 1.0)

                let dx = target.position.x - origin.x
                let dy = target.position.y - origin.y
                let length = sqrt(dx * dx + dy * dy)
                guard length > 1 else { continue }
                let perpX = -dy / length
                let perpY = dx / length

                // Color shifts red → orange → white as dwell builds
                let r: Double = 1.0
                let g: Double = progress * 0.8
                let b: Double = progress * progress * 0.6
                let beamColor = Color(red: r, green: g, blue: b)

                // Outer glow (wide, faint)
                let glowWidth: CGFloat = 12 + CGFloat(progress) * 20
                var glowPath = Path()
                glowPath.move(to: origin)
                glowPath.addLine(to: target.position)
                context.opacity = 0.15 + progress * 0.15
                context.stroke(glowPath, with: .color(beamColor), lineWidth: glowWidth)
                context.opacity = 1.0

                // Multi-beam: 3 thin beams with jitter
                let beamCount = 3
                for b in 0..<beamCount {
                    let seed = tick * 7.3 + Double(b) * 123.7 + Double(target.id.hashValue & 0xFF)
                    let jitterAmt: CGFloat = (2 + CGFloat(progress) * 4)
                    let offsetStart = CGFloat(sin(seed * 0.13)) * jitterAmt
                    let offsetEnd = CGFloat(sin(seed * 0.17 + 2.0)) * jitterAmt * 0.5

                    let startPt = CGPoint(
                        x: origin.x + perpX * offsetStart,
                        y: origin.y + perpY * offsetStart
                    )
                    let endPt = CGPoint(
                        x: target.position.x + perpX * offsetEnd,
                        y: target.position.y + perpY * offsetEnd
                    )

                    var beamPath = Path()
                    beamPath.move(to: startPt)
                    beamPath.addLine(to: endPt)

                    // Flicker opacity
                    let flicker = 0.6 + 0.4 * sin(seed * 0.31 + tick * 0.5)
                    let coreWidth: CGFloat = 1.5 + CGFloat(progress) * 2.5
                    context.opacity = flicker
                    context.stroke(beamPath, with: .color(beamColor), lineWidth: coreWidth)
                }
                context.opacity = 1.0

                // Central core beam (always stable)
                let coreWidth: CGFloat = 2 + CGFloat(progress) * 4
                var corePath = Path()
                corePath.move(to: origin)
                corePath.addLine(to: target.position)
                context.stroke(corePath, with: .color(.white.opacity(0.5 + progress * 0.5)), lineWidth: coreWidth)

                // Red pupil glow at beam origin
                let pupilRadius: CGFloat = 6 + CGFloat(progress) * 4
                let pupilRect = CGRect(
                    x: origin.x - pupilRadius,
                    y: origin.y - pupilRadius,
                    width: pupilRadius * 2,
                    height: pupilRadius * 2
                )
                let glowRadius: CGFloat = pupilRadius + 5 + CGFloat(progress) * 6
                let glowRect = CGRect(
                    x: origin.x - glowRadius,
                    y: origin.y - glowRadius,
                    width: glowRadius * 2,
                    height: glowRadius * 2
                )
                context.opacity = 0.3 + CGFloat(progress) * 0.3
                context.fill(Circle().path(in: glowRect), with: .color(.red))
                context.opacity = 0.7 + CGFloat(progress) * 0.3
                context.fill(Circle().path(in: pupilRect), with: .color(.red))

                // Impact glow at target
                let impactRadius: CGFloat = 10 + CGFloat(progress) * 25
                let impactRect = CGRect(
                    x: target.position.x - impactRadius,
                    y: target.position.y - impactRadius,
                    width: impactRadius * 2,
                    height: impactRadius * 2
                )
                let impactFlicker = 0.3 + 0.7 * sin(tick * 0.4 + Double(target.id.hashValue & 0xFF))
                context.opacity = CGFloat(impactFlicker) * CGFloat(0.4 + progress * 0.6)
                context.fill(Circle().path(in: impactRect), with: .color(beamColor))
                context.opacity = 1.0

                // Sparks at impact point
                let sparkCount = Int(progress * 6) + 1
                for s in 0..<sparkCount {
                    let sparkSeed = tick * 3.1 + Double(s) * 47.0 + Double(target.id.hashValue & 0xFFF)
                    let angle = CGFloat(sparkSeed.truncatingRemainder(dividingBy: 6.28))
                    let dist = CGFloat(8 + sin(sparkSeed * 0.7) * 12) * CGFloat(progress)
                    let sparkPt = CGPoint(
                        x: target.position.x + cos(angle) * dist,
                        y: target.position.y + sin(angle) * dist
                    )
                    let sparkSize: CGFloat = 2 + CGFloat(progress) * 2
                    let sparkRect = CGRect(
                        x: sparkPt.x - sparkSize / 2,
                        y: sparkPt.y - sparkSize / 2,
                        width: sparkSize,
                        height: sparkSize
                    )
                    let sparkOpacity = 0.5 + 0.5 * sin(sparkSeed * 0.5)
                    context.opacity = CGFloat(sparkOpacity)
                    context.fill(Circle().path(in: sparkRect), with: .color(.yellow))
                }
                context.opacity = 1.0
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    // MARK: - Reticle

    private var reticleLayer: some View {
        Group {
            if let gaze = viewModel.gazePoint, viewModel.gameState == .playing {
                GazeReticle(position: gaze, isFiring: !viewModel.lockedTargetIDs.isEmpty)
            }
        }
    }

    // MARK: - UI Layer

    private var uiLayer: some View {
        VStack(spacing: 0) {
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

                if viewModel.gameState == .playing {
                    HStack(spacing: 12) {
                        Label("\(viewModel.score)", systemImage: "flame.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)

                        Text(String(format: "%.0f", viewModel.timeRemaining))
                            .font(.system(.headline, design: .monospaced))
                            .foregroundStyle(viewModel.timeRemaining <= 5 ? .red : .white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.horizontal, isCompact ? 16 : 40)
            .padding(.top, isCompact ? 12 : 20)

            Spacer()
        }
    }

    // MARK: - Overlays

    private func countdownOverlay(_ n: Int) -> some View {
        Text("\(n)")
            .font(.system(size: 120, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .red.opacity(0.6), radius: 20)
            .transition(.scale.combined(with: .opacity))
            .animation(.easeOut(duration: 0.3), value: n)
    }

    private var startOverlay: some View {
        VStack(spacing: 20) {
            Text("Laser Eyes")
                .font(.system(size: isCompact ? 40 : 56, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Look at targets to destroy them")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))

            Button {
                viewModel.startGame()
            } label: {
                Text("Start")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 14)
                    .background(.white, in: Capsule())
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var gameOverOverlay: some View {
        VStack(spacing: 16) {
            Text("🔥")
                .font(.system(size: 56))
            Text("Time's Up!")
                .font(.system(size: isCompact ? 32 : 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Score: \(viewModel.score)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.orange)

            Button {
                viewModel.startGame()
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

    // MARK: - Hit Detection Feedback

    private func detectHitsAndDestructions(prev: [TargetItem]) {
        for i in viewModel.targets.indices {
            guard i < prev.count else { continue }
            let old = prev[i]
            let new = viewModel.targets[i]
            if !old.isDestroyed && new.isDestroyed {
                LaserHaptics.destroyed()
                audioEngine.playExplosion()
                let explosion = (id: UUID(), position: new.position, color: Color.orange)
                explosions.append(explosion)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    explosions.removeAll { $0.id == explosion.id }
                }
            } else if new.health < old.health && !new.isDestroyed {
                LaserHaptics.hit()
                hitFlashTargets.insert(new.id)
                let targetId = new.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    hitFlashTargets.remove(targetId)
                }
            }
        }
    }
}

// MARK: - Display Link

private struct LaserDisplayLinkModifier: ViewModifier {
    let onFrame: (_ delta: Double) -> Void
    @State private var lastTimestamp: CFTimeInterval = 0

    func body(content: Content) -> some View {
        content
            .onAppear { lastTimestamp = 0 }
            .background(LaserDisplayLinkRepresentable(onFrame: { ts in
                guard lastTimestamp != 0 else { lastTimestamp = ts; return }
                let delta = min(ts - lastTimestamp, 0.1)
                lastTimestamp = ts
                onFrame(delta)
            }))
    }
}

private struct LaserDisplayLinkRepresentable: UIViewRepresentable {
    let onFrame: (CFTimeInterval) -> Void

    func makeUIView(context: Context) -> LaserDisplayLinkView {
        let v = LaserDisplayLinkView()
        v.onFrame = onFrame
        return v
    }

    func updateUIView(_ uiView: LaserDisplayLinkView, context: Context) {
        uiView.onFrame = onFrame
    }
}

private class LaserDisplayLinkView: UIView {
    var onFrame: ((CFTimeInterval) -> Void)?
    private var link: CADisplayLink?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            let dl = CADisplayLink(target: self, selector: #selector(step))
            dl.add(to: .main, forMode: .common)
            link = dl
        } else {
            link?.invalidate()
            link = nil
        }
    }

    @objc private func step(_ link: CADisplayLink) {
        onFrame?(link.timestamp)
    }

    override var intrinsicContentSize: CGSize { .zero }
}
