import PhotosUI
import SwiftUI

/// 从相册选一张名片，校正并识别后进入核对页。
struct ImportView: View {
    @Binding var selectedTab: AppTab
    @State private var path = NavigationPath()
    @State private var pickerItem: PhotosPickerItem?
    @State private var originalImage: UIImage?
    @State private var imageToken = UUID()
    @State private var imageSource: ScanImageSource = .camera

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let originalImage {
                    ImageAdjustView(
                        image: originalImage,
                        navigationTitle: imageSource == .camera ? "拍摄名片" : "导入名片",
                        onConfirmed: { result in
                            path.append(CorrectionToken(originalImage: originalImage, result: result))
                        }
                    ) {
                        if imageSource == .camera {
                            Button {
                                retakePhoto()
                            } label: {
                                Text("重新拍照")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            HStack(spacing: 12) {
                                Button {
                                    retakePhoto()
                                } label: {
                                    Text("返回拍照")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                PhotosPicker(selection: $pickerItem, matching: .images) {
                                    Text("重新选择")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .id(imageToken)
                    .toolbar(.visible, for: .navigationBar)
                } else {
                    ScanCameraScreen(pickerItem: $pickerItem, onCapture: { image in
                        imageSource = .camera
                        originalImage = image
                        imageToken = UUID()
                    }, onClose: {
                        selectedTab = .cardHolder
                    })
                    .toolbar(.hidden, for: .navigationBar)
                }
            }
            .navigationDestination(for: CorrectionToken.self) { token in
                CorrectionResultView(result: token.result) { fields, rawText in
                    path.append(
                        ScanConfirmation(
                            originalImage: token.originalImage,
                            processedImage: token.result.image,
                            fields: fields,
                            ocrRawText: rawText
                        )
                    )
                }
            }
            .navigationDestination(for: ScanConfirmation.self) { confirmation in
                ConfirmView(
                    fields: confirmation.fields,
                    originalImage: confirmation.originalImage,
                    processedImage: confirmation.processedImage,
                    ocrRawText: confirmation.ocrRawText,
                    onCancel: { resetScanFlow(switchTo: .scan) },
                    onSaved: { resetScanFlow(switchTo: .cardHolder) }
                )
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await importPhoto(newItem) }
        }
        .onChange(of: selectedTab) { _, tab in
            if tab != .scan {
                clearUnconfirmedScan()
            }
        }
    }

    private func retakePhoto() {
        path = NavigationPath()
        originalImage = nil
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        imageSource = .album
        originalImage = await PickedPhoto.load(item)
        imageToken = UUID()
        pickerItem = nil
    }

    private func resetScanFlow(switchTo tab: AppTab) {
        clearUnconfirmedScan()
        selectedTab = tab
    }

    private func clearUnconfirmedScan() {
        path = NavigationPath()
        pickerItem = nil
        originalImage = nil
        imageSource = .camera
    }
}

private enum ScanImageSource {
    case camera
    case album
}

enum PickedPhoto {
    static func load(_ item: PhotosPickerItem) async -> UIImage? {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return nil }
            return await Task.detached(priority: .userInitiated) {
                UIImage(data: data)
            }.value
        } catch {
            return nil
        }
    }
}

/// 拖动边缘后做透视校正。扫描页、相册导入和编辑名片共用。
struct ImageAdjustView<Reselect: View>: View {
    let image: UIImage
    var navigationTitle = "导入名片"
    var onCancel: (() -> Void)?
    let onConfirmed: (CorrectedImage) -> Void
    @ViewBuilder var reselect: () -> Reselect

