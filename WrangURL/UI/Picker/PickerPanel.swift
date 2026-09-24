import AppKit

/// Borderless floating panel that takes keyboard focus without activating WrangURL,
/// so the app the link came from stays frontmost.
final class PickerPanel: NSPanel {
    /// Return true if the event was handled.
    var onKeyDown: ((NSEvent) -> Bool)?
    var onResignKey: (() -> Void)?

    static let cornerRadius: CGFloat = 16

    init(contentView: NSView) {
        let size = contentView.fittingSize
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        self.contentView = Self.roundedBackground(around: contentView, size: size)
    }

    /// The window's shape comes from a masked `NSVisualEffectView`: the mask makes the window
    /// itself rounded, so its shadow and edge follow the corners. On its own, a SwiftUI
    /// background or an `NSGlassEffectView` draws rounded but leaves the window rectangular,
    /// with the shadow showing as square corners. On macOS 26 the glass sits inside the mask.
    private static func roundedBackground(around content: NSView, size: NSSize) -> NSView {
        content.frame = NSRect(origin: .zero, size: size)
        content.autoresizingMask = [.width, .height]

        let effect = NSVisualEffectView(frame: content.frame)
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        // A mask image (not a layer corner radius) also shapes the behind-window blur and the shadow.
        effect.maskImage = roundedMask(radius: cornerRadius)

        if #available(macOS 26, *) {
            let glass = NSGlassEffectView(frame: content.frame)
            glass.autoresizingMask = [.width, .height]
            glass.cornerRadius = cornerRadius
            glass.contentView = content
            effect.addSubview(glass)
        } else {
            effect.addSubview(content)
        }
        return effect
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, onKeyDown?(event) == true {
            return
        }
        super.sendEvent(event)
    }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }

    /// Places the panel just below the mouse, kept inside the visible area of its screen.
    func positionNearMouse() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        let size = frame.size
        let gap: CGFloat = 12

        var origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - gap - size.height)
        if origin.y < visible.minY {
            origin.y = mouse.y + gap
        }
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        setFrameOrigin(origin)
    }
}
