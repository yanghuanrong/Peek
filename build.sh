#!/bin/bash
# 构建 Peek.app
# 用法：
#   ./build.sh          # release 构建 + 打包
#   ./build.sh debug    # debug 构建 + 打包

set -euo pipefail

CONFIG="${1:-release}"
cd "$(dirname "$0")"

APP_NAME="Peek"
BUNDLE_ID="com.peek.translate"
# 可用环境变量覆盖，CI 从 git tag 提取版本：PEEK_VERSION=0.2.0 ./build.sh
VERSION="${PEEK_VERSION:-0.1.0}"
BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"

# debug 参数会额外生成 Xcode 工程产物，方便断点调试
if [ "$CONFIG" = "debug" ]; then
    echo "==> 生成 Xcode 工程（调试用）"
    if [ -f Peek.xcodeproj ]; then
        echo "    已存在 Peek.xcodeproj，跳过生成"
        echo "    如需重建：rm -rf Peek.xcodeproj && ruby scripts/generate_xcodeproj.rb"
    else
        if ruby scripts/generate_xcodeproj.rb 2>/dev/null; then
            echo "    ✅ 工程已生成"
        else
            echo "    ⚠️  生成失败（需要 gem install xcodeproj），跳过"
        fi
    fi
    echo ""
fi

echo "==> 编译 (${CONFIG})"
swift build --disable-sandbox -c "${CONFIG}"
BIN_PATH="$(swift build --disable-sandbox -c "${CONFIG}" --show-bin-path)"

echo "==> 打包 ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BIN_PATH}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Sparkle 自动更新框架（universal binary，随包分发）
SPARKLE_FW=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [ -d "${SPARKLE_FW}" ]; then
    mkdir -p "${APP_DIR}/Contents/Frameworks"
    cp -R "${SPARKLE_FW}" "${APP_DIR}/Contents/Frameworks/"
else
    echo "    ⚠️  未找到 Sparkle.framework（swift package resolve 后重试）" >&2
    exit 1
fi

# Info.plist
cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <!-- 关键：无 Dock 图标，只在菜单栏与浮动面板出现 -->
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Peek · 个人划词翻译工具</string>
    <!-- Sparkle 自动更新 -->
    <key>SUFeedURL</key>
    <string>https://github.com/yanghuanrong/Peek/releases/latest/download/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>hAn4vBa2hKgaP1QnQ9r9zWbbdhxurnCQzoAbV/QV+S8=</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "${APP_DIR}/Contents/PkgInfo"

# 临时图标（若缺少正式图标则用系统符号生成一个）
if [ ! -f "Resources/AppIcon.icns" ]; then
    mkdir -p Resources
    ICONSET="Resources/AppIcon.iconset"
    rm -rf "${ICONSET}"
    mkdir -p "${ICONSET}"

    # 用SF Symbol 渲染图标为 PNG
    cat > /tmp/peek_icon.swift <<'SWIFT'
import AppKit
import CoreGraphics
import Foundation

guard CommandLine.arguments.count > 1 else { fputs("usage: peek_icon <png>\n", stderr); exit(1) }
let S: CGFloat = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(
    data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
ctx.setAllowsAntialiasing(true)
ctx.interpolationQuality = .high
ctx.translateBy(x: 0, y: S)
ctx.scaleBy(x: 1, y: -1)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r, g, b, a])!
}

func squircle(_ rect: CGRect, radius: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let r = min(radius, min(rect.width, rect.height) / 2)
    let k: CGFloat = 0.5522847498
    let c = r * k
    let x0 = rect.minX, y0 = rect.minY, x1 = rect.maxX, y1 = rect.maxY
    p.move(to: CGPoint(x: x0 + r, y: y0))
    p.addLine(to: CGPoint(x: x1 - r, y: y0))
    p.addCurve(to: CGPoint(x: x1, y: y0 + r), control1: CGPoint(x: x1 - r + c, y: y0), control2: CGPoint(x: x1, y: y0 + r - c))
    p.addLine(to: CGPoint(x: x1, y: y1 - r))
    p.addCurve(to: CGPoint(x: x1 - r, y: y1), control1: CGPoint(x: x1, y: y1 - r + c), control2: CGPoint(x: x1 - r + c, y: y1))
    p.addLine(to: CGPoint(x: x0 + r, y: y1))
    p.addCurve(to: CGPoint(x: x0, y: y1 - r), control1: CGPoint(x: x0 + r - c, y: y1), control2: CGPoint(x: x0, y: y1 - r + c))
    p.addLine(to: CGPoint(x: x0, y: y0 + r))
    p.addCurve(to: CGPoint(x: x0 + r, y: y0), control1: CGPoint(x: x0, y: y0 + r - c), control2: CGPoint(x: x0 + r - c, y: y0))
    p.closeSubpath()
    return p
}

// ---- 背景贴片：Big Sur 网格，1024 画布内 824x824 居中，四边留 100px ----
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = squircle(tile, radius: 185)
ctx.addPath(tilePath)
ctx.clip()
// 扁平对角渐变
ctx.drawLinearGradient(
    CGGradient(colorsSpace: cs, colors: [color(0.32, 0.58, 1.0), color(0.42, 0.30, 0.96)] as CFArray, locations: [0, 1])!,
    start: CGPoint(x: 100, y: 924), end: CGPoint(x: 924, y: 100), options: [])
ctx.restoreGState()

// ---- 书本几何（屏幕坐标，y 向下）----
let cover = CGRect(x: 322, y: 232, width: 380, height: 560)
let cr: CGFloat = 62
let spineW: CGFloat = 38