    @State private var rectangle: CardRectangle?
    @State private var isDetecting = false
    @State private var isCorrecting = false

    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if rectangle != nil, !isDetecting {
                        QuadAdjustOverlay(rectangle: rectangleBinding, imageSize: image.size)
                            .allowsHitTesting(!isCorrecting)
                    }
                }
                .overlay {
                    if isDetecting || isCorrecting {
                        ProgressView(isDetecting ? "正在检测名片" : "正在校正")
                            .padding(12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            if !isDetecting {
                Text("拖动圆点调整名片边缘")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            HStack(spacing: 12) {
                reselect()
                Button {
                    Task { await confirm() }
                } label: {
                    Text("确认")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isDetecting || isCorrecting)
            }
            .padding()
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if let onCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
            }
        }
        .task {
            isDetecting = true
            rectangle = await RectangleDetector.detect(in: image) ?? .manualFallback
            isDetecting = false
        }
    }

    private var rectangleBinding: Binding<CardRectangle> {
        Binding(
            get: { rectangle ?? .manualFallback },
            set: { rectangle = $0 }
        )
    }

    private func confirm() async {
        guard !isCorrecting else { return }
        isCorrecting = true
        let result = await ImageCorrector.correct(image: image, rectangle: rectangle)
        isCorrecting = false
        onConfirmed(result)
    }
}

extension ImageAdjustView where Reselect == EmptyView {
    init(
        image: UIImage,
        navigationTitle: String = "导入名片",
        onCancel: (() -> Void)? = nil,
        onConfirmed: @escaping (CorrectedImage) -> Void
    ) {
        self.image = image
        self.navigationTitle = navigationTitle
        self.onCancel = onCancel
        self.reselect = { EmptyView() }
        self.onConfirmed = onConfirmed
    }
}

/// 相册里选好的图片：校正、识别、核对后保存。不经过扫描页。
struct CardImportFlow: View {
    let image: UIImage
    var onCancel: () -> Void
    var onSaved: () -> Void

    @State private var path = NavigationPath()
    @State private var sourceImage: UIImage?
    @State private var imageToken = UUID()
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack(path: $path) {
            ImageAdjustView(
                image: sourceImage ?? image,
                onCancel: onCancel,
                onConfirmed: { result in
                    path.append(CorrectionToken(originalImage: sourceImage ?? image, result: result))
                }
            ) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Text("重新选择")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .id(imageToken)
            .navigationDestination(for: CorrectionToken.self) { token in
                CorrectionResultView(result: token.result) { fields, rawText in
                    path.append(
                        ScanConfirmation(
                            originalImage: token.originalImage,
                            processedImage: token.result.image,
                            fields: fields,
                            ocrRawText: rawText
                        )
                    )
                }
            }
            .navigationDestination(for: ScanConfirmation.self) { confirmation in
                ConfirmView(
                    fields: confirmation.fields,
                    originalImage: confirmation.originalImage,
                    processedImage: confirmation.processedImage,
                    ocrRawText: confirmation.ocrRawText,
                    onCancel: { path = NavigationPath() },
                    onSaved: onSaved
                )
            }
        }
        .onAppear {
            if sourceImage == nil {
                sourceImage = image
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let picked = await PickedPhoto.load(newItem) {
                    sourceImage = picked
                    imageToken = UUID()
                    path = NavigationPath()
                }
                pickerItem = nil
            }
        }
    }
}

private final class CorrectionToken: Hashable {
    let id = UUID()
    let originalImage: UIImage
    let result: CorrectedImage

    init(originalImage: UIImage, result: CorrectedImage) {
        self.originalImage = originalImage
        self.result = result
    }

    static func == (lhs: CorrectionToken, rhs: CorrectionToken) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// 核对页的数据放在导航值里。识别结束后立刻 push 时，旁边的 State 常常还没被目的页读到，页面就会是空的。
private final class ScanConfirmation: Hashable {
    let id = UUID()
    let originalImage: UIImage
    let processedImage: UIImage
    let fields: ParsedFields
    let ocrRawText: String

    init(originalImage: UIImage, processedImage: UIImage, fields: ParsedFields, ocrRawText: String) {
        self.originalImage = originalImage
        self.processedImage = processedImage
        self.fields = fields
        self.ocrRawText = ocrRawText
    }

