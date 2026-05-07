import AppKit
import SwiftUI

struct DependencySetupView: View {
    private let actionButtonWidth: CGFloat = 126
    private let actionButtonHeight: CGFloat = 24

    let status: DependencyStatus
    let onCopyPrompt: () -> Void
    let onCheckAgain: () -> Void

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to MediaDownloader")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("To use this app, install ffmpeg and yt-dlp on your Mac.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 0) {
                    SetupStepRow(number: 1, isLast: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Copy installation prompt.")
                                .font(.system(size: 16, weight: .regular))

                            Button(action: onCopyPrompt) {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.system(size: 14, weight: .regular))
                                    .frame(width: actionButtonWidth, height: actionButtonHeight)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    SetupStepRow(number: 2, isLast: false) {
                        Text("Paste and run it in your AI agent of choice.")
                            .font(.system(size: 16, weight: .regular))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    SetupStepRow(number: 3, isLast: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Verify installation.")
                                .font(.system(size: 16, weight: .regular))

                            Button(action: onCheckAgain) {
                                Text(status.isSatisfied ? "Open App" : "I installed libraries")
                                    .font(.system(size: 14, weight: .regular))
                                    .frame(width: actionButtonWidth, height: actionButtonHeight)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            .padding(26)
            .frame(width: 420)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.24), radius: 28, x: 0, y: 18)
        }
        .frame(width: 520, height: 360)
    }
}

private struct SetupStepRow<Content: View>: View {
    let number: Int
    let isLast: Bool
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Text("\(number)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.white.opacity(0.16)))

                if !isLast {
                    Rectangle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 4)
                }
            }
            .frame(width: 22)

            content
                .foregroundStyle(.primary)
                .padding(.top, 1)
                .padding(.bottom, isLast ? 0 : 16)

            Spacer(minLength: 0)
        }
    }
}
