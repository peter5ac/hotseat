import AVFoundation
import Observation

enum VocalGlideState: Equatable {
    case idle
    case countdown(Int)
    case playing
    case gameOver
}

struct GlideObstacle: Identifiable {
    let id = UUID()
    var xPosition: CGFloat      // 0 = left edge, 1 = right edge
    let gapCenter: CGFloat      // normalized Y (0 = top, 1 = bottom)
    let gapSize: CGFloat        // normalized height of the passable gap
    let isBarrier: Bool         // true = solid wall, must blast to pass
    var destroyed: Bool = false
}

@Observable
final class VocalGlideViewModel {
    // MARK: Published game state
    var gameState: VocalGlideState = .idle
    var characterYPosition: CGFloat = 0.5   // normalized 0...1
    var isBlasting: Bool = false
    var score: Int = 0

    var isGameOver: Bool { gameState == .gameOver }

    // MARK: Obstacle field
    var obstacles: [GlideObstacle] = []

    // MARK: Audio diagnostics
    var currentRMS: Float = 0
    var audioActive: Bool = false
    var pitchBarNormalized: CGFloat = 0  // 0 = silent, 1 = loud
    var blastCharge: CGFloat = 0         // 0 = silent, 1 = blast threshold
    var wallApproaching: Bool = false

    // MARK: Config
    private let bufferSize: AVAudioFrameCount = 1024
    private let gravityPerSecond: CGFloat = 0.28
    private let liftForce: CGFloat = 2.2
    private let voiceThreshold: Float = 0.01
    private let blastRMSThreshold: Float = 0.15
    private let blastCooldown: Double = 0.4
    private let maxVelocity: CGFloat = 1.5
    private let obstacleSpeed: CGFloat = 0.22       // normalized units per second
    private let spawnInterval: Double = 1.8
    private let characterX: CGFloat = 0.18          // fixed horizontal position
    private let hitboxRadius: CGFloat = 0.04

    // MARK: Internal state
    private var actualSampleRate: Double = 44100.0
    private var audioEngine: AVAudioEngine?
    var velocity: CGFloat = 0
    private var lastBlastTime: Double = 0
    private var timeSinceLastSpawn: Double = 0
    private var elapsedTime: Double = 0
    private var countdownTimer: Timer?

    // MARK: Lifecycle