    static func == (lhs: ScanConfirmation, rhs: ScanConfirmation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// 校正结果。识别后把字段和原文交给核对页。
private struct CorrectionResultView: View {
    let result: CorrectedImage
    var ocrService: any OCRServicing = VisionOCRService()
    var fieldParser: any BusinessCardFieldParsing = BusinessCardFieldParser()
    let onRecognized: (ParsedFields, String) -> Void
    @State private var isRecognizing = false
    @State private var recognizeError: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(uiImage: result.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !result.detected {
                Text("未检测到名片区域，显示原图")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let recognizeError {
                Text(recognizeError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await recognize() }
            } label: {
                if isRecognizing {
                    ProgressView()
                } else {
                    Text("进入识别")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRecognizing)
        }
        .padding()
        .navigationTitle("校正结果")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func recognize() async {
        guard !isRecognizing else { return }
        isRecognizing = true
        recognizeError = nil
        defer { isRecognizing = false }

        do {
            let raw = try await ocrService.recognizeText(in: result.image)
            let fields = fieldParser.parse(ocr: raw)
            onRecognized(fields, raw.fullText)
        } catch {
            recognizeError = error.localizedDescription
        }
    }
}

/// 四个角和四条边中点。角点只移动自己，边中点平移整条边。
private enum QuadHandle: CaseIterable, Identifiable {
    case topLeft, topRight, bottomRight, bottomLeft
    case top, right, bottom, left

    var id: Self { self }

    var isCorner: Bool {
        switch self {
        case .topLeft, .topRight, .bottomRight, .bottomLeft:
            return true
        case .top, .right, .bottom, .left:
            return false
        }
    }
}

/// 自动识别出的四边形，圆点可拖。坐标仍用 Vision 归一化坐标保存。
private struct QuadAdjustOverlay: View {
    @Binding var rectangle: CardRectangle
    let imageSize: CGSize
    @State private var dragBase: CardRectangle?

    var body: some View {
        GeometryReader { proxy in
            let frame = QuadGeometry.fittedRect(imageSize: imageSize, in: proxy.size)
            ZStack {
                quadPath(in: frame)
                    .stroke(Color.blue, lineWidth: 2)
                    .allowsHitTesting(false)

                ForEach(QuadHandle.allCases) { handle in
                    knob(handle, in: frame)
                }
            }
        }
    }

    private func quadPath(in frame: CGRect) -> Path {
        let points = rectangle.corners.map { QuadGeometry.displayPoint($0, in: frame) }
        return Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
    }

    private func knob(_ handle: QuadHandle, in frame: CGRect) -> some View {
        Circle()
            .fill(Color.white)
            .overlay {
                Circle().stroke(Color.blue, lineWidth: 2)
            }
            .frame(width: 18, height: 18)
            .padding(13)
            .contentShape(Rectangle())
            .position(location(of: handle, in: frame))
            .zIndex(handle.isCorner ? 1 : 0)
            .gesture(dragGesture(handle, in: frame))
    }

    private func location(of handle: QuadHandle, in frame: CGRect) -> CGPoint {
        let point: CGPoint
        switch handle {
        case .topLeft:
            point = rectangle.topLeft
        case .topRight:
            point = rectangle.topRight
        case .bottomRight:
            point = rectangle.bottomRight
        case .bottomLeft:
            point = rectangle.bottomLeft
        case .top:
            point = midpoint(rectangle.topLeft, rectangle.topRight)
        case .right:
            point = midpoint(rectangle.topRight, rectangle.bottomRight)
        case .bottom:
            point = midpoint(rectangle.bottomRight, rectangle.bottomLeft)
        case .left:
            point = midpoint(rectangle.bottomLeft, rectangle.topLeft)
        }
        return QuadGeometry.displayPoint(point, in: frame)
    }

    private func dragGesture(_ handle: QuadHandle, in frame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragBase == nil {
                    dragBase = rectangle
                }
                guard let dragBase, frame.width > 0, frame.height > 0 else { return }
                // SwiftUI 的 y 向下，Vision 的 y 向上，所以高度方向要反过来。
                let delta = CGPoint(
                    x: value.translation.width / frame.width,
                    y: -value.translation.height / frame.height
                )
                rectangle = moved(dragBase, handle: handle, delta: delta)
            }
            .onEnded { _ in
                dragBase = nil
            }
    }

    private func moved(_ base: CardRectangle, handle: QuadHandle, delta: CGPoint) -> CardRectangle {
        let shift = limitedDelta(delta, moving: anchors(of: handle, in: base))
        func shifted(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x + shift.x, y: point.y + shift.y)
        }

        var result = base
        switch handle {
        case .topLeft:
            result.topLeft = shifted(base.topLeft)
        case .topRight:
            result.topRight = shifted(base.topRight)
        case .bottomRight:
            result.bottomRight = shifted(base.bottomRight)
        case .bottomLeft:
            result.bottomLeft = shifted(base.bottomLeft)
        case .top:
            result.topLeft = shifted(base.topLeft)
            result.topRight = shifted(base.topRight)
        case .right:
            result.topRight = shifted(base.topRight)
            result.bottomRight = shifted(base.bottomRight)
        case .bottom:
            result.bottomRight = shifted(base.bottomRight)
            result.bottomLeft = shifted(base.bottomLeft)
        case .left:
            result.bottomLeft = shifted(base.bottomLeft)
            result.topLeft = shifted(base.topLeft)
        }
        return result
    }

    private func anchors(of handle: QuadHandle, in rectangle: CardRectangle) -> [CGPoint] {
        switch handle {
        case .topLeft:
            return [rectangle.topLeft]
        case .topRight:
            return [rectangle.topRight]
        case .bottomRight:
            return [rectangle.bottomRight]
        case .bottomLeft:
            return [rectangle.bottomLeft]
        case .top:
            return [rectangle.topLeft, rectangle.topRight]
        case .right:
            return [rectangle.topRight, rectangle.bottomRight]
        case .bottom:
            return [rectangle.bottomRight, rectangle.bottomLeft]
        case .left:
            return [rectangle.bottomLeft, rectangle.topLeft]
        }
    }

    /// 同一条边上的点共用一个位移，碰到图像边界就停住，避免边被拉斜。
    private func limitedDelta(_ delta: CGPoint, moving points: [CGPoint]) -> CGPoint {
        var dx = delta.x
        var dy = delta.y
        for point in points {
            if dx < 0 {
                dx = max(dx, -point.x)
            } else {
                dx = min(dx, 1 - point.x)
            }
            if dy < 0 {
                dy = max(dy, -point.y)
            } else {
                dy = min(dy, 1 - point.y)
            }
        }
        return CGPoint(x: dx, y: dy)
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}

private enum QuadGeometry {
    static func fittedRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, container.width > 0, container.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = container.width / container.height
        if imageAspect > containerAspect {
            let height = container.width / imageAspect
            return CGRect(x: 0, y: (container.height - height) / 2, width: container.width, height: height)
        }
        let width = container.height * imageAspect
        return CGRect(x: (container.width - width) / 2, y: 0, width: width, height: container.height)
    }

    static func displayPoint(_ vision: CGPoint, in frame: CGRect) -> CGPoint {
        CGPoint(
            x: frame.minX + vision.x * frame.width,
            y: frame.minY + (1 - vision.y) * frame.height
        )
    }
}

private extension CardRectangle {
    /// 自动检测失败时，先给一个缩在图内的四边形，方便手拖。
    static var manualFallback: CardRectangle {
        CardRectangle(
            topLeft: CGPoint(x: 0.12, y: 0.88),
            topRight: CGPoint(x: 0.88, y: 0.88),
            bottomRight: CGPoint(x: 0.88, y: 0.12),
            bottomLeft: CGPoint(x: 0.12, y: 0.12)
        )
    }
}

#Preview("未选择") {
    ImportView(selectedTab: .constant(.scan))
}
