//
//  File:      Battery.swift
//  Created:   2026-06-08
//  Updated:   2026-06-08
//  Developer: Kennt Kim / Calida Lab
//  Overview:  Battery charge level and charging state, sampled sudolessly via
//             IOPowerSources. Stateless.
//  Notes:     hasBattery is false on desktops (Mac mini/Studio). percent is current /
//             max capacity. Battery temperature is reported separately via SMC sensors.
//
import Foundation
import IOKit.ps

public struct BatteryInfo: Sendable, Equatable {
    public var hasBattery: Bool = false
    public var percent: Double = 0
    public var isCharging: Bool = false

    public init() {}
}

public final class BatterySampler {
    public init() {}

    public func sample() -> BatteryInfo {
        var info = BatteryInfo()
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return info
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?
                .takeUnretainedValue() as? [String: Any] else { continue }
            guard let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }

            info.hasBattery = true
            info.percent = Double(current) / Double(maximum) * 100
            let state = description[kIOPSPowerSourceStateKey] as? String
            info.isCharging = (state == kIOPSACPowerValue)
        }
        return info
    }
}
