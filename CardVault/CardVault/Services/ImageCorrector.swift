import CoreImage
import UIKit

/// 透视校正的结果。检测不到矩形时 image 仍是原图，detected 为 false。
struct CorrectedImage: Sendable {
    var image: UIImage
    var detected: Bool
}

/// 按四个角点做 CIPerspectiveCorrection。重活放在后台任务里。
enum ImageCorrector {
    static func correct(image: UIImage, rectangle: CardRectangle?) async -> CorrectedImage {
        guard let rectangle, let source = CIImage(image: image) else {
            return CorrectedImage(image: image, detected: false)
        }

        let scale = image.scale
        let rendered = await Task.detached(priority: .userInitiated) {
            render(source: source, rectangle: rectangle, scale: scale)
        }.value

        guard let rendered else {
            return CorrectedImage(image: image, detected: false)
        }
        return CorrectedImage(image: rendered, detected: true)
    }

    private static func render(source: CIImage, rectangle: CardRectangle, scale: CGFloat) -> UIImage? {
        let extent = source.extent
        func vector(_ point: CGPoint) -> CIVector {
            CIVector(
                x: extent.origin.x + point.x * extent.width,
                y: extent.origin.y + point.y * extent.height
            )
        }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(source, forKey: kCIInputImageKey)
        filter.setValue(vector(rectangle.topLeft), forKey: "inputTopLeft")
        filter.setValue(vector(rectangle.topRight), forKey: "inputTopRight")
        filter.setValue(vector(rectangle.bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(vector(rectangle.bottomRight), forKey: "inputBottomRight")

        guard let output = filter.outputImage else { return nil }
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}
