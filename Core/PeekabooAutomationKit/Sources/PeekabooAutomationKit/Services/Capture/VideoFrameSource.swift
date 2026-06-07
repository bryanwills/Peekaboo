import AVFoundation
import CoreGraphics
import Foundation
import PeekabooFoundation

/// Frame source that samples frames from a video asset.
public final class VideoFrameSource: CaptureFrameSource {
    private let generator: AVAssetImageGenerator
    private var timeline: VideoFrameTimeline
    private let mode: CaptureMode = .screen
    public let effectiveFPS: Double

    public init(
        url: URL,
        sampleFps: Double?,
        everyMs: Int?,
        startMs: Int?,
        endMs: Int?,
        resolutionCap: CGFloat?) async throws
    {
        let asset = AVAsset(url: url)
        let duration: CMTime = if #available(macOS 13.0, *) {
            try await asset.load(.duration)
        } else {
            asset.duration
        }
        guard duration.isNumeric, duration.seconds > 0 else {
            throw PeekabooError.captureFailed(reason: "Video has no duration")
        }

        let start = CMTime(milliseconds: startMs ?? 0)
        let end = endMs.map { CMTime(milliseconds: $0) } ?? duration
        guard end > start else { throw PeekabooError.captureFailed(reason: "end-ms must exceed start-ms") }

        // Derive sampling cadence from either fps or fixed millisecond interval,
        // and expose effectiveFPS so the video writer can match it later.
        let interval: CMTime
        if let everyMs, everyMs > 0 {
            interval = CMTime(milliseconds: everyMs)
            self.effectiveFPS = everyMs > 0 ? min(240, max(0.1, 1000.0 / Double(everyMs))) : 2.0
        } else {
            let fps = min(240, max(sampleFps ?? 2.0, 0.1))
            interval = CMTime(seconds: 1.0 / max(fps, 0.1), preferredTimescale: 1_000_000)
            self.effectiveFPS = fps
        }

        self.timeline = VideoFrameTimeline(
            start: start,
            end: end,
            interval: interval)

        self.generator = AVAssetImageGenerator(asset: asset)
        self.generator.appliesPreferredTrackTransform = true
        self.generator.requestedTimeToleranceBefore = .zero
        self.generator.requestedTimeToleranceAfter = .zero
        if let cap = resolutionCap {
            self.generator.maximumSize = CGSize(width: cap, height: cap)
        }
    }

    @MainActor
    public func nextFrame() async throws -> (cgImage: CGImage?, metadata: CaptureMetadata)? {
        guard let time = self.timeline.next() else { return nil }

        var actual = CMTime.zero
        do {
            let image = try self.generator.copyCGImage(at: time, actualTime: &actual)
            let size = CGSize(width: image.width, height: image.height)
            let millis = Self.milliseconds(from: actual, fallback: time)
            let meta = CaptureMetadata(
                size: size,
                mode: self.mode,
                videoTimestampMs: millis,
                applicationInfo: nil,
                windowInfo: nil,
                displayInfo: nil,
                timestamp: Date())
            return (image, meta)
        } catch {
            // Skip unreadable frames but keep advancing
            let meta = CaptureMetadata(
                size: .zero,
                mode: self.mode,
                videoTimestampMs: Self.milliseconds(from: actual, fallback: time),
                applicationInfo: nil,
                windowInfo: nil,
                displayInfo: nil,
                timestamp: Date())
            return (nil, meta)
        }
    }

    private static func milliseconds(from time: CMTime, fallback: CMTime) -> Int? {
        // Prefer the actual timestamp when present and non-zero; otherwise use the requested fallback.
        let hasActual = time.isNumeric && time.seconds.isFinite && time != .zero
        let resolved = hasActual ? time : fallback
        guard resolved.isNumeric else { return nil }
        return Int((resolved.seconds * 1000).rounded())
    }
}

struct VideoFrameTimeline {
    private var nextTime: CMTime
    private let end: CMTime
    private let interval: CMTime
    private var exhausted = false

    init(start: CMTime, end: CMTime, interval: CMTime) {
        self.nextTime = start
        self.end = end
        self.interval = interval
    }

    mutating func next() -> CMTime? {
        guard !self.exhausted else { return nil }
        let current = self.nextTime
        if current >= self.end {
            self.exhausted = true
            return current
        }

        let next = CMTimeAdd(current, self.interval)
        guard next.isNumeric, next > current else {
            self.exhausted = true
            return current
        }

        self.nextTime = next >= self.end ? self.end : next
        return current
    }
}

extension CMTime {
    fileprivate init(milliseconds: Int) {
        self.init(value: CMTimeValue(milliseconds), timescale: 1000)
    }
}
