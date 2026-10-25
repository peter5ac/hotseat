import SwiftUI

struct Game: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let icon: String?
    let isAvailable: Bool
}

let allGames: [Game] = [
    Game(id: "hotTake", name: "Hot Take", emoji: "\u{1F3C6}", icon: "HotTakeIcon", isAvailable: true),
    Game(id: "speedTap", name: "Speed Tap", emoji: "\u{26A1}", icon: nil, isAvailable: true),
    Game(id: "laneDodge", name: "Lane Dodge", emoji: "\u{1F697}", icon: nil, isAvailable: true),
    Game(id: "tugOfWar", name: "Tug-of-War", emoji: "\u{1FAA2}", icon: nil, isAvailable: true),
    Game(id: "headsUp", name: "Heads Up", emoji: "\u{1F9E0}", icon: nil, isAvailable: true),
    Game(id: "ticTacToe", name: "Tic Tac Toe", emoji: "#", icon: nil, isAvailable: true),
    Game(id: "simon", name: "Simon", emoji: "🎨", icon: nil, isAvailable: true),
    Game(id: "laserEyes", name: "Laser Eyes", emoji: "👀", icon: nil, isAvailable: true),
    Game(id: "chocolateRain", name: "Chocolate Rain", emoji: "🍫", icon: nil, isAvailable: true),
    Game(id: "vocalGlide", name: "Pig Flight", emoji: "🐷", icon: nil, isAvailable: true),
    Game(id: "choiceGate", name: "This or That", emoji: "⚖️", icon: nil, isAvailable: true),
    Game(id: "ultimateTTT", name: "Ultimate TTT", emoji: "#️⃣", icon: nil, isAvailable: true),
]

struct HomeView: View {
    let onSelectRank: () -> Void
    let onSelectSpeedTap: () -> Void
    let onSelectLaneDodge: () -> Void
    let onSelectTugOfWar: () -> Void
    let onSelectHeadsUp: () -> Void
    let onSelectTicTacToe: () -> Void
    let onSelectSimon: () -> Void
    let onSelectLaserEyes: () -> Void
    let onSelectChocolateRain: () -> Void
    let onSelectVocalGlide: () -> Void
    let onSelectChoiceGate: () -> Void
    let onSelectUltimateTTT: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingGameWheel = false

    private var availableGames: [Game] {
        allGames.filter { $0.isAvailable }
    }

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var columns: [GridItem] {
        if isCompact {
            return [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]
        } else {
            return [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
        }
    }

    @State private var showingBuildInfo = false

    private var buildTimestamp: String {
        let date = Date(timeIntervalSince1970: TimeInterval(BuildTimestamp.epoch))
        let fmt = DateFormatter()
        fmt.dateFormat = "dd/MM/yy HH:mm:ss"
        return fmt.string(from: date)
    }

    var body: some View {
        VStack(spacing: isCompact ? 16 : 24) {
            if !showingGameWheel {
                Text("Pick a game")
                    .font(.system(size: isCompact ? 32 : 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, isCompact ? 24 : 40)

                if availableGames.count >= 2 {
                    Button {
                        showingGameWheel = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("🎲")
                            Text("Spin for me")
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                    }
                }

                ScrollView {
                    LazyVGrid(columns: columns, spacing: isCompact ? 12 : 16) {
                        ForEach(allGames) { game in
                            gameTile(game)
                        }
                    }
                    .padding(.horizontal, isCompact ? 16 : 40)
                    .padding(.bottom, 40)

                    HStack {
                        Spacer()
                        Button {
                            showingBuildInfo.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .popover(isPresented: $showingBuildInfo) {
                            Text("Built: \(buildTimestamp)")
                                .font(.caption.monospaced())
                                .padding(12)
                                .presentationCompactAdaptation(.popover)
                        }
                    }
                    .padding(.horizontal, isCompact ? 16 : 40)
                    .padding(.bottom, 16)
                }
            }
        }
        .overlay {
            if showingGameWheel {
                SpinWheelView(
                    items: availableGames.map {
                        WheelItem(id: $0.id, label: $0.name, emoji: $0.emoji)
                    },
                    onLanded: { landed in
                        showingGameWheel = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.spring(duration: 0.3)) {
                                switch landed.id {
                                case "hotTake":
                                    onSelectRank()
                                case "speedTap":
                                    onSelectSpeedTap()
                                case "laneDodge":
                                    onSelectLaneDodge()
                                case "tugOfWar":
                                    onSelectTugOfWar()
                                case "headsUp":
                                    onSelectHeadsUp()
                                case "ticTacToe":
                                    onSelectTicTacToe()
                                case "simon":
                                    onSelectSimon()
                                case "laserEyes":
                                    onSelectLaserEyes()
                                case "chocolateRain":
                                    onSelectChocolateRain()
                                case "vocalGlide":
                                    onSelectVocalGlide()
                                case "choiceGate":
                                    onSelectChoiceGate()
                                case "ultimateTTT":
                                    onSelectUltimateTTT()
                                default:
                                    break
                                }
                            }
                        }
                    },
                    onCancel: {
                        showingGameWheel = false
                    }
                )
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func gameTile(_ game: Game) -> some View {
        Button {
            guard game.isAvailable else { return }
            withAnimation(.spring(duration: 0.3)) {
                switch game.id {
                case "hotTake":
                    onSelectRank()
                case "speedTap":
                    onSelectSpeedTap()
                case "laneDodge":
                    onSelectLaneDodge()
                case "tugOfWar":
                    onSelectTugOfWar()
                case "headsUp":
                    onSelectHeadsUp()
                case "ticTacToe":
                    onSelectTicTacToe()
                case "simon":
                    onSelectSimon()
                case "laserEyes":
                    onSelectLaserEyes()
                case "chocolateRain":
                    onSelectChocolateRain()
                case "vocalGlide":
                    onSelectVocalGlide()
                case "choiceGate":
                    onSelectChoiceGate()
                case "ultimateTTT":
                    onSelectUltimateTTT()
                default:
                    break
                }
            }
        } label: {
            VStack(spacing: 8) {
                if let icon = game.icon {
                    Image(icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: isCompact ? 44 : 56, height: isCompact ? 44 : 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Text(game.emoji)
                        .font(.system(size: isCompact ? 40 : 52))
                }
                Text(game.name)
                    .font(isCompact ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if !game.isAvailable {
                    Text("SOON")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.white.opacity(0.15)))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isCompact ? 24 : 36)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .opacity(game.isAvailable ? 1.0 : 0.4)
        }
        .disabled(!game.isAvailable)
    }
}
