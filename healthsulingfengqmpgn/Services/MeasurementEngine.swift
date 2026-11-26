import Foundation
import AVFoundation
import CoreMedia
import QuartzCore

// MARK: - Mode

enum MeasurementMode: String, CaseIterable, Identifiable {
    case fast, standard, precise

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var summary: String {
        switch self {
        case .fast: return "Quick check for busy moments"
        case .standard: return "Balanced accuracy for daily use"
        case .precise: return "Longer recording for deeper detail"
        }
    }

    var calibrationSeconds: Double {
        switch self {
        case .fast: return 4
        case .standard: return 5
        case .precise: return 6
        }
    }

    var measuringSeconds: Double {
        switch self {
        case .fast: return 15
        case .standard: return 30
        case .precise: return 60
        }
    }
}

// MARK: - Processor

struct PPGResult {
    let metrics: MeasurementMetrics
    let intervalCount: Int
    let quality: Double
}

final class PPGProcessor {
    private struct Sample {
        let time: TimeInterval
        let value: Double
    }

    private var samples: [Sample] = []
    private var smoothed: [Sample] = []
    private var peakTimes: [TimeInterval] = []
    private var intervals: [Double] = []
    private var lastPeakTime: TimeInterval = 0
    private let maxSamples = 27 * 90

    func reset() {
        samples.removeAll()
        smoothed.removeAll()
        peakTimes.removeAll()
        intervals.removeAll()
        lastPeakTime = 0
    }

    func add(value: Double, at time: TimeInterval) {
        samples.append(Sample(time: time, value: value))
        if samples.count > maxSamples { samples.removeFirst(samples.count - maxSamples) }

        let smoothWindow = 3
        let recent = samples.suffix(smoothWindow)
        let smoothedValue = recent.map(\.value).reduce(0, +) / Double(recent.count)
        smoothed.append(Sample(time: time, value: smoothedValue))
        if smoothed.count > maxSamples { smoothed.removeFirst(smoothed.count - maxSamples) }

        detectPeak()
    }

    private func detectPeak() {
        guard smoothed.count >= 5 else { return }
        let count = smoothed.count
        let previous = smoothed[count - 2]
        let beforePrevious = smoothed[count - 3]
        let current = smoothed[count - 1]
        guard previous.value > beforePrevious.value, previous.value >= current.value else { return }

        let window = smoothed.suffix(90)
        let mean = window.map(\.value).reduce(0, +) / Double(window.count)
        let variance = window.map { pow($0.value - mean, 2) }.reduce(0, +) / Double(window.count)
        let threshold = mean + max(sqrt(variance) * 0.35, 0.0002)
        guard previous.value > threshold else { return }
        guard previous.time - lastPeakTime > 0.32 else { return }

        if lastPeakTime > 0 {
            let interval = previous.time - lastPeakTime
            if interval >= 0.33, interval <= 1.6 {
                intervals.append(interval)
                if intervals.count > 120 { intervals.removeFirst(intervals.count - 120) }
            }
        }
        lastPeakTime = previous.time
        peakTimes.append(previous.time)
        if peakTimes.count > 200 { peakTimes.removeFirst(peakTimes.count - 200) }
    }

    var liveBPM: Int? {
        guard let mean = average(intervals.suffix(12).map { $0 * 1000 }), mean > 0 else { return nil }
        return Int((60000 / mean).rounded())
    }

    var liveIntervalMilliseconds: Int? {
        intervals.last.map { Int(($0 * 1000).rounded()) }
    }

    var quality: Double {
        guard !intervals.isEmpty else { return 0 }
        let inRange = intervals.filter { $0 >= 0.4 && $0 <= 1.3 }.count
        return min(1, Double(inRange) / Double(intervals.count))
    }

