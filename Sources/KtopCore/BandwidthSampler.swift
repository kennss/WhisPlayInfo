//
//  File:      BandwidthSampler.swift
//  Created:   2026-06-08
//  Updated:   2026-06-09
//  Developer: Kennt Kim / Calida Lab
//  Overview:  Reads unified-memory bandwidth (GB/s) sudolessly via IOReport
//             "AMC Stats". Subscribes once; each sample() diffs two snapshots and
//             converts accumulated bytes to GB/s.
//  Notes:     Channels live in subgroup "Perf Counters" named "<unit> DCS RD/WR"
//             (Simple format, bytes). GB/s = (bytes / seconds) / 1e9. Requestor map:
//             ECPU/PCPU* -> CPU, GFX -> GPU, ISP/VENC/VDEC/PRORES/CODEC/JPEG -> Media,
//             "DCS" is the chip-wide aggregate (= total); other = total - the above.
//             MSR is intentionally NOT media (matches NeoAsitop). Requestor list
//             adapted from NeoAsitop (op06072/NeoAsitop), MIT License.
//
import Foundation
import CIOReport

public final class BandwidthSampler {
    private let subscription: IOReportSubscriptionRef
    private let subscribedChannels: CFMutableDictionary

    public init?() {
        guard let channels = IOReportCopyChannelsInGroup("AMC Stats" as CFString, nil, 0, 0, 0)?
            .takeRetainedValue()
        else {
            return nil
        }
        var subbed: Unmanaged<CFMutableDictionary>?
        guard let sub = IOReportCreateSubscription(nil, channels, &subbed, 0, nil),
              let subscribed = subbed?.takeRetainedValue()
        else {
            return nil
        }
        self.subscription = sub
        self.subscribedChannels = subscribed
    }

    public func sample(interval: TimeInterval = 0.2) -> BandwidthSample {
        let first = IOReportCreateSamples(subscription, subscribedChannels, nil)
        Thread.sleep(forTimeInterval: interval)
        let second = IOReportCreateSamples(subscription, subscribedChannels, nil)

        guard let a = first?.takeRetainedValue(),
              let b = second?.takeRetainedValue(),
              let delta = IOReportCreateSamplesDelta(a, b, nil)?.takeRetainedValue()
        else {
            return BandwidthSample()
        }

        let seconds = max(interval, 0.001)
        var cpu = 0.0, gpu = 0.0, media = 0.0, total = 0.0

        IOReportIterate(delta) { channel in
            guard IOReportChannelGetFormat(channel) == kKtopIOReportFormatSimple,
                  let subgroupRef = IOReportChannelGetSubGroup(channel)?.takeUnretainedValue(),
                  (subgroupRef as String) == "Perf Counters",
                  let nameRef = IOReportChannelGetChannelName(channel)?.takeUnretainedValue()
            else {
                return Int32(kKtopIOReportIterOk)
            }

            let name = (nameRef as String).uppercased()
            // Only DCS read/write byte counters (skip CAS/RAS/cycle/entry counters).
            guard name.hasSuffix(" RD") || name.hasSuffix(" WR"), name.contains("DCS") else {
                return Int32(kKtopIOReportIterOk)
            }
            let requestor = String(name.dropLast(3))   // strip " RD" / " WR"
            let gbs = (Double(IOReportSimpleGetIntegerValue(channel, 0)) / seconds) / 1_000_000_000.0

            if requestor == "DCS" {
                total += gbs                                  // chip-wide aggregate = true total
            } else if requestor.hasPrefix("ECPU") || requestor.hasPrefix("PCPU") {
                cpu += gbs
            } else if requestor.hasPrefix("GFX") {
                gpu += gbs
            } else if requestor.hasPrefix("VENC") || requestor.hasPrefix("VDEC")
                   || requestor.hasPrefix("ISP") || requestor.hasPrefix("JPG")
                   || requestor.hasPrefix("JPEG") || requestor.contains("PRORES")
                   || requestor.contains("CODEC") {
                // Media Engine = isp + strm codec + prores + vdec + venc + jpeg + jpg
                // (matches NeoAsitop's requestor list). MSR is NOT media -> falls into "other".
                media += gbs
            }
            // remaining requestors (MSR / DISP / ANS / PCIe …) are folded into "other" below
            return Int32(kKtopIOReportIterOk)
        }

        var result = BandwidthSample()
        result.cpuGBs = cpu
        result.gpuGBs = gpu
        result.mediaGBs = media
        // "DCS" is the authoritative chip total; derive other so the parts sum to it.
        result.otherGBs = total > 0 ? max(0, total - cpu - gpu - media) : 0
        return result
    }
}