    func startCountdown() {
        guard gameState == .idle || gameState == .gameOver else { return }
        resetGame()
        gameState = .countdown(3)
        var tick = 3
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            tick -= 1
            guard let self else { timer.invalidate(); return }
            if tick <= 0 {
                timer.invalidate()
                self.beginPlay()
            } else {
                self.gameState = .countdown(tick)
            }
        }
    }

    func stop() {
        teardownAudio()
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    // MARK: Frame update (called from TimelineView)

    private var lastFrameTime: CFTimeInterval = 0

    func update(timestamp: CFTimeInterval) {
        guard gameState == .playing else { return }
        if lastFrameTime == 0 {
            lastFrameTime = timestamp
            return
        }
        let dt = min(timestamp - lastFrameTime, 1.0 / 30.0)
        lastFrameTime = timestamp
        guard dt > 0 else { return }

        elapsedTime += dt
        applyPhysics(dt: dt)
        moveObstacles(dt: dt)
        spawnIfNeeded(dt: dt)
        checkCollisions()
        pruneOffscreen()
    }

    // MARK: Private — game logic

    private func resetGame() {
        characterYPosition = 0.5
        velocity = 0
        score = 0
        obstacles = []
        isBlasting = false
        elapsedTime = 0
        timeSinceLastSpawn = 0
        currentRMS = 0
        lastFrameTime = 0
    }

    private func beginPlay() {
        gameState = .playing
        setupAudio()
    }

    private func applyPhysics(dt: Double) {
        let cgDt = CGFloat(dt)
        let rms = currentRMS

        if rms > voiceThreshold {
            let normalized = min(CGFloat(rms - voiceThreshold) / 0.15, 1.0)
            pitchBarNormalized = normalized
            velocity = -liftForce * normalized
            blastCharge = min(CGFloat(rms / blastRMSThreshold), 1.0)
        } else {
            pitchBarNormalized = 0
            blastCharge = 0
            velocity = gravityPerSecond
        }

        characterYPosition += velocity * cgDt
        characterYPosition = min(max(characterYPosition, 0.02), 0.98)

        // Blast decay
        if isBlasting && (elapsedTime - lastBlastTime) > blastCooldown {
            isBlasting = false
        }

        // Detect approaching barrier
        wallApproaching = obstacles.contains { $0.isBarrier && !$0.destroyed && $0.xPosition > characterX && $0.xPosition < 0.55 }
    }

    private func moveObstacles(dt: Double) {
        let dx = obstacleSpeed * CGFloat(dt)
        for i in obstacles.indices {
            obstacles[i].xPosition -= dx
        }
    }

    private func spawnIfNeeded(dt: Double) {
        timeSinceLastSpawn += dt
        let adjustedInterval = max(spawnInterval - elapsedTime * 0.01, 1.0)
        guard timeSinceLastSpawn >= adjustedInterval else { return }
        timeSinceLastSpawn = 0

        let isBarrier = Int.random(in: 0..<5) == 0
        let gapCenter = CGFloat.random(in: 0.25...0.75)
        let gapSize: CGFloat = isBarrier ? 0 : CGFloat.random(in: 0.18...0.30)

        let obstacle = GlideObstacle(
            xPosition: 1.3,
            gapCenter: gapCenter,
            gapSize: gapSize,
            isBarrier: isBarrier
        )
        obstacles.append(obstacle)
    }

    private func checkCollisions() {
        for i in obstacles.indices {
            guard !obstacles[i].destroyed else { continue }
            let ox = obstacles[i].xPosition
            guard abs(ox - characterX) < hitboxRadius else { continue }

            if obstacles[i].isBarrier {
                if isBlasting {
                    obstacles[i].destroyed = true
                    score += 3
                } else {
                    endGame()
                    return
                }
            } else {
                let gap = obstacles[i].gapCenter
                let halfGap = obstacles[i].gapSize / 2
                let inGap = characterYPosition > (gap - halfGap) && characterYPosition < (gap + halfGap)
                if !inGap {
                    endGame()
                    return
                }
            }
        }

        // Score for passing obstacles
        for i in obstacles.indices where !obstacles[i].destroyed {
            let ox = obstacles[i].xPosition
            if ox < characterX - hitboxRadius && ox > characterX - hitboxRadius - obstacleSpeed * 0.02 {
                score += 1
            }
        }
    }

    private func pruneOffscreen() {
        obstacles.removeAll { $0.xPosition < -0.1 }
    }

    private func endGame() {
        gameState = .gameOver
        teardownAudio()
    }

    // MARK: Audio engine

    private func setupAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            return
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // After activating the session, read the actual hardware format
        let hwFormat = inputNode.outputFormat(forBus: 0)
        guard hwFormat.sampleRate > 0, hwFormat.channelCount > 0 else { return }
        actualSampleRate = hwFormat.sampleRate

        // Pass nil format — AVAudioEngine delivers float32 PCM in whatever
        // channel/rate the hardware is configured for. This avoids format
        // mismatch crashes when the camera session has already configured audio.
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: nil) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        do {
            try engine.start()
            self.audioEngine = engine
            self.audioActive = true
        } catch {
            inputNode.removeTap(onBus: 0)
            return
        }
    }

    private func teardownAudio() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        // RMS from first channel — nil format tap always delivers float32
        guard let floatData = buffer.floatChannelData else { return }
        let channelData = floatData[0]

        var sumSquares: Float = 0
        for i in 0..<frameCount {
            sumSquares += channelData[i] * channelData[i]
        }
        let rms = sqrtf(sumSquares / Float(frameCount))

        DispatchQueue.main.async { [weak self] in
            guard let self, self.gameState == .playing else { return }
            self.currentRMS = rms

            if rms > self.blastRMSThreshold && (self.elapsedTime - self.lastBlastTime) > self.blastCooldown {
                self.isBlasting = true
                self.lastBlastTime = self.elapsedTime
            }
        }
    }
}
