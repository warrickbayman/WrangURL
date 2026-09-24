import AppKit
import Testing
@testable import WrangURL

struct PickerActionTests {
    private func action(_ keyCode: UInt16, _ characters: String? = nil, _ modifiers: NSEvent.ModifierFlags = []) -> PickerAction? {
        PickerAction(keyCode: keyCode, characters: characters, modifiers: modifiers)
    }

    @Test func digitsChooseByPosition() {
        #expect(action(18, "1") == .choose(index: 0))
        #expect(action(25, "9") == .choose(index: 8))
        #expect(action(29, "0") == nil)
    }

    @Test func navigationKeys() {
        #expect(action(36) == .chooseSelected)
        #expect(action(76) == .chooseSelected)
        #expect(action(53) == .cancel)
        #expect(action(123) == .moveSelection(by: -1))
        #expect(action(124) == .moveSelection(by: 1))
        #expect(action(48) == .moveSelection(by: 1))
        #expect(action(48, nil, .shift) == .moveSelection(by: -1))
    }

    @Test func commandC() {
        #expect(action(8, "c", .command) == .copyURL)
        #expect(action(18, "1", .command) == nil)
    }

    @Test func otherKeysAreIgnored() {
        #expect(action(0, "a") == nil)
    }
}

@MainActor
struct PickerModelTests {
    private func model(count: Int) -> PickerModel {
        let browsers = (0..<count).map { Browser(id: "b\($0)", name: "B\($0)", url: URL(filePath: "/Applications/B\($0).app")) }
        return PickerModel(url: URL(string: "https://example.com")!, browsers: browsers, icons: [:])
    }

    @Test func selectionWrapsAround() {
        let model = model(count: 3)
        model.moveSelection(by: -1)
        #expect(model.selectedIndex == 2)
        model.moveSelection(by: 1)
        #expect(model.selectedIndex == 0)
    }
}
