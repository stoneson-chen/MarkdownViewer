import SwiftUI

/// Beautiful About window showcasing app info and developer credits.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top gradient section
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.15, blue: 0.22),
                        Color(red: 0.10, green: 0.10, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Subtle pattern overlay
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(x: -80, y: -60)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.12), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .offset(x: 100, y: 40)

                VStack(spacing: 16) {
                    // App icon
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 12, y: 4)

                    VStack(spacing: 6) {
                        Text(String(localized: "about.name", bundle: .appResources))
                            .font(.system(size: 28, weight: .semibold, design: .serif))
                            .foregroundColor(.white)

                        Text("MarkdownViewer")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    // Tagline
                    Text(String(localized: "about.tagline", bundle: .appResources))
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .foregroundColor(.white.opacity(0.7))
                        .italic()
                }
                .padding(.vertical, 36)
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 0))

            // MARK: - Info section
            VStack(spacing: 20) {
                // Version info
                HStack(spacing: 24) {
                    infoTag(label: String(localized: "about.version", bundle: .appResources), value: appVersion)
                    infoTag(label: String(localized: "about.build", bundle: .appResources), value: buildNumber)
                    infoTag(label: String(localized: "about.engine", bundle: .appResources), value: "Swift 6.2")
                }
                .padding(.top, 20)

                Divider()
                    .padding(.horizontal, 32)

                // Developer info
                VStack(spacing: 12) {
                    Text(String(localized: "about.developer", bundle: .appResources))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(1.5)

                    Text(String(localized: "about.author", bundle: .appResources))
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundColor(.primary)

                    HStack(spacing: 20) {
                        // Website link
                        Link(destination: URL(string: "https://www.chenxx.org")!) {
                            HStack(spacing: 5) {
                                Image(systemName: "globe")
                                    .font(.system(size: 12))
                                Text("chenxx.org")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.accentColor)
                        }
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }

                        Text("·")
                            .foregroundStyle(.quaternary)

                        // Email link
                        Link(destination: URL(string: "mailto:a@chenxx.org")!) {
                            HStack(spacing: 5) {
                                Image(systemName: "envelope")
                                    .font(.system(size: 12))
                                Text("a@chenxx.org")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.accentColor)
                        }
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                }

                Divider()
                    .padding(.horizontal, 32)

                // Copyright
                Text(String(localized: "about.copyright", bundle: .appResources))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)

                // MIT badge
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10))
                    Text("MIT License")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.5), in: Capsule())
                .padding(.bottom, 20)
            }
        }
        .frame(width: 380)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Components

    private func infoTag(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(1)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}
