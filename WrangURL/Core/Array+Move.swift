extension Array where Element: Equatable {
    /// Moves `element` to the gap at `insertionIndex`, where 0 is before the first element and
    /// `count` is after the last (indices refer to the array before the move). No-op if absent.
    mutating func move(_ element: Element, toInsertionIndex insertionIndex: Int) {
        guard let from = firstIndex(of: element),
              (0...count).contains(insertionIndex),
              insertionIndex != from, insertionIndex != from + 1 else { return }
        remove(at: from)
        insert(element, at: insertionIndex > from ? insertionIndex - 1 : insertionIndex)
    }
}
