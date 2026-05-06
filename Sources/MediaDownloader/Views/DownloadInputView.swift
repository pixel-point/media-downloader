import SwiftUI

struct DownloadInputView: View {
    @Binding var text: String
    let isDownloading: Bool
    let folderName: String
    let onSubmit: () -> Void
    let onPaste: () -> Void
    let onChooseFolder: () -> Void
    let onFocusHistory: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            PasteAwareTextField(
                text: $text,
                placeholder: "Paste Instagram, X, or YouTube URL",
                onSubmit: onSubmit,
                onPaste: onPaste,
                onTab: onFocusHistory
            )
            .frame(height: 36)

            if isDownloading {
                CircularDownloadIndicator()
                    .frame(width: 24, height: 24)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            Button(action: onChooseFolder) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.primary.opacity(0.58))
            .opacity(isHovering ? 1 : 0)
            .allowsHitTesting(isHovering)
            .animation(.easeOut(duration: 0.14), value: isHovering)
            .help("Download folder: \(folderName)")
        }
        .padding(.leading, 20)
        .padding(.trailing, 12)
        .frame(width: 680, height: 64)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 28, x: 0, y: 18)
        .onHover { isHovering = $0 }
    }
}

private struct CircularDownloadIndicator: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 2.4)

            Circle()
                .trim(from: 0.08, to: 0.74)
                .stroke(
                    Color.primary.opacity(0.72),
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))
        }
        .padding(3)
        .onAppear {
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
