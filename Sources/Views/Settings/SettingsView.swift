// * Copyright © 2026  CHENXX & CHENXX.ORG. All rights reserved.
// * CHENXX.ORG 版权所有，全球范围内保留所有权利。
// * 项目名称：MarkdownViewer（墨阅）
// * 开发人员：Chen Xinxing（陈新兴）
// * 创建日期：2026
// *
// * Licensed under the MIT License.
// * See the LICENSE file in the project root for full license text.

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
        Form {
            Section(header: Text(String(localized: "settings.themeMode", bundle: .appResources))) {
                Picker(String(localized: "settings.themeMode", bundle: .appResources), selection: $appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Label(theme.localizedTitle, systemImage: theme.icon)
                            .tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section(header: Text(String(localized: "settings.customCSS", bundle: .appResources))) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "settings.customCSSDesc", bundle: .appResources))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text(customCSSPath.isEmpty
                             ? String(localized: "settings.customCSSNone", bundle: .appResources)
                             : (URL(fileURLWithPath: customCSSPath).lastPathComponent))
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Button(String(localized: "menu.open", bundle: .appResources)) {
                            selectCSSFile()
                        }
                        
                        if !customCSSPath.isEmpty {
                            Button {
                                customCSSPath = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)

                    Text(String(localized: "settings.customCSSTip", bundle: .appResources))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 320)
    }

    // MARK: - Helpers

    private func selectCSSFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.css]

        if panel.runModal() == .OK, let url = panel.url {
            customCSSPath = url.path
        }
    }
}
