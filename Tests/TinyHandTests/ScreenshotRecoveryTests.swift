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

    @Test func regionConvertsBottomLeftDisplayCoordinatesToTopLeftPixels() {
        let pixels = ScreenshotRegion.pixels(for: CGRect(x: 20, y: 30, width: 100, height: 60),
                                            on: CGRect(x: 0, y: 0, width: 400, height: 300),
                                            imageSize: CGSize(width: 800, height: 600))
        #expect(pixels == CGRect(x: 40, y: 420, width: 200, height: 120))
    }

    @Test func regionHandlesNegativeOriginsAndClipsAtDisplayEdges() {
        let pixels = ScreenshotRegion.pixels(for: CGRect(x: -450, y: 100, width: 100, height: 50),
                                            on: CGRect(x: -400, y: 0, width: 400, height: 300),
                                            imageSize: CGSize(width: 400, height: 300))
        #expect(pixels == CGRect(x: 0, y: 150, width: 50, height: 50))
        #expect(ScreenshotRegion.pixels(for: .zero, on: CGRect(x: 0, y: 0, width: 400, height: 300),
                                       imageSize: CGSize(width: 800, height: 600)) == nil)
    }
}
