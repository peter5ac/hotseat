import SwiftUI
import UIKit

struct VocalGlideView: View {
    @State private var viewModel = VocalGlideViewModel()
    let onExit: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }

    @State private var impactHaptic = UIImpactFeedbackGenerator(style: .heavy)

    private let characterEmoji = "🚀"
    private let barrierEmoji = "🧱"
    private let obstacleColor = Color.red.opacity(0.7)
    private let gapColor = Color.clear
    private let blastColor = Color.yellow

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                skyBackground

                // Game content driven by frame updates
                TimelineView(.animation) { context in
                    let _ = updateFrame(context.date)
                    ZStack {
                        gameLayer(size: size)

                        // Pig with charge ring
                        ZStack {
                            // Charge ring
                            Circle()
                                .trim(from: 0, to: viewModel.blastCharge)
                                .stroke(
                                    viewModel.blastCharge >= 1.0 ? Color.yellow : Color.orange,
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .frame(width: 52, height: 52)
                                .rotationEffect(.degrees(-90))
                                .opacity(viewModel.blastCharge > 0.1 ? 1 : 0)

                            BirdSprite(isRising: viewModel.velocity < 0)
                        }
                        .position(
                            x: size.width * 0.18,
                            y: size.height * viewModel.characterYPosition
                        )

                        // SHOUT! warning
                        if viewModel.wallApproaching {
                            Text("SHOUT!")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(.yellow)
                                .shadow(color: .black, radius: 4)
                                .position(
                                    x: size.width * 0.18,
                                    y: size.height * viewModel.characterYPosition - 50
                                )
                        }
                    }
                    .frame(width: size.width, height: size.height)
                    .clipped()
                }
                .allowsHitTesting(false)

                // Debug strip
                debugStrip

                // Interactive UI on top
                VStack {
                    HStack {
                        Button(action: {
                            viewModel.stop()
                            onExit()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white)
                                .shadow(radius: 4)
                                .frame(width: 60, height: 60)
                                .contentShape(Rectangle())
                        }

                        Spacer()

                        if viewModel.gameState == .playing {
                            Text("\(viewModel.score)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.6), radius: 3)
                                .padding(.trailing, 20)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.leading, 8)

                    Spacer()
                }

                // State overlays
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
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
        .onDisappear {
            viewModel.stop()
        }
    }

    // MARK: - Sky background

    private var skyBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.3, green: 0.5, blue: 0.9),
                    Color(red: 0.6, green: 0.8, blue: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Ground strip pinned to bottom
            VStack(spacing: 0) {
                Spacer()
                HStack(spacing: 0) {
                    ForEach(0..<40, id: \.self) { i in
                        Rectangle()
                            .fill(i % 2 == 0 ? Color(red: 0.2, green: 0.6, blue: 0.1) : Color(red: 0.15, green: 0.5, blue: 0.08))
                            .frame(width: 20, height: 30)
                    }
                }
                Rectangle()
                    .fill(Color(red: 0.4, green: 0.25, blue: 0.1))
                    .frame(height: 16)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Frame driver

    @discardableResult
    private func updateFrame(_ date: Date) -> Bool {
        viewModel.update(timestamp: date.timeIntervalSinceReferenceDate)
        return true
    }

    // MARK: - Game layer

    private func gameLayer(size: CGSize) -> some View {
        ZStack {
            // Obstacles
            ForEach(viewModel.obstacles) { obstacle in
                if !obstacle.destroyed {
                    obstacleView(obstacle: obstacle, size: size)
                }
            }

            // Blast aura
            if viewModel.isBlasting {
                blastEffect(size: size)
            }
        }
        .allowsHitTesting(false)
    }

    private func characterView(size: CGSize) -> some View {
        Circle()
            .fill(Color.orange)
            .frame(width: 60, height: 60)
            .overlay(
                Text(characterEmoji)
                    .font(.system(size: 36))
            )
            .shadow(color: .black, radius: 8)
            .position(x: size.width * 0.18, y: size.height * viewModel.characterYPosition)
    }

    private func obstacleView(obstacle: GlideObstacle, size: CGSize) -> some View {
        let x = size.width * obstacle.xPosition
        let fullHeight = size.height

        return ZStack {
            if obstacle.isBarrier {
                // Full-height barrier wall
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.orange.opacity(0.85))
                    .frame(width: 24, height: fullHeight)
                    .overlay(
                        VStack(spacing: 30) {
                            ForEach(0..<5, id: \.self) { _ in
                                Text(barrierEmoji)
                                    .font(.system(size: 22))
                            }
                        }
                    )
                    .position(x: x, y: fullHeight / 2)
            } else {
                // Top pillar
                let gapTop = (obstacle.gapCenter - obstacle.gapSize / 2) * fullHeight
                RoundedRectangle(cornerRadius: 8)
                    .fill(obstacleColor)
                    .frame(width: 30, height: max(gapTop, 0))
                    .position(x: x, y: gapTop / 2)

                // Bottom pillar
                let gapBottom = (obstacle.gapCenter + obstacle.gapSize / 2) * fullHeight
                let bottomHeight = fullHeight - gapBottom
                RoundedRectangle(cornerRadius: 8)
                    .fill(obstacleColor)
                    .frame(width: 30, height: max(bottomHeight, 0))
                    .position(x: x, y: gapBottom + bottomHeight / 2)
            }
        }
    }

    private func blastEffect(size: CGSize) -> some View {
        let x = size.width * 0.18
        let y = size.height * viewModel.characterYPosition
        return HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(blastColor.opacity(Double(5 - i) / 5.0))
                    .frame(width: CGFloat(20 - i * 3), height: CGFloat(20 - i * 3))
            }
        }
        .position(x: x + 50, y: y)
        .transition(.opacity)
    }

    // MARK: - Debug strip

    private var debugStrip: some View {
        VStack {
            Spacer()
            if viewModel.gameState == .playing {
                VStack(spacing: 4) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(viewModel.audioActive ? .green : .red)
                            .frame(width: 8, height: 8)
                        Label(String(format: "VOL %.3f", viewModel.currentRMS), systemImage: "speaker.wave.2")
                        if viewModel.isBlasting {
                            Text("BLAST")
                                .foregroundStyle(.yellow)
                                .bold()
                        }
                    }
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white.opacity(0.7))

                    // Volume bar — fixed width, no GeometryReader
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.black.opacity(0.5))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.cyan)
                            .frame(width: 300 * viewModel.pitchBarNormalized, height: 8)
                    }
                    .frame(width: 300, height: 8)
                }
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Overlays

    private func countdownOverlay(_ count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: 96, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 8)
    }

    private var startOverlay: some View {
        VStack(spacing: 20) {
            Text("🐷 Pig Flight")
                .font(.system(size: isCompact ? 34 : 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(radius: 6)

            VStack(spacing: 8) {
                Text("Hum to fly up! Louder = more lift.")
                Text("SHOUT to blast through brick walls! 🧱")
            }
            .font(.system(size: isCompact ? 16 : 20, weight: .medium))
            .foregroundStyle(.white.opacity(0.85))
            .multilineTextAlignment(.center)

            Button(action: { viewModel.startCountdown() }) {
                Text("START")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(.white))
            }
            .padding(.top, 10)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial.opacity(0.85))
        )
    }

    private var gameOverOverlay: some View {
        VStack(spacing: 16) {
            Text("Game Over")
                .font(.system(size: isCompact ? 30 : 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Score: \(viewModel.score)")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            Button(action: { viewModel.startCountdown() }) {
                Text("RETRY")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.white))
            }
            .padding(.top, 8)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial.opacity(0.85))
        )
    }
}