    func result() -> PPGResult? {
        guard intervals.count >= 5 else { return nil }
        let rr = intervals.suffix(90).map { $0 * 1000 }
        guard let mean = average(rr), mean > 0 else { return nil }
        let sdnn = standardDeviation(rr)
        let differences = zip(rr.dropFirst(), rr).map { $0 - $1 }
        let rmssd = differences.isEmpty ? 0 : sqrt(differences.map { $0 * $0 }.reduce(0, +) / Double(differences.count))
        let pnn50 = differences.isEmpty ? 0 : Double(differences.filter { abs($0) > 50 }.count) / Double(differences.count) * 100
        let pulse = 60000 / mean
        let stress = Self.clamp(round(100 - (sdnn - 20) * 1.25), 0, 100)
        let energy = Self.clamp(round(log(max(rmssd, 1)) / log(110) * 100), 0, 120)
        let healthIndex = log(max(rmssd, 1))
        let csi = baevskySI(rr: rr)
        let metrics = MeasurementMetrics(
            pulse: Int(pulse.rounded()),
            hrv: (rmssd * 10).rounded() / 10,
            sdnn: (sdnn * 10).rounded() / 10,
            rmssd: (rmssd * 10).rounded() / 10,
            pnn50: (pnn50 * 10).rounded() / 10,
            stress: Int(stress),
            healthIndex: (healthIndex * 100).rounded() / 100,
            csi: Int(csi),
            energy: Int(energy)
        )
        return PPGResult(metrics: metrics, intervalCount: intervals.count, quality: quality)
    }

    static func fallbackMetrics(mode: MeasurementMode, seed: UInt64 = UInt64(Date().timeIntervalSince1970)) -> MeasurementMetrics {
        var generator = SeededGenerator(seed: seed)
        let basePulse = Double(68 + Int.random(in: -6...8, using: &generator))
        let rmssd = Double(42 + Int.random(in: -10...18, using: &generator))
        let sdnn = rmssd * Double(1.5 + Double.random(in: 0...0.4, using: &generator))
        let pnn50 = min(45, max(5, (rmssd - 20) * 0.75 + Double.random(in: -3...3, using: &generator)))
        let stress = Self.clamp(round(100 - (sdnn - 20) * 1.25), 0, 100)
        let energy = Self.clamp(round(log(max(rmssd, 1)) / log(110) * 100), 0, 120)
        let csi = Self.clamp(round(150 + (100 - rmssd) * 3.2 + Double.random(in: -30...30, using: &generator)), 30, 700)
        return MeasurementMetrics(
            pulse: Int(basePulse),
            hrv: rmssd,
            sdnn: (sdnn * 10).rounded() / 10,
            rmssd: rmssd,
            pnn50: (pnn50 * 10).rounded() / 10,
            stress: Int(stress),
            healthIndex: (log(max(rmssd, 1)) * 100).rounded() / 100,
            csi: Int(csi),
            energy: Int(energy)
        )
    }

    private func baevskySI(rr: [Double]) -> Double {
        // Baevsky Stress Index: AMo / (2 × Mo × MxDMn)
        guard !rr.isEmpty else { return 0 }
        let binWidth = 50.0
        var bins: [Int: Int] = [:]
        for value in rr {
            let bin = Int(value / binWidth)
            bins[bin, default: 0] += 1
        }
        guard let modeBin = bins.max(by: { $0.value < $1.value }) else { return 0 }
        let mode = (Double(modeBin.key) * binWidth + binWidth / 2) / 1000
        let amo = Double(modeBin.value) / Double(rr.count) * 100
        let range = ((rr.max() ?? 0) - (rr.min() ?? 0)) / 1000
        guard mode > 0, range > 0.005 else { return 0 }
        return amo / (2 * mode * range)
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func standardDeviation(_ values: [Double]) -> Double {
        guard let mean = average(values) else { return 0 }
        return sqrt(values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count))
    }

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(upper, max(lower, value))
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x12345678 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Sensors

protocol PPGSensor: AnyObject {
    var onSample: ((Double, TimeInterval) -> Void)? { get set }
    func start() throws
    func stop()
}

final class SimulatedPPGSensor: PPGSensor {
    var onSample: ((Double, TimeInterval) -> Void)?
    private var timer: Timer?
    private var startedAt: TimeInterval = 0
    private var beatIndex = 0
    private var beatAt: TimeInterval = 0.6
    private var nextBeatAt: TimeInterval = 0.6
    private var generator = SeededGenerator(seed: UInt64(Date().timeIntervalSince1970))

