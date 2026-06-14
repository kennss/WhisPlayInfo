//
//  File:      TemperatureSampler.swift
//  Created:   2026-06-08
//  Updated:   2026-06-08
//  Developer: Kennt Kim / Calida Lab
//  Overview:  Reads categorized temperatures sudolessly via SMC. Enumerates the SMC
//             temperature keys once, classifies them by prefix, then reads them each
//             sample and aggregates into groups with CPU/GPU/Battery representatives.
//  Notes:     Prefix map (Apple Silicon convention): Tp*=CPU cores, Tg*=GPU, Tm*=Memory,
//             TB*=Battery; everything else -> Other. Within a category, sensors are
//             numbered for friendly labels (e.g. "CPU 1"). Values outside (5,120)C dropped.
//
import Foundation

public final class TemperatureSampler {
    private let smc: SMCReader?
    private let keysByCategory: [SensorCategory: [String]]
    private let coreCount: Int

    public init(coreCount: Int = 0) {
        let reader = SMCReader()
        self.smc = reader
        self.coreCount = coreCount

        var map: [SensorCategory: [String]] = [:]
        if let reader {
            for key in reader.temperatureKeys() {
                map[Self.category(for: key), default: []].append(key)
            }
        }
        self.keysByCategory = map.mapValues { $0.sorted() }
    }

    public func sample() -> TemperatureSample {
        var result = TemperatureSample()
        guard let smc else { return result }

        var groups: [SensorGroup] = []
        for category in SensorCategory.allCases {
            guard let keys = keysByCategory[category], !keys.isEmpty else { continue }

            var sensors: [TempSensor] = []
            for (index, key) in keys.enumerated() {
                guard let value = smc.readDouble(key), value > 5, value < 120 else { continue }
                let label = category == .other ? key : "\(category.rawValue) \(index + 1)"
                sensors.append(TempSensor(rawName: key, name: label, celsius: value))
            }
            // Apple Silicon exposes ~3 thermal sensors per CPU core; fold them back to
            // one reading per core (hottest of the group) so the count matches reality.
            if category == .cpu { sensors = foldToCores(sensors) }
            guard !sensors.isEmpty else { continue }

            let group = SensorGroup(category: category, sensors: sensors)
            groups.append(group)
            switch category {
            case .cpu:     result.cpuCelsius = group.average; result.cpuMaxCelsius = group.maximum
            case .gpu:     result.gpuCelsius = group.average
            case .battery: result.batteryCelsius = group.average
            default:       break
            }
        }
        result.groups = groups
        return result
    }

    /// Folds per-core sensor groups (sorted by key) into one reading per core, using
    /// the hottest sensor in each group. No-op unless the sensor count is a clean
    /// multiple of the core count.
    private func foldToCores(_ sensors: [TempSensor]) -> [TempSensor] {
        guard coreCount > 0, sensors.count > coreCount, sensors.count % coreCount == 0 else { return sensors }
        let perCore = sensors.count / coreCount
        return (0..<coreCount).map { core in
            let chunk = sensors[(core * perCore)..<((core + 1) * perCore)]
            let hottest = chunk.map(\.celsius).max() ?? 0
            return TempSensor(rawName: "cpu-core-\(core)", name: "CPU core \(core + 1)", celsius: hottest)
        }
    }

    /// Maps an SMC key to a friendly category by its documented Apple Silicon prefix.
    static func category(for key: String) -> SensorCategory {
        if key.hasPrefix("TB") { return .battery }
        if key.hasPrefix("Tp") { return .cpu }      // CPU cores
        if key.hasPrefix("Tg") { return .gpu }
        if key.hasPrefix("Tm") { return .memory }
        return .other
    }
}
