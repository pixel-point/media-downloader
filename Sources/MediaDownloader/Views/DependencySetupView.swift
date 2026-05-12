import AppKit
import SwiftUI

struct DependencySetupView: View {
    @State private var showsPromptPreview = false
    @State private var showsManualInstructions = false

    let status: DependencyStatus
    let onCopyPrompt: () -> Void
    let onInstallWithHomebrew: () -> Void
    let onOpenHomebrew: () -> Void
    let onCheckAgain: () -> Void
    let onPreferredHeightChange: (CGFloat) -> Void

    private var preferredWindowHeight: CGFloat {
        guard !status.isSatisfied else {
            return 560
        }

        var height: CGFloat = 600

        if showsPromptPreview {
            height += 150
        }

        if showsManualInstructions {
            height += status.hasHomebrew ? 180 : 200
        }

        return height
    }

    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome to MediaDownloader")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(status.isSatisfied
                             ? "Everything required to download and trim media is ready."
                             : "MediaDownloader needs FFmpeg and yt-dlp before you can continue.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Required tools")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        ForEach(status.requiredTools) { tool in
                            DependencyToolRow(
                                tool: tool,
                                isInstalled: status.installedTools.contains(tool)
                            )
                        }
                    }

                    if !status.isSatisfied {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recommended")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)

                            Text("Copy this setup prompt into your AI agent. It asks the agent to check what is already installed and install only what is missing.")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            DisclosureGroup("Preview setup prompt", isExpanded: $showsPromptPreview) {
                                PromptTextView(prompt: DependencyChecker.installPrompt(for: status))
                                    .padding(.top, 12)
                            }
                            .font(.system(size: 14, weight: .medium))
                            .tint(.primary)
                        }

                        DisclosureGroup("Manual instructions", isExpanded: $showsManualInstructions) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Missing right now: \(status.missingToolNames)")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.primary)

                                if let installCommand = status.installCommand {
                                    Text("Homebrew was detected, so you can install the missing requirement directly if you prefer to do it yourself.")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    PromptTextView(prompt: installCommand)

                                    HStack(spacing: 10) {
                                        Button(action: onInstallWithHomebrew) {
                                            Text("Install with Homebrew")
                                                .frame(minWidth: 150)
                                        }
                                        .buttonStyle(.bordered)

                                        Button(action: onCheckAgain) {
                                            Text("I installed it")
                                                .frame(minWidth: 110)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                } else {
                                    Text("Homebrew was not found. Install Homebrew first, then run the command below.")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    PromptTextView(prompt: "brew install \(status.missingTools.map(\.executableName).joined(separator: " "))")

                                    HStack(spacing: 10) {
                                        Button(action: onOpenHomebrew) {
                                            Text("Install Homebrew")
                                                .frame(minWidth: 138)
                                        }
                                        .buttonStyle(.bordered)

                                        Button(action: onCheckAgain) {
                                            Text("I installed it")
                                                .frame(minWidth: 110)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                            .padding(.top, 12)
                        }
                        .font(.system(size: 14, weight: .medium))
                        .tint(.primary)
                    }

                    HStack(spacing: 10) {
                        if status.isSatisfied {
                            Button(action: onCheckAgain) {
                                Text("Continue")
                                    .frame(minWidth: 108)
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button(action: onCopyPrompt) {
                                Label("Copy setup prompt", systemImage: "doc.on.doc")
                                    .frame(minWidth: 156)
                            }
                            .buttonStyle(.borderedProminent)

                            Button(action: onCheckAgain) {
                                Text("I installed it")
                                    .frame(minWidth: 110)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(26)
                .frame(width: 500)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.24), radius: 28, x: 0, y: 18)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.vertical, 20)
        .frame(width: 600, height: preferredWindowHeight)
        .onAppear(perform: notifyPreferredHeightChange)
        .onChange(of: showsPromptPreview) {
            notifyPreferredHeightChange()
        }
        .onChange(of: showsManualInstructions) {
            notifyPreferredHeightChange()
        }
        .onChange(of: status.isSatisfied) {
            notifyPreferredHeightChange()
        }
    }

    private func notifyPreferredHeightChange() {
        onPreferredHeightChange(preferredWindowHeight)
    }
}

private struct DependencyToolRow: View {
    let tool: ToolDependency
    let isInstalled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isInstalled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isInstalled ? .green : .orange)
                .font(.system(size: 15, weight: .semibold))

            VStack(alignment: .leading, spacing: 2) {
                Text(tool.displayName)
                    .font(.system(size: 14, weight: .medium))

                Text(tool.executableName)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text(isInstalled ? "Installed" : "Missing")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isInstalled ? .green : .orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.08))
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.06))
        )
    }
}

private struct PromptTextView: View {
    let prompt: String

    var body: some View {
        Text(prompt)
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.black.opacity(0.16))
            )
    }
}
