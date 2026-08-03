import Cocoa

// MARK: - レイアウト定義
//
// 各列に何行入れるかで分割を表す。
//   [1, 1]     → 左右2分割
//   [2, 2, 2]  → 3列×2段の6分割
//   [1, 2, 1]  → 左1枚・中央2枚・右1枚

struct LayoutDef {
    let title: String
    let columns: [Int]
    var count: Int { columns.reduce(0, +) }
}

let LAYOUTS: [LayoutDef] = [
    LayoutDef(title: "2分割（左右）",   columns: [1, 1]),
    LayoutDef(title: "2分割（上下）",   columns: [2]),
    LayoutDef(title: "3分割（縦）",     columns: [1, 1, 1]),
    LayoutDef(title: "4分割（2×2）",   columns: [2, 2]),
    LayoutDef(title: "6分割（3×2）",   columns: [2, 2, 2]),
    LayoutDef(title: "左1・中2・右1",  columns: [1, 2, 1]),
]

/// ウィンドウ同士の隙間（ポイント）
let GAP: CGFloat = 4

/// メニューに並べる、そのレイアウトの形を表す小さな絵。
/// テンプレート画像にしておくとダーク／ライトや選択中の反転に自動で追従する。
func layoutIcon(for layout: LayoutDef, size: NSSize = NSSize(width: 19, height: 14)) -> NSImage {
    let image = NSImage(size: size, flipped: false) { _ in
        let gap = size.width / 12          // 大きさを変えても比率が保たれるようにする
        let radius = size.width / 24
        let nCols = CGFloat(layout.columns.count)
        let colW = (size.width - gap * (nCols - 1)) / nCols

        NSColor.black.setFill()
        for (ci, rows) in layout.columns.enumerated() {
            let x = (colW + gap) * CGFloat(ci)
            let nRows = CGFloat(rows)
            let rowH = (size.height - gap * (nRows - 1)) / nRows
            for ri in 0..<rows {
                // 上の段から描く
                let y = size.height - rowH - (rowH + gap) * CGFloat(ri)
                NSBezierPath(roundedRect: NSRect(x: x, y: y, width: colW, height: rowH),
                             xRadius: radius, yRadius: radius).fill()
            }
        }
        return true
    }
    image.isTemplate = true
    return image
}

// MARK: - 座標計算

/// AppleScript の bounds と同じ左上原点の矩形
struct Box {
    let l: Int, t: Int, r: Int, b: Int
}

/// マウスカーソルのある画面を対象にする（外部ディスプレイでも意図どおりに効く）
func targetScreen() -> NSScreen {
    let mouse = NSEvent.mouseLocation
    return NSScreen.screens.first { $0.frame.contains(mouse) }
        ?? NSScreen.main
        ?? NSScreen.screens[0]
}

func boxes(for layout: LayoutDef) -> [Box] {
    let screen = targetScreen()
    let vf = screen.visibleFrame          // メニューバーと Dock を除いた領域
    // NSScreen は左下原点、AppleScript は左上原点なので主画面の上端を基準に反転する
    let globalTop = NSScreen.screens[0].frame.maxY

    let originX = vf.minX
    let originY = globalTop - vf.maxY
    let totalW = vf.width
    let totalH = vf.height

    let nCols = CGFloat(layout.columns.count)
    let colW = (totalW - GAP * (nCols - 1)) / nCols

    var result: [Box] = []
    for (ci, rows) in layout.columns.enumerated() {
        let x = originX + (colW + GAP) * CGFloat(ci)
        let nRows = CGFloat(rows)
        let rowH = (totalH - GAP * (nRows - 1)) / nRows
        for ri in 0..<rows {
            let y = originY + (rowH + GAP) * CGFloat(ri)
            result.append(Box(l: Int(x.rounded()),
                              t: Int(y.rounded()),
                              r: Int((x + colW).rounded()),
                              b: Int((y + rowH).rounded())))
        }
    }
    return result
}

