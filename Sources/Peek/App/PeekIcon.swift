import AppKit
import CoreText

/// Peek 品牌图标：书本剪影 + 镂空 A（与 App 图标同一设计语言）。
/// 生成 isTemplate 模板位图，调用方用 foregroundStyle 染色即可适配明暗模式。
enum PeekIcon {

    /// 18pt 基准坐标系内渲染一层位图
    private static func renderLayer(pointSize: CGFloat, backingScale: Int, draw: (CGContext) -> Void) -> NSBitmapImageRep {
        let px = max(1, Int((pointSize * CGFloat(backingScale)).rounded()))
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.scaleBy(x: pointSize / 18 * CGFloat(backingScale), y: pointSize / 18 * CGFloat(backingScale))
        draw(ctx)
        return NSBitmapImageRep(cgImage: ctx.makeImage()!)
    }

    /// finalAlpha = bookAlpha * (1 - glyphAlpha)，直接操作位图字节保留抗锯齿
    private static func punchOut(book: NSBitmapImageRep, glyph: NSBitmapImageRep) -> NSBitmapImageRep {
        let w = book.pixelsWide, h = book.pixelsHigh
        guard let bd = book.bitmapData, let gd = glyph.bitmapData else { return book }
        let bs = book.samplesPerPixel, gs = glyph.samplesPerPixel
        for y in 0..<h {
            for x in 0..<w {
                let bi = y * book.bytesPerRow + x * bs
                let ba = CGFloat(bd[bi + bs - 1]) / 255.0
                if ba == 0 { continue }
                let gi = y * glyph.bytesPerRow + x * gs
                let ga = CGFloat(gd[gi + gs - 1]) / 255.0
                let a = ba * (1 - ga)
                bd[bi + bs - 1] = a <= 0.002 ? 0 : UInt8(max(1, min(255, (a * 255).rounded())))
            }
        }
        return book
    }

    /// 书本剪影 + 镂空 A 的完整位图
    private static func compositeRep(pointSize: CGFloat, backingScale: Int) -> NSBitmapImageRep {
        let book = renderLayer(pointSize: pointSize, backingScale: backingScale) { ctx in
            ctx.addPath(CGPath(roundedRect: CGRect(x: 2.5, y: 1.5, width: 13, height: 15), cornerWidth: 2.6, cornerHeight: 2.6, transform: nil))
            ctx.setFillColor(CGColor(gray: 0, alpha: 1))
            ctx.fillPath()
        }
        let glyph = renderLayer(pointSize: pointSize, backingScale: backingScale) { ctx in
            let font = NSFont.systemFont(ofSize: 8.4, weight: .bold)
            var glyph = CGGlyph()
            var ch: UniChar = UniChar(UnicodeScalar("A").value)
            CTFontGetGlyphsForCharacters(font, &ch, &glyph, 1)
            guard let p = CTFontCreatePathForGlyph(font, glyph, nil) else { return }
            let bb = p.boundingBox
            let target = CGRect(x: 4.6, y: 3.4, width: 8.8, height: 11.2)
            let s = min(target.width / bb.width, target.height / bb.height)
            var t = CGAffineTransform(translationX: target.midX, y: target.midY)
                .scaledBy(x: s, y: s)
                .translatedBy(x: -bb.midX, y: -bb.midY)
            ctx.addPath(p.copy(using: &t)!)
            ctx.setFillColor(CGColor(gray: 0, alpha: 1))
            ctx.fillPath()
        }
        return punchOut(book: book, glyph: glyph)
    }

    /// 品牌图标模板图，含 @2x/@3x 表示；pointSize 为逻辑尺寸（默认 18pt 用于状态栏）
    static func templateImage(pointSize: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize))
        image.accessibilityDescription = "Peek"
        for scale in [2, 3] {
            image.addRepresentation(compositeRep(pointSize: pointSize, backingScale: scale))
        }
        return image
    }
}
