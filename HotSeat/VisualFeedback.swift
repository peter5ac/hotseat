import SwiftUI
import UIKit
import AVFoundation

struct LaserHaptics {
    private static let impact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let success = UINotificationFeedbackGenerator()

    static func hit() {
        impact.impactOccurred()
        impact.prepare()
    }

    static func destroyed() {
        heavy.impactOccurred(intensity: 1.0)
        success.notificationOccurred(.success)
        heavy.prepare()
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var color: Color
    var scale: CGFloat = 1.0
    var opacity: Double = 1.0
    var lifetime: TimeInterval = 0
    let maxLifetime: TimeInterval
}

struct ExplosionView: View {
    let origin: CGPoint
    let color: Color
    @State private var particles: [Particle] = []
    @State private var isActive = true

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, _ in
                for particle in particles {
                    let rect = CGRect(
                        x: particle.position.x - 4 * particle.scale,
                        y: particle.position.y - 4 * particle.scale,
                        width: 8 * particle.scale,
                        height: 8 * particle.scale
                    )
                    context.opacity = particle.opacity
                    context.fill(Circle().path(in: rect), with: .color(particle.color))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { spawnParticles() }
        .onReceive(Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()) { _ in
            stepParticles()
        }
    }

    private func spawnParticles() {
        particles = (0..<20).map { _ in
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 80...220)
            return Particle(
                position: origin,
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                color: [color, .white, .yellow].randomElement()!,
                scale: CGFloat.random(in: 0.5...1.5),
                maxLifetime: Double.random(in: 0.4...0.8)
            )
        }
    }

    private func stepParticles() {
        let dt: TimeInterval = 1.0 / 60.0
        for i in particles.indices {
            particles[i].lifetime += dt
            let t = particles[i].lifetime / particles[i].maxLifetime
            particles[i].position.x += particles[i].velocity.x * CGFloat(dt)
            particles[i].position.y += particles[i].velocity.y * CGFloat(dt)
            particles[i].velocity.y += 300 * CGFloat(dt)
            particles[i].opacity = max(0, 1.0 - t)
            particles[i].scale = max(0.1, 1.0 - CGFloat(t) * 0.6)
        }
        particles.removeAll { $0.lifetime >= $0.maxLifetime }
    }
}

struct DamageFlashModifier: ViewModifier {
    let isHit: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .fill(.white.opacity(isHit ? 0.6 : 0))
                    .animation(.easeOut(duration: 0.15), value: isHit)
            )
    }
}

struct GazeReticle: View {
    let position: CGPoint
    let isFiring: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(isFiring ? Color.red : Color.red.opacity(0.5), lineWidth: 2)
                .frame(width: 28, height: 28)

            Circle()
                .fill(Color.red.opacity(isFiring ? 0.8 : 0.4))
                .frame(width: 8, height: 8)

            if isFiring {
                Circle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    .frame(width: 44, height: 44)
                    .scaleEffect(isFiring ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isFiring)
            }
        }
        .position(position)
    }
}

// MARK: - Laser Audio Engine

private final class LaserOscillatorState {
    var chargeProgress: Double = 0  // 0...1
    var phase: Double = 0
    var explosionPhase: Double = 0
    var explosionRemaining: Double = 0
    var lfsr: UInt32 = 0xACE1  // noise LFSR for explosion
}

final class LaserAudioEngine {
    private let audioEngine = AVAudioEngine()
    private let sourceNode: AVAudioSourceNode
    private let state = LaserOscillatorState()
    private let sampleRate: Double = 44100.0

    init() {
        let oscState = state
        let sr = sampleRate
        sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buffer = abl[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }

            for frame in 0..<Int(frameCount) {
                var sample: Float = 0

                // Charge-up whine: sawtooth rising from 200Hz to 2000Hz
                if oscState.chargeProgress > 0.01 {
                    let freq = 200.0 + oscState.chargeProgress * 1800.0
                    let phaseInc = freq / sr
                    oscState.phase += phaseInc
                    if oscState.phase >= 1.0 { oscState.phase -= 1.0 }
                    // Sawtooth wave
                    let saw = Float(oscState.phase * 2.0 - 1.0)
                    let volume = Float(oscState.chargeProgress * 0.12)
                    sample += saw * volume
                } else {
                    oscState.phase = 0
                }

                // Explosion: filtered noise burst
                if oscState.explosionRemaining > 0 {
                    oscState.explosionRemaining -= 1.0 / sr
                    // Galois LFSR for white noise
                    let bit = oscState.lfsr & 1
                    oscState.lfsr >>= 1
                    if bit == 1 { oscState.lfsr ^= 0xB400 }
                    let noise = Float(Int32(bitPattern: oscState.lfsr << 16) >> 16) / 32768.0
                    // Envelope: fast attack, medium decay
                    let env = Float(min(1.0, oscState.explosionRemaining * 8.0))
                    sample += noise * env * 0.25
                }

                buffer[frame] = sample
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

    func setChargeProgress(_ progress: Double) {
        state.chargeProgress = progress
    }

    func playExplosion() {
        state.explosionRemaining = 0.35
        state.lfsr = 0xACE1
    }
}

struct ChompHaptics {
    private static let impact = UIImpactFeedbackGenerator(style: .medium)

    static func chomp() {
        impact.impactOccurred()
        impact.prepare()
    }
}

private final class ChompOscillatorState {
    var remainingSamples: Int = 0
    var phase: Double = 0
}

final class ChompAudioEngine {
    private let audioEngine = AVAudioEngine()
    private let sourceNode: AVAudioSourceNode
    private let state = ChompOscillatorState()
    private let sampleRate: Double = 44100.0

    init() {
        let oscState = state
        let sr = sampleRate
        sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buffer = abl[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }

            for frame in 0..<Int(frameCount) {
                var sample: Float = 0

                if oscState.remainingSamples > 0 {
                    let totalSamples = Int(sr * 0.1)
                    let progress = 1.0 - Double(oscState.remainingSamples) / Double(totalSamples)
                    // Sine sweep 300Hz → 100Hz
                    let freq = 300.0 - progress * 200.0
                    let phaseInc = freq / sr
                    oscState.phase += phaseInc
                    if oscState.phase >= 1.0 { oscState.phase -= 1.0 }
                    let sine = sin(oscState.phase * 2.0 * .pi)
                    // Exponential decay envelope
                    let env = exp(-progress * 4.0) * 0.3
                    sample = Float(sine * env)
                    oscState.remainingSamples -= 1
                } else {
                    oscState.phase = 0
                }

                buffer[frame] = sample
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

    func playChomp() {
        state.remainingSamples = Int(sampleRate * 0.1)
        state.phase = 0
    }
}
