import AppKit
import Foundation

struct Palette {
    static let blueDark = NSColor(calibratedRed: 0.18, green: 0.46, blue: 1.00, alpha: 1.0)
    static let blueLight = NSColor(calibratedRed: 0.46, green: 0.73, blue: 1.00, alpha: 1.0)
    static let blueSoft = NSColor(calibratedRed: 0.88, green: 0.93, blue: 1.00, alpha: 1.0)
    static let white = NSColor.white
}

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let appIconURL = root.appendingPathComponent("YijiApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
let launchBrand1xURL = root.appendingPathComponent("YijiApp/Resources/Assets.xcassets/LaunchBrand.imageset/LaunchBrand.png")
let launchBrand2xURL = root.appendingPathComponent("YijiApp/Resources/Assets.xcassets/LaunchBrand.imageset/LaunchBrand@2x.png")
let launchBrand3xURL = root.appendingPathComponent("YijiApp/Resources/Assets.xcassets/LaunchBrand.imageset/LaunchBrand@3x.png")

try fileManager.createDirectory(at: appIconURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try fileManager.createDirectory(at: launchBrand1xURL.deletingLastPathComponent(), withIntermediateDirectories: true)

func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawLinearGradient(in context: CGContext, rect: CGRect, colors: [NSColor], start: CGPoint, end: CGPoint) {
    let cgColors = colors.map(\.cgColor) as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: [0, 1])!
    context.saveGState()
    context.addRect(rect)
    context.clip()
    context.drawLinearGradient(gradient, start: start, end: end, options: [])
    context.restoreGState()
}

func fill(_ context: CGContext, rect: CGRect, color: NSColor, radius: CGFloat) {
    context.saveGState()
    context.addPath(roundedRect(rect, radius: radius))
    context.setFillColor(color.cgColor)
    context.fillPath()
    context.restoreGState()
}

func drawBackground(in context: CGContext, rect: CGRect, rounded: Bool) {
    if rounded {
        context.saveGState()
        context.addPath(roundedRect(rect, radius: rect.width * 0.24))
        context.clip()
    }

    drawLinearGradient(
        in: context,
        rect: rect,
        colors: [Palette.blueDark, Palette.blueLight],
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY)
    )

    context.setFillColor(NSColor.white.withAlphaComponent(0.10).cgColor)
    context.fillEllipse(in: CGRect(x: rect.minX - rect.width * 0.12, y: rect.maxY - rect.height * 0.44, width: rect.width * 0.56, height: rect.width * 0.56))
    context.fillEllipse(in: CGRect(x: rect.maxX - rect.width * 0.40, y: rect.minY + rect.height * 0.08, width: rect.width * 0.34, height: rect.width * 0.34))

    context.setStrokeColor(NSColor.white.withAlphaComponent(0.16).cgColor)
    context.setLineWidth(rect.width * 0.018)
    context.strokeEllipse(in: CGRect(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.14, width: rect.width * 0.72, height: rect.width * 0.72))

    if rounded {
        context.restoreGState()
    }
}

func drawMagnifyingGlass(in context: CGContext, center: CGPoint, radius: CGFloat) {
    context.saveGState()
    context.setStrokeColor(NSColor.white.cgColor)
    context.setLineWidth(radius * 0.16)
    context.setLineCap(.round)

    let lensRadius = radius * 0.42
    context.strokeEllipse(in: CGRect(x: center.x - lensRadius, y: center.y - lensRadius, width: lensRadius * 2, height: lensRadius * 2))
    context.move(to: CGPoint(x: center.x + lensRadius * 0.58, y: center.y - lensRadius * 0.58))
    context.addLine(to: CGPoint(x: center.x + radius * 0.66, y: center.y - radius * 0.66))
    context.strokePath()
    context.restoreGState()
}

