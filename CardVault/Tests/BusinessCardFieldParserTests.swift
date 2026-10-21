import UIKit
import XCTest
@testable import CardVault

final class BusinessCardFieldParserTests: XCTestCase {
    private let fieldNames = ["name", "company", "jobTitle", "mobile", "phone", "email", "website", "address"]

    func testParsedFieldsMatchGroundTruthOrStayNil() async throws {
        let cards = try loadGroundTruth()
        XCTAssertGreaterThanOrEqual(cards.count, 10)

        let parser = BusinessCardFieldParser()
        var correct = 0
        var total = 0
        var misses: [String] = []
        var wrongs: [String] = []
        var perFieldCorrect = [String: Int](uniqueKeysWithValues: fieldNames.map { ($0, 0) })
        var perFieldTotal = [String: Int](uniqueKeysWithValues: fieldNames.map { ($0, 0) })
        var perCardRows: [String] = []
        var ocrDumps: [String] = []

        for card in cards {
            let image = try loadCardImage(named: card.cardID)
            let ocr = try await VisionOCRService().recognizeText(in: image)
            let parsed = parser.parse(ocr: ocr)
            let actual = values(of: parsed)
            let expected = card.values

            var cardCorrect = 0
            for field in fieldNames {
                total += 1
                perFieldTotal[field, default: 0] += 1
                let got = actual[field] ?? nil
                let truth = expected[field] ?? nil
                if got == truth {
                    correct += 1
                    cardCorrect += 1
                    perFieldCorrect[field, default: 0] += 1
                } else if got == nil, truth != nil {
                    misses.append("\(card.cardID) \(field): Ground Truth「\(truth ?? "")」，解析为 nil")
                } else {
                    wrongs.append("\(card.cardID) \(field): 解析「\(got ?? "nil")」，Ground Truth「\(truth ?? "nil")」")
                }
            }
            perCardRows.append("\(card.cardID) \(cardCorrect)/\(fieldNames.count)")
            if cardCorrect < fieldNames.count {
                let lines = ocr.lines.map { line in
                    String(format: "  %.2f %@", line.confidence, line.text)
                }
                ocrDumps.append("[\(card.cardID)]\n\(lines.joined(separator: "\n"))")
            }
        }

        var report = ["字段准确率 \(correct)/\(total) = \(percent(correct, total))", "分字段："]
        for field in fieldNames {
            let hit = perFieldCorrect[field, default: 0]
            let count = perFieldTotal[field, default: 0]
            report.append("  \(field) \(hit)/\(count) = \(percent(hit, count))")
        }
        report.append("分名片：\(perCardRows.joined(separator: "，"))")
        if misses.isEmpty {
            report.append("漏识别：无")
        } else {
            report.append("漏识别（Ground Truth 有值，解析为 nil，不判失败）：")
            report.append(contentsOf: misses.map { "  \($0)" })
        }
        if !ocrDumps.isEmpty {
            report.append("未全对名片的 OCR：")
            report.append(contentsOf: ocrDumps)
        }
        let summary = report.joined(separator: "\n")
        print(summary)
        let attachment = XCTAttachment(string: summary)
        attachment.name = "字段准确率"
        attachment.lifetime = .keepAlways
        add(attachment)
        if !wrongs.isEmpty {
            XCTFail(summary + "\n\n出现与 Ground Truth 不同的非空字段，属于虚构或张冠李戴：\n" + wrongs.joined(separator: "\n"))
        }
    }

    private func percent(_ hit: Int, _ count: Int) -> String {
        guard count > 0 else { return "0%" }
        return String(format: "%.1f%%", Double(hit) / Double(count) * 100)
    }

    private func values(of fields: ParsedFields) -> [String: String?] {
        [
            "name": fields.name,
            "company": fields.company,
            "jobTitle": fields.jobTitle,
            "mobile": fields.mobile,
            "phone": fields.phone,
            "email": fields.email,
            "website": fields.website,
            "address": fields.address,
        ]
    }

    private func loadGroundTruth() throws -> [FixtureCard] {
        let bundle = Bundle(for: BusinessCardFieldParserTests.self)
        let url = bundle.url(forResource: "ground_truth", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "ground_truth", withExtension: "json")
        let resolved = try XCTUnwrap(url, "ground_truth.json 不在测试包里")
        let data = try Data(contentsOf: resolved)
        return try JSONDecoder().decode([FixtureCard].self, from: data)
    }

    private func loadCardImage(named name: String) throws -> UIImage {
        let bundle = Bundle(for: BusinessCardFieldParserTests.self)
        let url = bundle.url(forResource: name, withExtension: "png", subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: "png")
        let resolved = try XCTUnwrap(url, "测试图片 \(name).png 不在测试包里")
        let data = try Data(contentsOf: resolved)
        return try XCTUnwrap(UIImage(data: data))
    }
}

private struct FixtureCard: Decodable {
    let cardID: String
    let name: String?
    let company: String?
    let jobTitle: String?
    let mobile: String?
    let phone: String?
    let email: String?
    let website: String?
    let address: String?

    var values: [String: String?] {
        [
            "name": name,
            "company": company,
            "jobTitle": jobTitle,
            "mobile": mobile,
            "phone": phone,
            "email": email,
            "website": website,
            "address": address,
        ]
    }
}
