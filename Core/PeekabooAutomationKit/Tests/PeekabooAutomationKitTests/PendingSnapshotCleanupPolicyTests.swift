import Foundation
import PeekabooFoundation
import Testing
@testable import PeekabooAutomationKit

struct PendingSnapshotCleanupPolicyTests {
    @Test
    func `transport timeout and disconnect preserve pending reservations`() {
        #expect(PendingSnapshotCleanupPolicy.shouldPreserveReservation(after: POSIXError(.ETIMEDOUT)))
        #expect(PendingSnapshotCleanupPolicy.shouldPreserveReservation(after: POSIXError(.ECONNRESET)))
        #expect(PendingSnapshotCleanupPolicy.shouldPreserveReservation(after: POSIXError(.EPIPE)))
    }

    @Test
    func `definite failures can clean pending reservations`() {
        #expect(!PendingSnapshotCleanupPolicy.shouldPreserveReservation(
            after: PeekabooError.permissionDeniedAccessibility))
        #expect(!PendingSnapshotCleanupPolicy.shouldPreserveReservation(after: POSIXError(.ENOENT)))
    }

    @Test
    func `wrapped timeout preserves pending reservation`() {
        let error = CaptureError.captureCreationFailed(POSIXError(.ETIMEDOUT))
        #expect(PendingSnapshotCleanupPolicy.shouldPreserveReservation(after: error))
    }
}
