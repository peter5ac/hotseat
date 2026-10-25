import SwiftUI
import AVFoundation
import UIKit

struct SimonGameView: View {
    @State private var viewModel = SimonGameViewModel()
    let onExit: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }

    @State private var impactHaptic = UIImpactFeedbackGenerator(style: .medium)
    @State private var errorHaptic = UINotificationFeedbackGenerator()
    @State private var tonePlayer = SimonTonePlayer()

    private let buttonColors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]

    var body: some View {
        ZStack {
            quadrantGrid
            topOverlay
            if viewModel.gameState == .idle {
                startOverlay
            }
            if viewModel.gameState == .failure {
                failureOverlay
            }
            if viewModel.gameState == .success {
                successFlash
            }
        }
        .onAppear {
            impactHaptic.prepare()
            errorHaptic.prepare()
        }
        .modifier(SimonDisplayLinkModifier { delta in
            viewModel.tick(delta: delta)
        })
    }

    // MARK: - Button Grid

    private var buttonCount: Int {
        viewModel.gameState == .freePlay ? 6 : viewModel.currentDifficulty.buttonCount
    }

    private var quadrantGrid: some View {
        let columns = buttonCount <= 4 ? 2 : 3
        let rows = (buttonCount + columns - 1) / columns
        return VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        if index < buttonCount {
                            quadrantButton(index: index)
                        }
                    }
                }
            }
        }
        .padding(isCompact ? 16 : 32)
    }

    @ViewBuilder
    private func quadrantButton(index: Int) -> some View {
        let isLit = viewModel.litQuadrant == index
        let baseColor = buttonColors[index]
        let canTap = viewModel.gameState == .accepting || viewModel.gameState == .freePlay

        Button {
            guard canTap else { return }
            if viewModel.gameState == .freePlay {
                impactHaptic.impactOccurred()
                tonePlayer.play(index: index)
                impactHaptic.prepare()
                return
            }
            let correct = viewModel.checkUserPress(quadrant: index)
            if correct {
                impactHaptic.impactOccurred()
                tonePlayer.play(index: index)
            } else {
                errorHaptic.notificationOccurred(.error)
                tonePlayer.playError()
            }
            impactHaptic.prepare()
        } label: {
            RoundedRectangle(cornerRadius: 20)
                .fill(baseColor.opacity(isLit ? 1.0 : 0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(isLit ? 0.8 : 0.2), lineWidth: isLit ? 3 : 1)
                )
                .shadow(color: isLit ? baseColor.opacity(0.6) : .clear, radius: isLit ? 20 : 0)
        }
        .disabled(!canTap)
        .animation(.easeInOut(duration: 0.15), value: isLit)
        .onChange(of: isLit) { _, nowLit in
            if nowLit && viewModel.isDisplayingPattern {
                impactHaptic.impactOccurred(intensity: 0.6)
                tonePlayer.play(index: index)
                impactHaptic.prepare()
            }
        }
    }

    // MARK: - Top Overlay

    private var topOverlay: some View {
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

                if viewModel.gameState == .accepting || viewModel.gameState == .displaying {
                    Text("Round \(viewModel.round + 1) · \(viewModel.simonSequence.count) tones")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, isCompact ? 16 : 40)
            .padding(.top, isCompact ? 12 : 20)

            if viewModel.gameState == .accepting {
                countdownBar
            }

            if viewModel.gameState == .displaying {
                Text("Watch…")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.top, 8)
            }

            Spacer()
        }
    }

    private var countdownBar: some View {
        let fraction = max(0, viewModel.timeRemaining / viewModel.currentDifficulty.totalRoundTime)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.15))
                    .frame(height: 8)
                Capsule()
                    .fill(fraction > 0.3 ? Color.white : Color.orange)
                    .frame(width: geo.size.width * fraction, height: 8)
                    .animation(.linear(duration: 0.1), value: fraction)
            }
        }
        .frame(height: 8)
        .padding(.horizontal, isCompact ? 24 : 48)
        .padding(.top, 10)
    }

    // MARK: - Start Overlay

    private var startOverlay: some View {
        VStack(spacing: 20) {
            Text("Simon")
                .font(.system(size: isCompact ? 40 : 56, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Picker("Difficulty", selection: $viewModel.currentDifficulty) {
                ForEach(SimonDifficulty.allCases) { d in
                    Text(d.label).tag(d)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)
            .onChange(of: viewModel.currentDifficulty) { _, newVal in
                viewModel.resetWithDifficulty(newVal)
            }

            HStack(spacing: 16) {
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

                Button {
                    viewModel.startFreePlay()
                } label: {
                    Text("Free Play")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.2), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                }
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Failure Overlay

    private var failureOverlay: some View {
        VStack(spacing: 16) {
            Text("💥")
                .font(.system(size: 56))
            Text("Game Over")
                .font(.system(size: isCompact ? 32 : 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("You went \(viewModel.round) \(viewModel.round == 1 ? "round" : "rounds") and made it up to \(viewModel.maxSequenceReached) \(viewModel.maxSequenceReached == 1 ? "tone" : "tones")!")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

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

    // MARK: - Success Flash

    private var successFlash: some View {
        Text("✓")
            .font(.system(size: 64, weight: .bold))
            .foregroundStyle(.green)
            .transition(.opacity)
    }
}

// MARK: - Display Link

private struct SimonDisplayLinkModifier: ViewModifier {
    let onFrame: (_ delta: Double) -> Void
    @State private var lastTimestamp: CFTimeInterval = 0

    func body(content: Content) -> some View {
        content
            .onAppear { lastTimestamp = 0 }
            .background(SimonDisplayLinkRepresentable(onFrame: { ts in
                guard lastTimestamp != 0 else { lastTimestamp = ts; return }
                let delta = min(ts - lastTimestamp, 0.1)
                lastTimestamp = ts
                onFrame(delta)
            }))
    }
}

private struct SimonDisplayLinkRepresentable: UIViewRepresentable {
    let onFrame: (CFTimeInterval) -> Void

    func makeUIView(context: Context) -> SimonDisplayLinkView {
        let v = SimonDisplayLinkView()
        v.onFrame = onFrame
        return v
    }

    func updateUIView(_ uiView: SimonDisplayLinkView, context: Context) {
        uiView.onFrame = onFrame
    }
}

private class SimonDisplayLinkView: UIView {
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

// MARK: - Simon Tone Engine (square wave, media volume)

private final class SimonOscillatorState {
    var frequency: Double = 0
    var phase: Double = 0
    var playing: Bool = false
}

private class SimonTonePlayer {
    private let audioEngine = AVAudioEngine()
    private let sourceNode: AVAudioSourceNode
    private let state = SimonOscillatorState()
    private let sampleRate: Double = 44100.0

    // Green, Red, Yellow, Blue (classic Simon), plus E4 and F#4 for hard mode.
    private let toneFrequencies: [Double] = [209.0, 252.0, 310.0, 415.0, 330.0, 370.0]
    private let razzFrequency: Double = 42.0

    init() {
        let oscState = state
        sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buffer = abl[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }

            guard oscState.playing else {
                for i in 0..<Int(frameCount) { buffer[i] = 0 }
                return noErr
            }

            let phaseIncrement = (2.0 * .pi * oscState.frequency) / 44100.0
            for frame in 0..<Int(frameCount) {
                buffer[frame] = sin(oscState.phase) >= 0 ? 0.15 : -0.15
                oscState.phase += phaseIncrement
                if oscState.phase >= 2.0 * .pi { oscState.phase -= 2.0 * .pi }
            }
            return noErr
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: audioEngine.mainMixerNode, format: format)

        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        try? audioEngine.start()
    }

    func play(index: Int) {
        let freq = toneFrequencies[index % toneFrequencies.count]
        playTone(frequency: freq, duration: 0.42)
    }

    func playError() {
        playTone(frequency: razzFrequency, duration: 1.5)
    }

    private func playTone(frequency: Double, duration: TimeInterval) {
        state.frequency = frequency
        state.phase = 0
        state.playing = true

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.state.playing = false
        }
    }
}
