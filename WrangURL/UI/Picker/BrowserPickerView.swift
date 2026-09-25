import SwiftUI

@MainActor
@Observable
final class PickerModel {
    let url: URL
    let browsers: [Browser]
    let icons: [String: NSImage]
    var selectedIndex = 0

    @ObservationIgnored var onChoose: (Browser) -> Void = { _ in }
    @ObservationIgnored var onCopy: () -> Void = {}

    init(url: URL, browsers: [Browser], icons: [String: NSImage]) {
        self.url = url
        self.browsers = browsers
        self.icons = icons
    }

    func moveSelection(by offset: Int) {
        guard !browsers.isEmpty else { return }
        selectedIndex = (selectedIndex + offset + browsers.count) % browsers.count
    }
}

struct BrowserPickerView: View {
    let model: PickerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.url.absoluteString)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 440, alignment: .leading)
                .help(model.url.absoluteString)

            HStack(spacing: 4) {
                ForEach(Array(model.browsers.enumerated()), id: \.element.id) { index, browser in
                    BrowserChoice(
                        browser: browser,
                        icon: model.icons[browser.id],
                        shortcut: index < 9 ? "\(index + 1)" : nil,
                        isSelected: index == model.selectedIndex
                    ) {
                        model.onChoose(browser)
                    }
                    .onHover { hovering in
                        if hovering { model.selectedIndex = index }
                    }
                }
            }

            HStack {
                Text("esc to cancel")
                Spacer()
                Button("Copy Link  ⌘C") { model.onCopy() }
                    .buttonStyle(.plain)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .fixedSize()
    }
}

private struct BrowserChoice: View {
    let browser: Browser
    let icon: NSImage?
    let shortcut: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Group {
                    if let icon {
                        Image(nsImage: icon).resizable()
                    } else {
                        Image(systemName: "globe").resizable().foregroundStyle(.secondary)
                    }
                }
                .frame(width: 48, height: 48)

                Text(browser.name)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(shortcut ?? " ")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            .frame(width: 80)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.25) : .clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open in \(browser.name)")
    }
}
