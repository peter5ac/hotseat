import SwiftUI
import UIKit

struct HeadsUpView: View {
    @State private var viewModel = HeadsUpViewModel()
    @State private var motion = MotionTracker()
    let onExit: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }

    // Readying auto-start: how close to a forehead pose (pitch ~0° or ~180° in
    // landscape) counts as "on the forehead", how long it must be held before we
    // auto-begin the countdown, and how long without detection before the manual
    // Start button appears as a fallback.
    private let foreheadBand: Double = 30
    private let foreheadDwellTarget: Double = 0.8
    private let startFallbackDelay: Double = 3.0

    // Display-link timing.
    @State private var lastTimestamp: CFTimeInterval = 0
    // Pitch captured as "level" when the player taps Start.
    @State private var neutralPitch: Double = 0
    // Slot-machine overlay for the "Surprise me" random category pick.
    @State private var showingCategoryWheel = false
    // Seconds the phone has been held in a forehead pose during readying, and
    // whether we've waited long enough to fall back to the manual Start button.
    @State private var foreheadDwell: Double = 0
    @State private var readyElapsed: Double = 0
    @State private var showStartFallback = false

    // Pre-warmed haptic generators so the first correct/pass tap fires without
    // the cold-start latency of a freshly allocated generator.
    @State private var notificationHaptics = UINotificationFeedbackGenerator()
    @State private var impactHaptics = UIImpactFeedbackGenerator(style: .rigid)

    var body: some View {
        ZStack {
            switch viewModel.state {
            case .categoryPicker:
                if !showingCategoryWheel {
                    categoryPicker
                }
            case .readying:
                readyingView
            case .countdown:
                countdownView
            case .playing:
                playingView
            case .recap:
                recapView
            }

            flashOverlay
            topBar

            if showingCategoryWheel {
                SpinWheelView(
                    items: headsUpCategories.map {
                        WheelItem(id: $0.name, label: $0.name, emoji: $0.emoji)
                    },
                    onLanded: { landed in
                        guard let category = headsUpCategories.first(where: { $0.name == landed.id }) else {
                            showingCategoryWheel = false
                            return
                        }
                        // Enter readying under the still-visible wheel, then drop
                        // the wheel on the next runloop tick so the two state
                        // changes don't race into a transient picker flash.
                        viewModel.selectCategory(category)
                        DispatchQueue.main.async {
                            withAnimation(.spring(duration: 0.3)) {
                                showingCategoryWheel = false
                            }
                        }
                    },
                    onCancel: {
                        showingCategoryWheel = false
                    },
                    autoSpin: true
                )
                .transition(.opacity)
            }
        }
        .onAppear {
            motion.start()
            lastTimestamp = 0
            notificationHaptics.prepare()
            impactHaptics.prepare()
        }
        .onDisappear {
            motion.stop()
        }
        .onChange(of: viewModel.state) { _, newValue in
            if newValue == .readying {
                foreheadDwell = 0
                readyElapsed = 0
                showStartFallback = false
            }
        }
        .onChange(of: viewModel.flash) { _, newValue in
            fireHaptic(for: newValue)
        }
        .onChange(of: viewModel.isFinalSeconds) { _, newValue in
            if newValue {
                impactHaptics.impactOccurred()
            }
        }
        .modifier(HeadsUpDisplayLinkModifier { timestamp in
            advance(to: timestamp)
        })
    }

    // MARK: - Tick driver

    private func advance(to timestamp: CFTimeInterval) {
        guard lastTimestamp != 0 else { lastTimestamp = timestamp; return }
        // Clamp the per-frame delta so an app-resume (display link paused while
        // backgrounded) can't deliver one multi-second delta that burns the whole
        // round clock in a single frame. 0.1s tolerates dropped frames while
        // capping a resume to a normal-sized step.
        let delta = min(Double(timestamp - lastTimestamp), 0.1)
        lastTimestamp = timestamp

        switch viewModel.state {
        case .readying:
            // Try to detect the forehead pose automatically. In landscape the
            // phone-on-forehead pitch sits near 0° or ±180°; accept either.
            if motion.isLandscape && motion.isAvailable {
                let p = motion.pitch
                let nearForehead = abs(p) <= foreheadBand || abs(abs(p) - 180) <= foreheadBand
                if nearForehead {
                    foreheadDwell += delta
                    if foreheadDwell >= foreheadDwellTarget {
                        neutralPitch = p
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        viewModel.beginCountdown()
                    }
                } else {
                    foreheadDwell = 0
                }
            } else {
                foreheadDwell = 0
            }
            // Reveal the manual Start button if detection hasn't fired in time.
            readyElapsed += delta
            if readyElapsed >= startFallbackDelay {
                showStartFallback = true
            }
        case .countdown:
            // Track the current pitch while the player raises the phone to their
            // forehead. When the countdown ends this holds the forehead pose,
            // which becomes the neutral reference for tilt detection.
            neutralPitch = motion.pitch
            viewModel.tickCountdown(delta: delta)
        case .playing:
            viewModel.tickPlaying(delta: delta)
            viewModel.registerPitch(motion.pitch, neutral: neutralPitch)
        default:
            break
        }
    }

    // MARK: - Haptics

    private func fireHaptic(for flash: FlashKind) {
        switch flash {
        case .correct:
            notificationHaptics.notificationOccurred(.success)
            notificationHaptics.prepare()
        case .pass:
            notificationHaptics.notificationOccurred(.warning)
            notificationHaptics.prepare()
        case .none:
            break
        }
    }
}

// MARK: - Display link (private copy; unique names per file)

