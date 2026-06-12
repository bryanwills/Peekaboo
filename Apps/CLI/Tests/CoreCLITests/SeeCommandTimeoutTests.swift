import Foundation
import PeekabooFoundation
import Testing
@testable import PeekabooCLI

struct SeeCommandTimeoutTests {
    @Test
    func `returns result before timeout`() async throws {
        let result = try await SeeCommand.withWallClockTimeout(seconds: 1.0) {
            "ok"
        }
        #expect(result == "ok")
    }

    @Test
    func `throws detectionTimedOut when operation exceeds deadline`() async {
        let startedAt = Date()
        let error = await #expect(throws: CaptureError.self) {
            try await SeeCommand.withWallClockTimeout(seconds: 0.05) {
                await withCheckedContinuation { continuation in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                        continuation.resume(returning: "late")
                    }
                }
            }
        }

        switch error {
        case let .detectionTimedOut(seconds):
            #expect(seconds == 0.05, "Timeout should propagate configured deadline")
        default:
            Issue.record("Unexpected capture error: \(error)")
        }
        #expect(Date().timeIntervalSince(startedAt) < 0.25)
    }

    @Test
    func `parent cancellation remains cancellation`() async throws {
        let task = Task {
            try await SeeCommand.withWallClockTimeout(seconds: 5) {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                return "late"
            }
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        task.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }

    @Test
    func `nested timeout errors pass through unchanged`() async {
        let error = await #expect(throws: PeekabooError.self) {
            try await SeeCommand.withWallClockTimeout(seconds: 5) {
                throw PeekabooError.timeout("nested capture timeout")
            }
        }

        guard case let .timeout(reason) = error else {
            Issue.record("Expected nested PeekabooError.timeout")
            return
        }
        #expect(reason == "nested capture timeout")
    }
}
