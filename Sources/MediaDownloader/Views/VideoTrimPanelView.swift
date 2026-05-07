import AppKit
import AVFoundation
import SwiftUI

struct VideoTrimPanelView: View {
    let session: ActiveTrimSession
    let playbackCommand: Int
    let onClose: () -> Void
    let onCopy: (TrimSelection) async throws -> Void
    let onSave: (TrimSelection) async throws -> URL

    @State private var player = AVPlayer()
    @State private var duration: Double = 0
    @State private var selection = TrimSelection(start: 0, end: 0)
    @State private var isHoveringVideo = false
    @State private var isPlaying = false
    @State private var isExporting = false
    @State private var feedback: String?
    @State private var timelineFrames: [NSImage] = []
    @State private var playheadTime: Double = 0
    @State private var timeObserver: Any?
    @State private var copySucceeded = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black

            VStack(spacing: 0) {
                VideoPlayerSurface(player: player)
                    .frame(width: 680, height: 430)
                    .background(.black)

                Spacer(minLength: 0)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.42)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 170)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)

            videoControls
                .opacity(isHoveringVideo || isExporting ? 1 : 0)
                .animation(.easeOut(duration: 0.14), value: isHoveringVideo)
                .animation(.easeOut(duration: 0.14), value: isExporting)

            VStack(spacing: 8) {
                if let feedback {
                    Text(feedback)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .frame(width: 648, alignment: .leading)
                }

                TrimTimelineView(
                    selection: $selection,
                    playheadTime: $playheadTime,
                    duration: duration,
                    frames: timelineFrames,
                    onSeek: seekPreview
                )
                .frame(width: 640, height: 60)
            }
            .padding(.bottom, 12)
        }
        .frame(width: 680, height: 520)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.24), radius: 32, x: 0, y: 18)
        .onHover { isHoveringVideo = $0 }
        .onAppear(perform: loadVideo)
        .onChange(of: playbackCommand) { _, _ in
            togglePlayback()
        }
        .onDisappear {
            player.pause()
            removeTimeObserver()
        }
    }

    private var videoControls: some View {
        ZStack {
            VStack {
                HStack {
                    Spacer()
                    overlayButton(systemName: "xmark", help: "Close trim mode", action: onClose)
                }
                Spacer()
            }
            .padding(14)

            VStack {
                Spacer()
                HStack {
                    overlayButton(systemName: isPlaying ? "pause.fill" : "play.fill", help: "Play", action: togglePlayback)
                    Spacer()

                    HStack(spacing: 8) {
                        overlayButton(systemName: copySucceeded ? "checkmark" : "doc.on.doc", help: "Copy trim", action: copyTrim)
                        overlayButton(systemName: "externaldrive", help: "Save trim", action: saveTrim)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 88)

            if isExporting {
                TrimExportIndicator()
                    .frame(width: 30, height: 30)
            }
        }
    }

    private func overlayButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .disabled(isExporting)
    }

    private func loadVideo() {
        removeTimeObserver()
        player.replaceCurrentItem(with: AVPlayerItem(url: session.fileURL))
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { time in
            let seconds = CMTimeGetSeconds(time)
            guard seconds.isFinite else { return }
            playheadTime = seconds
        }

        Task {
            let asset = AVURLAsset(url: session.fileURL)
            let loadedDuration = (try? await asset.load(.duration)) ?? .zero
            let seconds = CMTimeGetSeconds(loadedDuration)
            duration = seconds.isFinite && seconds > 0 ? seconds : 0
            selection = TrimSelection(start: 0, end: duration)
            playheadTime = 0
            timelineFrames = await generateTimelineFrames(asset: asset, duration: duration)
        }
    }

    private func removeTimeObserver() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }

    private func generateTimelineFrames(asset: AVAsset, duration: Double) async -> [NSImage] {
        guard duration > 0 else {
            return []
        }

        return await Task.detached(priority: .userInitiated) {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 180, height: 110)

            let frameCount = 18
            return (0..<frameCount).compactMap { index in
                let seconds = duration * (Double(index) + 0.5) / Double(frameCount)
                let time = CMTime(seconds: seconds, preferredTimescale: 600)
                guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
                    return nil
                }

                return NSImage(cgImage: cgImage, size: .zero)
            }
        }.value
    }

    private func togglePlayback() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    private func seekPreview(_ seconds: Double) {
        let shouldResumePlayback = isPlaying
        if !shouldResumePlayback {
            player.pause()
        }

        playheadTime = seconds
        player.seek(
            to: CMTime(seconds: seconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { finished in
            guard finished, shouldResumePlayback else { return }
            DispatchQueue.main.async {
                player.play()
                isPlaying = true
            }
        }
    }

    private func copyTrim() {
        runExport(label: nil) {
            try await onCopy(selection.clamped(to: duration))
        } onSuccess: {
            copySucceeded = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                copySucceeded = false
            }
        }
    }

    private func saveTrim() {
        runExport(label: nil) {
            _ = try await onSave(selection.clamped(to: duration))
        }
    }

    private func runExport(
        label: String?,
        operation: @escaping () async throws -> Void,
        onSuccess: (() -> Void)? = nil
    ) {
        guard !isExporting else { return }
        isExporting = true
        feedback = nil

        Task {
            do {
                try await operation()
                feedback = label
                onSuccess?()
            } catch {
                feedback = error.localizedDescription
            }

            isExporting = false
        }
    }
}

private struct VideoPlayerSurface: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        return view
    }

    func updateNSView(_ nsView: PlayerContainerView, context: Context) {
        nsView.playerLayer.player = player
    }
}

private final class PlayerContainerView: NSView {
    let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.black.cgColor
        playerLayer.videoGravity = .resizeAspect
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}

private struct TrimExportIndicator: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.24), lineWidth: 2.5)

            Circle()
                .trim(from: 0.08, to: 0.74)
                .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(rotation))
        }
        .padding(3)
        .background(.black.opacity(0.36), in: Circle())
        .onAppear {
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
