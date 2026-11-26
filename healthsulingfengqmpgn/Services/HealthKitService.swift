import Foundation
import HealthKit

@MainActor
final class HealthKitService: ObservableObject {
    private enum Key {
        static let enabled = "appleHealthSyncEnabled"
        static let connected = "appleHealthConnected"
        static let lastSync = "appleHealthLastSync"
        static let userID = "appUserID"
    }

    @Published private(set) var isAvailable = HKHealthStore.isHealthDataAvailable()
    @Published private(set) var isAuthorized = false
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published var enabled: Bool {
        didSet { defaults.set(enabled, forKey: Key.enabled) }
    }
    @Published var lastMessage: String?

    private let store = HKHealthStore()
    private let defaults = UserDefaults.standard

    let userID: String

    static let shared = HealthKitService()

    private init() {
        enabled = UserDefaults.standard.object(forKey: Key.enabled) as? Bool ?? false
        lastSyncDate = UserDefaults.standard.object(forKey: Key.lastSync) as? Date
        if let existing = UserDefaults.standard.string(forKey: Key.userID) {
            userID = existing
        } else {
            let value = UUID().uuidString
            UserDefaults.standard.set(value, forKey: Key.userID)
            userID = value
        }
        isAuthorized = UserDefaults.standard.bool(forKey: Key.connected)
    }

    // MARK: Types

