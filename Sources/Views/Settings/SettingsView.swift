import SwiftUI

/// App theme options
enum AppTheme: String, CaseIterable, Identifiable {
    case system = "settings.theme.system"
    case light = "settings.theme.light"
    case dark = "settings.theme.dark"

    var id: String { self.rawValue }

    var localizedTitle: String {
        String(localized: String.LocalizationValue(rawValue), bundle: .appResources)
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

/// Settings window
struct SettingsView: View {
    @AppStorage("userCustomCSSPath") private var customCSSPath: String = ""
    @AppStorage("appTheme") private var appTheme: AppTheme = .system

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("设置")
                    .font(.title2.bold())
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 28)

            ScrollView {
                VStack(spacing: 24) {
                    themeSection
                    cssSection
                }
                .padding(24)
            }
        }
        .frame(width: 480, height: 380)
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(String(localized: "settings.themeMode", bundle: .appResources), systemImage: "circle.lefthalf.filled")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(AppTheme.allCases) { theme in
                    themeCard(theme, isSelected: appTheme == theme)
                        .onTapGesture { appTheme = theme }
                }
            }
        }
        .padding(20)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private func themeCard(_ theme: AppTheme, isSelected: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: theme.icon)
                .font(.system(size: 22))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 44, height: 44)
                .background(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary), in: RoundedRectangle(cornerRadius: 10))

            Text(theme.localizedTitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isSelected ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(isSelected ? AnyShapeStyle(.primary.opacity(0.06)) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - CSS Section

    private var cssSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "settings.customCSS", bundle: .appResources), systemImage: "paintpalette.fill")
                .font(.headline)

            Text(String(localized: "settings.customCSSDesc", bundle: .appResources))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text(customCSSPath.isEmpty
                     ? String(localized: "settings.customCSSNone", bundle: .appResources)
                     : (URL(fileURLWithPath: customCSSPath).lastPathComponent))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(customCSSPath.isEmpty ? .tertiary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    selectCSSFile()
                } label: {
                    Label(String(localized: "menu.open", bundle: .appResources), systemImage: "folder")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if !customCSSPath.isEmpty {
                    Button {
                        customCSSPath = ""
                        UserDefaults.standard.removeObject(forKey: Self.customCSSBookmarkKey)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))

            Text(String(localized: "settings.customCSSTip", bundle: .appResources))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    private static let customCSSBookmarkKey = "userCustomCSSBookmark"

    private func selectCSSFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.css]

        if panel.runModal() == .OK {
            guard let url = panel.url else { return }
            customCSSPath = url.path

            if let bookmark = try? url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                UserDefaults.standard.set(bookmark, forKey: Self.customCSSBookmarkKey)
            }
        }
    }
}