private struct HeadsUpDisplayLinkModifier: ViewModifier {
    let onFrame: (CFTimeInterval) -> Void
    func body(content: Content) -> some View {
        content.background(HeadsUpDisplayLinkView(onFrame: onFrame))
    }
}

private struct HeadsUpDisplayLinkView: UIViewRepresentable {
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
        init(onFrame: @escaping (CFTimeInterval) -> Void) { self.onFrame = onFrame }
        func start() {
            let link = CADisplayLink(target: self, selector: #selector(step(_:)))
            link.add(to: .main, forMode: .common)
            self.link = link
        }
        func stop() { link?.invalidate(); link = nil }
        @objc private func step(_ link: CADisplayLink) { onFrame(link.timestamp) }
    }
}

// MARK: - Subviews

private extension HeadsUpView {
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
                    Text("\(Int(viewModel.timeRemaining.rounded()))s")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(viewModel.isFinalSeconds ? .red : .white)
                }
            }
            .padding(.horizontal, isCompact ? 16 : 40)
            .padding(.top, isCompact ? 12 : 20)
            Spacer()
        }
    }

    var categoryColumns: [GridItem] {
        if isCompact {
            return [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        } else {
            return Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
        }
    }

    var categoryPicker: some View {
        VStack(spacing: isCompact ? 16 : 24) {
            Text("Pick a category")
                .font(.system(size: isCompact ? 32 : 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, isCompact ? 56 : 72)

            Button {
                showingCategoryWheel = true
            } label: {
                HStack(spacing: 6) {
                    Text("🎲")
                    Text("Surprise me")
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
            }

            ScrollView {
                LazyVGrid(columns: categoryColumns, spacing: isCompact ? 12 : 16) {
                    ForEach(headsUpCategories) { category in
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                viewModel.selectCategory(category)
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Text(category.emoji).font(.system(size: isCompact ? 28 : 36))
                                Text(category.name)
                                    .font(isCompact ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, isCompact ? 14 : 20)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.ultraThinMaterial)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, isCompact ? 16 : 40)
                .padding(.bottom, 40)
            }
        }
    }

    var readyingView: some View {
        VStack(spacing: 20) {
            if motion.isLandscape {
                Text("Hold it to your forehead")
                    .font(.system(size: isCompact ? 28 : 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("The countdown starts on its own once it's up there")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            } else {
                Text("Turn sideways")
                    .font(.system(size: isCompact ? 28 : 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Hold the phone in landscape")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            // Manual fallback: only shown if auto-detection hasn't started the
            // countdown after a few seconds (or motion is unavailable).
            if showStartFallback || !motion.isAvailable {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    neutralPitch = motion.pitch
                    viewModel.beginCountdown()
                } label: {
                    Text("Start")
                        .font(.system(size: isCompact ? 28 : 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isCompact ? 16 : 22)
                        .padding(.horizontal, isCompact ? 48 : 80)
                        .background(.white, in: Capsule())
                }
                .disabled(!motion.isAvailable)
                .opacity(motion.isAvailable ? 1 : 0.4)
                .transition(.opacity)
            }

            if !motion.isAvailable {
                Text("Motion not available on this device")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding(isCompact ? 24 : 40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .animation(.easeInOut(duration: 0.25), value: showStartFallback)
    }

    var countdownView: some View {
        Text("\(max(1, viewModel.countdownValue))")
            .font(.system(size: 120, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(.white)
    }

    var playingView: some View {
        ZStack {
            if let item = viewModel.currentItem {
                Text(item)
                    .font(.system(size: isCompact ? 48 : 80, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 40)
            }
            VStack {
                Spacer()
                if !motion.isLandscape {
                    Text("Turn sideways")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 40)
                } else if let category = viewModel.currentCategory {
                    Text("\(category.emoji) \(category.name)")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .padding(.bottom, isCompact ? 24 : 40)
                }
            }
        }
    }

    var flashOverlay: some View {
        Group {
            switch viewModel.flash {
            case .correct:
                flashColor(.green, label: "CORRECT")
            case .pass:
                flashColor(.orange, label: "PASS")
            case .none:
                EmptyView()
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.flash)
    }

    func flashColor(_ color: Color, label: String) -> some View {
        ZStack {
            color.opacity(0.45).ignoresSafeArea()
            Text(label)
                .font(.system(size: isCompact ? 56 : 96, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .transition(.opacity)
    }

    var recapView: some View {
        VStack(spacing: isCompact ? 16 : 24) {
            Text("Time's up!")
                .font(.system(size: isCompact ? 32 : 48, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, isCompact ? 56 : 72)

            Text("\(viewModel.totalGuessed) correct")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.guessed, id: \.self) { item in
                        Label(item, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    ForEach(viewModel.missed, id: \.self) { item in
                        Label(item, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .font(isCompact ? .body : .title3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, isCompact ? 24 : 80)
            }

            HStack(spacing: isCompact ? 12 : 16) {
                Button("Play again") {
                    withAnimation(.spring(duration: 0.3)) { viewModel.playAgain() }
                }
                .font(.title2.weight(.semibold))
                .padding(.horizontal, isCompact ? 20 : 32).padding(.vertical, 14)
                .background(.white).foregroundStyle(.black).clipShape(Capsule())

                Button("New category") {
                    withAnimation(.spring(duration: 0.3)) { viewModel.backToPicker() }
                }
                .font(.title2.weight(.semibold))
                .padding(.horizontal, isCompact ? 20 : 32).padding(.vertical, 14)
                .background(.white.opacity(0.2)).foregroundStyle(.white).clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
            }
            .padding(.bottom, isCompact ? 24 : 40)
        }
    }
}
