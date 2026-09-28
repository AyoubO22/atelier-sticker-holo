// Génère l'icône de l'app : un sticker holo rond, coin décollé, posé sur un tapis de coupe.
// Usage : make-icon <dossier .iconset>

import AppKit

struct LCG {
    var s: UInt64
    mutating func next() -> CGFloat {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((s >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
    }
}

func hex(_ v: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: a)
}

func drawIcon(_ ctx: CGContext) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!

    // 1. Plaque : tapis de coupe vert quadrillé
    let plate = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: hex(0x000000, 0.38))
    ctx.addPath(plate); ctx.setFillColor(hex(0x1d5645)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(plate); ctx.clip()
    let ground = CGGradient(colorsSpace: space, colors: [hex(0x2c7059), hex(0x173f33)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(ground, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.setStrokeColor(hex(0xcfeede, 0.12)); ctx.setLineWidth(2)
    var x: CGFloat = 100
    while x <= 925 {
        ctx.move(to: CGPoint(x: x, y: 100)); ctx.addLine(to: CGPoint(x: x, y: 924))
        ctx.move(to: CGPoint(x: 100, y: x)); ctx.addLine(to: CGPoint(x: 924, y: x))
        x += 82.4
    }
    ctx.strokePath()
    ctx.restoreGState()

    // 2. Sticker rond ; le pli coupe le coin en haut à droite
    let c = CGPoint(x: 505, y: 500), R: CGFloat = 272
    let u = CGPoint(x: 0.7071, y: 0.7071), t = R * 0.40
    let F = CGPoint(x: c.x + u.x * t, y: c.y + u.y * t)
    let v = CGPoint(x: -u.y, y: u.x)
    func keepSide() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: F.x + v.x * 3000, y: F.y + v.y * 3000))
        p.addLine(to: CGPoint(x: F.x - v.x * 3000, y: F.y - v.y * 3000))
        p.addLine(to: CGPoint(x: F.x - v.x * 3000 - u.x * 5000, y: F.y - v.y * 3000 - u.y * 5000))
        p.addLine(to: CGPoint(x: F.x + v.x * 3000 - u.x * 5000, y: F.y + v.y * 3000 - u.y * 5000))
        p.closeSubpath()
        return p
    }
    let disc = CGPath(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R), transform: nil)

    ctx.saveGState()
    ctx.addPath(keepSide()); ctx.clip()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: hex(0x000000, 0.45))
    ctx.addPath(disc); ctx.setFillColor(hex(0xdfe6ee)); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(keepSide()); ctx.clip()
    ctx.addPath(disc); ctx.clip()
    let steps = 180
    for i in 0..<steps {
        let a0 = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let a1 = CGFloat(i + 1) / CGFloat(steps) * 2 * .pi + 0.01
        let p = CGMutablePath()
        p.move(to: c)
        p.addArc(center: c, radius: R + 4, startAngle: a0, endAngle: a1, clockwise: false)
        p.closeSubpath()
        ctx.addPath(p)
        ctx.setFillColor(NSColor(hue: CGFloat(i) / CGFloat(steps), saturation: 0.30, brightness: 1.0, alpha: 1).cgColor)
        ctx.fillPath()
    }
    var rng = LCG(s: 42)
    for _ in 0..<5200 {
        let a = rng.next() * 2 * .pi, r = sqrt(rng.next()) * R
        let px = c.x + cos(a) * r, py = c.y + sin(a) * r, sz = 2 + rng.next() * 5
        let b = rng.next()
        let col = b > 0.82 ? hex(0xffffff, 0.95) : NSColor(hue: rng.next(), saturation: 0.35, brightness: 0.75 + 0.25 * b, alpha: 0.75).cgColor
        ctx.setFillColor(col)
        ctx.fill(CGRect(x: px, y: py, width: sz, height: sz))
    }

    // Pastille imprimée : relief, contour et dégradé chaud
    let r2: CGFloat = 158
    let inner = CGPath(ellipseIn: CGRect(x: c.x - r2, y: c.y - r2, width: 2 * r2, height: 2 * r2), transform: nil)
    ctx.setLineJoin(.round)
    for k in stride(from: 14, through: 1, by: -1) {
        ctx.saveGState()
        ctx.translateBy(x: CGFloat(k) * 0.4, y: -CGFloat(k))
        ctx.addPath(inner); ctx.setFillColor(hex(0x2a1140)); ctx.setStrokeColor(hex(0x2a1140)); ctx.setLineWidth(22)
        ctx.drawPath(using: .fillStroke)
        ctx.restoreGState()
    }
    ctx.addPath(inner); ctx.setStrokeColor(hex(0x2a1140)); ctx.setLineWidth(22); ctx.strokePath()
    ctx.saveGState()
    ctx.addPath(inner); ctx.clip()
    let warm = CGGradient(colorsSpace: space, colors: [hex(0xfff06a), hex(0xffab3d), hex(0xff4d8d)] as CFArray, locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(warm, start: CGPoint(x: c.x, y: c.y + r2), end: CGPoint(x: c.x, y: c.y - r2), options: [])
    ctx.restoreGState()

    // Éclair
    let raw: [(CGFloat, CGFloat)] = [(0.02, -0.5), (-0.27, 0.07), (-0.03, 0.07), (-0.14, 0.5), (0.29, -0.11), (0.05, -0.11), (0.23, -0.5)]
    let bolt = CGMutablePath()
    bolt.addLines(between: raw.map { CGPoint(x: c.x + $0.0 * 230, y: c.y - $0.1 * 230) })
    bolt.closeSubpath()
    for k in stride(from: 10, through: 1, by: -1) {
        ctx.saveGState()
        ctx.translateBy(x: CGFloat(k) * 0.4, y: -CGFloat(k))
        ctx.addPath(bolt); ctx.setFillColor(hex(0x2a1140)); ctx.setStrokeColor(hex(0x2a1140)); ctx.setLineWidth(18)
        ctx.drawPath(using: .fillStroke)
        ctx.restoreGState()
    }
    ctx.addPath(bolt); ctx.setStrokeColor(hex(0x2a1140)); ctx.setLineWidth(18); ctx.strokePath()
    ctx.addPath(bolt); ctx.setFillColor(hex(0xffe14d)); ctx.fillPath()

    // Liseré clair du bord découpé
    ctx.addPath(disc); ctx.setStrokeColor(hex(0xffffff, 0.7)); ctx.setLineWidth(5); ctx.strokePath()
    ctx.restoreGState()

    // 3. Rabat décollé : le morceau retiré, retourné, montre son dos blanc
    let c2 = CGPoint(x: c.x + 2 * t * u.x, y: c.y + 2 * t * u.y)
    let flap = CGPath(ellipseIn: CGRect(x: c2.x - R, y: c2.y - R, width: 2 * R, height: 2 * R), transform: nil)
    ctx.saveGState()
    ctx.addPath(keepSide()); ctx.clip()
    ctx.setShadow(offset: CGSize(width: 10, height: -16), blur: 26, color: hex(0x000000, 0.42))
    ctx.addPath(flap); ctx.setFillColor(hex(0xf2f3f0)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(keepSide()); ctx.clip()
    ctx.addPath(flap); ctx.clip()
    let paper = CGGradient(colorsSpace: space, colors: [hex(0xffffff), hex(0xe9ebe6), hex(0xd2d6ce)] as CFArray, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(paper, start: F, end: CGPoint(x: F.x - u.x * 220, y: F.y - u.y * 220), options: [.drawsAfterEndLocation])
    ctx.restoreGState()
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
let sizes: [(String, Int)] = [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                              ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)]
for (name, px) in sizes {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gctx
    gctx.cgContext.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)
    drawIcon(gctx.cgContext)
    gctx.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
print("icône OK")
