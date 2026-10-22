// Renders the Astra Dial app icon: a graphite knob with a blue-to-magenta ring, on the
// macOS icon grid (824 pt rounded square inside a 1024 pt canvas).
//
//   swift Scripts/make-icon.swift Resources/AppIcon.icns

import AppKit
import CoreGraphics

let output = CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.icns"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func render(size: Int) -> Data {
    let s = CGFloat(size)
    let unit = s / 1024
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let center = CGPoint(x: s / 2, y: s / 2)

    // Tile with drop shadow and a vertical graphite gradient.
    let tile = CGRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185 * unit, cornerHeight: 185 * unit, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * unit), blur: 24 * unit, color: color(0x000000, 0.35))
    ctx.addPath(tilePath)
    ctx.setFillColor(color(0x1B1F27))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let tileGradient = CGGradient(colorsSpace: space, colors: [color(0x2A303B), color(0x12151B)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(tileGradient, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    ctx.restoreGState()

    // RGB ring: an arc gradient approximated with short segments, blue at the top to magenta.
    let ringRadius = 318 * unit
    let ringWidth = 30 * unit
    let segments = 180
    let start = color(0x5B74FF), end = color(0xE45FBD)
    for i in 0..<segments {
        let t = CGFloat(i) / CGFloat(segments)
        let a0 = .pi / 2 - t * 2 * .pi
        let a1 = .pi / 2 - (t + 1.2 / CGFloat(segments)) * 2 * .pi
        let mix = 0.5 - 0.5 * cos(t * 2 * .pi) // blue → magenta → blue around the ring
        let c = start.components!, d = end.components!
        ctx.setStrokeColor(CGColor(srgbRed: c[0] + (d[0] - c[0]) * mix, green: c[1] + (d[1] - c[1]) * mix,
                                   blue: c[2] + (d[2] - c[2]) * mix, alpha: 1))
        ctx.setLineWidth(ringWidth)
        ctx.addArc(center: center, radius: ringRadius, startAngle: a0, endAngle: a1, clockwise: true)
        ctx.strokePath()
    }

    // Detent ticks between ring and knob.
    for i in 0..<24 {
        let angle = CGFloat(i) / 24 * 2 * .pi
        let inner = (i % 6 == 0 ? 262 : 272) * unit, outer = 288 * unit
        ctx.move(to: CGPoint(x: center.x + sin(angle) * inner, y: center.y + cos(angle) * inner))
        ctx.addLine(to: CGPoint(x: center.x + sin(angle) * outer, y: center.y + cos(angle) * outer))
        ctx.setStrokeColor(color(0xFFFFFF, i % 6 == 0 ? 0.55 : 0.25))
        ctx.setLineWidth((i % 6 == 0 ? 7 : 4) * unit)
        ctx.setLineCap(.round)
        ctx.strokePath()
    }

    // Knob body with knurled edge and a lit top.
    let knobRadius = 236 * unit
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14 * unit), blur: 30 * unit, color: color(0x000000, 0.55))
    ctx.addEllipse(in: CGRect(x: center.x - knobRadius, y: center.y - knobRadius, width: knobRadius * 2, height: knobRadius * 2))
    ctx.setFillColor(color(0x3A414E))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: center.x - knobRadius, y: center.y - knobRadius, width: knobRadius * 2, height: knobRadius * 2))
    ctx.clip()
    let knobGradient = CGGradient(colorsSpace: space, colors: [color(0x5A6372), color(0x2B313B)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(knobGradient, start: CGPoint(x: 0, y: center.y + knobRadius), end: CGPoint(x: 0, y: center.y - knobRadius), options: [])
    for i in 0..<72 {
        let angle = CGFloat(i) / 72 * 2 * .pi
        ctx.move(to: CGPoint(x: center.x + sin(angle) * (knobRadius - 34 * unit), y: center.y + cos(angle) * (knobRadius - 34 * unit)))
        ctx.addLine(to: CGPoint(x: center.x + sin(angle) * knobRadius, y: center.y + cos(angle) * knobRadius))
    }
    ctx.setStrokeColor(color(0x000000, 0.28))
    ctx.setLineWidth(5 * unit)
    ctx.strokePath()
    ctx.restoreGState()

    // Inner cap.
    let capRadius = 170 * unit
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: center.x - capRadius, y: center.y - capRadius, width: capRadius * 2, height: capRadius * 2))
    ctx.clip()
    let capGradient = CGGradient(colorsSpace: space, colors: [color(0x4A525F), color(0x242932)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(capGradient, start: CGPoint(x: 0, y: center.y + capRadius), end: CGPoint(x: 0, y: center.y - capRadius), options: [])
    ctx.restoreGState()

    // Indicator, pointing to about one o'clock.
    let angle: CGFloat = .pi / 7
    let from = CGPoint(x: center.x + sin(angle) * 110 * unit, y: center.y + cos(angle) * 110 * unit)
    let to = CGPoint(x: center.x + sin(angle) * 150 * unit, y: center.y + cos(angle) * 150 * unit)
    ctx.move(to: from)
    ctx.addLine(to: to)
    ctx.setStrokeColor(color(0x8FA2FF))
    ctx.setLineWidth(18 * unit)
    ctx.setLineCap(.round)
    ctx.strokePath()

    let image = ctx.makeImage()!
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon-\(getpid()).iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote \(output)")
