<div align="center">
<img src="docs/icon.png" width="160" alt="TermGrid">

# TermGrid

**macOS のターミナルを、選んだレイアウトに一発で並べるメニューバーアプリ**

</div>

メニューバーから分割数を選ぶだけで、ターミナルのウィンドウが整列します。
枚数が足りなければ自動で開いて埋めます。

## できること

- 2分割 / 3分割 / 4分割 / 6分割 などをメニューから選ぶだけ
- 足りない分のターミナルを自動で開く
- **マウスカーソルのある画面**が対象。外部ディスプレイでもそのまま使える
- メニューバー常駐（Dock には出ない）
- コマンドラインからも実行可能（Raycast・ショートカット向け）

| レイアウト | 枚数 |
| --- | --- |
| 2分割（左右） | 2 |
| 2分割（上下） | 2 |
| 3分割（縦） | 3 |
| 4分割（2×2） | 4 |
| 6分割（3×2） | 6 |
| 左1・中2・右1 | 4 |

既存ウィンドウは**今の並び順（左→右、上→下）を保ったまま**割り当てられるため、
どのセッションがどこへ動くか入れ替わりません。

## インストール

```sh
git clone https://github.com/ikkei0713-collab/TermGrid.git
cd TermGrid
./build.sh
open ~/Applications/TermGrid.app
```

Xcode は不要です（Command Line Tools の `swiftc` のみ使用）。

初回起動後、最初にレイアウトを選んだ時点で **オートメーションの許可** を求められます。
許可しなかった場合は、システム設定 → プライバシーとセキュリティ → オートメーション →
TermGrid の「ターミナル」にチェックを入れてください。

ログイン時に自動起動したい場合は、システム設定 → 一般 → ログイン項目 に
`~/Applications/TermGrid.app` を追加します。

## コマンドライン

```sh
TG=~/Applications/TermGrid.app/Contents/MacOS/TermGrid

$TG --list        # レイアウト一覧
$TG --apply 4     # 6分割を適用（足りない分は新しく開く）
$TG --tidy 2      # 3分割で整列のみ（新しく開かない）
$TG --dry 4       # 適用せず座標だけ表示
```

## レイアウトを追加する

`main.swift` 冒頭の `LAYOUTS` に1行足して `./build.sh` を実行するだけです。

```swift
LayoutDef(title: "左3・右1", columns: [3, 1]),
```

`columns` は **各列に何段入れるか**を表します。`[2, 2, 2]` なら3列×2段の6分割、
`[1, 2, 1]` なら左1枚・中央2枚・右1枚。ウィンドウ同士の隙間は `GAP`（既定 4pt）で変えられます。

## 仕組み

- ウィンドウの操作は AppleScript 経由（`bounds` の設定）
- 対象は `visible` かつタブを持つウィンドウのみ。設定ウィンドウなどは巻き込みません
- 配置領域は `NSScreen.visibleFrame`。メニューバーと Dock を自動で避けます
- NSScreen（左下原点）と AppleScript（左上原点）の座標系の差はアプリ側で吸収しています

## アイコンについて

`makeicon.swift` が CoreGraphics で全サイズを描画します。画像ファイルは同梱していません。

- 角丸は円弧ではなく superellipse（`|x|^n + |y|^n = 1`, n=4.6）
- 16px / 32px は縮小すると溝が潰れるため、溝の太さや要素の有無を変えて個別に描画

## 必要環境

macOS 13 以降 / Xcode Command Line Tools

## ライセンス

MIT