// MARK: - Flying pig sprite

struct BirdSprite: View {
    let isRising: Bool

    @State private var wingPhase: Bool = false

    private let pigPink = Color(red: 1.0, green: 0.6, blue: 0.7)
    private let pigDark = Color(red: 0.9, green: 0.45, blue: 0.55)
    private let pigLight = Color(red: 1.0, green: 0.75, blue: 0.82)

    var body: some View {
        ZStack {
            // Body
            Ellipse()
                .fill(pigPink)
                .frame(width: 40, height: 32)

            // Snout
            Ellipse()
                .fill(pigDark)
                .frame(width: 14, height: 10)
                .offset(x: 14, y: 4)
            // Nostrils
            Circle()
                .fill(Color(red: 0.7, green: 0.3, blue: 0.4))
                .frame(width: 3, height: 3)
                .offset(x: 12, y: 4)
            Circle()
                .fill(Color(red: 0.7, green: 0.3, blue: 0.4))
                .frame(width: 3, height: 3)
                .offset(x: 16, y: 4)

            // Eyes
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
                .offset(x: 8, y: -6)
            Circle()
                .fill(Color.black)
                .frame(width: 5, height: 5)
                .offset(x: 9, y: -6)

            // Ears
            Ellipse()
                .fill(pigDark)
                .frame(width: 10, height: 8)
                .rotationEffect(.degrees(-20))
                .offset(x: 2, y: -16)
            Ellipse()
                .fill(pigDark)
                .frame(width: 10, height: 8)
                .rotationEffect(.degrees(20))
                .offset(x: -8, y: -16)

            // Wings
            Ellipse()
                .fill(Color.white)
                .frame(width: 22, height: 10)
                .rotationEffect(.degrees(wingAngle), anchor: .trailing)
                .offset(x: -14, y: -10)
            Ellipse()
                .fill(Color.white)
                .frame(width: 22, height: 10)
                .rotationEffect(.degrees(wingAngle * 0.8), anchor: .trailing)
                .offset(x: -10, y: -8)

            // Curly tail
            Circle()
                .trim(from: 0.1, to: 0.75)
                .stroke(pigDark, lineWidth: 2.5)
                .frame(width: 10, height: 10)
                .offset(x: -22, y: 4)
        }
        .rotationEffect(.degrees(isRising ? -8 : 8))
        .animation(.easeInOut(duration: 0.2), value: isRising)
        .onChange(of: isRising) { _, rising in
            if rising {
                startFlapping()
            } else {
                stopFlapping()
            }
        }
        .onAppear {
            if isRising { startFlapping() }
        }
    }

    private var wingAngle: Double {
        if !isRising { return -5 }
        return wingPhase ? -40 : 15
    }

    private func startFlapping() {
        withAnimation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true)) {
            wingPhase = true
        }
    }

    private func stopFlapping() {
        withAnimation(.easeInOut(duration: 0.3)) {
            wingPhase = false
        }
    }
}
