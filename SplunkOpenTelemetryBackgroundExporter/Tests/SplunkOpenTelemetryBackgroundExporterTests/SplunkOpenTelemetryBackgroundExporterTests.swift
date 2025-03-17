import XCTest
@testable import SplunkOpenTelemetryBackgroundExporter

final class SplunkOpenTelemetryBackgroundExporterTests: XCTestCase {

    // MARK: - Should send tests

    func testShouldSend_givenThreePreviousAttempts() throws {
        var requestDescriotor = RequestDescriptor(
            id: UUID(),
            endpoint: URL(string: "example.com")!,
            explicitTimeout: 0)

        requestDescriotor.sentCount = 3
        
        XCTAssertTrue(requestDescriotor.shouldSend)
    }

    func testShouldSend_givenSixPreviousAttempts() throws {
        var requestDescriotor = RequestDescriptor(
            id: UUID(),
            endpoint: URL(string: "example.com")!,
            explicitTimeout: 0)

        requestDescriotor.sentCount = 6
        
        XCTAssertFalse(requestDescriotor.shouldSend)
    }


    // MARK: - Request delay tests

    func testRequestDelay() throws {
        var requestDescriotor = RequestDescriptor(
            id: UUID(),
            endpoint: URL(string: "example.com")!,
            explicitTimeout: 0)

        requestDescriotor.sentCount = 3

        var delay = DateComponents()
        delay.minute = 30
        let expectedSendDate = Calendar.current.date(byAdding: delay, to: Date()) ?? Date()

        // Check the date intervals with an arbitrarily small accuracy.
        XCTAssertEqual(expectedSendDate.timeIntervalSinceReferenceDate, requestDescriotor.scheduled.timeIntervalSinceReferenceDate, accuracy: 0.001)
    }
}
