import SwiftUI

struct ChoiceScenario: Identifiable {
    let id = UUID()
    let leftOption: String
    let rightOption: String
    let category: String
}

enum ChoiceGatePhase {
    case idle
    case processingChoice
    case transitioning
}

enum ChosenSide {
    case left
    case right
}

@Observable
final class ChoiceGateViewModel {
    // MARK: - Config
    private let rollThreshold: CGFloat = 0.26  // ~15 degrees in radians
    private let transitionDuration: CGFloat = 0.6
    private let passPhoneInterval = 5

    // MARK: - Public state
    var currentScenario: ChoiceScenario?
    var scenariosPlayed: Int = 0
    var isAnimatingTransition: Bool = false
    var phase: ChoiceGatePhase = .idle
    var chosenSide: ChosenSide?
    var showPassPhone: Bool = false

    // MARK: - Private
    private var scenarios: [ChoiceScenario] = []
    private var scenarioIndex: Int = 0
    private var transitionTimer: CGFloat = 0

    // MARK: - Lifecycle

    func startGame() {
        scenarios = Self.allScenarios.shuffled()
        scenarioIndex = 0
        scenariosPlayed = 0
        showPassPhone = false
        chosenSide = nil
        phase = .idle
        isAnimatingTransition = false
        currentScenario = scenarios.first
    }

    func reset() {
        startGame()
    }

    // MARK: - Input

    func updateRoll(_ roll: CGFloat?) {
        guard let roll, phase == .idle, !showPassPhone else { return }

        if roll < -rollThreshold {
            registerChoice(.right)
        } else if roll > rollThreshold {
            registerChoice(.left)
        }
    }

    // MARK: - Frame tick

    func tick(delta: CGFloat) {
        guard phase == .transitioning else { return }
        transitionTimer += delta
        if transitionTimer >= transitionDuration {
            advanceToNext()
        }
    }

    // MARK: - Pass phone

    func dismissPassPhone() {
        showPassPhone = false
        phase = .idle
    }

    // MARK: - Private

