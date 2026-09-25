import SwiftUI
import UniformTypeIdentifiers

struct RuleEditorView: View {
    @Environment(BrowserRegistry.self) private var browsers
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Rule
    @State private var testInput = ""
    /// Browser being dragged, set when the drag starts.
    @State private var draggingID: String?
    /// Where the dragged browser would land: 0 is above the first row, `count` below the last.
    @State private var insertionIndex: Int?
    @State private var rowHeights: [String: CGFloat] = [:]
    let isNew: Bool
    let onSave: (Rule) -> Void

    init(rule: Rule, isNew: Bool, onSave: @escaping (Rule) -> Void) {
        _draft = State(initialValue: rule)
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $draft.name, prompt: Text("Optional"))
                    Picker("Type", selection: $draft.kind) {
                        Text("Simple").tag(Rule.Kind.simple)
                        Text("Regular Expression").tag(Rule.Kind.regex)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextField("Pattern", text: $draft.pattern, prompt: Text(patternPrompt))
                        .labelsHidden()
                        .font(.body.monospaced())
                } header: {
                    Text("Pattern")
                } footer: {
                    patternHint
                }

                Section {
                    if draft.browserIDs.isEmpty {
                        Text("No browsers yet")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(draft.browserIDs.enumerated()), id: \.element) { index, id in
                        selectedBrowserRow(id: id, index: index)
                    }
                    addBrowserMenu
                } header: {
                    Text("Open In")
                } footer: {
                    Text("One browser opens directly. With two or more, you choose from the picker, in this order. Drag to reorder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Test") {
                    TextField("URL", text: $testInput, prompt: Text("Paste a URL to check it against this rule"))
                        .labelsHidden()
                        .font(.body.monospaced())
                    if let testResult {
                        Label(testResult.text, systemImage: testResult.matches ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(testResult.matches ? .green : .secondary)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isNew ? "Add Rule" : "Save") {
                    draft.pattern = draft.pattern.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(12)
        }
        .frame(width: 520, height: 500)
        #if DEBUG
        // Launch with `-DebugInsertionIndex <n>` to preview the drop indicator (for UI work).
        .onAppear {
            insertionIndex = UserDefaults.standard.string(forKey: "DebugInsertionIndex").flatMap(Int.init)
        }
        #endif
    }

    // MARK: - Pattern

    private var patternError: PatternError? {
        RuleMatcher.validate(draft.pattern, kind: draft.kind)
    }

    private var patternPrompt: String {
        switch draft.kind {
        case .simple: "localhost, *.example.com, github.com/org/*"
        case .regex: #"^https://(www\.)?example\.com/"#
        }
    }

    @ViewBuilder
    private var patternHint: some View {
        if draft.pattern.isEmpty {
            Text(draft.kind == .simple
                 ? "Without a scheme, http and https both match. Without a port, any port matches. Use * as a wildcard."
                 : "Searched anywhere in the full URL. Case-sensitive; start with (?i) to ignore case.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let patternError {
            Text(patternError.localizedDescription)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Browsers

    private func selectedBrowserRow(id: String, index: Int) -> some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .help("Drag to reorder")
            BrowserIcon(id: id, size: 20)
            Text(browsers.name(forID: id))
            if browsers.resolve(id) == nil {
                Text("Not installed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { draft.browserIDs.remove(at: index) } label: { Image(systemName: "minus.circle.fill") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Remove")
        }
        // Extend the row through the form's row padding to the dividers, so the gaps
        // between rows are drop targets too. The negative padding below undoes the
        // layout change.
        .padding(.vertical, Self.rowInset)
        .contentShape(.rect)
        .overlay(alignment: .top) {
            if showsInsertionLine(at: index) {
                InsertionLine().offset(y: -1.5)
            }
        }
        .overlay(alignment: .bottom) {
            if index == draft.browserIDs.count - 1, showsInsertionLine(at: index + 1) {
                InsertionLine().offset(y: 1.5)
            }
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { rowHeights[id] = geometry.size.height }
                    .onChange(of: geometry.size.height) { _, height in rowHeights[id] = height }
            }
        }
        .onDrag {
            draggingID = id
            let provider = NSItemProvider()
            provider.registerDataRepresentation(
                forTypeIdentifier: UTType.wrangurlBrowser.identifier,
                visibility: .ownProcess
            ) { completion in
                completion(Data(id.utf8), nil)
                return nil
            }
            return provider
        } preview: {
            HStack {
                BrowserIcon(id: id, size: 20)
                Text(browsers.name(forID: id))
            }
            .padding(6)
        }
        .onDrop(of: [.wrangurlBrowser], delegate: BrowserRowDropDelegate(
            index: index,
            rowHeight: rowHeights[id] ?? 0,
            isActive: draggingID != nil,
            insertionIndex: $insertionIndex,
            onDrop: { destination in
                guard let draggingID else { return }
                withAnimation(.snappy) {
                    draft.browserIDs.move(draggingID, toInsertionIndex: destination)
                }
                self.draggingID = nil
            }
        ))
        .padding(.vertical, -Self.rowInset)
    }

    /// Vertical padding a grouped form puts above and below each row's content.
    private static let rowInset: CGFloat = 10

    /// Hides the line where dropping wouldn't change anything (directly above or below the dragged row).
    private func showsInsertionLine(at position: Int) -> Bool {
        guard insertionIndex == position else { return false }
        guard let draggingID, let from = draft.browserIDs.firstIndex(of: draggingID) else { return true }
        return position != from && position != from + 1
    }

    private var addBrowserMenu: some View {
        let available = browsers.browsers.filter { !draft.browserIDs.contains($0.id) }
        return Menu("Add Browser") {
            ForEach(available) { browser in
                Button {
                    draft.browserIDs.append(browser.id)
                } label: {
                    Label {
                        Text(browser.name)
                    } icon: {
                        if let icon = browsers.menuIcon(forID: browser.id) {
                            Image(nsImage: icon)
                        }
                    }
                }
            }
        }
        .disabled(available.isEmpty)
        .fixedSize()
    }

    // MARK: - Test

    private var testResult: (matches: Bool, text: String)? {
        guard !testInput.isEmpty else { return nil }
        guard let url = URL(userInput: testInput) else { return (false, "Not a valid URL") }
        guard patternError == nil else { return (false, "Fix the pattern first") }
        var rule = draft
        rule.isEnabled = true
        let matches = RuleMatcher(rules: [rule]).match(url) != nil
        return (matches, matches ? "This rule matches" : "This rule doesn't match")
    }

    private var canSave: Bool {
        patternError == nil && !draft.browserIDs.isEmpty
    }
}

/// Tracks whether the pointer is over the top or bottom half of a browser row, so the
/// insertion line can be drawn on the divider above or below it.
private struct BrowserRowDropDelegate: DropDelegate {
    let index: Int
    let rowHeight: CGFloat
    let isActive: Bool
    @Binding var insertionIndex: Int?
    let onDrop: (Int) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        isActive
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        insertionIndex = info.location.y < rowHeight / 2 ? index : index + 1
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        insertionIndex = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let destination = insertionIndex else { return false }
        insertionIndex = nil
        onDrop(destination)
        return true
    }
}

private struct InsertionLine: View {
    var body: some View {
        Capsule()
            .fill(Color.accentColor)
            .frame(height: 3)
            .overlay(alignment: .leading) {
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .background(Circle().fill(.background))
                    .frame(width: 8, height: 8)
                    .offset(x: -4)
            }
            .allowsHitTesting(false)
    }
}

/// Private to this process, so dragged rows can't be dropped as text into the pattern or test fields.
private extension UTType {
    static let wrangurlBrowser = UTType(exportedAs: "com.thepublicgood.wrangurl.browser")
}
