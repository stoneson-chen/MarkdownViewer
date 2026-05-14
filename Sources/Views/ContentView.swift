import SwiftUI

/// Main content view: preview-only by default, dual-pane when editing.
struct ContentView: View {
    @State private var viewModel = DocumentViewModel()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var hasLoadedInitialContent = false
    @State private var commandScope = WindowCommandScope()

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detailContent
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                toolbarContent
            }
        }
        .navigationTitle(viewModel.windowTitle)
        .task {
            guard !hasLoadedInitialContent else { return }
            hasLoadedInitialContent = true
            await viewModel.loadInitialContent()
            if viewModel.fileURL != nil {
                columnVisibility = .all
            }
        }
        .onAppear {
            AppDelegate.registerWindow(
                scope: commandScope,
                canReuse: { viewModel.canReuseForExternalOpen },
                openURL: { viewModel.openFile($0) }
            )
        }
        .onDisappear {
            AppDelegate.unregisterWindow(scope: commandScope)
        }
        .focusedValue(\.documentCommandActions, commandActions)
        .alert(String(localized: "common.error", bundle: .appResources), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(String(localized: "common.ok", bundle: .appResources)) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .overlay(alignment: .bottom) {
            StatusBar(viewModel: viewModel)
        }
        .onChange(of: viewModel.fileURL) { _, newValue in
            if newValue != nil {
                withAnimation {
                    columnVisibility = .all
                }
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        OutlineView(
            headings: viewModel.headings,
            activeHeadingID: viewModel.activeHeadingID
        ) { heading in
            viewModel.scrollToHeading(heading, scope: commandScope)
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 350)
        .padding(.top, 8)
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        if viewModel.isEditing {
            editingLayout
        } else {
            previewOnlyLayout
        }
    }

    private var previewOnlyLayout: some View {
        PreviewView(viewModel: viewModel, commandScope: commandScope)
    }

    @ViewBuilder
    private var editingLayout: some View {
        switch viewModel.splitOrientation {
        case .horizontal:
            HSplitView {
                editorPane
                previewPane
            }
        case .vertical:
            VSplitView {
                editorPane
                previewPane
            }
        }
    }

    private var editorPane: some View {
        EditorView(text: Binding(
            get: { viewModel.text },
            set: { viewModel.textDidChange($0) }
        ), commandScope: commandScope)
        .frame(minWidth: 280, minHeight: 200)
    }

    private var previewPane: some View {
        PreviewView(viewModel: viewModel, commandScope: commandScope)
            .frame(minWidth: 280, minHeight: 200)
    }

    private var commandActions: DocumentCommandActions {
        DocumentCommandActions(
            isDirty: viewModel.isDirty,
            isEditing: viewModel.isEditing,
            openFile: { viewModel.openFilePanel() },
            saveFile: { viewModel.saveFile() },
            saveFileAs: { viewModel.saveFileAs() },
            toggleEditing: { viewModel.toggleEditing() },
            toggleSplitOrientation: { viewModel.toggleSplitOrientation() },
            formatBold: { postFormatCommand(.formatBold) },
            formatItalic: { postFormatCommand(.formatItalic) },
            formatCode: { postFormatCommand(.formatCode) },
            formatH1: { postFormatCommand(.formatH1) },
            formatH2: { postFormatCommand(.formatH2) },
            formatH3: { postFormatCommand(.formatH3) },
            formatLink: { postFormatCommand(.formatLink) },
            formatImage: { postFormatCommand(.formatImage) }
        )
    }

    private func postFormatCommand(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: commandScope)
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbarContent: some View {
        // Open file
        Button {
            viewModel.openFilePanel()
        } label: {
            Image(systemName: "doc.badge.plus")
        }
        .help(String(localized: "toolbar.openFile", bundle: .appResources))

        Divider()

        // Toggle editing
        Button {
            viewModel.toggleEditing()
        } label: {
            Image(systemName: viewModel.isEditing ? "eye.fill" : "pencil.line")
        }
        .help(viewModel.isEditing ? String(localized: "toolbar.previewMode", bundle: .appResources) : String(localized: "toolbar.editMode", bundle: .appResources))

        // Split orientation (only visible in editing mode)
        if viewModel.isEditing {
            Button {
                viewModel.toggleSplitOrientation()
            } label: {
                Image(systemName: viewModel.splitOrientation.systemImage)
            }
            .help(String(localized: "toolbar.toggleSplit", bundle: .appResources))
        }

        // Dirty indicator
        if viewModel.isDirty {
            Text(String(localized: "status.unsaved", bundle: .appResources))
                .font(.caption)
                .foregroundColor(.orange)
        }
    }
}