// 封面：纯白扁平
ctx.saveGState()
ctx.addPath(squircle(cover, radius: cr))
ctx.setFillColor(color(1, 1, 1))
ctx.fillPath()
// 书脊（限制在封面内）
ctx.saveGState()
ctx.addPath(squircle(cover, radius: cr))
ctx.clip()
ctx.drawLinearGradient(
    CGGradient(colorsSpace: cs, colors: [color(0.82, 0.86, 0.96), color(1, 1, 1)] as CFArray, locations: [0, 1])!,
    start: CGPoint(x: cover.minX, y: 0), end: CGPoint(x: cover.minX + spineW + 22, y: 0), options: [])
// 书脊凹槽
ctx.setStrokeColor(color(0.66, 0.72, 0.90))
ctx.setLineWidth(4.5)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: cover.minX + spineW, y: cover.minY + cr * 0.7))
ctx.addLine(to: CGPoint(x: cover.minX + spineW, y: cover.maxY - cr * 0.7))
ctx.strokePath()
ctx.restoreGState()
// 页缘线：两条圆头短线
ctx.setStrokeColor(color(0.76, 0.81, 0.94))
ctx.setLineWidth(8)
for i in 0...1 {
    let yy = cover.maxY - 96 - CGFloat(i) * 24
    ctx.move(to: CGPoint(x: cover.minX + spineW + 34, y: yy))
    ctx.addLine(to: CGPoint(x: cover.maxX - 54, y: yy))
}
ctx.strokePath()
ctx.restoreGState()

// ---- 字母 A ----
func glyph(_ s: String, size: CGFloat, weight: NSFont.Weight) -> CGPath {
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    var u = s.utf16.first!
    var g = CTFontCreatePathForGlyph(font, CTFontGetGlyphWithName(font, s as CFString), nil)
    if g == nil {
        var glyph = CGGlyph()
        CTFontGetGlyphsForCharacters(font, &u, &glyph, 1)
        g = CTFontCreatePathForGlyph(font, glyph, nil)
    }
    return g!
}
let aPath = glyph("A", size: 300, weight: .bold)
let b = aPath.boundingBox
let target = CGRect(x: cover.minX + spineW + 30, y: cover.minY + 128, width: cover.width - spineW - 88, height: 280)
let sc = min(target.width / b.width, target.height / b.height)
var t = CGAffineTransform(translationX: target.midX, y: target.midY)
    .scaledBy(x: sc, y: -sc)
    .translatedBy(x: -(b.midX), y: -(b.midY))
let placed = aPath.copy(using: &t)!
// A：扁平靛蓝
ctx.addPath(placed)
ctx.setFillColor(color(0.35, 0.33, 0.88))
ctx.fillPath()

// ---- 导出 ----
let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
SWIFT

    if swiftc -O /tmp/peek_icon.swift -o /tmp/peek_icon 2>/dev/null; then
        /tmp/peek_icon "${ICONSET}/icon_512x512@2x.png" 2>/dev/null || true
        if [ -f "${ICONSET}/icon_512x512@2x.png" ]; then
            cp "${ICONSET}/icon_512x512@2x.png" "${ICONSET}/icon_512x512.png"
            for s in 16 32 64 128 256 512; do
                sips -z ${s} ${s} "${ICONSET}/icon_512x512.png" \
                    --out "${ICONSET}/icon_${s}x${s}.png" >/dev/null 2>&1 || true
                d=$((s * 2))
                sips -z ${d} ${d} "${ICONSET}/icon_512x512.png" \
                    --out "${ICONSET}/icon_${s}x${s}@2x.png" >/dev/null 2>&1 || true
            done
            iconutil -c icns "${ICONSET}" -o Resources/AppIcon.icns 2>/dev/null \
                && cp Resources/AppIcon.icns "${APP_DIR}/Contents/Resources/AppIcon.icns" \
                || true
        fi
    fi
else
    cp Resources/AppIcon.icns "${APP_DIR}/Contents/Resources/AppIcon.icns"
fi

echo "==> 签名（ad-hoc）"
# 先签框架再签 App；ad-hoc 签名可保证 Gatekeeper 放行
codesign --force --sign - --timestamp=none "${APP_DIR}/Contents/Frameworks/Sparkle.framework" 2>/dev/null || {
    echo "    Sparkle 签名跳过（不影响本机运行）"
}
codesign --force --sign - --timestamp=none "${APP_DIR}" 2>/dev/null || {
    echo "    签名跳过（不影响本机运行）"
}

echo "==> 打包 DMG"
DMG_PATH="${BUILD_DIR}/Peek-${VERSION}.dmg"
STAGING="${BUILD_DIR}/dmg-staging"
rm -rf "${STAGING}" "${DMG_PATH}"
mkdir -p "${STAGING}"
cp -R "${APP_DIR}" "${STAGING}/"
# 拖拽安装用的 /Applications 快捷方式
ln -s /Applications "${STAGING}/Applications"
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${STAGING}" \
    -format UDZO \
    "${DMG_PATH}" -ov >/dev/null
rm -rf "${STAGING}"

echo ""
echo "✅ 构建完成: ${APP_DIR}"
echo "✅ DMG 打包完成: ${DMG_PATH}"
echo ""
echo "运行方式："
echo "  open ${APP_DIR}                # 启动"
echo "  open -a ${APP_DIR} --args     # 启动"
echo ""
echo "安装到「应用程序」："
echo "  cp -R ${APP_DIR} /Applications/"