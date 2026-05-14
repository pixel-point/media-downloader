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
    @State private var boundaryObserver: Any?
    @State private var copySucceeded = false

    private var clampedSelection: TrimSelection {
        selection.clamped(to: duration)
    }

    private var currentTimeText: String {
        PlaybackTimeFormatter.string(for: playheadTime)
    }

    private var durationText: String {
        PlaybackTimeFormatter.string(for: duration)
    }

    private var trimStartText: String {
        PlaybackTimeFormatter.string(for: clampedSelection.start)
    }

    private var trimEndText: String {
        PlaybackTimeFormatter.string(for: clampedSelection.end)
    }

    private var trimLengthText: String {
        PlaybackTimeFormatter.string(for: max(clampedSelection.end - clampedSelection.start, 0))
    }

    private var controlsBottomInset: CGFloat {
        duration > 0 ? 132 : 88
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black

            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    VideoPlayerSurface(player: player)
                        .background(.black)

                    if duration > 0 {
                        timeBadge(
                            systemName: isPlaying ? "play.fill" : "clock",
                            text: "\(currentTimeText) / \(durationText)"
                        )
                        .padding(16)
                    }
                }
                .frame(width: 680, height: 430)

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
                .zIndex(1)

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

                if duration > 0 {
                    HStack(alignment: .center, spacing: 12) {
                        Text("From \(trimStartText)")
                        Spacer()
                        Text("Playhead \(currentTimeText)")
                        Spacer()
                        Text("To \(trimEndText)")
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.76))
                    .frame(width: 640)

                    HStack(spacing: 10) {
                        timeBadge(systemName: "timeline.selection", text: "Trim \(trimStartText) → \(trimEndText)")
                        Spacer(minLength: 0)
                        timeBadge(systemName: "scissors", text: "Length \(trimLengthText)")
                    }
                    .frame(width: 640)
                }
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
            .padding(.bottom, controlsBottomInset)

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

    private func timeBadge(systemName: String, text: String) -> some View {
        Label(text, systemImage: systemName)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.46), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
    }

    private func loadVideo() {
        removePlaybackObservers()
        player.replaceCurrentItem(with: AVPlayerItem(url: session.fileURL))
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.02, preferredTimescale: 600),
            queue: .main
        ) { time in
            let seconds = CMTimeGetSeconds(time)
            guard seconds.isFinite else { return }

            let boundedSelection = clampedSelection
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
        let boundedSelection = clampedSelection
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
        let boundedSelection = clampedSelection
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

        let boundedSelection = clampedSelection
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

        let boundedSelection = clampedSelection
        guard boundedSelection.end > boundedSelection.start else { return }

        let endTime = CMTime(seconds: boundedSelection.end, preferredTimescale: 600)
        boundaryObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: endTime)], queue: .main) {
            stopPlaybackAtSelectionEnd()
        }
    }

    private func stopPlaybackAtSelectionEnd() {
        let endSeconds = clampedSelection.end
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
            try await onCopy(clampedSelection)
        } onSuccess: {
            copySucceeded = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                copySucceeded = false
            }
        }
    }

    private func saveTrim() {
        runExport(label: nil) {
            _ = try await onSave(clampedSelection)
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
