import SwiftUI
import AVFoundation
import Vision

struct PerFaceExpression: Equatable {
    var mouthOpen: Bool
    var yaw: CGFloat      // radians, positive = turning right in mirrored feed
    var pitch: CGFloat    // radians, positive = looking up
    var roll: CGFloat     // radians, head tilt
}

/// A single frame's face-derived signals, emitted on the main thread.
/// `nil` fields mean "no face detected" (or no landmarks) for that signal.
struct FaceReading {
    var foreheadPoint: CGPoint?   // top-center of the largest face box, view coordinates
    var roll: CGFloat?            // head tilt in radians (largest face's VNFaceObservation.roll)
    var faceCentersX: [CGFloat]   // normalized X-centers (0...1) of up to 2 faces, sorted ascending
    var mouthOpen: Bool?          // true when the inner-lip openness ratio exceeds a threshold
    var mouthCenter: CGPoint?     // centroid of inner-lip points, view coordinates (matches foreheadPoint space)
    var noseTip: CGPoint?         // nose tip landmark, view coordinates
    var yaw: CGFloat?             // face yaw in radians (positive = turning right in mirrored selfie)
    var pitch: CGFloat?           // face pitch in radians (positive = looking up)
    var leftEyeCenter: CGPoint?   // centroid of left eye landmarks, view coordinates
    var rightEyeCenter: CGPoint?  // centroid of right eye landmarks, view coordinates
    var mouthRect: CGRect?            // bounding rect of outerLips landmarks, view coordinates
    var faceBBoxWidth: CGFloat?       // screen-space width of the largest face bounding box
    var perFaceExpressions: [PerFaceExpression]  // up to 2, sorted by X ascending
}

/// Live front-camera background that also runs Vision face detection and reports
/// the on-screen location of the user's forehead (top-center of the face box).
struct CameraPreviewView: UIViewRepresentable {
    var onReadingChange: (FaceReading) -> Void

    func makeUIView(context: Context) -> CameraUIView {
        let view = CameraUIView()
        view.onReadingChange = onReadingChange
        return view
    }

    func updateUIView(_ uiView: CameraUIView, context: Context) {
        uiView.onReadingChange = onReadingChange
    }
}

final class CameraUIView: UIView, AVCaptureVideoDataOutputSampleBufferDelegate {
    /// Latest face reading (forehead point + roll). Always invoked on main.
    var onReadingChange: ((FaceReading) -> Void)?

    private let captureSession = AVCaptureSession()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let videoDataOutput = AVCaptureVideoDataOutput()

    /// High-priority queue for all frame processing. The main thread never touches Vision.
    private let dataOutputQueue = DispatchQueue(
        label: "com.audrey.HotSeat.DataOutputQueue",
        qos: .userInitiated
    )

    private let faceRequest = VNDetectFaceLandmarksRequest()

    /// Inner-lip openness ratio above which the mouth counts as "open".
    /// (verticalGap / mouthWidth). Tuned on-device; start conservative.
    private let mouthOpenThreshold: CGFloat = 0.28

