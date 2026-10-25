import SwiftUI
import UIKit

struct TicTacToeView: View {
    @State private var viewModel = TicTacToeViewModel()
    var faceTracker: FaceTracker
    let onExit: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }

    // Display-link timing.
    @State private var lastTimestamp: CFTimeInterval = 0
    // The grid's frame in view space, captured via GeometryReader, used to
    // hit-test the mouth center against cells.
    @State private var gridFrame: CGRect = .zero

    // Pre-warmed haptic for a placement.
    @State private var impactHaptics = UIImpactFeedbackGenerator(style: .rigid)

    var body: some View {
        ZStack {
            gridLayer
            turnIndicator
            topBar
            if viewModel.isGameOver { endCard }
        }
        .onAppear {
            lastTimestamp = 0
            impactHaptics.prepare()
        }
        .onChange(of: viewModel.board) { _, _ in
            // Re-arm the generator after each board mutation (cheap, like Heads Up).
            impactHaptics.prepare()
        }
        .modifier(TTTDisplayLinkModifier { timestamp in
            advance(to: timestamp)
        })
    }

    // MARK: - Tick driver

    private func advance(to timestamp: CFTimeInterval) {
        guard lastTimestamp != 0 else { lastTimestamp = timestamp; return }
        // Clamp delta so an app-resume can't deliver one huge step.
        let delta = min(Double(timestamp - lastTimestamp), 0.1)
        lastTimestamp = timestamp

        let before = viewModel.board
        let cell = targetedCell()
        viewModel.tick(delta: delta,
                       targetedCell: cell,
                       mouthOpen: faceTracker.mouthOpen ?? false)
        // Fire a haptic exactly when a mark lands (board changed this frame).
        if viewModel.board != before {
            impactHaptics.impactOccurred()
        }
    }

    /// The empty cell whose rect contains the mouth center, or nil.
    private func targetedCell() -> Int? {
        guard gridFrame.width > 0, let mc = faceTracker.mouthCenter else { return nil }
        guard gridFrame.contains(mc) else { return nil }
        let cellW = gridFrame.width / 3
        let cellH = gridFrame.height / 3
        let col = min(2, max(0, Int((mc.x - gridFrame.minX) / cellW)))
        let row = min(2, max(0, Int((mc.y - gridFrame.minY) / cellH)))
        let index = row * 3 + col
        return viewModel.board[index] == nil ? index : nil
    }

    // MARK: - Grid

    private var gridSide: CGFloat { isCompact ? 320 : 460 }

    private var gridLayer: some View {
        GeometryReader { geo in
            let side = min(gridSide, min(geo.size.width, geo.size.height) - 40)
            let origin = CGPoint(x: (geo.size.width - side) / 2,
                                 y: (geo.size.height - side) / 2)
            ZStack {
                ForEach(0..<9, id: \.self) { index in
                    cellView(index: index, side: side / 3)
                        .position(cellCenter(index: index, side: side, origin: origin))
                }
            }
            .onAppear { gridFrame = CGRect(origin: origin, size: CGSize(width: side, height: side)) }
            .onChange(of: geo.size) { _, _ in
                let s = min(gridSide, min(geo.size.width, geo.size.height) - 40)
                let o = CGPoint(x: (geo.size.width - s) / 2, y: (geo.size.height - s) / 2)
                gridFrame = CGRect(origin: o, size: CGSize(width: s, height: s))
            }
        }
        .ignoresSafeArea()
    }

    private func cellCenter(index: Int, side: CGFloat, origin: CGPoint) -> CGPoint {
        let cell = side / 3
        let col = CGFloat(index % 3)
        let row = CGFloat(index / 3)
        return CGPoint(x: origin.x + cell * (col + 0.5),
                       y: origin.y + cell * (row + 0.5))
    }

    private func cellView(index: Int, side: CGFloat) -> some View {
        let isPending = viewModel.pendingCell == index
        let isWinning = viewModel.winningLine?.contains(index) ?? false
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isPending ? 0.18 : 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isWinning ? Color.green : Color.white.opacity(0.5),
                                lineWidth: isWinning ? 4 : 2)
                )

            // Confirm ring grows with confirmProgress on the pending cell.
            if isPending {
                Circle()
                    .trim(from: 0, to: viewModel.confirmProgress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(side * 0.22)
            }

            if let mark = viewModel.board[index] {
                Text(mark.glyph)
                    .font(.system(size: side * 0.55, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: side - 8, height: side - 8)
    }

    // MARK: - Overlays

    private var turnIndicator: some View {
        VStack {
            Spacer()
            if !viewModel.isGameOver {
                let mark = viewModel.currentPlayer
                Text("\(mark.glyph)'s turn: open mouth to place")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, isCompact ? 28 : 44)
            }
        }
    }

    private var topBar: some View {
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
            }
            .padding(.horizontal, isCompact ? 16 : 40)
            .padding(.top, isCompact ? 12 : 20)
            Spacer()
        }
    }

    private var endCard: some View {
        VStack(spacing: isCompact ? 16 : 24) {
            Text(endTitle)
                .font(.system(size: isCompact ? 34 : 50, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: isCompact ? 12 : 16) {
                Button("Play again") {
                    withAnimation(.spring(duration: 0.3)) { viewModel.playAgain() }
                }
                .font(.title2.weight(.semibold))
                .padding(.horizontal, isCompact ? 20 : 32).padding(.vertical, 14)
                .background(.white).foregroundStyle(.black).clipShape(Capsule())

                Button("Games") {
                    withAnimation(.spring(duration: 0.3)) { onExit() }
                }
                .font(.title2.weight(.semibold))
                .padding(.horizontal, isCompact ? 20 : 32).padding(.vertical, 14)
                .background(.white.opacity(0.2)).foregroundStyle(.white).clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
            }
        }
        .padding(isCompact ? 24 : 40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var endTitle: String {
        if let w = viewModel.winner { return "\(w.glyph) wins!" }
        if viewModel.isDraw { return "It's a draw!" }
        return ""
    }
}

// MARK: - Display link (private copy; unique names per file)

private struct TTTDisplayLinkModifier: ViewModifier {
    let onFrame: (CFTimeInterval) -> Void
    func body(content: Content) -> some View {
        content.background(TTTDisplayLinkView(onFrame: onFrame))
    }
}

private struct TTTDisplayLinkView: UIViewRepresentable {
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
