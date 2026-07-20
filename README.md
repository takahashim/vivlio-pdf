# vivlio-pdf

CSS 組版による PDF 生成を Ruby から行う gem です。
同梱の[Vivliostyle Viewer](https://github.com/vivliostyle/vivliostyle.js) をローカルの Chrome/Chromium 上で駆動し(CDP / [ferrum](https://github.com/rubycdp/ferrum))、CSS Paged Media(柱・ノンブル・目次リーダー・PDF しおり)に対応した印刷品質の PDF を出力します。

Node.js には依存せず、Ruby 単体で動作します。

## 必要環境

- Ruby >= 3.1
- Chrome / Chromium(ローカルにインストール済みであること)
- macOS / Linux(Windows はパスの `file://` URL 化が未対応)

## インストール

```ruby
# Gemfile
gem 'vivlio-pdf', github: 'takahashim/vivlio-pdf'
```

## 使い方

```ruby
require 'vivlio/pdf'

# 単発変換
result = Vivlio::PDF.print(
  source: 'book/OEBPS/package.opf', # HTML / 展開済みEPUBのOPF / webpub manifest
  output: 'book.pdf',
  outline: :toc,                    # :toc(既定) / :headings / :none
  metadata: { title: 'Vivliostyleで技術書をかこう！', author: 'takahashim' }
)

result.pages      #=> 120
result.bookmarks  #=> 79（PDF に実際に入ったしおりの数）
result.warnings   #=> []（目次が読めなかった等、変換は続行した問題）
result.to_s       #=> "book.pdf"（文字列としても振る舞う）

# 複数変換(ブラウザを使い回す)
Vivlio::PDF::Printer.open do |printer|
  printer.print(source: 'a.html', output: 'a.pdf', style: 'print.css')
  printer.print(source: 'b.html', output: 'b.pdf')
end
```

#### 主なオプション

- `browser_path:` Chrome 実行ファイルのパス(省略時は自動検出)
- `viewer:` 同梱以外の Vivliostyle Viewer(パスまたは `Viewer` オブジェクト)
- `timeout:` レンダリング待ちの上限秒(既定 300)
- `style:` 追加スタイルシートのパス(複数可)
- `book_mode:` 目次/spine をたどって全体を読む(既定: OPF/manifest なら true)

## 構成

| クラス | 責務 |
|---|---|
| `Printer` | ブラウザを保有し、変換全体を差配する |
| `Viewer` | Viewer の所在と、文書を開く URL の組み立て |
| `Source` | 変換対象の文書(HTML / OPF / manifest) |
| `Session` | 開かれた1文書。描画完了待ち・目次取得・PDF 化 |
| `Outline::{Toc,Headings,None}` | しおりの作り方(ストラテジ) |
| `TocItem` | 目次の木構造(値オブジェクト) |
| `Metadata` | 文書情報辞書に書く値(値オブジェクト) |
| `Document` | 出力 PDF。hexapdf でしおり・メタデータを書き込む |
| `Result` | 変換結果(パス・ページ数・しおり数) |

## PDF しおりの仕組み

`outline: :toc` では vivliostyle-cli と同じ方式を使います。
印刷前に目次リンクを DOM に表示して Chromium に名前付きデスティネーションを埋め込ませ、`coreViewer.getTOC()` の木構造から [hexapdf](https://hexapdf.gettalong.org/) で /Outlines を構築します。
ページ番号の計算は行いません。

## ライセンス

AGPL-3.0-or-later。詳細は [LICENSE](./LICENSE.txt) を参照してください。

- 本 gem で生成した PDF は AGPL の対象外です(ソフトウェア自体の配布・ネットワーク提供時のみ義務が発生します)
- `vendor/viewer/` には [@vivliostyle/viewer](https://www.npmjs.com/package/@vivliostyle/viewer)(AGPL-3.0)を同梱しています。
  対応するソースコードは[vivliostyle/vivliostyle.js](https://github.com/vivliostyle/vivliostyle.js)の該当バージョンタグから入手できます。
- 依存 gem: ferrum(MIT)、hexapdf(AGPL-3.0)

## Viewer の更新方法

```console
$ rake "viewer:update[2.45.0]"
```

バージョンは同梱の `package.json` から読むので、他に更新すべき箇所はありません。
