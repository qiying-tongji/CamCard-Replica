import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// 编辑已保存的名片。可以改字段，也可以更换或调整图片。
struct EditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let card: BusinessCard
    @State private var draft: CardFieldDraft
    @State private var pickerItem: PhotosPickerItem?
    @State private var adjustRequest: ImageAdjustRequest?
    @State private var pendingOriginalData: Data?
    @State private var pendingProcessedData: Data?

    init(card: BusinessCard) {
        self.card = card
        _draft = State(initialValue: CardFieldDraft(card: card))
    }

    var body: some View {
        VStack(spacing: 0) {
            imageEditor
            CardFieldForm(draft: $draft)
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("取消")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    save()
                } label: {
                    Text("保存")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("编辑名片")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let image = await PickedPhoto.load(newItem) {
                    adjustRequest = ImageAdjustRequest(image: image, replacesOriginal: true)
                }
                pickerItem = nil
            }
        }
        .fullScreenCover(item: $adjustRequest) { request in
            NavigationStack {
                ImageAdjustView(
                    image: request.image,
                    navigationTitle: "调整图片",
                    onCancel: { adjustRequest = nil },
                    onConfirmed: { result in
                        Task { await apply(result, replacesOriginal: request.replacesOriginal, original: request.image) }
                    }
                )
            }
        }
    }

    private var imageEditor: some View {
        VStack(spacing: 10) {
            Group {
                if let preview {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(Color(.secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 12) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("从相册更换", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    guard let sourceImage else { return }
                    adjustRequest = ImageAdjustRequest(image: sourceImage, replacesOriginal: pendingOriginalData != nil)
                } label: {
                    Label("调整图片", systemImage: "crop")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(sourceImage == nil)
            }
        }
        .padding([.horizontal, .top])
    }

    private var preview: UIImage? {
        if let pendingProcessedData, let image = UIImage(data: pendingProcessedData) {
            return image
        }
        if let pendingOriginalData, let image = UIImage(data: pendingOriginalData) {
            return image
        }
        if let data = card.processedImageData ?? card.originalImageData {
            return UIImage(data: data)
        }
        return nil
    }

    private var sourceImage: UIImage? {
        let data = pendingOriginalData ?? card.originalImageData ?? card.processedImageData
        guard let data else { return nil }
        return UIImage(data: data)
    }

    private func apply(_ result: CorrectedImage, replacesOriginal: Bool, original: UIImage) async {
        let processed = await encoded(result.image)
        let originalData = replacesOriginal ? await encoded(original) : pendingOriginalData
        pendingProcessedData = processed
        if replacesOriginal {
            pendingOriginalData = originalData
        }
        adjustRequest = nil
    }

    private func encoded(_ image: UIImage) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            image.jpegData(compressionQuality: 0.85) ?? image.pngData()
        }.value
    }

    private func save() {
        draft.apply(to: card)
        if let pendingOriginalData {
            card.originalImageData = pendingOriginalData
        }
        if let pendingProcessedData {
            card.processedImageData = pendingProcessedData
        }
        try? modelContext.save()
        dismiss()
    }
}

private struct ImageAdjustRequest: Identifiable {
    let id = UUID()
    let image: UIImage
    let replacesOriginal: Bool
}
