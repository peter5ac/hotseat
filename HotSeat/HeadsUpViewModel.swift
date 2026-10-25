import Foundation

enum HeadsUpState: Equatable {
    case categoryPicker
    case readying
    case countdown
    case playing
    case recap
}

enum FlashKind: Equatable {
    case none
    case correct
    case pass
}

@Observable
final class HeadsUpViewModel {
    static let roundDuration: Double = 90

    // Thresholds in degrees, relative to the captured neutral. Tuned on-device.
    // triggerDelta must stay comfortably above neutralBand to give the
    // neutral-reset hysteresis enough margin to avoid double-firing on jitter.
    private let triggerDelta: Double = 45
    private let neutralBand: Double = 18

    // How long the CORRECT/PASS flash stays up before auto-clearing, in seconds.
    // Decoupled from motion so the next item appears immediately on a mark
    // instead of waiting for the phone to return to neutral.
    private let flashDuration: Double = 0.45

    var state: HeadsUpState = .categoryPicker
    var currentCategory: HeadsUpCategory?
    var currentItem: String?
    var guessed: [String] = []
    var missed: [String] = []
    var timeRemaining: Double = roundDuration
    var countdownValue: Int = 3
    var flash: FlashKind = .none

    var isFinalSeconds: Bool {
        state == .playing && timeRemaining <= 10
    }

    var totalGuessed: Int { guessed.count }

    private var deck: [String] = []
    private var deckIndex: Int = 0
    private var awaitingNeutral: Bool = false
    private var countdownAccumulator: Double = 0
    private var flashRemaining: Double = 0
    // True while a flash is up and the next item is waiting to load. The advance
    // is deferred until the flash clears so the word and the CORRECT/PASS banner
    // never render at the same time.
    private var pendingAdvance: Bool = false

    // MARK: Picker

    func selectCategory(_ category: HeadsUpCategory) {
        currentCategory = category
        state = .readying
    }

    func backToPicker() {
        state = .categoryPicker
        currentCategory = nil
        resetRoundState()
    }

    // MARK: Readying → countdown

    /// Called by the view once the phone has been held in the neutral band in
    /// landscape for the required dwell time.
    func beginCountdown() {
        guard state == .readying else { return }
        countdownValue = 3
        countdownAccumulator = 0
        state = .countdown
    }

    /// Advance the 3-2-1 countdown. Returns nothing; transitions to playing at 0.
    func tickCountdown(delta: Double) {
        guard state == .countdown else { return }
        countdownAccumulator += delta
        if countdownAccumulator >= 1.0 {
            countdownAccumulator -= 1.0
            countdownValue -= 1
            if countdownValue <= 0 {
                startPlaying()
            }
        }
    }

    // MARK: Playing

    func startPlaying() {
        guard let category = currentCategory else { return }
        deck = category.items.shuffled()
        deckIndex = 0
        guessed = []
        missed = []
        timeRemaining = Self.roundDuration
        awaitingNeutral = false
        flash = .none
        flashRemaining = 0
        pendingAdvance = false
        currentItem = deck.first
        state = .playing
    }

    /// Advance the round clock and the flash auto-clear timer. Ends the round at 0.
    func tickPlaying(delta: Double) {
        guard state == .playing else { return }

        // Auto-clear the CORRECT/PASS flash after a fixed time, independent of
        // how long the phone stays tilted. The next item is loaded only once the
        // flash clears, so the banner and the word never overlap.
        if flashRemaining > 0 {
            flashRemaining = max(0, flashRemaining - delta)
            if flashRemaining == 0 {
                flash = .none
                if pendingAdvance {
                    pendingAdvance = false
                    advanceDeck()
                }
            }
        }

        timeRemaining = max(0, timeRemaining - delta)
        if timeRemaining <= 0 {
            endRound()
        }
    }

    /// Pure motion entry point. `pitch` and `neutral` are degrees; `neutral` is
    /// the pitch captured when the countdown finished. Marks correct (tilt up)
    /// or pass (tilt down) with neutral-reset locking.
    func registerPitch(_ pitch: Double, neutral: Double) {
        guard state == .playing else { return }
        // Normalize into [-180, 180] so a neutral captured near ±180° (the phone
        // can rest at either of two forehead orientations) produces a sane signed
        // offset instead of a ~360° jump.
        var offset = pitch - neutral
        if offset > 180 { offset -= 360 }
        if offset < -180 { offset += 360 }

        if awaitingNeutral {
            // The phone must return roughly level before another tilt can fire,
            // so one tilt can't burn multiple items.
            if abs(offset) <= neutralBand {
                awaitingNeutral = false
            }
            return
        }

        if offset >= triggerDelta {
            // Tilt up = pass.
            markCurrent(correct: false)
        } else if offset <= -triggerDelta {
            // Tilt down = correct.
            markCurrent(correct: true)
        }
    }

    private func markCurrent(correct: Bool) {
        guard let item = currentItem else { return }
        if correct {
            guessed.append(item)
            flash = .correct
        } else {
            missed.append(item)
            flash = .pass
        }
        // Clear the word so only the CORRECT/PASS banner shows, then load the
        // next item once the flash timer expires (see tickPlaying).
        currentItem = nil
        flashRemaining = flashDuration
        pendingAdvance = true
        awaitingNeutral = true
    }

    private func advanceDeck() {
        deckIndex += 1
        if deckIndex >= deck.count {
            endRound()   // got through the whole deck
            return
        }
        currentItem = deck[deckIndex]
    }

    private func endRound() {
        currentItem = nil
        flash = .none
        state = .recap
    }

    // MARK: Recap actions

    func playAgain() {
        guard currentCategory != nil else { return }
        // Re-enter readying so the player re-seats the phone and re-calibrates.
        resetRoundState()
        state = .readying
    }

    private func resetRoundState() {
        deck = []
        deckIndex = 0
        guessed = []
        missed = []
        timeRemaining = Self.roundDuration
        countdownValue = 3
        awaitingNeutral = false
        flash = .none
        flashRemaining = 0
        pendingAdvance = false
        currentItem = nil
    }
}
