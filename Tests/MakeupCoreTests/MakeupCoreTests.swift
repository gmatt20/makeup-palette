import Foundation
import XCTest
@testable import MakeupCore

final class MakeupCoreTests: XCTestCase {
    private func style(_ intensity: Double = 0.7) throws -> MakeupStyle {
        try MakeupStyle(color: MakeupColor(red: 0.8, green: 0.1, blue: 0.2), intensity: intensity)
    }

    func testReplacementClearResetAndStableOrder() throws {
        var look = MakeupLook()
        look.set(.lipstick, style: try style())
        look.set(.foundation, style: try style(0.2))
        let previous = look
        look.set(.lipstick, style: try style())
        XCTAssertEqual(look, previous)
        look.set(.lipstick, style: try style(0.9))
        XCTAssertEqual(look.treatments[.lipstick]?.intensity, 0.9)
        XCTAssertEqual(look.orderedTreatments, [.foundation, .lipstick])
        look.clear(.lipstick)
        XCTAssertEqual(look.treatments[.foundation], previous.treatments[.foundation])
        XCTAssertNil(look.treatments[.lipstick])
        look.reset()
        XCTAssertEqual(look, MakeupLook())
    }

    func testInvalidInputsAndDecodedValuesCannotBypassValidation() throws {
        for value in [Double.nan, .infinity, -.infinity, -0.01, 1.01] {
            XCTAssertThrowsError(try MakeupColor(red: value, green: 0, blue: 0))
            XCTAssertThrowsError(try MakeupColor(red: 0, green: value, blue: 0))
            XCTAssertThrowsError(try MakeupColor(red: 0, green: 0, blue: value))
            XCTAssertThrowsError(try style(value))
        }
        XCTAssertNoThrow(try MakeupColor(red: 0, green: 1, blue: 0.5))
        XCTAssertNoThrow(try style(0))
        XCTAssertNoThrow(try style(1))
        for json in [
            #"{"version":2,"treatments":{}}"#,
            #"{"version":1,"treatments":{"unknown":{"color":{"red":1,"green":0,"blue":0},"intensity":1}}}"#,
            #"{"version":1,"treatments":{"lipstick":{"color":{"red":2,"green":0,"blue":0},"intensity":1}}}"#,
            #"{"version":1,"treatments":{"lipstick":{"color":{"red":1,"green":0,"blue":0},"intensity":-1}}}"#
        ] {
            XCTAssertThrowsError(try JSONDecoder().decode(MakeupLook.self, from: Data(json.utf8)))
        }
    }

    func testPersistenceRoundTripResetAndCorruptDataPreserved() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = LookStore(url: folder.appendingPathComponent("look.json"))
        XCTAssertEqual(try store.load(), MakeupLook())
        var look = MakeupLook()
        for treatment in Treatment.allCases { look.set(treatment, style: try style()) }
        try store.save(look)
        XCTAssertEqual(try store.load(), look)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: store.url)) as? [String: Any])
        XCTAssertEqual(object["version"] as? Int, 1)
        XCTAssertEqual((object["treatments"] as? [String: Any])?.count, Treatment.allCases.count)
        look.clear(.lipstick)
        try store.save(look)
        XCTAssertNil(try store.load().treatments[.lipstick])
        look.reset()
        try store.save(look)
        XCTAssertEqual(try store.load(), MakeupLook())
        let corrupt = Data("not a saved look".utf8)
        try corrupt.write(to: store.url)
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(try Data(contentsOf: store.url), corrupt)
    }

    func testReadAndWriteFailuresAreNotReportedAsEmptyOrSuccess() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = LookStore(url: folder)
        XCTAssertThrowsError(try store.load())
        XCTAssertThrowsError(try store.save(MakeupLook()))
    }

    func testBlendPreservesUnmaskedPixelsAndUsesOriginalShading() {
        XCTAssertEqual(MakeupBlend.channel(accumulated: 0.6, color: 1, originalLuminance: 0.5,
                                           mask: 0, intensity: 1), 0.6)
        XCTAssertEqual(MakeupBlend.channel(accumulated: 0.6, color: 1, originalLuminance: 0.5,
                                           mask: 1, intensity: 0), 0.6)
        XCTAssertEqual(MakeupBlend.channel(accumulated: 0.6, color: 1, originalLuminance: 0.5,
                                           mask: 1, intensity: 1), 0.7, accuracy: 0.000001)
        XCTAssertLessThan(MakeupBlend.channel(accumulated: 0.2, color: 1, originalLuminance: 0.1,
                                              mask: 1, intensity: 1),
                          MakeupBlend.channel(accumulated: 0.2, color: 1, originalLuminance: 0.9,
                                              mask: 1, intensity: 1))
    }
}
