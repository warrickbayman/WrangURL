import Testing
@testable import WrangURL

struct ArrayMoveTests {
    @Test func movesDownIntoGap() {
        var items = ["a", "b", "c", "d"]
        items.move("a", toInsertionIndex: 3) // between c and d
        #expect(items == ["b", "c", "a", "d"])
    }

    @Test func movesUpIntoGap() {
        var items = ["a", "b", "c", "d"]
        items.move("d", toInsertionIndex: 1) // between a and b
        #expect(items == ["a", "d", "b", "c"])
    }

    @Test func movesToEnds() {
        var items = ["a", "b", "c"]
        items.move("a", toInsertionIndex: 3)
        #expect(items == ["b", "c", "a"])
        items.move("a", toInsertionIndex: 0)
        #expect(items == ["a", "b", "c"])
    }

    @Test func gapsAdjacentToElementAreNoOps() {
        var items = ["a", "b", "c"]
        items.move("b", toInsertionIndex: 1)
        items.move("b", toInsertionIndex: 2)
        #expect(items == ["a", "b", "c"])
    }

    @Test func ignoresMissingElementAndBadIndex() {
        var items = ["a", "b"]
        items.move("z", toInsertionIndex: 0)
        items.move("a", toInsertionIndex: 5)
        items.move("a", toInsertionIndex: -1)
        #expect(items == ["a", "b"])
    }
}