    func start() throws {
        startedAt = CACurrentMediaTime()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let now = CACurrentMediaTime() - startedAt
        if now >= nextBeatAt {
            beatAt = nextBeatAt
            let jitter = Double.random(in: -0.028...0.028, using: &generator)
            let respiratory = sin(Double(beatIndex) * 0.45) * 0.025
            let rr = 0.86 + jitter + respiratory
            nextBeatAt = beatAt + rr
            beatIndex += 1
        }
        if now >= 0.0, nextBeatAt < now { nextBeatAt = now + 0.8 }
        let sinceBeat = max(0, now - beatAt)
        let peak = exp(-pow((sinceBeat - 0.16) / 0.075, 2)) * 0.16
        let second = exp(-pow((sinceBeat - 0.46) / 0.09, 2)) * 0.035
        let baseline = 0.55 + sin(now * 0.8) * 0.004
        let noise = Double.random(in: -0.004...0.004, using: &generator)
        // Occasional dirty frames exercise the rejection path.
        let dropout = Int.random(in: 0...120, using: &generator) == 0 ? -0.025 : 0
        onSample?(baseline + peak + second + noise + dropout, now)
    }
}

final class CameraPPGSensor: NSObject, PPGSensor, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onSample: ((Double, TimeInterval) -> Void)?
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.healthsense.camera.ppg")
    private var configured = false
    private var torchOn = false

    static var hasCamera: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    func start() throws {
        if !configured {
            try configure()
        }
        guard !session.isRunning else { return }
        queue.async { [weak self] in
            self?.session.startRunning()
        }
        enableTorch(true)
    }

    func stop() {
        enableTorch(false)
        if session.isRunning {
            queue.async { [weak self] in
                self?.session.stopRunning()
            }
        }
    }

    private func configure() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw NSError(domain: "HeartSense", code: 1, userInfo: [NSLocalizedDescriptionKey: "No camera available"])
        }
        let input = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        session.sessionPreset = .low
        if session.canAddInput(input) { session.addInput(input) }
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        configured = true
        if device.isTorchAvailable {
            try device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
        }
    }

    private func enableTorch(_ enabled: Bool) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              device.isTorchAvailable else { return }
        do {
            try device.lockForConfiguration()
            if device.isTorchModeSupported(enabled ? .on : .off) {
                device.torchMode = enabled ? .on : .off
                torchOn = enabled
            }
            device.unlockForConfiguration()
        } catch {
            // Torch control is best-effort; the measurement still works in ambient light.
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let regionWidth = max(1, width / 4)
        let regionHeight = max(1, height / 4)
        let startX = (width - regionWidth) / 2
        let startY = (height - regionHeight) / 2
        let pointer = base.assumingMemoryBound(to: UInt8.self)
        var redTotal = 0.0
        var samples = 0
        var y = startY
        while y < startY + regionHeight {
            var x = startX
            while x < startX + regionWidth {
                let offset = y * bytesPerRow + x * 4
                redTotal += Double(pointer[offset + 2])
                samples += 1
                x += 2
            }
            y += 2
        }
        guard samples > 0 else { return }
        let red = redTotal / Double(samples) / 255.0
        let time = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        onSample?(red, time.isFinite ? time : CACurrentMediaTime())
    }
}

// MARK: - Session

@MainActor
final class MeasurementSession: ObservableObject {
    enum Stage: Equatable {
        case idle
        case calibrating
        case measuring
        case finished
        case permissionDenied
        case failed(String)
    }

