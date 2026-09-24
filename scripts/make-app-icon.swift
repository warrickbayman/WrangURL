#!/usr/bin/env swift
// Renders WrangURL's app icon into WrangURL/Assets.xcassets/AppIcon.appiconset.
// Usage: swift scripts/make-app-icon.swift
import AppKit

let output = URL(filePath: "WrangURL/Assets.xcassets/AppIcon.appiconset", directoryHint: .isDirectory)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func render(pixels: Int) -> Data {
    let size = CGFloat(pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS icon grid: an 824pt rounded square centred on a 1024pt canvas.
    let scale = size / 1024
    let body = NSRect(x: 100 * scale, y: 100 * scale, width: 824 * scale, height: 824 * scale)
    let path = NSBezierPath(roundedRect: body, xRadius: 185 * scale, yRadius: 185 * scale)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -10 * scale)
    shadow.shadowBlurRadius = 20 * scale
    shadow.set()
    NSColor.black.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.20, green: 0.78, blue: 0.74, alpha: 1),
        NSColor(srgbRed: 0.18, green: 0.42, blue: 0.86, alpha: 1),
        NSColor(srgbRed: 0.33, green: 0.22, blue: 0.70, alpha: 1),
    ])!
    gradient.draw(in: path, angle: -60)

    // Soft highlight on the top half.
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    NSGradient(starting: NSColor.white.withAlphaComponent(0.18), ending: .clear)!
        .draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    let config = NSImage.SymbolConfiguration(pointSize: 440 * scale, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let symbolSize = symbol.size
        let rect = NSRect(
            x: body.midX - symbolSize.width / 2,
            y: body.midY - symbolSize.height / 2,
            width: symbolSize.width,
            height: symbolSize.height
        )
        NSGraphicsContext.saveGraphicsState()
        let glyphShadow = NSShadow()
        glyphShadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
        glyphShadow.shadowOffset = NSSize(width: 0, height: -6 * scale)
        glyphShadow.shadowBlurRadius = 12 * scale
        glyphShadow.set()
        symbol.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try render(pixels: points * scale).write(to: output.appending(path: filename))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": filename])
    }
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appending(path: "Contents.json"))

let catalog = output.deletingLastPathComponent().appending(path: "Contents.json")
try Data(#"{"info":{"author":"xcode","version":1}}"#.utf8).write(to: catalog)
print("Wrote \(images.count) icons to \(output.path)")
