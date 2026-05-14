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
}

/// Document view settings
struct SettingsView: View {
    @AppStorage("userCustomCSSPath") private var customCSSPath: String = ""
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label(String(localized: "settings.general", bundle: .appResources), systemImage: "gearshape")
                }
            
            AppearanceSettingsView(customCSSPath: $customCSSPath, appTheme: $appTheme)
                .tabItem {
                    Label(String(localized: "settings.appearance", bundle: .appResources), systemImage: "paintpalette")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section(String(localized: "settings.sectionFile", bundle: .appResources)) {
                Text(String(localized: "settings.comingSoon", bundle: .appResources))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

struct AppearanceSettingsView: View {
    private static let customCSSBookmarkKey = "userCustomCSSBookmark"

    @Binding var customCSSPath: String
    @Binding var appTheme: AppTheme
    
    var body: some View {
        Form {
            Section(String(localized: "settings.theme", bundle: .appResources)) {
                Picker(String(localized: "settings.themeMode", bundle: .appResources), selection: $appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.localizedTitle).tag(theme)
                    }
                }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
            }
            
            Section(String(localized: "settings.customCSS", bundle: .appResources)) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "settings.customCSSDesc", bundle: .appResources))
                        .font(.headline)
                    
                    HStack {
                        TextField(String(localized: "settings.customCSSNone", bundle: .appResources), text: $customCSSPath)
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)
                        
                        Button(String(localized: "menu.open", bundle: .appResources)) {
                            selectCSSFile()
                        }
                    }
                    
                    if !customCSSPath.isEmpty {
                        Button(String(localized: "settings.customCSSRemove", bundle: .appResources)) {
                            customCSSPath = ""
                            UserDefaults.standard.removeObject(forKey: Self.customCSSBookmarkKey)
                        }
                        .buttonStyle(.link)
                        .foregroundStyle(.red)
                    }
                    
                    Text(String(localized: "settings.customCSSTip", bundle: .appResources))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
    
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
