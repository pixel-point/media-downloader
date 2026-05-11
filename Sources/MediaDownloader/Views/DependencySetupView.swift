import AppKit
import SwiftUI

struct DependencySetupView: View {
    let status: DependencyStatus
    let onCopyPrompt: () -> Void
    let onInstallWithHomebrew: () -> Void
    let onOpenHomebrew: () -> Void
    let onCheckAgain: () -> Void

    var body: some View {
        ZStack {
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
                        Text("Missing right now: \(status.missingToolNames)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)

                        if let installCommand = status.installCommand {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Homebrew was detected, so you can install the missing requirement directly:")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(.secondary)

                                InstallCommandView(command: installCommand)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Homebrew was not found. Install Homebrew first, then install the missing tools.")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(.secondary)

                                InstallCommandView(command: "brew install \(status.missingTools.map(\.executableName).joined(separator: " "))")
                            }
                        }
                    }
                }

                HStack(spacing: 10) {
                    if status.isSatisfied {
                        Button(action: onCheckAgain) {
                            Text("Continue")
                                .frame(minWidth: 108)
                        }
                        .buttonStyle(.borderedProminent)
                    } else if status.hasHomebrew {
                        Button(action: onInstallWithHomebrew) {
                            Text("Install with Homebrew")
                                .frame(minWidth: 150)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: onCopyPrompt) {
                            Label("Copy command", systemImage: "doc.on.doc")
                                .frame(minWidth: 132)
                        }
                        .buttonStyle(.bordered)

                        Button(action: onCheckAgain) {
                            Text("I installed it")
                                .frame(minWidth: 110)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(action: onOpenHomebrew) {
                            Text("Install Homebrew")
                                .frame(minWidth: 138)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: onCopyPrompt) {
                            Label("Copy steps", systemImage: "doc.on.doc")
                                .frame(minWidth: 118)
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
            .padding(26)
            .frame(width: 500)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.24), radius: 28, x: 0, y: 18)
        }
        .padding(.vertical, 20)
        .frame(width: 600, height: 470)
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

private struct InstallCommandView: View {
    let command: String

    var body: some View {
        Text(command)
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
