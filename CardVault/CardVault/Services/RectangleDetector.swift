import ImageIO
import UIKit
import Vision

/// 名片四角，坐标为 Vision 归一化坐标：原点在左下角，x、y 都在 0...1。
struct CardRectangle: Sendable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    var corners: [CGPoint] {
        [topLeft, topRight, bottomRight, bottomLeft]
    }
}

/// 用 Vision 在图像里找一张最突出的矩形名片。
enum RectangleDetector {
    static func detect(in image: UIImage) async -> CardRectangle? {
        guard let cgImage = image.cgImage else { return nil }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return await Task.detached(priority: .userInitiated) {
            detect(cgImage: cgImage, orientation: orientation)
        }.value
    }

    private static func detect(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> CardRectangle? {
        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = 0.5
        request.maximumObservations = 1
        // Vision 只接受 [0.0, 1.0]（短边 / 长边）。按要求写入 1.2，超出部分会被夹到 1.0。
        request.minimumAspectRatio = 1.2

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first else { return nil }
        return CardRectangle(
            topLeft: observation.topLeft,
            topRight: observation.topRight,
            bottomRight: observation.bottomRight,
            bottomLeft: observation.bottomLeft
        )
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
