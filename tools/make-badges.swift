#!/usr/bin/env swift
//
// make-badges.swift — draws the "BA" input-menu badges for the Bosnian keyboard layouts.
//
//   swift tools/make-badges.swift [output-dir]        (default output-dir: icons)
//
// Output:
//   BA.icns            filled badge with the letters cut out.
//   BA-underline.icns  the same badge with a bar cut out under the letters (marks an English layout).
//   *.svg         vector masters of the same drawings
//   preview.png   both badges on a light bar, a dark bar and a highlighted menu row
//
// Both are monochrome templates. They only turn white on a dark menu bar if the bundle's Info.plist
// says so: each layout's KLInfo_<name> dictionary needs TISIconIsTemplate = true. Without that key
// macOS shows the icon exactly as stored, which is black. Nothing inside an .icns can do this, and a
// template cannot carry colour: macOS tints the whole image, so the mark has to be a shape.
//
// What macOS draws for its own layouts (read from its badge code, macOS 27.2):
//   - a 22 × 16 pt rounded rectangle; filled, its corner radius is 5 pt (the outlined variant is the
//     same path stroked, so its outer radius is 5.5 pt)
//   - the label in the system font (SF, default design) Semibold 11 pt, drawn as smoothed text
//   - the label's typographic advance width centred horizontally, its baseline 4 pt above the bottom
//   - filled with the label cut out in the Input menu's rows and in Keyboard settings; in the menu bar
//     filled only for the primary layout and outlined for the others
//
// What a layout bundle can do. macOS reads only an .icns for a bundle's icon, shows it in a 16 × 16 pt
// square (anything wider is cut off; tested on a real menu bar), and uses that one image everywhere.
// So the badge here keeps the native height, corner radius, font and weight, but is 16 pt wide instead
// of 22 pt. Set at the native 11 pt the letters would sit 1.2 pt and 0.7 pt from the edges, so they
// are scaled to 7 pt capitals (90 %) and drawn 0.3 pt closer together. They are not centred by their
// outer edges: the A only reaches the right edge at its foot and leaves the space above it open, so
// the letters sit towards that side, 2.25 pt from the left edge and 1.3 pt beside the foot of the A.
// Two alternatives were drawn and compared on a real menu bar. Centring the letters geometrically
// looks left-heavy, because the B is a solid block while the A is open and tapers to a point: the
// weight of a centred "BA" falls 0.8 pt left of the middle, against 0.3 pt here. Setting them at
// 2.5 pt instead lands the stem of the B on a whole pixel at 2x, so its edge is crisper, but it
// crowds the A against the right edge; the extra room won. The top and bottom of the letters are on
// whole pixels either way. The underline sits below them and takes no room from the letters.
//
// Why bitmaps. An .icns is a container of bitmaps; it cannot hold vectors. Every size the format
// defines is included, from 16 px up to 1024 px, each rasterised here at its exact pixel size (never
// scaled from another bitmap). The menu uses the 16 px image on a 1x display and the 32 px image on a
// Retina (2x) display. The letters are drawn as text, with the same smoothing macOS applies to its
// own badges; the .svg masters hold plain outlines instead.
//
// The letters are drawn with the macOS system font, so the icons are meant for use on macOS only.

import AppKit
import CoreText
import ImageIO
import UniformTypeIdentifiers

// MARK: - Design (points, on a 16 × 16 canvas, origin bottom-left)

let canvas: CGFloat = 16
let cornerRadius: CGFloat = 5              // as the native filled badge
let capHeight: CGFloat = 7                 // height of the capitals (7.75 pt in the native badge)
let tracking: CGFloat = -0.3               // letters this much closer together than the font's default

let labelLeft: CGFloat = 2.25              // x of the left edge of the letters

// The underline is cut out of the 4.5 pt of badge below the letters: a bar their own weight, with
// 1.5 pt of badge left above it so it reads as a mark rather than as part of them, and 1.75 pt below
// so it does not touch the rounded bottom edge. A dot in the corner was tried first and is too faint
// at 1x, where it falls across two pixels; a bar lands on whole pixels and stays crisp.
let underlineRect = CGRect(x: 3.25, y: 1.75, width: 9.5, height: 1.25)
let underlineRadius: CGFloat = 0.625       // the bar's own rounded ends

struct Badge {
    let name: String
    let label: String
    let underline: Bool
}

let badges = [
    Badge(name: "BA", label: "BA", underline: false),
    Badge(name: "BA-underline", label: "BA", underline: true),
]

func cgColor(_ rgb: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255, blue: CGFloat(rgb & 0xFF) / 255, alpha: alpha)
}

// MARK: - Shapes

