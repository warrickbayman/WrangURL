import SwiftUI

struct RulesSettingsView: View {
    @Environment(ConfigStore.self) private var config

    @State private var selection = Set<Rule.ID>()
    @State private var editing: EditorSession?

    private struct EditorSession: Identifiable {
        var rule: Rule
        var isNew: Bool
        var id: Rule.ID { rule.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(config.config.rules) { rule in
                    RuleRow(rule: rule, isEnabled: enabledBinding(for: rule))
                        .tag(rule.id)
                }
                .onMove { source, destination in
                    config.update { $0.rules.move(fromOffsets: source, toOffset: destination) }
                }
            }
            .contextMenu(forSelectionType: Rule.ID.self) { ids in
                if ids.count == 1, let id = ids.first {
                    Button("Edit…") { edit(id) }
                    Button("Duplicate") { duplicate(id) }
                    Divider()
                }
                if !ids.isEmpty {
                    Button("Delete", role: .destructive) { delete(ids) }
                }
            } primaryAction: { ids in
                if let id = ids.first { edit(id) }
            }
            .onDeleteCommand { delete(selection) }
            .overlay {
                if config.config.rules.isEmpty {
                    ContentUnavailableView {
                        Label("No Rules", systemImage: "arrow.triangle.branch")
                    } description: {
                        Text("Add a rule to send matching links to a specific browser, or to choose between several.")
                    } actions: {
                        Button("Add Rule") { addRule() }
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                Button { addRule() } label: { Image(systemName: "plus") }
                    .help("Add a rule")
                Button { delete(selection) } label: { Image(systemName: "minus") }
                    .help("Delete the selected rules")
                    .disabled(selection.isEmpty)
                Button("Edit…") { selection.first.map(edit) }
                    .disabled(selection.count != 1)
                Spacer()
                Text("Rules are checked from top to bottom. The first match wins. Drag to reorder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .padding(8)

            Divider()

            URLTesterView()
                .padding(12)
        }
        .frame(width: 680, height: 520)
        #if DEBUG
        // Launch with `-DebugEditRule <index>` to open the editor directly (for UI work).
        .task {
            guard let index = UserDefaults.standard.string(forKey: "DebugEditRule").flatMap(Int.init),
                  config.config.rules.indices.contains(index) else { return }
            try? await Task.sleep(for: .milliseconds(500))
            edit(config.config.rules[index].id)
        }
        #endif
        .sheet(item: $editing) { session in
            RuleEditorView(rule: session.rule, isNew: session.isNew) { saved in
                save(saved)
            }
        }
    }

    private func enabledBinding(for rule: Rule) -> Binding<Bool> {
        Binding(
            get: { rule.isEnabled },
            set: { isEnabled in
                config.update { config in
                    if let index = config.rules.firstIndex(where: { $0.id == rule.id }) {
                        config.rules[index].isEnabled = isEnabled
                    }
                }
            }
        )
    }

    private func addRule() {
        editing = EditorSession(rule: Rule(name: "", pattern: "", kind: .simple, browserIDs: []), isNew: true)
    }

    private func edit(_ id: Rule.ID) {
        guard let rule = config.config.rules.first(where: { $0.id == id }) else { return }
        editing = EditorSession(rule: rule, isNew: false)
    }

    private func duplicate(_ id: Rule.ID) {
        guard let index = config.config.rules.firstIndex(where: { $0.id == id }) else { return }
        var copy = config.config.rules[index]
        copy.id = UUID()
        copy.name = "\(copy.displayName) copy"
        config.update { $0.rules.insert(copy, at: index + 1) }
        selection = [copy.id]
    }

    private func delete(_ ids: Set<Rule.ID>) {
        config.update { $0.rules.removeAll { ids.contains($0.id) } }
        selection.subtract(ids)
    }

    private func save(_ rule: Rule) {
        config.update { config in
            if let index = config.rules.firstIndex(where: { $0.id == rule.id }) {
                config.rules[index] = rule
            } else {
                config.rules.append(rule)
            }
        }
        selection = [rule.id]
    }
}

private struct RuleRow: View {
    let rule: Rule
    @Binding var isEnabled: Bool

    private var hasName: Bool {
        !rule.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Enabled", isOn: $isEnabled)
                .labelsHidden()
                .toggleStyle(.checkbox)

            VStack(alignment: .leading, spacing: 2) {
                if hasName {
                    Text(rule.name)
                        .fontWeight(.medium)
                }
                HStack(spacing: 6) {
                    Text(rule.pattern)
                        .font(hasName ? .callout.monospaced() : .body.monospaced())
                        .foregroundStyle(hasName ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if rule.kind == .regex {
                        Text("REGEX")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .background(.quaternary, in: .rect(cornerRadius: 3))
                    }
                }
            }

            Spacer()

            if let error = RuleMatcher.validate(rule.pattern, kind: rule.kind) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .help(error.localizedDescription)
            }

            HStack(spacing: 2) {
                ForEach(rule.browserIDs, id: \.self) { id in
                    BrowserIcon(id: id, size: 22)
                }
            }
        }
        .padding(.vertical, 3)
        .opacity(rule.isEnabled ? 1 : 0.5)
    }
}

/// Shows where a URL would go with the saved rules and settings.
private struct URLTesterView: View {
    @Environment(URLRouter.self) private var router
    @Environment(BrowserRegistry.self) private var browsers
    @Environment(ConfigStore.self) private var config

    @State private var input = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Test a URL", text: $input, prompt: Text("Test a URL, e.g. http://localhost:3000"))
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
            Text(result)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var result: String {
        _ = config.config // Re-evaluate when rules or settings change.
        guard !input.isEmpty else { return " " }
        guard let url = URL(userInput: input) else { return "Not a valid URL" }
        let (rule, decision) = router.preview(url)
        let match = rule.map { "Matches “\($0.displayName)”." } ?? "No rule matches."
        return "\(match) \(browsers.describe(decision))."
    }
}
