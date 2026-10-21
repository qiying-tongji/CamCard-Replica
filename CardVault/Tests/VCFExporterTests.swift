import XCTest
@testable import CardVault

final class VCFExporterTests: XCTestCase {
    func testVCardContainsMappedFieldsAndSkipsNil() {
        let card = BusinessCard(
            name: "何予安",
            company: "津渡咨询",
            mobile: "+86 138-0000-1008",
            phone: nil,
            email: nil,
            website: nil,
            address: nil
        )

        let vcard = VCFExporter.vCardString(from: card)

        XCTAssertTrue(vcard.contains("BEGIN:VCARD\r\n"))
        XCTAssertTrue(vcard.contains("VERSION:3.0\r\n"))
        XCTAssertTrue(vcard.contains("FN:何予安\r\n"))
        XCTAssertTrue(vcard.contains("N:何予安;;;;\r\n"))
        XCTAssertTrue(vcard.contains("ORG:津渡咨询\r\n"))
        XCTAssertTrue(vcard.contains("TEL;TYPE=CELL:+86 138-0000-1008\r\n"))
        XCTAssertTrue(vcard.hasSuffix("END:VCARD\r\n"))

        XCTAssertFalse(vcard.contains("TEL;TYPE=WORK"))
        XCTAssertFalse(vcard.contains("EMAIL"))
        XCTAssertFalse(vcard.contains("URL"))
        XCTAssertFalse(vcard.contains("ADR"))
        XCTAssertFalse(vcard.contains("TITLE"))

        let withoutCarriageReturn = vcard.replacingOccurrences(of: "\r\n", with: "")
        XCTAssertFalse(withoutCarriageReturn.contains("\n"))
    }
}
