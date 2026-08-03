import Cocoa
import CoreGraphics

// TermGrid のアプリアイコンを .iconset ディレクトリとして書き出す。
// 使い方: makeicon <出力先.iconset>
//
// 小さいサイズは縮小すると溝が潰れて読めなくなるため、
// サイズごとに溝の太さ・要素の有無を変えて直接描画している（Apple 純正も同じ考え方）。

// MARK: - 図形

/// Apple の角丸は円弧ではなく superellipse（|x|^n + |y|^n = 1）。n が大きいほど角ばる。
func squircle(in rect: CGRect, n: CGFloat = 4.6) -> CGPath {
    let path = CGMutablePath()
    let cx = rect.midX, cy = rect.midY
    let a = rect.width / 2, b = rect.height / 2
    let steps = 1440
    let e = 2 / n
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * pow(abs(ct), e) * (ct < 0 ? -1 : 1)
        let y = cy + b * pow(abs(st), e) * (st < 0 ? -1 : 1)
        i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a)
}
func white(_ w: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: w, green: w, blue: w, alpha: a)
}

// MARK: - サイズ別の見た目

struct Spec {
    let groove: CGFloat      // 分割の溝の太さ（px）
    let bodyRatio: CGFloat   // キャンバスに対する本体の大きさ
    let winRatio: CGFloat    // 本体に対するウィンドウの幅
    let showBar: Bool        // タイトルバー
    let showDots: Bool       // 信号機のドット
    let showRowSplit: Bool   // 右列の上下分割
    let shadow: Bool
}

func spec(for size: CGFloat) -> Spec {
    switch size {
    case ..<24:   // 16px — 縦3列だけ残す
        return Spec(groove: 1, bodyRatio: 0.94, winRatio: 0.80,
                    showBar: false, showDots: false, showRowSplit: false, shadow: false)
    case ..<48:   // 32px — バーは出すがドットは潰れるので省く
        return Spec(groove: 2, bodyRatio: 0.90, winRatio: 0.78,
                    showBar: true, showDots: false, showRowSplit: true, shadow: false)
    case ..<96:   // 64px
        return Spec(groove: 3, bodyRatio: 0.86, winRatio: 0.74,
                    showBar: true, showDots: true, showRowSplit: true, shadow: true)
    case ..<192:  // 128px
        return Spec(groove: 4, bodyRatio: 0.82, winRatio: 0.70,
                    showBar: true, showDots: true, showRowSplit: true, shadow: true)
    default:      // 256px 以上
        return Spec(groove: size * 0.0117, bodyRatio: 0.805, winRatio: 0.687,
                    showBar: true, showDots: true, showRowSplit: true, shadow: true)
    }
}

// MARK: - 描画

