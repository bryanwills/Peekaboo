import MCP
import PeekabooAutomationKit

enum CaptureMetaBuilder {
    static func buildMeta(from summary: CaptureMetaSummary) -> Value {
        .object(self.summaryMeta(from: summary))
    }

    static func buildMeta(from result: CaptureSessionResult) -> Value {
        var meta = self.summaryMeta(from: .make(from: result))
        meta["source"] = .string(result.source.rawValue)
        if let videoIn = result.videoIn {
            meta["video_in"] = .string(videoIn)
        }
        if let videoOut = result.videoOut {
            meta["video_out"] = .string(videoOut)
        }
        meta["stats"] = .object([
            "duration_ms": .int(result.stats.durationMs),
            "fps_idle": .double(result.stats.fpsIdle),
            "fps_active": .double(result.stats.fpsActive),
            "fps_effective": .double(result.stats.fpsEffective),
            "frames_kept": .int(result.stats.framesKept),
            "frames_dropped": .int(result.stats.framesDropped),
            "max_frames_hit": .bool(result.stats.maxFramesHit),
            "max_mb_hit": .bool(result.stats.maxMbHit),
        ])
        meta["warnings"] = .array(result.warnings.map(self.warningMeta))
        return .object(meta)
    }

    private static func summaryMeta(from summary: CaptureMetaSummary) -> [String: Value] {
        [
            "frames": .array(summary.frames.map { .string($0) }),
            "contact": .string(summary.contactPath),
            "metadata": .string(summary.metadataPath),
            "diff_algorithm": .string(summary.diffAlgorithm),
            "diff_scale": .string(summary.diffScale),
            "contact_columns": .string("\(summary.contactColumns)"),
            "contact_rows": .string("\(summary.contactRows)"),
            "contact_thumb_width": .string("\(summary.contactThumbSize.width)"),
            "contact_thumb_height": .string("\(summary.contactThumbSize.height)"),
            "contact_sampled_indexes": .array(summary.contactSampledIndexes.map { .string("\($0)") }),
        ]
    }

    private static func warningMeta(_ warning: CaptureWarning) -> Value {
        var meta: [String: Value] = [
            "code": .string(warning.code.rawValue),
            "message": .string(warning.message),
        ]
        if let details = warning.details {
            meta["details"] = .object(details.mapValues(Value.string))
        }
        return .object(meta)
    }
}
