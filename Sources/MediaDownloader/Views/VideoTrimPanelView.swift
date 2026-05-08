import AppKit
import AVFoundation
import SwiftUI

struct VideoTrimPanelView: View {
    let session: ActiveTrimSession
    let playbackCommand: Int
    let onClose: () -> Void
    let onCopy: (TrimSelection, @escaping @Sendable (Double) -> Void) async throws -> Void
    let onSave: (TrimSelection, @escaping @Sendable (Double) -> Void) async throws -> URL

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
    @State private var boundaryObserver: Any?
    @State private var copySucceeded = false
    @State private var isPreparingPreview = true
    @State private var exportProgress: Double = 0

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
                .opacity(isHoveringVideo || isExporting || isPreparingPreview ? 1 : 0)
                .animation(.easeOut(duration: 0.14), value: isHoveringVideo)
                .animation(.easeOut(duration: 0.14), value: isExporting)
                .animation(.easeOut(duration: 0.14), value: isPreparingPreview)

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
        .onChange(of: selection) { _, _ in
            updatePlaybackBoundsForSelection()
        }
        .onDisappear {
            player.pause()
            removePlaybackObservers()
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

            if isPreparingPreview {
                LoadingOverlay(
                    title: "Preparing preview",
                    subtitle: "The download is done. Building the trim view now."
                )
            } else if isExporting {
                LoadingOverlay(
                    title: "Exporting trim",
                    subtitle: "Saving your selected clip.",
                    progress: exportProgress
                )
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
        isPreparingPreview = true
        removePlaybackObservers()
        player.replaceCurrentItem(with: AVPlayerItem(url: session.fileURL))
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.02, preferredTimescale: 600),
            queue: .main
        ) { time in
            let seconds = CMTimeGetSeconds(time)
            guard seconds.isFinite else { return }

            let boundedSelection = selection.clamped(to: duration)
            if isPlaying, seconds >= boundedSelection.end - 0.001 {
                stopPlaybackAtSelectionEnd()
                return
            }

            playheadTime = min(max(seconds, boundedSelection.start), boundedSelection.end)
        }

        Task {
            let asset = AVURLAsset(url: session.fileURL)
            let loadedDuration = (try? await asset.load(.duration)) ?? .zero
            let seconds = CMTimeGetSeconds(loadedDuration)
            duration = seconds.isFinite && seconds > 0 ? seconds : 0
            selection = TrimSelection(start: 0, end: duration)
            playheadTime = 0
            timelineFrames = await generateTimelineFrames(asset: asset, duration: duration)
            installEndBoundaryObserver()
            isPreparingPreview = false
        }
    }

    private func removePlaybackObservers() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        removeEndBoundaryObserver()
    }

    private func removeEndBoundaryObserver() {
        if let boundaryObserver {
            player.removeTimeObserver(boundaryObserver)
            self.boundaryObserver = nil
        }
    }

    private func generateTimelineFrames(asset: AVAsset, duration: Double) async -> [NSImage] {
        guard duration > 0 else {
            return []
        }

        return await Task.detached(priority: .userInitiated) {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
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
            startBoundedPlayback()
        }
    }

    private func seekPreview(_ seconds: Double) {
        let boundedSelection = selection.clamped(to: duration)
        let boundedSeconds = min(max(seconds, boundedSelection.start), boundedSelection.end)
        let shouldResumePlayback = isPlaying && boundedSeconds < boundedSelection.end - 0.001

        if !shouldResumePlayback {
            player.pause()
            isPlaying = false
        }

        playheadTime = boundedSeconds
        player.seek(
            to: CMTime(seconds: boundedSeconds, preferredTimescale: 600),
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

    private func startBoundedPlayback() {
        let boundedSelection = selection.clamped(to: duration)
        guard boundedSelection.end > boundedSelection.start else { return }

        installEndBoundaryObserver()

        let currentSeconds = CMTimeGetSeconds(player.currentTime())
        let startSeconds: Double
        if currentSeconds.isFinite,
           currentSeconds >= boundedSelection.start,
           currentSeconds < boundedSelection.end - 0.001 {
            startSeconds = currentSeconds
        } else {
            startSeconds = boundedSelection.start
        }

        playheadTime = startSeconds
        player.seek(
            to: CMTime(seconds: startSeconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { finished in
            guard finished else { return }
            DispatchQueue.main.async {
                player.play()
                isPlaying = true
            }
        }
    }

    private func updatePlaybackBoundsForSelection() {
        installEndBoundaryObserver()

        guard isPlaying else { return }

        let boundedSelection = selection.clamped(to: duration)
        let currentSeconds = CMTimeGetSeconds(player.currentTime())
        guard currentSeconds.isFinite else { return }

        if currentSeconds >= boundedSelection.end - 0.001 {
            stopPlaybackAtSelectionEnd()
        } else if currentSeconds < boundedSelection.start {
            seekPreview(boundedSelection.start)
        }
    }

    private func installEndBoundaryObserver() {
        removeEndBoundaryObserver()

        let boundedSelection = selection.clamped(to: duration)
        guard boundedSelection.end > boundedSelection.start else { return }

        let endTime = CMTime(seconds: boundedSelection.end, preferredTimescale: 600)
        boundaryObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: endTime)], queue: .main) {
            stopPlaybackAtSelectionEnd()
        }
    }

    private func stopPlaybackAtSelectionEnd() {
        let endSeconds = selection.clamped(to: duration).end
        player.pause()
        isPlaying = false
        playheadTime = endSeconds
        player.seek(
            to: CMTime(seconds: endSeconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    private func copyTrim() {
        runExport(label: nil) {
            try await onCopy(selection.clamped(to: duration), updateExportProgress)
        } onSuccess: {
            copySucceeded = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                copySucceeded = false
            }
        }
    }

    private func saveTrim() {
        runExport(label: nil) {
            _ = try await onSave(selection.clamped(to: duration), updateExportProgress)
        }
    }

    private func runExport(
        label: String?,
        operation: @escaping () async throws -> Void,
        onSuccess: (() -> Void)? = nil
    ) {
        guard !isExporting, !isPreparingPreview else { return }
        isExporting = true
        exportProgress = 0
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
            exportProgress = 0
        }
    }

    private func updateExportProgress(_ progress: Double) {
        DispatchQueue.main.async {
            exportProgress = progress
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

private struct LoadingOverlay: View {
    let title: String
    let subtitle: String
    var progress: Double? = nil

    var body: some View {
        VStack(spacing: 10) {
            TrimExportIndicator()
                .frame(width: 30, height: 30)

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))

            Text(subtitle)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 220)

            if let progress {
                VStack(spacing: 6) {
                    Text("\(Int(progress.rounded()))%")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.86))

                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.16))
                            .frame(width: 170, height: 6)

                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.88))
                            .frame(width: max(10, 170 * max(0, min(progress, 100)) / 100), height: 6)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