// MARK: - AppleScript

var lastErrorShown = false

@discardableResult
func runAppleScript(_ source: String) -> String? {
    guard let script = NSAppleScript(source: source) else { return nil }
    var err: NSDictionary?
    let out = script.executeAndReturnError(&err)
    if let err = err {
        showScriptError(err)
        return nil
    }
    return out.stringValue
}

func showScriptError(_ err: NSDictionary) {
    let num = err[NSAppleScript.errorNumber] as? Int ?? 0
    let msg = err[NSAppleScript.errorMessage] as? String ?? "不明なエラー"

    let alert = NSAlert()
    alert.messageText = "ターミナルを操作できませんでした"
    switch num {
    case -1743, -1744:
        alert.informativeText = """
        システム設定 → プライバシーとセキュリティ → オートメーション を開き、
        TermGrid の「ターミナル」にチェックを入れてください。
        """
    default:
        alert.informativeText = "\(msg)（\(num)）"
    }
    alert.alertStyle = .warning
    NSApp.activate(ignoringOtherApps: true)
    alert.runModal()
}

// MARK: - ターミナルのウィンドウ操作

struct TermWindow {
    let id: Int, x: Int, y: Int
}

/// 実体のあるターミナルウィンドウだけを拾う（設定ウィンドウ等を除外）
func currentWindows() -> [TermWindow] {
    let src = """
    tell application "Terminal"
      set r to ""
      repeat with w in windows
        try
          if visible of w and (count of tabs of w) > 0 then
            set b to bounds of w
            set r to r & (id of w) & "," & (item 1 of b) & "," & (item 2 of b) & linefeed
          end if
        end try
      end repeat
      return r
    end tell
    """
    guard let out = runAppleScript(src) else { return [] }
    return out.split(separator: "\n").compactMap { line in
        let f = line.split(separator: ",")
        guard f.count == 3, let id = Int(f[0]), let x = Int(f[1]), let y = Int(f[2]) else { return nil }
        return TermWindow(id: id, x: x, y: y)
    }
}

func openWindows(_ n: Int) {
    guard n > 0 else { return }
    runAppleScript("""
    tell application "Terminal"
      activate
      repeat \(n) times
        do script ""
      end repeat
    end tell
    """)
    // ウィンドウが実際に生成されるまで少し待つ
    Thread.sleep(forTimeInterval: 0.15 * Double(n) + 0.25)
}

func apply(_ layout: LayoutDef, openMissing: Bool) {
    let targets = boxes(for: layout)
    var wins = currentWindows()
    let existingIds = Set(wins.map { $0.id })

    if openMissing && wins.count < targets.count {
        openWindows(targets.count - wins.count)
        wins = currentWindows()
    }
    guard !wins.isEmpty else { return }

    // 既存ウィンドウは今の並び順（左→右、上→下）を保ったまま埋める。新しく開いた分は後ろへ。
    let old = wins.filter { existingIds.contains($0.id) }
                  .sorted { ($0.x, $0.y) < ($1.x, $1.y) }
    let fresh = wins.filter { !existingIds.contains($0.id) }
                    .sorted { $0.id < $1.id }
    let ordered = old + fresh

    var lines: [String] = []
    for (i, box) in targets.enumerated() where i < ordered.count {
        lines.append("set bounds of window id \(ordered[i].id) to {\(box.l), \(box.t), \(box.r), \(box.b)}")
    }
    guard !lines.isEmpty else { return }

    runAppleScript("""
    tell application "Terminal"
      activate
    \(lines.joined(separator: "\n  "))
    end tell
    """)
}