func drawCardMark(in context: CGContext, rect: CGRect) {
    let backCard = CGRect(
        x: rect.minX + rect.width * 0.33,
        y: rect.minY + rect.height * 0.27,
        width: rect.width * 0.34,
        height: rect.height * 0.42
    )
    fill(context, rect: backCard, color: Palette.white.withAlphaComponent(0.18), radius: rect.width * 0.08)

    let frontCard = CGRect(
        x: rect.minX + rect.width * 0.24,
        y: rect.minY + rect.height * 0.21,
        width: rect.width * 0.45,
        height: rect.height * 0.55
    )

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -18), blur: 32, color: NSColor(calibratedWhite: 0.0, alpha: 0.10).cgColor)
    fill(context, rect: frontCard, color: Palette.white, radius: rect.width * 0.09)
    context.restoreGState()

    let searchBar = CGRect(
        x: frontCard.minX + frontCard.width * 0.12,
        y: frontCard.maxY - frontCard.height * 0.22,
        width: frontCard.width * 0.58,
        height: frontCard.height * 0.11
    )
    fill(context, rect: searchBar, color: Palette.blueSoft, radius: searchBar.height / 2)

    context.setFillColor(Palette.blueLight.withAlphaComponent(0.95).cgColor)
    context.fillEllipse(in: CGRect(x: searchBar.minX + 18, y: searchBar.midY - 9, width: 18, height: 18))

    context.setStrokeColor(Palette.blueDark.withAlphaComponent(0.85).cgColor)
    context.setLineCap(.round)
    context.setLineWidth(rect.width * 0.020)

    let lines: [(CGFloat, CGFloat)] = [
        (0.72, 0.54),
        (0.60, 0.44),
        (0.78, 0.34)
    ]

    for (length, yFactor) in lines {
        let y = frontCard.minY + frontCard.height * yFactor
        let startX = frontCard.minX + frontCard.width * 0.14
        let endX = startX + frontCard.width * length
        context.move(to: CGPoint(x: startX, y: y))
        context.addLine(to: CGPoint(x: endX, y: y))
        context.strokePath()
    }

    let badgeRadius = rect.width * 0.10
    let badgeCenter = CGPoint(x: frontCard.maxX + badgeRadius * 0.18, y: frontCard.minY + frontCard.height * 0.18)
    context.setFillColor(Palette.blueDark.cgColor)
    context.fillEllipse(in: CGRect(x: badgeCenter.x - badgeRadius, y: badgeCenter.y - badgeRadius, width: badgeRadius * 2, height: badgeRadius * 2))
    drawMagnifyingGlass(in: context, center: badgeCenter, radius: badgeRadius)
}

func savePNG(size: CGSize, draw: (CGContext, CGRect) -> Void, to url: URL) throws {
    let image = NSImage(size: size)
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        throw NSError(domain: "BrandAssets", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing graphics context"])
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    draw(context, CGRect(origin: .zero, size: size))
    image.unlockFocus()

    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "BrandAssets", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
    }

    try pngData.write(to: url)
}

try savePNG(size: CGSize(width: 1024, height: 1024), draw: { context, rect in
    drawBackground(in: context, rect: rect, rounded: false)
    drawCardMark(in: context, rect: rect)
}, to: appIconURL)

func drawLaunchBrand(in context: CGContext, rect: CGRect) {
    let iconRect = rect.insetBy(dx: 76, dy: 76)
    drawBackground(in: context, rect: iconRect, rounded: true)
    drawCardMark(in: context, rect: iconRect)
}

try savePNG(size: CGSize(width: 256, height: 256), draw: drawLaunchBrand, to: launchBrand1xURL)
try savePNG(size: CGSize(width: 512, height: 512), draw: drawLaunchBrand, to: launchBrand2xURL)
try savePNG(size: CGSize(width: 768, height: 768), draw: drawLaunchBrand, to: launchBrand3xURL)

print("Generated:")
print(appIconURL.path)
print(launchBrand1xURL.path)
print(launchBrand2xURL.path)
print(launchBrand3xURL.path)