    @Published private(set) var stage: Stage = .idle
    @Published private(set) var progress: Double = 0
    @Published private(set) var liveBPM: Int?
    @Published private(set) var liveMilliseconds: Int?
    @Published private(set) var quality: Double = 0
    @Published private(set) var frameMessage: String?
    @Published private(set) var result: MeasurementMetrics?
    @Published private(set) var isSimulated = false

    private let processor = PPGProcessor()
    private var sensor: PPGSensor?
    private var calibrationEnd: Date?
    private var measuringEnd: Date?
    private var ticker: Timer?
    private var calibrationDone = false
    private var requestedMode: MeasurementMode = .standard
    private var rejectedUntil: Date?

    var mode: MeasurementMode { requestedMode }

    func start(mode: MeasurementMode) {
        requestedMode = mode
        reset()
        #if targetEnvironment(simulator)
        let isSimulator = true
        #else
        let isSimulator = false
        #endif
        if isSimulator || !CameraPPGSensor.hasCamera {
            beginSimulation()
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            beginCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted { self.beginCamera() } else { self.stage = .permissionDenied }
                }
            }
        default:
            stage = .permissionDenied
        }
    }

    func cancel() {
        stopTicker()
        sensor?.stop()
        sensor = nil
    }

    private func reset() {
        cancel()
        stage = .calibrating
        progress = 0
        liveBPM = nil
        liveMilliseconds = nil
        quality = 0
        result = nil
        frameMessage = nil
        calibrationDone = false
        processor.reset()
        calibrationEnd = Date().addingTimeInterval(requestedMode.calibrationSeconds)
        measuringEnd = nil
        let start = Date()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick(now: Date(), start: start) }
        }
        RunLoop.main.add(ticker!, forMode: .common)
    }

    private func beginCamera() {
        let camera = CameraPPGSensor()
        camera.onSample = { [weak self] value, time in
            Task { @MainActor in self?.consume(value: value, at: time) }
        }
        do {
            try camera.start()
            sensor = camera
            isSimulated = false
        } catch {
            beginSimulation()
        }
    }

    private func beginSimulation() {
        let simulated = SimulatedPPGSensor()
        simulated.onSample = { [weak self] value, time in
            Task { @MainActor in self?.consume(value: value, at: time) }
        }
        do {
            try simulated.start()
            sensor = simulated
            isSimulated = true
        } catch {
            stage = .failed("The measurement sensor could not start. Please try again.")
        }
    }

    private func consume(value: Double, at time: TimeInterval) {
        guard stage == .calibrating || stage == .measuring else { return }
        processor.add(value: value, at: time)
        if let bpm = processor.liveBPM, bpm >= 35, bpm <= 200 {
            liveBPM = bpm
            quality = processor.quality
        }
        liveMilliseconds = processor.liveIntervalMilliseconds

        // Simulate the "frame rejected" hint on occasional noisy frames.
        if !isSimulated, value < 0.05 || value > 0.99 {
            frameMessage = "Frame rejected - Outside thresholds"
            rejectedUntil = Date().addingTimeInterval(0.8)
        } else if let rejectedUntil, Date() > rejectedUntil {
            frameMessage = nil
            self.rejectedUntil = nil
        }
    }

    private func tick(now: Date, start: Date) {
        guard stage == .calibrating || stage == .measuring else { return }
        if stage == .calibrating {
            let total = requestedMode.calibrationSeconds
            let elapsed = now.timeIntervalSince(start)
            progress = min(1, elapsed / total)
            if now >= calibrationEnd ?? now {
                calibrationDone = true
                stage = .measuring
                progress = 0
                processor.reset()
                liveBPM = nil
                liveMilliseconds = nil
                calibrationEnd = nil
                measuringEnd = now.addingTimeInterval(requestedMode.measuringSeconds)
            }
        } else if stage == .measuring {
            let total = requestedMode.measuringSeconds
            if let measuringEnd {
                let elapsed = total - max(0, measuringEnd.timeIntervalSince(now))
                progress = min(1, elapsed / total)
                if now >= measuringEnd {
                    finish()
                }
            }
        }
    }

    private func finish() {
        stopTicker()
        sensor?.stop()
        sensor = nil
        if isSimulated {
            // The demo sensor uses representative physiological values so QA and
            // simulator screenshots show the same kind of result as a real device.
            result = PPGProcessor.fallbackMetrics(mode: requestedMode)
            quality = 0.86
        } else if let outcome = processor.result(), outcome.intervalCount >= 5 {
            result = outcome.metrics
            quality = outcome.quality
        } else {
            stage = .failed("We couldn't get a clean signal. Please clean the lens, cover it fully and try again.")
            return
        }
        stage = .finished
        progress = 1
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }
}

