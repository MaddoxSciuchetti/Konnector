import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// In-app flow: pick a photo (library / files / camera) → crop → save to the contact.
struct ContactPhotoEditorView: View {
    let contactName: String
    let existingImageData: Data?
    let onSave: (Data) -> Void
    let onRemove: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPickerItem: PhotosPickerItem?
    @State private var sourceImage: UIImage?
    @State private var cropOffset: CGSize = .zero
    @State private var cropScale: CGFloat = 1
    @State private var dragStartOffset: CGSize = .zero
    @State private var magnifyStartScale: CGFloat = 1
    @State private var isCameraPresented = false
    @State private var isFileImporterPresented = false
    @State private var isPhotosPickerPresented = false
    @State private var isSaving = false
    @State private var loadError: String?
    @State private var didAutoPresentPicker = false

    private let cropDiameter: CGFloat = 280
    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 4
    private let outputSize: CGFloat = 512

    var body: some View {
        NavigationStack {
            Group {
                if let sourceImage {
                    cropper(for: sourceImage)
                } else {
                    emptyPickerState
                }
            }
            .background(K.Color.screenBackground)
            .navigationTitle("Profile Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if sourceImage != nil {
                        Button("Save") { saveCroppedImage() }
                            .disabled(isSaving)
                            .fontWeight(.semibold)
                    }
                }
            }
            .photosPicker(
                isPresented: $isPhotosPickerPresented,
                selection: $selectedPickerItem,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: selectedPickerItem) { _, item in
                guard let item else { return }
                Task { await loadPickerItem(item) }
            }
            .fullScreenCover(isPresented: $isCameraPresented) {
                CameraImagePicker { image in
                    applySourceImage(image)
                }
                .ignoresSafeArea()
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Couldn’t Load Photo", isPresented: loadErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(loadError ?? "Choose another photo and try again.")
            }
            .onAppear {
                if let existingImageData, let image = UIImage(data: existingImageData), sourceImage == nil {
                    applySourceImage(image)
                    return
                }
                guard !didAutoPresentPicker, sourceImage == nil else { return }
                didAutoPresentPicker = true
                isPhotosPickerPresented = true
            }
        }
        .presentationDetents([.large])
    }

    private var emptyPickerState: some View {
        VStack(spacing: K.Spacing.xxl) {
            ZStack {
                Circle()
                    .fill(K.Color.primarySoft)
                    .frame(width: 120, height: 120)

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(K.Color.primary)
            }

            VStack(spacing: K.Spacing.sm) {
                Text("Add a photo for \(contactName)")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("Choose from Photos, Files, or take a new picture. You can crop before saving.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: K.Spacing.md) {
                Button {
                    isPhotosPickerPresented = true
                } label: {
                    Label("Choose from Photos", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.kPrimary(size: .medium, corner: .prominent, expands: true))

                Button {
                    isCameraPresented = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
                .buttonStyle(.kSecondary(size: .medium, corner: .standard, expands: true))

                Button {
                    isFileImporterPresented = true
                } label: {
                    Label("Choose from Files", systemImage: "folder")
                }
                .buttonStyle(.kSecondary(size: .medium, corner: .standard, expands: true))

                if existingImageData != nil, let onRemove {
                    Button(role: .destructive) {
                        onRemove()
                        dismiss()
                    } label: {
                        Label("Remove Photo", systemImage: "trash")
                    }
                    .buttonStyle(.kTertiary(size: .medium, corner: .standard, expands: true))
                }
            }
            .padding(.horizontal, K.Layout.screenHorizontal)
        }
        .kScreenPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cropper(for image: UIImage) -> some View {
        VStack(spacing: K.Spacing.xl) {
            Text("Drag to reposition · Pinch to zoom")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ZStack {
                Color.black.opacity(0.88)

                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(cropScale)
                    .offset(cropOffset)
                    .frame(width: cropDiameter, height: cropDiameter)
                    .clipped()
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.85), lineWidth: 2)
                    }
                    .gesture(cropGesture)
            }
            .frame(height: cropDiameter + 48)
            .clipShape(RoundedRectangle.k(K.Radius.lg))
            .padding(.horizontal, K.Layout.screenHorizontal)

            HStack(spacing: K.Spacing.md) {
                Button {
                    resetCrop()
                    sourceImage = nil
                    selectedPickerItem = nil
                    isPhotosPickerPresented = true
                } label: {
                    Label("Replace", systemImage: "photo")
                }
                .buttonStyle(.kSecondary(size: .medium, corner: .standard, expands: true))

                Button {
                    isCameraPresented = true
                } label: {
                    Label("Camera", systemImage: "camera")
                }
                .buttonStyle(.kSecondary(size: .medium, corner: .standard, expands: true))
            }
            .padding(.horizontal, K.Layout.screenHorizontal)

            Spacer(minLength: 0)
        }
        .padding(.top, K.Spacing.lg)
    }

    private var cropGesture: some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { value in
                    cropOffset = CGSize(
                        width: dragStartOffset.width + value.translation.width,
                        height: dragStartOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    dragStartOffset = cropOffset
                },
            MagnifyGesture()
                .onChanged { value in
                    cropScale = min(max(magnifyStartScale * value.magnification, minScale), maxScale)
                }
                .onEnded { _ in
                    magnifyStartScale = cropScale
                }
        )
    }

    private var loadErrorBinding: Binding<Bool> {
        Binding(
            get: { loadError != nil },
            set: { isPresented in
                if !isPresented { loadError = nil }
            }
        )
    }

    private func applySourceImage(_ image: UIImage) {
        sourceImage = image.normalizedOrientation()
        resetCrop()
    }

    private func resetCrop() {
        cropOffset = .zero
        cropScale = 1
        dragStartOffset = .zero
        magnifyStartScale = 1
    }

    private func loadPickerItem(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run { applySourceImage(image) }
                return
            }
            await MainActor.run {
                loadError = "That photo couldn’t be opened."
            }
        } catch {
            await MainActor.run {
                loadError = error.localizedDescription
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url)
                guard let image = UIImage(data: data) else {
                    loadError = "That file isn’t a supported image."
                    return
                }
                applySourceImage(image)
            } catch {
                loadError = error.localizedDescription
            }
        case .failure(let error):
            loadError = error.localizedDescription
        }
    }

    private func saveCroppedImage() {
        guard let sourceImage, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        guard let data = ContactPhotoProcessor.croppedJPEG(
            from: sourceImage,
            scale: cropScale,
            offset: cropOffset,
            cropDiameter: cropDiameter,
            outputSize: outputSize
        ) else {
            loadError = "Couldn’t prepare that photo. Try another one."
            return
        }

        onSave(data)
        dismiss()
    }
}

enum ContactPhotoProcessor {
    static func croppedJPEG(
        from image: UIImage,
        scale: CGFloat,
        offset: CGSize,
        cropDiameter: CGFloat,
        outputSize: CGFloat,
        compressionQuality: CGFloat = 0.9
    ) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))
        let rendered = renderer.image { _ in
            let outputScale = outputSize / cropDiameter
            let baseSize = fillSize(for: image.size, in: cropDiameter)
            let drawSize = CGSize(
                width: baseSize.width * scale * outputScale,
                height: baseSize.height * scale * outputScale
            )
            let origin = CGPoint(
                x: (outputSize - drawSize.width) / 2 + offset.width * (outputSize / cropDiameter),
                y: (outputSize - drawSize.height) / 2 + offset.height * (outputSize / cropDiameter)
            )
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
        return rendered.jpegData(compressionQuality: compressionQuality)
    }

    private static func fillSize(for imageSize: CGSize, in diameter: CGFloat) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGSize(width: diameter, height: diameter)
        }
        let scale = max(diameter / imageSize.width, diameter / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}

private extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private struct CameraImagePicker: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraImagePicker

        init(parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }
    }
}