    private var sdnnType: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
    }

    private var heartRateType: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .heartRate)
    }

    private var sleepType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
    }

    private var mindfulType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .mindfulSession)
    }

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let sdnnType { types.insert(sdnnType) }
        if let sleepType { types.insert(sleepType) }
        if let mindfulType { types.insert(mindfulType) }
        if let heartRateType { types.insert(heartRateType) }
        return types
    }

    private var writeTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        if let sdnnType { types.insert(sdnnType) }
        return types
    }

    var authorizationSummary: String {
        if !isAvailable { return "Health data is not available on this device." }
        if isAuthorized { return "Apple Health connected" }
        return "Connect Apple Health to sync HRV, sleep and mindfulness data."
    }

    // MARK: Authorization

    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isAvailable else {
            lastMessage = "Health data is not available on this device."
            return false
        }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            enabled = true
            defaults.set(true, forKey: Key.connected)
            return true
        } catch {
            lastMessage = "Apple Health access could not be granted: \(error.localizedDescription)"
            return false
        }
    }

    func disconnect() {
        enabled = false
        isAuthorized = false
        defaults.set(false, forKey: Key.connected)
    }

    // MARK: Sync

    struct SyncResult {
        let added: Int
        let sleepRecords: Int
        let mindfulRecords: Int
        let message: String
    }

    func sync() async -> SyncResult {
        guard isAvailable else {
            return SyncResult(added: 0, sleepRecords: 0, mindfulRecords: 0,
                              message: "Health data is not available on this device.")
        }
        if !isAuthorized {
            let granted = await requestAuthorization()
            guard granted else {
                return SyncResult(added: 0, sleepRecords: 0, mindfulRecords: 0,
                                  message: "Apple Health access is required to sync.")
            }
        }
        guard !isSyncing else {
            return SyncResult(added: 0, sleepRecords: 0, mindfulRecords: 0, message: "Sync already in progress.")
        }
        isSyncing = true
        defer { isSyncing = false }

        let from = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let existing = syncedIDs()
        var newIDs: [(String, String)] = []
        var added = 0

        if let sdnnType {
            let hrvSamples = await quantitySamples(type: sdnnType, from: from, limit: 200)
            let heartSamples = await quantitySamples(type: heartRateType ?? sdnnType, from: from, limit: 400)
            for sample in hrvSamples {
                let id = sample.uuid.uuidString
                guard !existing.contains(id) else { continue }
                let nearestPulse = nearestHeartRate(to: sample.startDate, samples: heartSamples)
                let metrics = deriveMetrics(sdnn: sample.quantity.doubleValue(for: HKUnit(from: "ms")), pulse: nearestPulse)
                _ = MeasurementService.save(
                    metrics: metrics,
                    tag: .none,
                    source: .appleWatch,
                    healthKitID: id,
                    createdAt: sample.startDate
                )
                newIDs.append((id, "heartRateVariabilitySDNN"))
                added += 1
            }
        }

        var sleepRecords = 0
        if let sleepType {
            let samples = await samples(type: sleepType, from: from, limit: 200)
            for sample in samples where !existing.contains(sample.uuid.uuidString) {
                newIDs.append((sample.uuid.uuidString, "sleepAnalysis"))
                sleepRecords += 1
            }
        }

        var mindfulRecords = 0
        if let mindfulType {
            let samples = await samples(type: mindfulType, from: from, limit: 200)
            for sample in samples where !existing.contains(sample.uuid.uuidString) {
                newIDs.append((sample.uuid.uuidString, "mindfulSession"))
                mindfulRecords += 1
            }
        }

        let context = PersistenceController.shared.context
        for (id, type) in newIDs {
            let record = SyncedHealthKitRecordMO(context: context)
            record.healthKitID = id
            record.recordType = type
            record.syncedAt = Date()
        }
        PersistenceController.shared.save()

        let now = Date()
        lastSyncDate = now
        defaults.set(now, forKey: Key.lastSync)
        lastMessage = added > 0 ? "\(added) measurements added" : "No new Apple Watch data found"
        return SyncResult(
            added: added,
            sleepRecords: sleepRecords,
            mindfulRecords: mindfulRecords,
            message: lastMessage ?? ""
        )
    }

    private func syncedIDs() -> Set<String> {
        let records: [SyncedHealthKitRecordMO] = PersistenceController.shared.fetch(SyncedHealthKitRecordMO.self)
        return Set(records.map(\.healthKitID))
    }

    private func deriveMetrics(sdnn: Double, pulse: Double?) -> MeasurementMetrics {
        let safeSDNN = max(1, sdnn)
        let rmssd = max(5, safeSDNN * 0.72)
        let pnn50 = min(60, max(1, (rmssd - 20) * 0.8))
        let stress = min(100, max(0, 100 - (safeSDNN - 20) * 1.25))
        let energy = min(120, max(0, log(rmssd) / log(110) * 100))
        let csi = min(700, max(25, 150 + (100 - rmssd) * 3.2))
        return MeasurementMetrics(
            pulse: Int((pulse ?? 0).rounded()),
            hrv: (safeSDNN * 10).rounded() / 10,
            sdnn: (safeSDNN * 10).rounded() / 10,
            rmssd: (rmssd * 10).rounded() / 10,
            pnn50: (pnn50 * 10).rounded() / 10,
            stress: Int(stress.rounded()),
            healthIndex: (log(rmssd) * 100).rounded() / 100,
            csi: Int(csi.rounded()),
            energy: Int(energy.rounded())
        )
    }

    private func nearestHeartRate(to date: Date, samples: [HKQuantitySample]) -> Double? {
        let nearest = samples.min { lhs, rhs in
            abs(lhs.startDate.timeIntervalSince(date)) < abs(rhs.startDate.timeIntervalSince(date))
        }
        guard let nearest, abs(nearest.startDate.timeIntervalSince(date)) < 15 * 60 else { return nil }
        return nearest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
    }

    private func samples(type: HKSampleType, from: Date, limit: Int) async -> [HKSample] {
        await withCheckedContinuation { continuation in
            let state = QueryResumeState()
            let predicate = HKQuery.predicateForSamples(withStart: from, end: Date(), options: .strictStartDate)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, _ in
                state.resume(continuation, with: samples ?? [])
            }
            store.execute(query)
            // HealthKit can leave a query unanswered when read permission was
            // never granted. Time out so the UI never stays in a syncing state.
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                state.resume(continuation, with: [])
            }
        }
    }

    private func quantitySamples(type: HKSampleType, from: Date, limit: Int) async -> [HKQuantitySample] {
        let results = await samples(type: type, from: from, limit: limit)
        return results.compactMap { $0 as? HKQuantitySample }
    }

    // MARK: Write-back

    func writeSDNN(_ value: Double, date: Date = Date()) async {
        guard isAuthorized, enabled, let sdnnType, value > 0 else { return }
        let quantity = HKQuantity(unit: HKUnit(from: "ms"), doubleValue: value)
        let sample = HKQuantitySample(type: sdnnType, quantity: quantity, start: date, end: date)
        do {
            try await store.save(sample)
        } catch {
            lastMessage = "Could not write to Apple Health: \(error.localizedDescription)"
        }
    }

    func openHealthApp() {
        guard let url = URL(string: "x-apple-health://") else { return }
        UIApplication.shared.open(url)
    }
}

import UIKit


private final class QueryResumeState: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false

    func resume(_ continuation: CheckedContinuation<[HKSample], Never>, with samples: [HKSample]) {
        lock.lock()
        if finished {
            lock.unlock()
            return
        }
        finished = true
        lock.unlock()
        continuation.resume(returning: samples)
    }
}
