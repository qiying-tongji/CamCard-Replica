import ImageIO
import UIKit
import Vision

protocol OCRServicing {
    func recognizeText(in image: UIImage) async throws -> OCRRawResult
}

/// 整张图的原文。还没有拆成姓名、电话等字段。
struct OCRRawResult: Sendable {
    var fullText: String
    var lines: [OCRLine]
}

/// 一行文字。boundingBox 是 Vision 归一化矩形，原点在左下角。
struct OCRLine: Sendable {
    var text: String
    var confidence: Float
    var boundingBox: CGRect
}

enum OCRError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "无法读取图像"
        }
    }
}

/// 用 Vision 识别中英文本。识别在后台执行。
final class VisionOCRService: OCRServicing {
    func recognizeText(in image: UIImage) async throws -> OCRRawResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return try await Task.detached(priority: .userInitiated) {
            try Self.recognize(cgImage: cgImage, orientation: orientation)
        }.value
    }

    private static func recognize(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) throws -> OCRRawResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
        try handler.perform([request])

        let lines = (request.results ?? []).compactMap { observation -> OCRLine? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return OCRLine(
                text: candidate.string,
                confidence: candidate.confidence,
                boundingBox: observation.boundingBox
            )
        }
        .sorted(by: readingOrder)

        return OCRRawResult(
            fullText: lines.map(\.text).joined(separator: "\n"),
            lines: lines
        )
    }

    /// 先上后下、再从左到右。只为拼出可读的原文，不判断字段。
    private static func readingOrder(_ lhs: OCRLine, _ rhs: OCRLine) -> Bool {
        if abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > 0.02 {
            return lhs.boundingBox.midY > rhs.boundingBox.midY
        }
        return lhs.boundingBox.minX < rhs.boundingBox.minX
    }
}