func drawIcon(size S: CGFloat) -> CGImage {
    let sp = spec(for: S)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: Int(S), height: Int(S),
                              bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fatalError("コンテキストを作れませんでした")
    }
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    let body = S * sp.bodyRatio
    let bodyRect = CGRect(x: (S - body) / 2, y: (S - body) / 2, width: body, height: body)
    let base = squircle(in: bodyRect)

    // 本体（影 → グラデーション → 縁のハイライト）
    ctx.saveGState()
    if sp.shadow {
        ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.016), blur: S * 0.039, color: white(0, 0.38))
    }
    ctx.addPath(base)
    ctx.setFillColor(rgb(30, 34, 42))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(base)
    ctx.clip()
    let bg = CGGradient(colorsSpace: cs,
                        colors: [rgb(78, 88, 106), rgb(45, 51, 63), rgb(24, 28, 35)] as CFArray,
                        locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(bg,
                           start: CGPoint(x: 0, y: bodyRect.maxY),
                           end: CGPoint(x: 0, y: bodyRect.minY),
                           options: [])
    ctx.restoreGState()

    if S >= 64 {   // 小サイズでは縁の光がノイズになるので入れない
        ctx.saveGState()
        ctx.addPath(base)
        ctx.clip()
        ctx.addPath(squircle(in: bodyRect.insetBy(dx: S * 0.003, dy: S * 0.003)))
        ctx.setStrokeColor(white(1, 0.22))
        ctx.setLineWidth(S * 0.005)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // ウィンドウ
    let winW = (body * sp.winRatio).rounded()
    let winH = (winW * 0.834).rounded()
    let winRect = CGRect(x: ((S - winW) / 2).rounded(), y: ((S - winH) / 2).rounded(),
                         width: winW, height: winH)
    let corner = max(2, S * 0.045)
    let winPath = CGPath(roundedRect: winRect, cornerWidth: corner, cornerHeight: corner, transform: nil)

    let barH = sp.showBar ? max(2, (winH * 0.131).rounded()) : 0
    let groove = max(1, sp.groove.rounded())
    let grooveColor = rgb(34, 39, 49)

    ctx.saveGState()
    if sp.shadow {
        ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.01), blur: S * 0.025, color: white(0, 0.40))
    }
    ctx.addPath(winPath)
    ctx.setFillColor(white(0.97))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(winPath)
    ctx.clip()

    if sp.showBar {
        ctx.setFillColor(white(0.88))
        ctx.fill(CGRect(x: winRect.minX, y: winRect.maxY - barH, width: winW, height: barH))
    }

    // 本体を 3列に割り、右端の列だけ上下 2段にする。
    // 左右非対称にしておかないと溝が「H」の字に見えてしまう。
    let bodyY = winRect.minY
    let bodyH = winH - barH
    let colW = (winW - groove * 2) / 3

    ctx.setFillColor(grooveColor)
    for i in 1...2 {
        let x = (winRect.minX + colW * CGFloat(i) + groove * CGFloat(i - 1)).rounded()
        ctx.fill(CGRect(x: x, y: bodyY, width: groove, height: bodyH))
    }
    if sp.showRowSplit {
        let rightX = (winRect.minX + (colW + groove) * 2).rounded()
        ctx.fill(CGRect(x: rightX, y: (bodyY + (bodyH - groove) / 2).rounded(),
                        width: colW, height: groove))
    }
    ctx.restoreGState()

    if sp.showDots {
        let dotR = winH * 0.0265
        let dotY = winRect.maxY - barH / 2
        let step = winH * 0.0805
        for (i, c) in [rgb(255, 95, 87), rgb(254, 188, 46), rgb(40, 200, 64)].enumerated() {
            let cx = winRect.minX + winH * 0.0805 + CGFloat(i) * step
            ctx.setFillColor(c)
            ctx.fillEllipse(in: CGRect(x: cx - dotR, y: dotY - dotR, width: dotR * 2, height: dotR * 2))
        }
    }

    guard let image = ctx.makeImage() else { fatalError("画像を生成できませんでした") }
    return image
}

// MARK: - 書き出し

func writePNG(_ image: CGImage, to path: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG に変換できませんでした")
    }
    try! data.write(to: URL(fileURLWithPath: path))
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "TermGrid.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// (ピクセル数, iconset 内でのファイル名) — 32 や 256 は 2 つの役割を兼ねる
let entries: [(CGFloat, [String])] = [
    (16,   ["icon_16x16.png"]),
    (32,   ["icon_16x16@2x.png", "icon_32x32.png"]),
    (64,   ["icon_32x32@2x.png"]),
    (128,  ["icon_128x128.png"]),
    (256,  ["icon_128x128@2x.png", "icon_256x256.png"]),
    (512,  ["icon_256x256@2x.png", "icon_512x512.png"]),
    (1024, ["icon_512x512@2x.png"]),
]

for (size, names) in entries {
    let image = drawIcon(size: size)
    for n in names {
        writePNG(image, to: "\(outDir)/\(n)")
    }
}
print("wrote: \(outDir)")
