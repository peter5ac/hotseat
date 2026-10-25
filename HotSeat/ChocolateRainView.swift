import SwiftUI
import AVFoundation

struct ChocolateRainView: View {
    let faceTracker: FaceTracker
    let onExit: () -> Void

    @State private var viewModel = ChocolateRainViewModel()
    @State private var audioEngine = ChompAudioEngine()
    @State private var razzEngine = RazzAudioEngine()
    @State private var showRedFlash = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                chocolateLayer
                timerLabel
                scoreLabel
                exitButton

                if showRedFlash {
                    Color.red.opacity(0.4)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                if viewModel.gameState == .idle {
                    startOverlay
                }
                if case .countdown(let n) = viewModel.gameState {
                    countdownOverlay(n)
                }
                if viewModel.gameState == .gameOver {
                    gameOverOverlay
                }
            }
            .onAppear {
                viewModel.setCanvasSize(geo.size)
            }
            .onChange(of: geo.size) { _, newSize in
                viewModel.setCanvasSize(newSize)
            }
        }
        .modifier(ChocolateDisplayLinkModifier { delta in
            viewModel.updateMouth(
                rect: faceTracker.mouthRect,
                faceBBoxWidth: faceTracker.faceBBoxWidth,
                mouthOpen: faceTracker.mouthOpen ?? false
            )
            if let result = viewModel.tick(delta: delta) {
                switch result {
                case .treat:
                    audioEngine.playChomp()
                    ChompHaptics.chomp()
                case .trap:
                    razzEngine.playRazz()
                    triggerRedFlash()
                }
            }
        })
    }

    // MARK: - Chocolate Layer

    private var chocolateLayer: some View {
        ForEach(viewModel.activeChocolates) { item in
            Text(item.emoji)
                .font(.system(size: item.size))
                .position(item.position)
        }
    }

    // MARK: - Timer

    private var timerLabel: some View {
        VStack {
            HStack {
                Spacer()
                Text("\(Int(viewModel.timeRemaining))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(viewModel.timeRemaining <= 10 ? .red : .white)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                    .padding(.top, 60)
                    .padding(.trailing, 20)
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }

    // MARK: - Score

    private var scoreLabel: some View {
        VStack {
            Text("\(viewModel.score)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                .padding(.top, 60)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    // MARK: - Exit

    private var exitButton: some View {
        VStack {
            HStack {
                Button {
                    viewModel.reset()
                    withAnimation(.spring(duration: 0.3)) {
                        onExit()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(16)
                }
                Spacer()
            }
            Spacer()
        }
    }

    // MARK: - Start Overlay

    private var startOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Text("🍫")
                    .font(.system(size: 80))
                Text("Chocolate Rain")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text("Open wide to catch treats!\nAvoid the junk!")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    ForEach(ChocolateDifficulty.allCases, id: \.self) { diff in
                        Button {
                            viewModel.difficulty = diff
                        } label: {
                            Text(diff.label)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule().fill(viewModel.difficulty == diff ? .brown : .white.opacity(0.2))
                                )
                        }
                    }
                }
                .padding(.top, 8)

                Button {
                    viewModel.startGame()
                } label: {
                    Text("Play")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(.brown))
                }
                .padding(.top, 12)
            }
        }
    }

    // MARK: - Countdown

    private func countdownOverlay(_ n: Int) -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            Text("\(n)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(radius: 10)
        }
    }

    // MARK: - Game Over

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Text("⏱️")
                    .font(.system(size: 60))
                Text("Time's Up!")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(viewModel.score)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
                Text("treats caught")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                Button {
                    viewModel.startGame()
                } label: {
                    Text("Play Again")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(.brown))
                }
                .padding(.top, 12)
            }
        }
    }

    // MARK: - Red Flash

    private func triggerRedFlash() {
        showRedFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showRedFlash = false
        }
    }
}

// MARK: - Razz Audio Engine (42Hz square wave, same as Simon)

private final class RazzOscillatorState {
    var phase: Double = 0
    var remainingSamples: Int = 0
}

final class RazzAudioEngine {
    private let audioEngine = AVAudioEngine()
    private let sourceNode: AVAudioSourceNode
    private let state = RazzOscillatorState()
    private let sampleRate: Double = 44100.0
    private let frequency: Double = 42.0

    init() {
        let oscState = state
        let sr = sampleRate
        let freq = frequency
        sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buffer = abl[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }

            for frame in 0..<Int(frameCount) {
                if oscState.remainingSamples > 0 {
                    let phaseInc = freq / sr
                    oscState.phase += phaseInc
                    if oscState.phase >= 1.0 { oscState.phase -= 1.0 }
                    buffer[frame] = oscState.phase < 0.5 ? 0.15 : -0.15
                    oscState.remainingSamples -= 1
                } else {
                    buffer[frame] = 0
                }
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

    func playRazz() {
        state.phase = 0
        state.remainingSamples = Int(sampleRate * 0.6)
    }
}

// MARK: - Display Link

private struct ChocolateDisplayLinkModifier: ViewModifier {
    let onFrame: (_ delta: Double) -> Void
    @State private var lastTimestamp: CFTimeInterval = 0

    func body(content: Content) -> some View {
        content
            .onAppear { lastTimestamp = 0 }
            .background(ChocolateDisplayLinkRepresentable(onFrame: { ts in
                guard lastTimestamp != 0 else { lastTimestamp = ts; return }
                let delta = min(ts - lastTimestamp, 0.1)
                lastTimestamp = ts
                onFrame(delta)
            }))
    }
}

private struct ChocolateDisplayLinkRepresentable: UIViewRepresentable {
    let onFrame: (CFTimeInterval) -> Void

    func makeUIView(context: Context) -> ChocolateDisplayLinkUIView {
        let v = ChocolateDisplayLinkUIView()
        v.onFrame = onFrame
        return v
    }

    func updateUIView(_ uiView: ChocolateDisplayLinkUIView, context: Context) {
        uiView.onFrame = onFrame
    }
}

private class ChocolateDisplayLinkUIView: UIView {
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
}
