//
//  File:      ThermalSampler.swift
//  Created:   2026-06-08
//  Updated:   2026-06-08
//  Developer: Kennt Kim / Calida Lab
//  Overview:  Reads thermal pressure (ProcessInfo) and fan RPMs (SMC) sudolessly.
//  Notes:     Fan keys: FNum = fan count (ui8), F{i}Ac = fan i actual RPM (flt).
//             SMC may be unavailable; fanRPMs is then empty and we still report
//             thermal pressure. Per-sensor die temperatures come later via the HID
//             sensor API (richer than SMC on Apple Silicon).
//
import Foundation

public final class ThermalSampler {
    private let smc: SMCReader?

    public init() {
        self.smc = SMCReader()
    }

    public func sample() -> ThermalSample {
        var result = ThermalSample()

        switch ProcessInfo.processInfo.thermalState {
        case .nominal:  result.pressure = .nominal
        case .fair:     result.pressure = .fair
        case .serious:  result.pressure = .serious
        case .critical: result.pressure = .critical
        @unknown default: result.pressure = .unknown
        }

        if let smc {
            let fanCount = Int(smc.readDouble("FNum") ?? 0)
            var rpms: [Double] = []
            for i in 0..<max(fanCount, 0) {
                if let rpm = smc.readDouble("F\(i)Ac"), rpm >= 0, rpm < 100_000 {
                    rpms.append(rpm)
                }
            }
            result.fanRPMs = rpms
        }

        return result
    }
}
