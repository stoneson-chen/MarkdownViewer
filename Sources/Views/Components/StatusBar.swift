import SwiftUI

/// Bottom status bar showing document statistics and mode info.
struct StatusBar: View {
    @Bindable var viewModel: DocumentViewModel

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "list.number")
                Text("\(viewModel.lineCount) \(String(localized: "status.lines", bundle: .appResources))")
            }
            
            HStack(spacing: 4) {
                Text("\(String(localized: "status.totalCharacters", bundle: .appResources))\(viewModel.characterCount)")
            }

            Spacer()

            // Current mode indicator
            HStack(spacing: 4) {
                Image(systemName: viewModel.isEditing ? "pencil.line" : "eye.fill")
                    .font(.system(size: 10))
                Text(String(localized: viewModel.isEditing ? "status.edit" : "status.preview", bundle: .appResources))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary.opacity(0.5), in: Capsule())

            if viewModel.isEditing {
                Text(viewModel.splitOrientation.displayName)
            }

            Text("UTF-8")
            Text("Markdown")

            // Dirty indicator
            Circle()
                .fill(viewModel.isDirty ? .orange : .green)
                .frame(width: 6, height: 6)
                .help(String(localized: viewModel.isDirty ? "status.unsaved" : "status.saved", bundle: .appResources))
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
