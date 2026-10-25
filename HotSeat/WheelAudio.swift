import AVFoundation

final class WheelAudio {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private let tickBuffer: AVAudioPCMBuffer
    private let dingBuffer: AVAudioPCMBuffer

    init() {
        let sampleRate: Double = 44100
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        tickBuffer = WheelAudio.synthesizeTick(format: format, sampleRate: sampleRate)
        dingBuffer = WheelAudio.synthesizeDing(format: format, sampleRate: sampleRate)
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
    }

    func start() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient)
            try session.setActive(true)
            try engine.start()
        } catch {
            // Best-effort: silence on failure
        }
    }

    func stop() {
        playerNode.stop()
        engine.stop()
    }

    func playTick() {
        guard engine.isRunning else { return }
        playerNode.scheduleBuffer(tickBuffer, at: nil, options: [], completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }

    func playDing() {
        guard engine.isRunning else { return }
        playerNode.scheduleBuffer(dingBuffer, at: nil, options: [], completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }

    // MARK: - Synthesis

    private static func synthesizeTick(format: AVAudioFormat, sampleRate: Double) -> AVAudioPCMBuffer {
        let duration: Double = 0.010
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]
        let frequency: Double = 1200
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = exp(-t * 500)
            data[i] = Float(sin(2.0 * .pi * frequency * t) * envelope * 0.4)
        }
        return buffer
    }

    private static func synthesizeDing(format: AVAudioFormat, sampleRate: Double) -> AVAudioPCMBuffer {
        let duration: Double = 0.400
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]
        let freq1: Double = 880
        let freq2: Double = 1109
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = exp(-t * 6.0)
            let sample = (sin(2.0 * .pi * freq1 * t) + 0.6 * sin(2.0 * .pi * freq2 * t)) * envelope * 0.35
            data[i] = Float(sample)
        }
        return buffer
    }
}
