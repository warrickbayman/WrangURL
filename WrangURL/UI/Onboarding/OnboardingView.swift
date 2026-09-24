import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case fallback
    case unmatched
    case defaultBrowser
    case launchAtLogin
}

struct OnboardingView: View {
    @Environment(ConfigStore.self) private var config
    @Environment(URLRouter.self) private var router

    @State private var step: OnboardingStep
    let onFinish: (_ openRules: Bool) -> Void

    init(step: OnboardingStep = .fallback, onFinish: @escaping (_ openRules: Bool) -> Void) {
        _step = State(initialValue: step)
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .fallback: FallbackStep()
                case .unmatched: UnmatchedStep()
                case .defaultBrowser: DefaultBrowserStep()
                case .launchAtLogin: LaunchAtLoginStep()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 44)
            .padding(.top, 40)

            Divider()

            HStack(spacing: 10) {
                StepDots(current: step.rawValue, count: OnboardingStep.allCases.count)
                Spacer()
                if let previous = OnboardingStep(rawValue: step.rawValue - 1) {
                    Button("Back") { step = previous }
                }
                if let next = OnboardingStep(rawValue: step.rawValue + 1) {
                    Button("Continue") { step = next }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Add a Rule") { onFinish(true) }
                    Button("Done") { onFinish(false) }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .controlSize(.large)
            .padding(16)
        }
        .frame(width: 600, height: 480)
        .onAppear {
            // Normally captured from the previous default browser at launch; make sure
            // something sensible is selected if that wasn't possible.
            if config.config.settings.fallbackBrowserID == nil, let fallback = router.planner.fallbackBrowserID {
                config.update { $0.settings.fallbackBrowserID = fallback }
            }
        }
    }
}

// MARK: - Steps

private struct StepHeader: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.tint)
            Text(title)
                .font(.title.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 20)
    }
}

private struct FallbackStep: View {
    @Environment(ConfigStore.self) private var config
    @Environment(BrowserRegistry.self) private var browsers

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeader(
                symbol: "arrow.triangle.branch",
                title: "Welcome to WrangURL",
                message: "WrangURL sends each link you open to the right browser, based on rules you set. First, choose the browser for links that no rule covers."
            )
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(browsers.browsers) { browser in
                        BrowserTile(browser: browser, isSelected: config.config.settings.fallbackBrowserID == browser.id) {
                            config.update { $0.settings.fallbackBrowserID = browser.id }
                        }
                    }
                }
            }
        }
    }
}

private struct BrowserTile: View {
    let browser: Browser
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                BrowserIcon(id: browser.id, size: 48)
                Text(browser.name)
                    .font(.callout)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
            .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct UnmatchedStep: View {
    @Environment(ConfigStore.self) private var config
    @Environment(BrowserRegistry.self) private var browsers

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StepHeader(
                symbol: "questionmark.circle",
                title: "Links without a rule",
                message: "When you open a link that doesn't match any of your rules, WrangURL can open it straight away or let you choose."
            )
            OptionCard(
                symbol: "arrow.up.forward.app",
                title: "Open in \(fallbackName)",
                detail: "Links go straight to your fallback browser.",
                isSelected: behavior == .openFallback
            ) { setBehavior(.openFallback) }
            OptionCard(
                symbol: "square.grid.2x2",
                title: "Ask me each time",
                detail: "Shows the browser picker so you can choose where the link opens.",
                isSelected: behavior == .showPicker
            ) { setBehavior(.showPicker) }
        }
    }

    private var behavior: UnmatchedBehavior {
        config.config.settings.unmatchedBehavior
    }

    private var fallbackName: String {
        config.config.settings.fallbackBrowserID.map(browsers.name(forID:)) ?? "the fallback browser"
    }

    private func setBehavior(_ behavior: UnmatchedBehavior) {
        config.update { $0.settings.unmatchedBehavior = behavior }
    }
}

private struct OptionCard: View {
    let symbol: String
    let title: String
    let detail: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title2)
                    .frame(width: 32)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(detail).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
            .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct DefaultBrowserStep: View {
    @Environment(DefaultBrowserManager.self) private var defaultBrowser

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(
                symbol: "link",
                title: "Make WrangURL your default browser",
                message: "To route links from other apps, WrangURL has to be the default browser. It passes each link on to the browser your rules choose. macOS will ask you to confirm."
            )
            if defaultBrowser.isDefault {
                Label("WrangURL is your default browser", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            } else {
                Button("Set as Default Browser") {
                    Task { await defaultBrowser.makeDefault() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Text("You can also do this later from the menu bar icon.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let error = defaultBrowser.lastError {
                Text(error).foregroundStyle(.red)
            }
        }
        .onAppear { defaultBrowser.refresh() }
    }
}

private struct LaunchAtLoginStep: View {
    @Environment(LoginItemManager.self) private var loginItem

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(
                symbol: "power",
                title: "Open at login",
                message: "WrangURL lives in the menu bar. Open it at login so your links are always routed, even after a restart."
            )
            Toggle("Open WrangURL at login", isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.setEnabled($0) }
            ))
            .toggleStyle(.switch)
            .font(.headline)

            if loginItem.requiresApproval {
                LoginItemApprovalNote()
            }
            if let error = loginItem.lastError {
                Text(error).foregroundStyle(.red)
            }

            Spacer()

            Label("You're all set. Add rules any time from the menu bar icon.", systemImage: "checkmark.seal")
                .foregroundStyle(.secondary)
        }
        .onAppear { loginItem.refresh() }
    }
}

/// Shown when macOS needs the user to allow the login item in System Settings.
struct LoginItemApprovalNote: View {
    @Environment(LoginItemManager.self) private var loginItem

    var body: some View {
        HStack {
            Label("Allow WrangURL in System Settings to finish turning this on.", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Button("Open Login Items…") { loginItem.openSystemSettings() }
        }
    }
}

private struct StepDots: View {
    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}
