//
//  File:      PowerSampler.swift
//  Created:   2026-06-08
//  Updated:   2026-06-08
//  Developer: Kennt Kim / Calida Lab
//  Overview:  Reads per-domain SoC power (CPU E/P, GPU, ANE, DRAM) sudolessly via
//             the private IOReport framework. Subscribes once, then each sample()
//             takes two snapshots `interval` apart and converts the delta to Watts.
//  Notes:     Energy unit is millijoules: Watts = (mJ delta / seconds) / 1000.
//             Everything lives in the "Energy Model" group: CPU Energy = total CPU,
//             EACC*_CPU = E clusters, PACC*_CPU = P clusters, GPU0/GPU SRAM0 = GPU,
//             ANE0/ANE1 = Neural Engine, DRAM0 = memory. "GPU Energy" is excluded
//             (different unit, ~nJ). PMP group carries no usable power channels on
//             M-series (verified M1 Max). Only Simple-format channels hold energy.
//
import Foundation
import CIOReport

public final class PowerSampler {
    private let subscription: IOReportSubscriptionRef
    private let subscribedChannels: CFMutableDictionary

    /// Returns nil if IOReport is unavailable (e.g. non-Apple-Silicon hardware).
    public init?() {
        guard let energy = IOReportCopyChannelsInGroup("Energy Model" as CFString, nil, 0, 0, 0)?
            .takeRetainedValue()
        else {
            return nil
        }
        var subbed: Unmanaged<CFMutableDictionary>?
        guard let sub = IOReportCreateSubscription(nil, energy, &subbed, 0, nil),
              let channels = subbed?.takeRetainedValue()
        else {
            return nil
        }
        self.subscription = sub
        self.subscribedChannels = channels
    }

    /// Takes a power reading averaged over `interval` seconds.
    public func sample(interval: TimeInterval = 0.2) -> PowerSample {
        let first = IOReportCreateSamples(subscription, subscribedChannels, nil)
        Thread.sleep(forTimeInterval: interval)
        let second = IOReportCreateSamples(subscription, subscribedChannels, nil)

        guard let a = first?.takeRetainedValue(),
              let b = second?.takeRetainedValue(),
              let delta = IOReportCreateSamplesDelta(a, b, nil)?.takeRetainedValue()
        else {
            return PowerSample()
        }

        var result = PowerSample()
        let seconds = max(interval, 0.001)

        IOReportIterate(delta) { channel in
            guard IOReportChannelGetFormat(channel) == kKtopIOReportFormatSimple,
                  let groupRef = IOReportChannelGetGroup(channel)?.takeUnretainedValue(),
                  let nameRef = IOReportChannelGetChannelName(channel)?.takeUnretainedValue()
            else {
                return Int32(kKtopIOReportIterOk)
            }

            let group = groupRef as String
            let name = nameRef as String
            let milliJoules = Double(IOReportSimpleGetIntegerValue(channel, 0))
            let watts = (milliJoules / seconds) / 1000.0

            guard group == "Energy Model" else { return Int32(kKtopIOReportIterOk) }

            if name == "CPU Energy" {
                result.cpuWatts += watts
            } else if name.hasSuffix("_CPU") {
                if name.hasPrefix("EACC") {
                    result.eCPUWatts += watts        // efficiency clusters
                } else if name.hasPrefix("PACC") {
                    result.pCPUWatts += watts        // performance clusters
                }
            } else if name.hasPrefix("GPU") && name != "GPU Energy" {
                result.gpuWatts += watts             // GPU0 + GPU SRAM0
            } else if name.hasPrefix("ANE") {
                result.aneWatts += watts             // ANE0, ANE1 (estimate)
            } else if name.hasPrefix("DRAM") {
                result.dramWatts += watts            // DRAM0
            }
            return Int32(kKtopIOReportIterOk)
        }
        return result
    }
}