    /// Low-pass-filtered forehead point (main thread only) to kill per-frame jitter.
    private var smoothedPoint: CGPoint?
    /// Low-pass-filtered roll (main thread only) to prevent lane flicker.
    private var smoothedRoll: CGFloat?
    /// Low-pass-filtered, sorted normalized X-centers of up to 2 faces.
    /// Reset (not blended) when the detected face count changes.
    private var smoothedCentersX: [CGFloat] = []
    /// Low-pass-filtered mouth center (view space); nil when no mouth landmarks.
    private var smoothedMouthCenter: CGPoint?
    /// Latched mouth-open state; nil when no face/landmarks.
    private var smoothedMouthOpen: Bool?
    /// Low-pass-filtered nose tip (view space); nil when no nose landmarks.
    private var smoothedNoseTip: CGPoint?
    /// Low-pass-filtered yaw; nil when no face.
    private var smoothedYaw: CGFloat?
    /// Low-pass-filtered pitch; nil when no face.
    private var smoothedPitch: CGFloat?
    /// Low-pass-filtered eye centers.
    private var smoothedLeftEye: CGPoint?
    private var smoothedRightEye: CGPoint?
    private var smoothedMouthRect: CGRect?
    private var smoothedFaceBBoxWidth: CGFloat?
    private let smoothing: CGFloat = 0.35   // 0 = frozen, 1 = no smoothing

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        syncPreviewOrientation()
        syncOutputOrientation()
    }

    // MARK: - Setup

    private func setupCamera() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ),
        let input = try? AVCaptureDeviceInput(device: device),
        captureSession.canAddInput(input)
        else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(input)

        // Preview layer — unchanged visual behavior (selfie, aspect fill).
        previewLayer.session = captureSession
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)

        // Video data output for Vision.
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }

        captureSession.commitConfiguration()

        dataOutputQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    /// Rotate the preview layer's video to match the current interface orientation.
    private func syncPreviewOrientation() {
        guard let previewConnection = previewLayer.connection else { return }
        let angle = currentVideoRotationAngle()
        if previewConnection.isVideoRotationAngleSupported(angle) {
            previewConnection.videoRotationAngle = angle
        }
    }

    private func currentVideoRotationAngle() -> CGFloat {
        guard let scene = window?.windowScene else { return 90 }
        switch scene.interfaceOrientation {
        case .portrait:            return 90
        case .portraitUpsideDown:  return 270
        case .landscapeLeft:       return 0
        case .landscapeRight:      return 180
        default:                   return 90
        }
    }

    /// Make the data-output buffers arrive in the same orientation and mirroring
    /// the user sees in the preview, so Vision works in display space directly.
    private func syncOutputOrientation() {
        guard let dataConnection = videoDataOutput.connection(with: .video) else { return }

        // Match the preview connection's rotation (covers all device orientations).
        if let previewAngle = previewLayer.connection?.videoRotationAngle,
           dataConnection.isVideoRotationAngleSupported(previewAngle) {
            dataConnection.videoRotationAngle = previewAngle
        }

        // Front camera preview is mirrored; mirror the analysis buffer to match.
        if dataConnection.isVideoMirroringSupported {
            dataConnection.automaticallyAdjustsVideoMirroring = false
            dataConnection.isVideoMirrored = true
        }
    }

    // MARK: - Frame processing (background queue)

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let bufferWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let bufferHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

        // Buffer is already rotated + mirrored to display orientation, so `.up`.
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            try handler.perform([faceRequest])
        } catch {
            DispatchQueue.main.async { [weak self] in self?.emit(nil, roll: nil, centersX: []) }
            return
        }

        // Largest face wins (the player in the hot seat is closest/biggest).
        let largest = (faceRequest.results as? [VNFaceObservation])?
            .max { lhs, rhs in
                lhs.boundingBox.width * lhs.boundingBox.height
                    < rhs.boundingBox.width * rhs.boundingBox.height
            }

        let faces = (faceRequest.results as? [VNFaceObservation]) ?? []

        // Two largest faces by area, then their normalized X-centers sorted ascending.
        let twoLargest = faces
            .sorted { ($0.boundingBox.width * $0.boundingBox.height)
                    > ($1.boundingBox.width * $1.boundingBox.height) }
            .prefix(2)
        let centersX = twoLargest
            .map { $0.boundingBox.midX }
            .sorted()

        // Per-face expression extraction — same faces as centersX, same X-ascending order.
        let twoLargestByX = twoLargest.sorted { $0.boundingBox.midX < $1.boundingBox.midX }
        let perFaceExpressions: [PerFaceExpression] = twoLargestByX.map { obs in
            // Mouth open: same inner-lip ratio logic as the single-face path
            var isOpen = false
            if let inner = obs.landmarks?.innerLips, inner.pointCount > 0 {
                let pts = inner.normalizedPoints
                let xs = pts.map { $0.x }
                let ys = pts.map { $0.y }
                if let minX = xs.min(), let maxX = xs.max(),
                   let minY = ys.min(), let maxY = ys.max(), (maxX - minX) > 0 {
                    isOpen = ((maxY - minY) / (maxX - minX)) >= self.mouthOpenThreshold
                }
            }
            return PerFaceExpression(
                mouthOpen: isOpen,
                yaw: obs.yaw.map { CGFloat(truncating: $0) } ?? 0,
                pitch: obs.pitch.map { CGFloat(truncating: $0) } ?? 0,
                roll: obs.roll.map { CGFloat(truncating: $0) } ?? 0
            )
        }

        guard let face = largest else {
            DispatchQueue.main.async { [weak self] in self?.emit(nil, roll: nil, centersX: [], perFaceExpressions: []) }
            return
        }

        let box = face.boundingBox   // normalized, bottom-left origin
        let roll = face.roll.map { CGFloat(truncating: $0) }

        // Inner-lip landmarks → openness ratio + image-normalized centroid.
        // Region points are normalized within the face bounding box.
        var mouthOpenRaw: Bool?
        var mouthCenterImageNorm: CGPoint?
        if let inner = face.landmarks?.innerLips, inner.pointCount > 0 {
            let pts = inner.normalizedPoints   // [CGPoint], 0...1 within the box
            let xs = pts.map { $0.x }
            let ys = pts.map { $0.y }
            if let minX = xs.min(), let maxX = xs.max(),
               let minY = ys.min(), let maxY = ys.max(), (maxX - minX) > 0 {
                let widthBox = maxX - minX
                let gapBox = maxY - minY
                mouthOpenRaw = (gapBox / widthBox) >= mouthOpenThreshold
                // Centroid in box-normalized space → image-normalized.
                let cx = xs.reduce(0, +) / CGFloat(pts.count)
                let cy = ys.reduce(0, +) / CGFloat(pts.count)
                mouthCenterImageNorm = CGPoint(
                    x: box.origin.x + cx * box.width,
                    y: box.origin.y + cy * box.height
                )
            }
        }

        // Nose tip landmark → image-normalized point.
        var noseTipImageNorm: CGPoint?
        if let nose = face.landmarks?.noseCrest, nose.pointCount > 0 {
            let tip = nose.normalizedPoints[nose.pointCount - 1]
            noseTipImageNorm = CGPoint(
                x: box.origin.x + tip.x * box.width,
                y: box.origin.y + tip.y * box.height
            )
        }

        // Eye centers → image-normalized centroids.
        var leftEyeImageNorm: CGPoint?
        var rightEyeImageNorm: CGPoint?
        if let leftEye = face.landmarks?.leftEye, leftEye.pointCount > 0 {
            let pts = leftEye.normalizedPoints
            let cx = pts.map(\.x).reduce(0, +) / CGFloat(pts.count)
            let cy = pts.map(\.y).reduce(0, +) / CGFloat(pts.count)
            leftEyeImageNorm = CGPoint(
                x: box.origin.x + cx * box.width,
                y: box.origin.y + cy * box.height
            )
        }
        if let rightEye = face.landmarks?.rightEye, rightEye.pointCount > 0 {
            let pts = rightEye.normalizedPoints
            let cx = pts.map(\.x).reduce(0, +) / CGFloat(pts.count)
            let cy = pts.map(\.y).reduce(0, +) / CGFloat(pts.count)
            rightEyeImageNorm = CGPoint(
                x: box.origin.x + cx * box.width,
                y: box.origin.y + cy * box.height
            )
        }

        let yaw = face.yaw.map { CGFloat(truncating: $0) }
        let pitch = face.pitch.map { CGFloat(truncating: $0) }

        // Outer-lips bounding rect → image-normalized rect.
        var mouthRectImageNorm: CGRect?
        if let outerLips = face.landmarks?.outerLips, outerLips.pointCount > 0 {
            let pts = outerLips.normalizedPoints
            let xs = pts.map { $0.x }
            let ys = pts.map { $0.y }
            if let minX = xs.min(), let maxX = xs.max(),
               let minY = ys.min(), let maxY = ys.max() {
                // Convert from face-box-normalized to image-normalized.
                mouthRectImageNorm = CGRect(
                    x: box.origin.x + minX * box.width,
                    y: box.origin.y + minY * box.height,
                    width: (maxX - minX) * box.width,
                    height: (maxY - minY) * box.height
                )
            }
        }

        // Coordinate math reads `bounds` and updates state — do it on main.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let point = self.screenPoint(
                forNormalizedBox: box,
                bufferWidth: bufferWidth,
                bufferHeight: bufferHeight
            )
            let mouthPoint = mouthCenterImageNorm.map {
                self.screenPoint(
                    forImageNormalized: $0,
                    bufferWidth: bufferWidth,
                    bufferHeight: bufferHeight
                )
            }
            let nosePoint = noseTipImageNorm.map {
                self.screenPoint(
                    forImageNormalized: $0,
                    bufferWidth: bufferWidth,
                    bufferHeight: bufferHeight
                )
            }
            let leftEyePoint = leftEyeImageNorm.map {
                self.screenPoint(
                    forImageNormalized: $0,
                    bufferWidth: bufferWidth,
                    bufferHeight: bufferHeight
                )
            }
            let rightEyePoint = rightEyeImageNorm.map {
                self.screenPoint(
                    forImageNormalized: $0,
                    bufferWidth: bufferWidth,
                    bufferHeight: bufferHeight
                )
            }
            let mouthRectScreen: CGRect? = mouthRectImageNorm.map { rect in
                let topLeft = self.screenPoint(
                    forImageNormalized: CGPoint(x: rect.minX, y: rect.maxY),
                    bufferWidth: bufferWidth,
                    bufferHeight: bufferHeight
                )
                let bottomRight = self.screenPoint(
                    forImageNormalized: CGPoint(x: rect.maxX, y: rect.minY),
                    bufferWidth: bufferWidth,
                    bufferHeight: bufferHeight
                )
                return CGRect(
                    x: min(topLeft.x, bottomRight.x),
                    y: min(topLeft.y, bottomRight.y),
                    width: abs(bottomRight.x - topLeft.x),
                    height: abs(bottomRight.y - topLeft.y)
                )
            }

            let faceBBoxScreenWidth: CGFloat? = {
                let left = self.screenPoint(
                    forImageNormalized: CGPoint(x: box.minX, y: box.midY),
                    bufferWidth: bufferWidth,
                    bufferHeight: bufferHeight
                )
                let right = self.screenPoint(
                    forImageNormalized: CGPoint(x: box.maxX, y: box.midY),
                    bufferWidth: bufferWidth,
                    bufferHeight: bufferHeight
                )
                return abs(right.x - left.x)
            }()
            self.emit(point, roll: roll, centersX: centersX,
                      mouthOpen: mouthOpenRaw, mouthCenter: mouthPoint,
                      noseTip: nosePoint, yaw: yaw, pitch: pitch,
                      leftEye: leftEyePoint, rightEye: rightEyePoint,
                      mouthRect: mouthRectScreen, faceBBoxWidth: faceBBoxScreenWidth,
                      perFaceExpressions: perFaceExpressions)
        }
    }

    // MARK: - Coordinate conversion (main thread)

    /// Converts a Vision bounding box into the forehead point in this view's space,
    /// accounting for `.resizeAspectFill` scaling/cropping and the Vision Y-flip.
    private func screenPoint(
        forNormalizedBox box: CGRect,
        bufferWidth: CGFloat,
        bufferHeight: CGFloat
    ) -> CGPoint {
        let viewSize = bounds.size
        guard bufferWidth > 0, bufferHeight > 0, viewSize.width > 0 else { return .zero }

        // resizeAspectFill: scale to cover, crop overflow, center.
        let scale = max(viewSize.width / bufferWidth, viewSize.height / bufferHeight)
        let displayedWidth = bufferWidth * scale
        let displayedHeight = bufferHeight * scale
        let offsetX = (viewSize.width - displayedWidth) / 2
        let offsetY = (viewSize.height - displayedHeight) / 2

        // Forehead = top-center of the face box.
        // Vision Y is bottom-left origin, so the box top is maxY; flip for UIKit.
        let normalizedX = box.midX
        let normalizedY = 1 - box.maxY

        let x = normalizedX * displayedWidth + offsetX
        let y = normalizedY * displayedHeight + offsetY
        return CGPoint(x: x, y: y)
    }

    /// Converts an image-normalized point (Vision space, bottom-left origin)
    /// into this view's coordinates, matching `.resizeAspectFill` and the Y-flip.
    private func screenPoint(
        forImageNormalized p: CGPoint,
        bufferWidth: CGFloat,
        bufferHeight: CGFloat
    ) -> CGPoint {
        let viewSize = bounds.size
        guard bufferWidth > 0, bufferHeight > 0, viewSize.width > 0 else { return .zero }
        let scale = max(viewSize.width / bufferWidth, viewSize.height / bufferHeight)
        let displayedWidth = bufferWidth * scale
        let displayedHeight = bufferHeight * scale
        let offsetX = (viewSize.width - displayedWidth) / 2
        let offsetY = (viewSize.height - displayedHeight) / 2
        let x = p.x * displayedWidth + offsetX
        let y = (1 - p.y) * displayedHeight + offsetY   // Vision Y is bottom-left
        return CGPoint(x: x, y: y)
    }

    /// Applies jitter smoothing to the forehead point, roll, and face centers, forwards upstream.
    private func emit(_ raw: CGPoint?, roll: CGFloat?, centersX: [CGFloat],
                      mouthOpen: Bool? = nil, mouthCenter: CGPoint? = nil,
                      noseTip: CGPoint? = nil, yaw: CGFloat? = nil, pitch: CGFloat? = nil,
                      leftEye: CGPoint? = nil, rightEye: CGPoint? = nil,
                      mouthRect: CGRect? = nil, faceBBoxWidth: CGFloat? = nil,
                      perFaceExpressions: [PerFaceExpression] = []) {
        // Forehead point smoothing (unchanged behavior).
        if let raw {
            if let prev = smoothedPoint {
                smoothedPoint = CGPoint(
                    x: prev.x + (raw.x - prev.x) * smoothing,
                    y: prev.y + (raw.y - prev.y) * smoothing
                )
            } else {
                smoothedPoint = raw
            }
        } else {
            smoothedPoint = nil
        }

        // Roll smoothing (same low-pass factor).
        if let roll {
            if let prev = smoothedRoll {
                smoothedRoll = prev + (roll - prev) * smoothing
            } else {
                smoothedRoll = roll
            }
        } else {
            smoothedRoll = nil
        }

        // Face-centers smoothing: blend element-wise only when the count matches;
        // otherwise snap to the new readings (a count change is not a continuous motion).
        if centersX.count == smoothedCentersX.count {
            smoothedCentersX = zip(smoothedCentersX, centersX).map { prev, new in
                prev + (new - prev) * smoothing
            }
        } else {
            smoothedCentersX = centersX
        }

        // Mouth-center smoothing (same low-pass factor); snap on appear/disappear.
        if let mc = mouthCenter {
            if let prev = smoothedMouthCenter {
                smoothedMouthCenter = CGPoint(
                    x: prev.x + (mc.x - prev.x) * smoothing,
                    y: prev.y + (mc.y - prev.y) * smoothing
                )
            } else {
                smoothedMouthCenter = mc
            }
        } else {
            smoothedMouthCenter = nil
        }
        smoothedMouthOpen = mouthOpen

        // Nose tip smoothing.
        if let nt = noseTip {
            if let prev = smoothedNoseTip {
                smoothedNoseTip = CGPoint(
                    x: prev.x + (nt.x - prev.x) * smoothing,
                    y: prev.y + (nt.y - prev.y) * smoothing
                )
            } else {
                smoothedNoseTip = nt
            }
        } else {
            smoothedNoseTip = nil
        }

        // Yaw smoothing.
        if let y = yaw {
            if let prev = smoothedYaw {
                smoothedYaw = prev + (y - prev) * smoothing
            } else {
                smoothedYaw = y
            }
        } else {
            smoothedYaw = nil
        }

        // Pitch smoothing.
        if let p = pitch {
            if let prev = smoothedPitch {
                smoothedPitch = prev + (p - prev) * smoothing
            } else {
                smoothedPitch = p
            }
        } else {
            smoothedPitch = nil
        }

        // Left eye smoothing.
        if let le = leftEye {
            if let prev = smoothedLeftEye {
                smoothedLeftEye = CGPoint(
                    x: prev.x + (le.x - prev.x) * smoothing,
                    y: prev.y + (le.y - prev.y) * smoothing
                )
            } else {
                smoothedLeftEye = le
            }
        } else {
            smoothedLeftEye = nil
        }

        // Right eye smoothing.
        if let re = rightEye {
            if let prev = smoothedRightEye {
                smoothedRightEye = CGPoint(
                    x: prev.x + (re.x - prev.x) * smoothing,
                    y: prev.y + (re.y - prev.y) * smoothing
                )
            } else {
                smoothedRightEye = re
            }
        } else {
            smoothedRightEye = nil
        }

        // Mouth rect smoothing: blend origin + size independently.
        if let mr = mouthRect {
            if let prev = smoothedMouthRect {
                smoothedMouthRect = CGRect(
                    x: prev.origin.x + (mr.origin.x - prev.origin.x) * smoothing,
                    y: prev.origin.y + (mr.origin.y - prev.origin.y) * smoothing,
                    width: prev.width + (mr.width - prev.width) * smoothing,
                    height: prev.height + (mr.height - prev.height) * smoothing
                )
            } else {
                smoothedMouthRect = mr
            }
        } else {
            smoothedMouthRect = nil
        }

        // Face bbox width smoothing.
        if let fw = faceBBoxWidth {
            if let prev = smoothedFaceBBoxWidth {
                smoothedFaceBBoxWidth = prev + (fw - prev) * smoothing
            } else {
                smoothedFaceBBoxWidth = fw
            }
        } else {
            smoothedFaceBBoxWidth = nil
        }

        onReadingChange?(FaceReading(
            foreheadPoint: smoothedPoint,
            roll: smoothedRoll,
            faceCentersX: smoothedCentersX,
            mouthOpen: smoothedMouthOpen,
            mouthCenter: smoothedMouthCenter,
            noseTip: smoothedNoseTip,
            yaw: smoothedYaw,
            pitch: smoothedPitch,
            leftEyeCenter: smoothedLeftEye,
            rightEyeCenter: smoothedRightEye,
            mouthRect: smoothedMouthRect,
            faceBBoxWidth: smoothedFaceBBoxWidth,
            perFaceExpressions: perFaceExpressions
        ))
    }
}