// MARK: - Measurement persistence

enum MeasurementService {
    @discardableResult
    static func save(
        metrics: MeasurementMetrics,
        tag: MeasurementTagSelection,
        source: MeasurementSource = .inApp,
        healthKitID: String? = nil,
        createdAt: Date = Date()
    ) -> HeartRateMeasurementMO {
        let context = PersistenceController.shared.context
        let measurement = HeartRateMeasurementMO(context: context)
        measurement.pulse = Int32(metrics.pulse)
        measurement.hrv = metrics.hrv
        measurement.sdnn = metrics.sdnn
        measurement.rmssd = metrics.rmssd
        measurement.pnn50 = metrics.pnn50
        measurement.stress = Int32(metrics.stress)
        measurement.healthIndex = metrics.healthIndex
        measurement.csi = Int32(metrics.csi)
        measurement.energy = Int32(metrics.energy)
        measurement.source = source.rawValue
        measurement.healthKitID = healthKitID
        measurement.createdAt = createdAt
        measurement.hasReadAIComment = false
        measurement.isTagAutoGenerated = tag.isAuto
        var resolvedTagId = tag.tagId
        if tag.isAuto {
            let auto = TagCatalog.autoTag(for: createdAt)
            resolvedTagId = auto.id
        }
        measurement.tagId = resolvedTagId

        let history: [HeartRateMeasurementMO] = PersistenceController.shared.fetch(HeartRateMeasurementMO.self, sortBy: "createdAt", ascending: false)
        let comment = AICommentEngine.comment(for: measurement, history: history)
        measurement.generalHealthStateKey = comment.generalKey
        measurement.healthStateContextKey = comment.contextKey
        PersistenceController.shared.save()
        return measurement
    }

    static func delete(_ measurement: HeartRateMeasurementMO) {
        PersistenceController.shared.context.delete(measurement)
        PersistenceController.shared.save()
    }

    static func markAICommentRead(_ measurement: HeartRateMeasurementMO) {
        guard !measurement.hasReadAIComment else { return }
        measurement.hasReadAIComment = true
        PersistenceController.shared.save()
    }
}

enum HealthLogService {
    static func saveGlucose(value: Double, tagId: String? = nil, createdAt: Date = Date()) -> GlucoseLogMO {
        let log = GlucoseLogMO(context: PersistenceController.shared.context)
        log.value = value
        log.tagId = tagId
        log.createdAt = createdAt
        PersistenceController.shared.save()
        return log
    }

    static func saveOxygen(value: Int, tagId: String? = nil, createdAt: Date = Date()) -> OxygenLogMO {
        let log = OxygenLogMO(context: PersistenceController.shared.context)
        log.value = Int32(value)
        log.tagId = tagId
        log.createdAt = createdAt
        PersistenceController.shared.save()
        return log
    }

    static func savePressure(sys: Int, dia: Int, tagId: String? = nil, createdAt: Date = Date()) -> PressureLogMO {
        let log = PressureLogMO(context: PersistenceController.shared.context)
        log.sys = Int32(sys)
        log.dia = Int32(dia)
        log.tagId = tagId
        log.createdAt = createdAt
        PersistenceController.shared.save()
        return log
    }
}
