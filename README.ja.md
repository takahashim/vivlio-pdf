# vivlio-pdf

CSS 組版による PDF 生成を Ruby から行う gem です。

[English README is here](./README.md)

ローカルの Chrome/Chromium を CDP / [ferrum](https://github.com/rubycdp/ferrum) 経由で起動し、同梱の [Vivliostyle Viewer](https://github.com/vivliostyle/vivliostyle.js) を使って CSS Paged Media(柱・ノンブル・目次リーダー・PDF しおり) に対応した印刷用PDFを出力します。

Node.js には依存せず、Ruby 単体で動作します。

## 必要環境

- Ruby >= 3.1
- Chrome / Chromium (ローカルにインストール済みであること)
- macOS / Linux (Windows はパスの `file://` URL 化が未対応)

## インストール

```ruby
# Gemfile
gem 'vivlio-pdf', github: 'takahashim/vivlio-pdf'
```

## 使い方

```ruby
require 'vivlio/pdf'

# 単発変換
begin
  result = Vivlio::PDF.print(
    source: 'book/OEBPS/package.opf', # HTML / 展開済みEPUBのOPF / webpub manifest
    output: 'book.pdf',
    outline: :toc,                    # :toc(既定) / :headings / :none
    metadata: { title: 'Vivliostyleで技術書をかこう！', author: 'takahashim' }
  )
rescue Vivlio::PDF::Error => e
  # 変換の失敗はすべてこの派生（TimeoutError / RenderError など）で届きます。
  # ブラウザ駆動の内部例外(Ferrum)がそのまま漏れてくることはありません。
  abort e.message
end

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

- `Printer`: ブラウザを保有し、変換全体を差配する
- `Viewer`: Viewer の所在と、文書を開く URL の組み立て
- `Source`: 変換対象の文書 (HTML / OPF / manifest)
- `Session`: 開かれた1文書用のセッション。描画完了待ち・目次取得・PDF化などに使用
- `Outline::{Toc,Headings,None}`: しおりの生成
- `TocItem`: 目次の木構造 (値オブジェクト)
- `Metadata`: 文書情報辞書に書く値 (値オブジェクト)
- `Document`: 出力 PDF。hexapdf でしおり・メタデータを書き込む
- `Result`: 変換結果(パス・ページ数・しおり数)

## PDF しおりの仕組み

`outline: :toc` では vivliostyle-cli と同じ方式を使います。

印刷前に目次リンクを DOM に表示して Chromium に名前付きデスティネーションを埋め込ませ、`coreViewer.getTOC()` の木構造から [hexapdf](https://hexapdf.gettalong.org/) で /Outlines を構築します。
ページ番号の計算は行いません。

## ライセンス

AGPL-3.0-or-later。詳細は [LICENSE](./LICENSE.txt) を参照してください。

- `vendor/viewer/` には [@vivliostyle/viewer](https://www.npmjs.com/package/@vivliostyle/viewer)(AGPL-3.0)を同梱しています。
  対応するソースコードは[vivliostyle/vivliostyle.js](https://github.com/vivliostyle/vivliostyle.js)の該当バージョンタグから入手できます。
- 依存gemのライセンスは ferrum は MIT、hexapdf は AGPL-3.0 です。

※ 本 gem で生成した PDF は AGPL の対象外です(ソフトウェア自体の配布・ネットワーク提供時のみ義務が発生します)

## 同梱している Viewer のバージョン

同梱中のバージョンは `vendor/viewer/package.json` に記録されており、実行時は
`Vivlio::PDF::Viewer.default.version` で参照できます。

Viewer は依存ではなく同梱物なので、gem のバージョンを固定すれば紙面が固定されます。
本のリポジトリで `Gemfile.lock` を維持していれば、あとから組み直しても同じ PDF が得られます。
入稿前に `bundle update` しないでください。

Viewer が変わるとページ送りが変わることがあります。テストが通っても変わります。
そのため本 gem では、Viewer の更新を含むリリースは patch では出しません(最低でも minor)。

別のバージョンを使いたい場合は、gem を待たずに差し替えられます。

```ruby
Vivlio::PDF.print(source: 'book.opf', output: 'book.pdf',
                  viewer: '/path/to/vivliostyle-viewer')
```

## Viewer の更新方法

```console
$ rake "viewer:update[2.45.0]"
```

バージョンは同梱の `package.json` から読むので、他に更新すべき箇所はありません。
ソースマップは同梱しません(実行時に不要で、他のファイルの合計より大きいため)。
Viewer の TypeScript を読みたいときは、npm の tarball から
`vendor/viewer/js/` に手で置いてください。`.gitignore` で除外してあります。

新しいリリースは GitHub Actions が週次で検出し、更新用のプルリクエストを起票します
(`.github/workflows/update-viewer.yml`)。自動マージはしません。
`test/test_viewer_behavior.rb` は Viewer の挙動を固定したテストで、
ここが落ちている場合は不具合ではなく Viewer 側の挙動が変わったことを意味します。
回避策を外せるようになった可能性があるので、内容を確認してください。