    private func registerChoice(_ side: ChosenSide) {
        phase = .processingChoice
        chosenSide = side
        isAnimatingTransition = true
        transitionTimer = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.phase = .transitioning
        }
    }

    private func advanceToNext() {
        scenariosPlayed += 1
        scenarioIndex += 1

        if scenarioIndex >= scenarios.count {
            scenarios.shuffle()
            scenarioIndex = 0
        }

        isAnimatingTransition = false
        chosenSide = nil
        currentScenario = scenarios[scenarioIndex]

        if scenariosPlayed > 0 && scenariosPlayed % passPhoneInterval == 0 {
            showPassPhone = true
            phase = .idle
        } else {
            phase = .idle
        }
    }

    // MARK: - Scenario Data

    static let allScenarios: [ChoiceScenario] = {
        var s: [ChoiceScenario] = []

        // Gaming (8)
        let gaming = "Gaming"
        s.append(ChoiceScenario(leftOption: "Uncapped 360 FPS but 720p resolution", rightOption: "Locked 60 FPS but beautiful 4K graphics", category: gaming))
        s.append(ChoiceScenario(leftOption: "Be the best player in the world at a dead game nobody plays", rightOption: "Be permanently average at every popular game", category: gaming))
        s.append(ChoiceScenario(leftOption: "Live inside Minecraft for a year", rightOption: "Live inside Fortnite for a year", category: gaming))
        s.append(ChoiceScenario(leftOption: "Infinite V-Bucks but you can only play solo", rightOption: "Zero skins forever but you always squad up with your best friends", category: gaming))
        s.append(ChoiceScenario(leftOption: "Play every game a week early but you can never stream or post clips", rightOption: "Always wait an extra month after release but your clips always go viral", category: gaming))
        s.append(ChoiceScenario(leftOption: "God-tier aim but 300ms ping forever", rightOption: "Terrible aim but zero ping on every server", category: gaming))
        s.append(ChoiceScenario(leftOption: "Only play mobile games for the rest of your life", rightOption: "Only play one console game that never gets an update", category: gaming))
        s.append(ChoiceScenario(leftOption: "Win every 1v1 but lose every team game", rightOption: "Lose every 1v1 but your team always wins", category: gaming))

        // Social Dilemma (7)
        let social = "Social Dilemma"
        s.append(ChoiceScenario(leftOption: "Be famous on the internet but everyone hates you", rightOption: "Be completely unknown but universally loved by everyone you meet", category: social))
        s.append(ChoiceScenario(leftOption: "Only communicate through memes for an entire week", rightOption: "Only communicate through voice notes for an entire month", category: social))
        s.append(ChoiceScenario(leftOption: "Accidentally like your crush's photo from 3 years ago", rightOption: "Send a text meant for your best friend to your teacher", category: social))
        s.append(ChoiceScenario(leftOption: "Have 10 million followers but zero real friends", rightOption: "Have 3 ride-or-die friends but zero social media presence", category: social))
        s.append(ChoiceScenario(leftOption: "Everyone can see your screen at all times", rightOption: "You can never use your phone around other people", category: social))
        s.append(ChoiceScenario(leftOption: "Your group chat gets leaked to the whole school", rightOption: "You get kicked from every group chat permanently", category: social))
        s.append(ChoiceScenario(leftOption: "Always say exactly what you're thinking out loud", rightOption: "Never be able to express your real opinion", category: social))

        // Tech Overload (8)
        let tech = "Tech Overload"
        s.append(ChoiceScenario(leftOption: "Your phone is permanently stuck at 1% battery", rightOption: "Your phone has infinite battery but a permanently cracked screen", category: tech))
        s.append(ChoiceScenario(leftOption: "Have the world's fastest internet but can only use one app", rightOption: "Have normal internet but unlimited access to every paid app and game for free", category: tech))
        s.append(ChoiceScenario(leftOption: "Every photo you take is automatically posted with no filter", rightOption: "You can never take another photo but your memory becomes photographic", category: tech))
        s.append(ChoiceScenario(leftOption: "Your phone autocorrects every word to something embarrassing", rightOption: "Your phone reads every text out loud through the speaker", category: tech))
        s.append(ChoiceScenario(leftOption: "Unlimited storage but your phone is always on speaker mode", rightOption: "256GB max but your phone never makes a sound", category: tech))
        s.append(ChoiceScenario(leftOption: "Have the newest phone on day one every year but it's always the wrong color", rightOption: "Keep the same phone for 5 years but it's your dream custom build", category: tech))
        s.append(ChoiceScenario(leftOption: "Wi-Fi that works perfectly but only between 3 AM and 6 AM", rightOption: "Wi-Fi that's always connected but drops for 10 seconds every minute", category: tech))
        s.append(ChoiceScenario(leftOption: "Only use dark mode for the rest of your life", rightOption: "Only use light mode at full brightness forever", category: tech))

        // School Life (8)
        let school = "School Life"
        s.append(ChoiceScenario(leftOption: "Never have to do homework again but take an exam every Friday", rightOption: "Do 30 minutes of homework every day but never take another test", category: school))
        s.append(ChoiceScenario(leftOption: "Your teacher reads your last 10 texts out loud to the class", rightOption: "Your search history gets posted on the school bulletin board for one day", category: school))
        s.append(ChoiceScenario(leftOption: "Have school start at noon but end at 8 PM", rightOption: "Have school start at 6 AM but be done by 11 AM", category: school))
        s.append(ChoiceScenario(leftOption: "Sit next to your best friend but it's the hardest class", rightOption: "Sit alone but the class is an easy A", category: school))
        s.append(ChoiceScenario(leftOption: "Have a locker that's a portal to your room but school is 12 hours", rightOption: "Normal locker but school is only 3 hours a day", category: school))
        s.append(ChoiceScenario(leftOption: "Be class president but everyone gives you their problems", rightOption: "Be invisible at school but totally stress-free", category: school))
        s.append(ChoiceScenario(leftOption: "Wear pajamas to school every day but get called on first every class", rightOption: "Wear a uniform but the teacher never picks you", category: school))
        s.append(ChoiceScenario(leftOption: "Perfect grades but you forget everything after the test", rightOption: "Average grades but you remember everything you learn forever", category: school))

        // Superpowers (8)
        let powers = "Superpowers"
        s.append(ChoiceScenario(leftOption: "Can read minds but only when someone is thinking something negative about you", rightOption: "Can become invisible but only when you are screaming at the top of your lungs", category: powers))
        s.append(ChoiceScenario(leftOption: "Fly but only 2 feet off the ground", rightOption: "Teleport but you always arrive 10 minutes late", category: powers))
        s.append(ChoiceScenario(leftOption: "Be able to talk to animals but they are all rude", rightOption: "Be able to talk to plants but they never shut up", category: powers))
        s.append(ChoiceScenario(leftOption: "Super strength but only in your pinky finger", rightOption: "Super speed but only when you're walking backwards", category: powers))
        s.append(ChoiceScenario(leftOption: "Breathe underwater but you smell like fish forever", rightOption: "Survive in space but you float slightly off the ground at all times", category: powers))
        s.append(ChoiceScenario(leftOption: "Pause time but you age while it's paused", rightOption: "Rewind time 10 seconds but it costs an hour of sleep", category: powers))
        s.append(ChoiceScenario(leftOption: "Shapeshift into any animal but you can't pick which one", rightOption: "Turn into one specific animal whenever you want", category: powers))
        s.append(ChoiceScenario(leftOption: "Control fire but you're always freezing cold", rightOption: "Control ice but you're always overheating", category: powers))

        // Pop Culture (7)
        let pop = "Pop Culture"
        s.append(ChoiceScenario(leftOption: "Spend 24 hours locked in a room with your favorite streamer", rightOption: "Get a free lifetime pass to front-row seats for any concert or festival", category: pop))
        s.append(ChoiceScenario(leftOption: "Your favorite artist writes a song about you but it's embarrassing", rightOption: "You write a hit song but nobody knows it was you", category: pop))
        s.append(ChoiceScenario(leftOption: "Star in a Marvel movie but you're the villain everyone hates", rightOption: "Be an extra in every Marvel movie for the next 10 years", category: pop))
        s.append(ChoiceScenario(leftOption: "Only listen to one song on repeat forever", rightOption: "Listen to any music but never the same song twice", category: pop))
        s.append(ChoiceScenario(leftOption: "Be best friends with a fictional character who only you can see", rightOption: "Be acquaintances with every celebrity but none of them remember you", category: pop))
        s.append(ChoiceScenario(leftOption: "Get a role in your favorite TV show but it gets cancelled after your episode", rightOption: "Never appear on screen but you write the most popular show of the decade", category: pop))
        s.append(ChoiceScenario(leftOption: "Your life has a soundtrack everyone can hear", rightOption: "Your life has subtitles that display your thoughts above your head", category: pop))

        // Food (8)
        let food = "Food"
        s.append(ChoiceScenario(leftOption: "Cereal", rightOption: "Pop-Tarts", category: food))
        s.append(ChoiceScenario(leftOption: "Pizza", rightOption: "Hamburger", category: food))
        s.append(ChoiceScenario(leftOption: "Popcorn", rightOption: "Cotton candy", category: food))
        s.append(ChoiceScenario(leftOption: "Tacos", rightOption: "Chicken nuggets", category: food))
        s.append(ChoiceScenario(leftOption: "Ice cream", rightOption: "Brownies", category: food))
        s.append(ChoiceScenario(leftOption: "Fries", rightOption: "Onion rings", category: food))
        s.append(ChoiceScenario(leftOption: "Sushi", rightOption: "Mac and cheese", category: food))
        s.append(ChoiceScenario(leftOption: "Pancakes", rightOption: "Waffles", category: food))

        // Famous Duos (10)
        let duos = "Famous Duos"
        s.append(ChoiceScenario(leftOption: "Tom", rightOption: "Jerry", category: duos))
        s.append(ChoiceScenario(leftOption: "Key", rightOption: "Peele", category: duos))
        s.append(ChoiceScenario(leftOption: "Matt Damon", rightOption: "Ben Affleck", category: duos))
        s.append(ChoiceScenario(leftOption: "Mario", rightOption: "Luigi", category: duos))
        s.append(ChoiceScenario(leftOption: "SpongeBob", rightOption: "Patrick", category: duos))
        s.append(ChoiceScenario(leftOption: "Batman", rightOption: "Robin", category: duos))
        s.append(ChoiceScenario(leftOption: "Woody", rightOption: "Buzz Lightyear", category: duos))
        s.append(ChoiceScenario(leftOption: "Drake", rightOption: "Josh", category: duos))
        s.append(ChoiceScenario(leftOption: "Phineas", rightOption: "Ferb", category: duos))
        s.append(ChoiceScenario(leftOption: "Shrek", rightOption: "Donkey", category: duos))

        return s
    }()
}
