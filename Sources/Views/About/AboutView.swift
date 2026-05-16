// * Copyright © 2026  CHENXX & CHENXX.ORG. All rights reserved.
// * CHENXX.ORG 版权所有，全球范围内保留所有权利。
// * 项目名称：MarkdownViewer（墨阅）
// * 开发人员：Chen Xinxing（陈新兴）
// * 创建日期：2026
// *
// * Licensed under the MIT License.
// * See the LICENSE file in the project root for full license text.

import SwiftUI

/// Beautiful About window showcasing app info and developer credits.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showPrivacy = false

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(spacing: 24) {
            // MARK: - Header
            VStack(spacing: 12) {
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 4) {
                    Text(String(localized: "about.name", bundle: .appResources))
                        .font(.title.bold())
                    
                    Text("MarkdownViewer")
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.tertiary)
                }
                
                Text(String(localized: "about.tagline", bundle: .appResources))
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)

            Divider()
                .padding(.horizontal, 40)

            // MARK: - Info section
            VStack(spacing: 20) {
                // Version info
                HStack(spacing: 32) {
                    infoTag(label: String(localized: "about.version", bundle: .appResources), value: appVersion)
                    infoTag(label: String(localized: "about.build", bundle: .appResources), value: buildNumber)
                }

                // Developer info
                VStack(spacing: 8) {
                    Text(String(localized: "about.author", bundle: .appResources))
                        .font(.headline)

                    HStack(spacing: 16) {
                        Link("Website", destination: URL(string: "https://www.chenxx.org")!)
                        Text("•").foregroundStyle(.quaternary)
                        Link("Email", destination: URL(string: "mailto:a@chenxx.org")!)
                    }
                    .font(.subheadline)
                }

                // Copyright & Privacy
                VStack(spacing: 12) {
                    Text(String(localized: "about.copyright", bundle: .appResources))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Button("隐私政策") {
                        showPrivacy = true
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
                .padding(.bottom, 24)
            }
        }
        .frame(width: 360)
        .background(.background)
        .sheet(isPresented: $showPrivacy) {
            PrivacyView()
        }
    }

    // MARK: - Components

    private func infoTag(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
        }
    }
}
