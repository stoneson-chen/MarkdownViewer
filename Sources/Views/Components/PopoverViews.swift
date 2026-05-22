// * Copyright © 2026  CHENXX & CHENXX.ORG. All rights reserved.
// * CHENXX.ORG 版权所有，全球范围内保留所有权利。
// * 项目名称：MarkdownViewer（墨阅）
// * 开发人员：Chen Xinxing（陈新兴）
// * 创建日期：2026
// *
// * Licensed under the MIT License.
// * See the LICENSE file in the project root for full license text.

import SwiftUI
import AppKit

/// Typography tuning popup
struct TypographyPopoverView: View {
    @AppStorage("editorFontSize") private var editorFontSize: Double = 15.0
    @AppStorage("editorFontFamily") private var editorFontFamily: String = "SF Pro"
    @AppStorage("editorLineHeight") private var editorLineHeight: Double = 1.6
    @AppStorage("previewTheme") private var previewTheme: String = "light"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "typography.title", bundle: .appResources))
                .font(.headline)
                .padding(.bottom, 4)

            // Font Family
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "typography.font", bundle: .appResources))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $editorFontFamily) {
                    Text("SF Pro").tag("SF Pro")
                    Text("SF Mono").tag("SF Mono")
                    Text("New York").tag("New York")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Font Size
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "typography.fontSize", bundle: .appResources))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Slider(value: $editorFontSize, in: 12...24, step: 1.0)
                    Text("\(Int(editorFontSize)) px")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 48, alignment: .trailing)
                }
            }

            // Line Height
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "typography.lineHeight", bundle: .appResources))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $editorLineHeight) {
                    Text("1.4 (Compact)").tag(1.4)
                    Text("1.6 (Normal)").tag(1.6)
                    Text("1.8 (Loose)").tag(1.8)
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }

            // Themes Grid (Luxury presets)
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "typography.theme", bundle: .appResources))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    ThemeButton(
                        id: "light",
                        label: String(localized: "typography.theme.light", bundle: .appResources),
                        bg: Color.white,
                        fg: Color.black,
                        borderColor: Color.gray.opacity(0.3),
                        selectedId: $previewTheme
                    )
                    
                    ThemeButton(
                        id: "dark",
                        label: String(localized: "typography.theme.dark", bundle: .appResources),
                        bg: Color(red: 0.11, green: 0.11, blue: 0.12),
                        fg: Color.white,
                        borderColor: Color.clear,
                        selectedId: $previewTheme
                    )
                    
                    ThemeButton(
                        id: "sepia",
                        label: String(localized: "typography.theme.sepia", bundle: .appResources),
                        bg: Color(red: 0.96, green: 0.93, blue: 0.85),
                        fg: Color(red: 0.36, green: 0.27, blue: 0.21),
                        borderColor: Color.clear,
                        selectedId: $previewTheme
                    )
                    
                    ThemeButton(
                        id: "ocean",
                        label: String(localized: "typography.theme.ocean", bundle: .appResources),
                        bg: Color(red: 0.04, green: 0.10, blue: 0.18),
                        fg: Color(red: 0.89, green: 0.95, blue: 1.0),
                        borderColor: Color.clear,
                        selectedId: $previewTheme
                    )
                }
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}

private struct ThemeButton: View {
    let id: String
    let label: String
    let bg: Color
    let fg: Color
    let borderColor: Color
    @Binding var selectedId: String

    var body: some View {
        Button {
            selectedId = id
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(bg)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.accentColor, lineWidth: selectedId == id ? 2.5 : 0)
                            .padding(-3)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(selectedId == id ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

/// Pro document export popover
struct ExportPopoverView: View {
    let commandScope: WindowCommandScope
    @State private var format: String = "pdf"
    @State private var margin: Double = 36.0
    @State private var includeTOC: Bool = false
    @State private var syntaxHighlight: Bool = true
    @State private var embedImages: Bool = true
    @State private var applyCSS: Bool = true
    
    @State private var isExporting: Bool = false
    
    let onGenerate: (String, Double, Bool, Bool, Bool, Bool) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "export.title", bundle: .appResources))
                .font(.headline)
                .padding(.bottom, 4)

            // Export Format
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "export.format", bundle: .appResources))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $format) {
                    Text(String(localized: "export.format.pdf", bundle: .appResources)).tag("pdf")
                    Text(String(localized: "export.format.docx", bundle: .appResources)).tag("docx")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if format == "pdf" {
                // PDF Margin Slider
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "export.margin", bundle: .appResources))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Slider(value: $margin, in: 10...90, step: 2.0)
                        Text("\(Int(margin)) pt")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }

            // Toggle Switches
            VStack(alignment: .leading, spacing: 8) {
                Toggle(String(localized: "export.includeTOC", bundle: .appResources), isOn: $includeTOC)
                Toggle(String(localized: "export.syntaxHighlight", bundle: .appResources), isOn: $syntaxHighlight)
                Toggle(String(localized: "export.embedImages", bundle: .appResources), isOn: $embedImages)
                Toggle(String(localized: "export.applyCSS", bundle: .appResources), isOn: $applyCSS)
            }
            .toggleStyle(.checkbox)
            .font(.system(size: 11))

            Divider()
                .padding(.vertical, 2)

            // Action Button
            Button {
                isExporting = true
                onGenerate(format, margin, includeTOC, syntaxHighlight, embedImages, applyCSS)
            } label: {
                HStack {
                    Spacer()
                    if isExporting {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "arrow.down.doc.fill")
                    }
                    Text(String(localized: "export.generate", bundle: .appResources))
                        .fontWeight(.medium)
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(isExporting)
        }
        .padding(16)
        .frame(width: 280)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("exportDidFinish"))) { notification in
            guard notification.object as? WindowCommandScope === commandScope else { return }
            isExporting = false
        }
    }
}
