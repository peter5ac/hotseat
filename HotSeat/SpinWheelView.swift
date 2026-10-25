import SwiftUI

struct WheelItem: Identifiable {
    let id: String
    let label: String
    let emoji: String?
}

struct SpinWheelView: View {
    let items: [WheelItem]
    let onLanded: (WheelItem) -> Void
    let onCancel: () -> Void
    /// When true, the wheel starts spinning on its own as soon as it appears,
    /// skipping the manual "Spin!" tap.
    var autoSpin: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Spin state
    @State private var rotation: Double = 0          // pie wheel, degrees
    @State private var reelOffset: CGFloat = 0       // slot reel, points
    @State private var isSpinning = false
    @State private var landedIndex: Int? = nil
    @State private var audio = WheelAudio()

    private let spinDuration: Double = 2.75
    private let holdDuration: Double = 1.0
    private let rowHeight: CGFloat = 64
    private let reelFullPasses = 4
    private let reelRepeats = 6

    private var isReel: Bool { items.count >= 10 }

    private let sliceColors: [Color] = [
        Color(red: 1.00, green: 0.42, blue: 0.42),
        Color(red: 1.00, green: 0.79, blue: 0.34),
        Color(red: 0.28, green: 0.86, blue: 0.98),
        Color(red: 0.11, green: 0.82, blue: 0.63),
        Color(red: 0.37, green: 0.15, blue: 0.80),
        Color(red: 1.00, green: 0.62, blue: 0.95),
        Color(red: 0.33, green: 0.63, blue: 1.00),
        Color(red: 0.55, green: 0.91, blue: 0.45)
    ]

    var body: some View {
        ZStack {
            // Scrim — tappable to cancel only when allowed
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { cancelIfAllowed() }

            VStack(spacing: 28) {
                HStack {
                    Spacer()
                    Button {
                        cancelIfAllowed()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .disabled(isSpinning)
                    .opacity(isSpinning ? 0.3 : 1.0)
                }
                .padding(.horizontal, 24)

                if items.isEmpty {
                    Text("Nothing to spin")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                } else if isReel {
                    reelView
                } else {
                    pieView
                }

                Button {
                    spin()
                } label: {
                    Text(isSpinning ? "Spinning…" : "Spin!")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 44)
                        .padding(.vertical, 16)
                        .background(.white, in: Capsule())
                }
                .disabled(isSpinning || items.isEmpty)
                .opacity(isSpinning ? 0.5 : 1.0)
                .scaleEffect(isSpinning ? 0.97 : 1.0)
            }
            .padding(.vertical, 40)
        }
        .onAppear {
            audio.start()
            if autoSpin {
                // Let the view settle a frame before kicking off the animation.
                DispatchQueue.main.async { spin() }
            }
        }
        .onDisappear { audio.stop() }
    }

    // MARK: - Pie wheel (<10 items)

