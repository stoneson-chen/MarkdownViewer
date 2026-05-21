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
                    Text(String.appLocalized("about.name"))
                        .font(.title.bold())

                    Text("MarkdownViewer")
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.tertiary)
                }
                
                Text(String.appLocalized("about.tagline"))
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
                    infoTag(label: String.appLocalized("about.version"), value: appVersion)
                    infoTag(label: String.appLocalized("about.build"), value: buildNumber)
                }

                // Developer info
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

                // Copyright & Privacy
                VStack(spacing: 12) {
                    Text(String.appLocalized("about.copyright"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Button(String.appLocalized("about.privacy")) {
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
