import Foundation
import Testing
@testable import TinyHand

@Suite struct ScreenshotRecoveryTests {
    @Test func permissionFailureOffersPermissionSettings() {
        #expect(ScreenshotRecovery.action(for: ScreenshotError.permission) == .permissionSettings)
    }

    @Test func frameAndEncodingFailuresOfferRetry() {
        for failure in [ScreenshotError.display, .timeout, .encoding] {
            #expect(ScreenshotRecovery.action(for: failure) == .retry)
        }
    }

    @Test func fileWriteFailureDoesNotSendUserToScreenRecordingSettings() {
        let failure = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)
        #expect(ScreenshotRecovery.action(for: failure) == .retry)
    }
}
