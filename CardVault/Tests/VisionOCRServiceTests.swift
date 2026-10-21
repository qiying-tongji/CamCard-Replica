import UIKit
import XCTest
@testable import CardVault

final class VisionOCRServiceTests: XCTestCase {
    /// C001 的 Ground Truth 姓名是 Elena Marsh。
    func testRecognizeTextContainsGroundTruthName() async throws {
        let image = try loadCardImage(named: "C001")
        let result = try await VisionOCRService().recognizeText(in: image)

        XCTAssertFalse(
            result.fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )

        let nameWords = ["Elena", "Marsh"]
        let matched = nameWords.contains { word in
            result.fullText.localizedCaseInsensitiveContains(word)
        }
        XCTAssertTrue(
            matched,
            "fullText 应包含 Ground Truth 姓名中的至少一个词，实际：\(result.fullText)"
        )
    }

    private func loadCardImage(named name: String) throws -> UIImage {
        let bundle = Bundle(for: VisionOCRServiceTests.self)
        let url = bundle.url(forResource: name, withExtension: "png", subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: "png")
        let resolved = try XCTUnwrap(url, "测试图片 \(name).png 不在测试包里")
        let data = try Data(contentsOf: resolved)
        return try XCTUnwrap(UIImage(data: data))
    }
}
