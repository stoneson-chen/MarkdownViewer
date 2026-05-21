// * Copyright © 2026  CHENXX & CHENXX.ORG. All rights reserved.
// * CHENXX.ORG 版权所有，全球范围内保留所有权利。
// * 项目名称：MarkdownViewer（墨阅）
// * 开发人员：Chen Xinxing（陈新兴）
// * 创建日期：2026
// *
// * Licensed under the MIT License.
// * See the LICENSE file in the project root for full license text.

import SwiftUI

/// A premium, zero-dependency, and lightweight dual-panel About view.
struct AboutView: View {
    @State private var activeTab: Tab = .about

    enum Tab {
        case about
        case privacy
    }

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    private var privacyContent: AttributedString {
        let markdown = String.appLocalized("privacy.content")
        return (try? AttributedString(
            markdown: markdown,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        )) ?? AttributedString(markdown)
    }

    var body: some View {
        HStack(spacing: 0) {
            // MARK: - Left: Brand Identity Panel
            VStack(spacing: 16) {
                Spacer()
                
                // Dynamically extract native high-res AppIcon to ensure zero third-party assets
                if let appIcon = NSApplication.shared.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                } else {
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                VStack(spacing: 4) {
                    Text(String.appLocalized("about.name"))
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("MarkdownViewer")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("v\(appVersion) (\(buildNumber))")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Spacer()
                
                Text(String.appLocalized("about.tagline"))
                    .font(.system(size: 11))
                    .italic()
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 24)
            }
            .frame(width: 170)
            .frame(maxHeight: .infinity)
            // Premium dark ink-green linear gradient background
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.18, blue: 0.16),
                        Color(red: 0.05, green: 0.10, blue: 0.09)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // MARK: - Right: Segmented Controller & Content Panel
            VStack(spacing: 0) {
                Picker("", selection: $activeTab) {
                    Text(String.appLocalized("menu.about")).tag(Tab.about)
                    Text(String.appLocalized("about.privacy")).tag(Tab.privacy)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Sliding Content Tabs
                Group {
                    switch activeTab {
                    case .about:
                        aboutContentTab
                            .transition(.opacity)
                    case .privacy:
                        privacyContentTab
                            .transition(.opacity)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(width: 310)
            .frame(maxHeight: .infinity)
            .background(.ultraThinMaterial) // Native macOS glassmorphism
        }
        .frame(width: 480, height: 360)
    }

    // MARK: - About Content Tab
    private var aboutContentTab: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 8) {
                Text(String.appLocalized("about.author"))
                    .font(.headline)
                
                HStack(spacing: 16) {
                    Link("Website", destination: URL(string: "https://www.chenxx.org")!)
                    Text("•").foregroundStyle(.quaternary)
                    Link("Email", destination: URL(string: "mailto:a@chenxx.org")!)
                }
                .font(.subheadline)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Text(String.appLocalized("about.copyright"))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Privacy Content Tab
    private var privacyContentTab: some View {
        ScrollView {
            Text(privacyContent)
                .textSelection(.enabled)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.primary.opacity(0.85))
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