var bodyPath: CGPath {
    CGPath(roundedRect: CGRect(x: 0, y: 0, width: canvas, height: canvas), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
}

var underlinePath: CGPath {
    CGPath(roundedRect: underlineRect, cornerWidth: underlineRadius, cornerHeight: underlineRadius, transform: nil)
}

/// The label in the native font and weight (system font, Semibold), sized so its capitals are
/// `capHeight` tall, and where its origin goes: `labelLeft` from the left edge, centred vertically.
func labelLine(_ badge: Badge) -> (line: CTLine, origin: CGPoint) {
    let reference = NSFont.systemFont(ofSize: 100, weight: .semibold)
    let font = NSFont.systemFont(ofSize: 100 * capHeight / reference.capHeight, weight: .semibold)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: badge.label, attributes: [
        .font: font, .foregroundColor: NSColor.black, .kern: tracking,
    ]))
    // Measured from the outline itself, which is what the eye sees — not the advance width, and not
    // the nominal cap height, since a letter may overshoot it.
    let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    return (line, CGPoint(x: labelLeft - ink.minX, y: (canvas - ink.height) / 2 - ink.minY))
}

/// The same label as plain outlines, for the vector masters.
func labelPath(_ badge: Badge) -> CGPath {
    let (line, origin) = labelLine(badge)
    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
        let runFont = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName as String] as! CTFont
        for i in 0..<count {
            guard let glyph = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) else { continue }
            path.addPath(glyph, transform: CGAffineTransform(translationX: origin.x + positions[i].x, y: origin.y + positions[i].y))
        }
    }
    return path
}

// MARK: - Drawing

func makeContext(width: Int, height: Int) -> CGContext {
    CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

/// The badge as a `pixels` × `pixels` bitmap. `tint` stands in for the colour macOS gives the template
/// (black in the shipped icon; only its alpha matters).
func render(_ badge: Badge, pixels: Int, tint: CGColor? = nil) -> CGImage {
    let ink = tint ?? cgColor(0x000000)
    let ctx = makeContext(width: pixels, height: pixels)
    ctx.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)

    ctx.addPath(bodyPath)
    ctx.setFillColor(ink)
    ctx.fillPath()

    // Cut the letters out, drawn as text with the smoothing and glyph positioning macOS itself uses.
    ctx.setBlendMode(.destinationOut)
    ctx.setAllowsFontSmoothing(true)
    ctx.setShouldSmoothFonts(true)
    ctx.setAllowsFontSubpixelPositioning(true)
    ctx.setShouldSubpixelPositionFonts(true)
    ctx.setAllowsFontSubpixelQuantization(true)
    ctx.setShouldSubpixelQuantizeFonts(true)
    let (line, origin) = labelLine(badge)
    ctx.textPosition = origin
    CTLineDraw(line, ctx)

    if badge.underline {
        ctx.addPath(underlinePath)                                      // still cutting out
        ctx.fillPath()
    }
    ctx.setBlendMode(.normal)
    return ctx.makeImage()!
}

func pngData(_ image: CGImage) throws -> Data {
    let data = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
    return data as Data
}

// MARK: - .icns

func writeICNS(_ badge: Badge, to url: URL) throws {
    // Written with ImageIO directly (no iconutil, no temporary files). 144 dpi marks the @2x images.
    // 16 pt is what the menu uses (16 px at 1x, 32 px at 2x); the larger sizes cover every other
    // place macOS may show the icon bigger.
    let sizes = [16, 32, 128, 256, 512]
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.icns.identifier as CFString, sizes.count * 2, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    for points in sizes {
        for scale in [1, 2] {
            let dpi = 72 * scale
            CGImageDestinationAddImage(dest, render(badge, pixels: points * scale),
                                       [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary)
        }
    }
    guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
}

// MARK: - .svg

func number(_ value: CGFloat) -> String {
    var text = String(format: "%.4f", Double(value))
    while text.hasSuffix("0") { text.removeLast() }
    if text.hasSuffix(".") { text.removeLast() }
    return text == "-0" ? "0" : text
}

/// SVG path data for `path`, flipped to SVG's top-left origin.
func svgPathData(_ path: CGPath) -> String {
    func point(_ p: CGPoint) -> String { "\(number(p.x)) \(number(canvas - p.y))" }
    var data: [String] = []
    path.applyWithBlock { element in
        let p = element.pointee.points
        switch element.pointee.type {
        case .moveToPoint: data.append("M\(point(p[0]))")
        case .addLineToPoint: data.append("L\(point(p[0]))")
        case .addQuadCurveToPoint: data.append("Q\(point(p[0])) \(point(p[1]))")
        case .addCurveToPoint: data.append("C\(point(p[0])) \(point(p[1])) \(point(p[2]))")
        case .closeSubpath: data.append("Z")
        @unknown default: break
        }
    }
    return data.joined()
}

func writeSVG(_ badge: Badge, to url: URL) throws {
    let side = number(canvas)
    var lines = ["<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(side) \(side)\" width=\"256\" height=\"256\">"]
    // Mirrors what macOS does with a template icon: dark ink on light, white ink on dark.
    lines.append("  <style>.ink{fill:#000000}@media (prefers-color-scheme:dark){.ink{fill:#FFFFFF}}</style>")
    // The mask cuts the letters, and the underline, out of the body.
    lines.append("  <mask id=\"cut\">")
    lines.append("    <rect width=\"\(side)\" height=\"\(side)\" fill=\"#FFFFFF\"/>")
    lines.append("    <path d=\"\(svgPathData(labelPath(badge)))\" fill=\"#000000\"/>")
    if badge.underline {
        lines.append("    <rect x=\"\(number(underlineRect.minX))\" y=\"\(number(canvas - underlineRect.maxY))\" width=\"\(number(underlineRect.width))\" height=\"\(number(underlineRect.height))\" rx=\"\(number(underlineRadius))\" fill=\"#000000\"/>")
    }
    lines.append("  </mask>")
    lines.append("  <rect class=\"ink\" width=\"\(side)\" height=\"\(side)\" rx=\"\(number(cornerRadius))\" mask=\"url(#cut)\"/>")
    lines.append("</svg>")
    try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: false, encoding: .utf8)
}