    private var pieView: some View {
        ZStack {
            // Pointer
            Triangle()
                .fill(.white)
                .frame(width: 26, height: 20)
                .offset(y: -200)
                .zIndex(2)

            ZStack {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    PieSlice(index: index, total: items.count)
                        .fill(sliceColors[index % sliceColors.count])
                    sliceLabel(item, index: index)
                }
            }
            .frame(width: 380, height: 380)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 4))
            .rotationEffect(.degrees(rotation))
            .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
        }
        .frame(height: 420)
    }

    private func sliceLabel(_ item: WheelItem, index: Int) -> some View {
        let sliceAngle = 360.0 / Double(items.count)
        let mid = sliceAngle * (Double(index) + 0.5)
        let chars = Array(item.label)
        let fontSize: CGFloat = items.count <= 4 ? 16 : 13
        let charSpacing: CGFloat = items.count <= 4 ? 1 : -1
        let radius: Double = items.count <= 4 ? 100 : 90
        return VStack(spacing: charSpacing) {
            if let emoji = item.emoji {
                Text(emoji).font(.system(size: fontSize))
            }
            ForEach(Array(chars.enumerated()), id: \.offset) { _, char in
                if char == " " {
                    Spacer().frame(height: 4)
                } else {
                    Text(String(char))
                        .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                }
            }
        }
        .foregroundStyle(.white)
        .rotationEffect(.degrees(mid))
        .offset(x: radius * cos((mid - 90) * .pi / 180),
                y: radius * sin((mid - 90) * .pi / 180))
    }

    // MARK: - Slot reel (>=10 items)

    private var reelRows: [(index: Int, item: WheelItem)] {
        guard !items.isEmpty else { return [] }
        return (0..<(items.count * reelRepeats)).map { i in (i, items[i % items.count]) }
    }

    private var reelView: some View {
        VStack(spacing: 0) {
            ForEach(reelRows, id: \.index) { row in
                Text("\(row.item.emoji ?? "") \(row.item.label)")
                    .font(.title3.weight(landedIndex == row.index ? .bold : .semibold))
                    .foregroundStyle(landedIndex == row.index ? .white : .white.opacity(0.55))
                    .frame(height: rowHeight)
                    .frame(maxWidth: .infinity)
            }
        }
        .offset(y: reelOffset)
        .frame(height: rowHeight * 5, alignment: .top)
        .clipped()
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white, lineWidth: 3)
                .frame(height: rowHeight)
        )
        .padding(.horizontal, 24)
    }

    // MARK: - Spin logic

    private func spin() {
        guard !isSpinning, !items.isEmpty else { return }
        let winner = Int.random(in: 0..<items.count)
        isSpinning = true
        landedIndex = nil

        if reduceMotion {
            if isReel {
                reelOffset = -CGFloat(winner) * rowHeight + rowHeight * 2
                landedIndex = winner
            } else {
                let sliceAngle = 360.0 / Double(items.count)
                rotation = -(sliceAngle * (Double(winner) + 0.5))
            }
            audio.playDing()
            DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) {
                finish(winner)
            }
            return
        }

        let reelLandingIndex = items.count * reelFullPasses + winner

        if isReel {
            let target = -CGFloat(reelLandingIndex) * rowHeight + rowHeight * 2
            withAnimation(.easeOut(duration: spinDuration)) {
                reelOffset = target
            }
        } else {
            let sliceAngle = 360.0 / Double(items.count)
            let landing = 360.0 * 5 - (sliceAngle * (Double(winner) + 0.5))
            withAnimation(.easeOut(duration: spinDuration)) {
                rotation = landing
            }
        }

        // Schedule decelerating ticks
        let tickCount: Int
        if isReel {
            tickCount = reelLandingIndex
        } else {
            tickCount = items.count * 5
        }
        var lastTickTime: Double = -1
        let minInterval: Double = 0.045
        for k in 1...tickCount {
            let fraction = Double(k) / Double(tickCount)
            let t = spinDuration * (1.0 - pow(1.0 - fraction, 1.0 / 3.0))
            if t - lastTickTime < minInterval { continue }
            lastTickTime = t
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { [audio] in
                audio.playTick()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration) { [audio] in
            audio.playDing()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration) {
            landedIndex = isReel ? reelLandingIndex : winner
            DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) {
                finish(winner)
            }
        }
    }

    private func finish(_ index: Int) {
        guard index < items.count else { return }
        isSpinning = false
        onLanded(items[index])
    }

    private func cancelIfAllowed() {
        guard !isSpinning else { return }
        onCancel()
    }
}

// MARK: - Shapes

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

private struct PieSlice: Shape {
    let index: Int
    let total: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let sliceAngle = 360.0 / Double(total)
        let start = Angle.degrees(sliceAngle * Double(index) - 90)
        let end = Angle.degrees(sliceAngle * Double(index + 1) - 90)
        var p = Path()
        p.move(to: center)
        p.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}

#Preview("Pie (3)") {
    SpinWheelView(
        items: [
            WheelItem(id: "a", label: "Hot Take", emoji: "🏆"),
            WheelItem(id: "b", label: "Game Two", emoji: "✨"),
            WheelItem(id: "c", label: "Game Three", emoji: "🎉")
        ],
        onLanded: { _ in },
        onCancel: {}
    )
}

#Preview("Reel (12)") {
    SpinWheelView(
        items: (1...12).map { WheelItem(id: "\($0)", label: "Category \($0)", emoji: "🎲") },
        onLanded: { _ in },
        onCancel: {}
    )
}