// MARK: - メニューバー

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var openMissing = UserDefaults.standard.object(forKey: "openMissing") as? Bool ?? true

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.split.3x1",
                                           accessibilityDescription: "ターミナル整列")
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        let header = NSMenuItem(title: "レイアウト", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        for (i, layout) in LAYOUTS.enumerated() {
            let item = NSMenuItem(title: layout.title, action: #selector(pick(_:)), keyEquivalent: "")
            item.tag = i
            item.target = self
            item.image = layoutIcon(for: layout)
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "足りない分は新しく開く", action: #selector(toggleOpen(_:)), keyEquivalent: "")
        toggle.target = self
        toggle.state = openMissing ? .on : .off
        menu.addItem(toggle)

        let tidy = NSMenuItem(title: "今あるウィンドウだけ整列", action: #selector(tidyNow(_:)), keyEquivalent: "")
        tidy.target = self
        menu.addItem(tidy)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "TermGrid を終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc func pick(_ sender: NSMenuItem) {
        apply(LAYOUTS[sender.tag], openMissing: openMissing)
    }

    @objc func toggleOpen(_ sender: NSMenuItem) {
        openMissing.toggle()
        UserDefaults.standard.set(openMissing, forKey: "openMissing")
        rebuildMenu()
    }

    /// 今開いている枚数にちょうど合うレイアウトを選んで整列する
    @objc func tidyNow(_ sender: NSMenuItem) {
        let n = currentWindows().count
        guard n > 0 else { return }
        let best = LAYOUTS.first { $0.count == n }
            ?? LAYOUTS.min { abs($0.count - n) < abs($1.count - n) }!
        apply(best, openMissing: false)
    }
}

// MARK: - 起動

let app = NSApplication.shared   // NSScreen / NSEvent を使うため CLI でも先に初期化する

// 引数つきで起動された場合はメニューを出さずにその場で処理して終わる。
//   TermGrid --list          レイアウト一覧
//   TermGrid --dry N         N番のレイアウトの座標を表示するだけ
//   TermGrid --apply N       N番のレイアウトを適用（足りない分は開く）
//   TermGrid --tidy N        N番のレイアウトで整列のみ（新規に開かない）
let args = CommandLine.arguments
if args.count > 1 {
    let flag = args[1]
    let index = args.count > 2 ? Int(args[2]) ?? -1 : -1

    func layoutAt(_ i: Int) -> LayoutDef? {
        (0..<LAYOUTS.count).contains(i) ? LAYOUTS[i] : nil
    }

    switch flag {
    case "--list":
        for (i, l) in LAYOUTS.enumerated() {
            print("\(i)  \(l.title)  （\(l.count)枚）")
        }
    case "--dry":
        guard let l = layoutAt(index) else { print("usage: TermGrid --dry <0-\(LAYOUTS.count - 1)>"); exit(1) }
        let s = targetScreen()
        print("screen: \(Int(s.frame.width))x\(Int(s.frame.height))  visible: \(s.visibleFrame)")
        print("\(l.title)")
        for (i, b) in boxes(for: l).enumerated() {
            print("  \(i + 1): \(b.l), \(b.t), \(b.r), \(b.b)")
        }
    case "--icons":
        // メニューに出るアイコンを拡大して書き出す（見た目の確認用）
        let dir = args.count > 2 ? args[2] : "."
        for (i, l) in LAYOUTS.enumerated() {
            let img = layoutIcon(for: l, size: NSSize(width: 19 * 8, height: 14 * 8))
            guard let tiff = img.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else { continue }
            try? png.write(to: URL(fileURLWithPath: "\(dir)/menu\(i).png"))
        }
        print("wrote \(LAYOUTS.count) icons to \(dir)")
    case "--apply", "--tidy":
        guard let l = layoutAt(index) else { print("usage: TermGrid \(flag) <0-\(LAYOUTS.count - 1)>"); exit(1) }
        apply(l, openMissing: flag == "--apply")
    default:
        print("usage: TermGrid [--list | --dry N | --apply N | --tidy N]")
        exit(1)
    }
    exit(0)
}

let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // Dock に出さずメニューバーだけに常駐
app.run()