// MARK: - Preview sheet

struct Theme {
    let title: String
    let background: CGColor
    let tint: CGColor          // colour macOS gives a template image on this background
    let text: CGColor
}

let themes = [
    Theme(title: "Light menu bar", background: cgColor(0xEDEDED), tint: cgColor(0x000000, alpha: 0.88), text: cgColor(0x000000, alpha: 0.6)),
    Theme(title: "Dark menu bar", background: cgColor(0x1F1F1F), tint: cgColor(0xFFFFFF), text: cgColor(0xFFFFFF, alpha: 0.6)),
    Theme(title: "Highlighted menu row", background: cgColor(0x0A61F2), tint: cgColor(0xFFFFFF), text: cgColor(0xFFFFFF, alpha: 0.75)),
]

func writePreview(to url: URL) throws {
    let cell: CGFloat = 160, gap: CGFloat = 20, margin: CGFloat = 28, header: CGFloat = 56, caption: CGFloat = 22
    let renditions: [(title: String, pixels: Int)] = [("large", 160), ("actual 2x pixels", 32), ("actual 1x pixels", 16)]
    let themeWidth = CGFloat(renditions.count) * cell + CGFloat(renditions.count - 1) * gap + 2 * margin
    let rowHeight = cell + caption + 2 * margin
    let width = Int(themeWidth * CGFloat(themes.count))
    let height = Int(header + rowHeight * CGFloat(badges.count))
    let ctx = makeContext(width: width, height: height)
    let ns = NSGraphicsContext(cgContext: ctx, flipped: false)

    func text(_ string: String, at point: CGPoint, size: CGFloat, weight: NSFont.Weight, colour: CGColor) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ns
        NSAttributedString(string: string, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: NSColor(cgColor: colour) ?? .black,
        ]).draw(at: point)
        NSGraphicsContext.restoreGraphicsState()
    }

    for (t, theme) in themes.enumerated() {
        let x0 = CGFloat(t) * themeWidth
        ctx.setFillColor(theme.background)
        ctx.fill(CGRect(x: x0, y: 0, width: themeWidth, height: CGFloat(height)))
        text(theme.title, at: CGPoint(x: x0 + margin, y: CGFloat(height) - 38), size: 17, weight: .semibold, colour: theme.text)
        for (r, badge) in badges.enumerated() {
            let y0 = CGFloat(height) - header - CGFloat(r + 1) * rowHeight + margin
            for (c, rendition) in renditions.enumerated() {
                let x = x0 + margin + CGFloat(c) * (cell + gap)
                ctx.interpolationQuality = .none      // show the real pixels of the small renditions
                ctx.draw(render(badge, pixels: rendition.pixels, tint: theme.tint), in: CGRect(x: x, y: y0 + caption, width: cell, height: cell))
                text("\(badge.name) · \(rendition.title)", at: CGPoint(x: x, y: y0), size: 11, weight: .regular, colour: theme.text)
            }
        }
    }
    try pngData(ctx.makeImage()!).write(to: url)
}

// MARK: - Main

let outputDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icons")
do {
    try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    for badge in badges {
        try writeICNS(badge, to: outputDir.appendingPathComponent("\(badge.name).icns"))
        try writeSVG(badge, to: outputDir.appendingPathComponent("\(badge.name).svg"))
        print("wrote \(badge.name).icns and \(badge.name).svg")
    }
    try writePreview(to: outputDir.appendingPathComponent("preview.png"))
    print("wrote preview.png  →  \(outputDir.path)\nBoth icons are templates: set TISIconIsTemplate = true for each layout in the bundle's Info.plist.")
} catch {
    FileHandle.standardError.write("make-badges: \(error)\n".data(using: .utf8)!)
    exit(1)
}
