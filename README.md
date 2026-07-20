# vivlio-pdf

CSS typesetting from Ruby: a gem that renders print-quality PDFs.

[日本語版 README はこちら](./README.ja.md)

It drives a local Chrome/Chromium over CDP via [ferrum](https://github.com/rubycdp/ferrum), loading documents into the bundled [Vivliostyle Viewer](https://github.com/vivliostyle/vivliostyle.js) to produce PDFs with full CSS Paged Media support — running heads, page numbers, TOC leaders, and PDF bookmarks.

No Node.js required; it runs on Ruby alone.

## Requirements

- Ruby >= 3.1
- Chrome / Chromium (installed locally)
- macOS / Linux (Windows is not supported: paths are not converted to `file://` URLs correctly)

## Installation

```ruby
# Gemfile
gem 'vivlio-pdf', github: 'takahashim/vivlio-pdf'
```

## Usage

```ruby
require 'vivlio/pdf'

# One-shot conversion
begin
  result = Vivlio::PDF.print(
    source: 'book/OEBPS/package.opf', # HTML / OPF of an unzipped EPUB / webpub manifest
    output: 'book.pdf',
    outline: :toc,                    # :toc (default) / :headings / :none
    metadata: { title: 'Writing Books with Vivliostyle', author: 'takahashim' }
  )
rescue Vivlio::PDF::Error => e
  # Every conversion failure arrives as a subclass of this
  # (TimeoutError, RenderError, and so on). The browser-driving
  # internals (Ferrum) never leak their own exceptions.
  abort e.message
end

result.pages      #=> 120
result.bookmarks  #=> 79 (bookmarks actually present in the PDF)
result.warnings   #=> [] (problems the conversion survived, e.g. an unreadable TOC)
result.to_s       #=> "book.pdf" (also acts as a string)

# Several conversions, reusing one browser
Vivlio::PDF::Printer.open do |printer|
  printer.print(source: 'a.html', output: 'a.pdf', style: 'print.css')
  printer.print(source: 'b.html', output: 'b.pdf')
end
```

#### Main options

- `browser_path:` path to the Chrome executable (auto-detected when omitted)
- `viewer:` a Vivliostyle Viewer other than the bundled one (a path or a `Viewer` object)
- `timeout:` upper limit in seconds to wait for rendering (default 300)
- `style:` additional stylesheet path(s)
- `book_mode:` follow the TOC/spine and read the whole publication (default: true for OPF/manifest)

## Architecture

- `Printer`: owns the browser and orchestrates conversions
- `Viewer`: locates the viewer and builds the URL that opens a document
- `Source`: the document to convert (HTML / OPF / manifest)
- `Session`: one open document; waits for rendering, reads the TOC, prints to PDF
- `Outline::{Toc,Headings,None}`: bookmark generation strategies
- `TocItem`: the TOC tree (value object)
- `Metadata`: values written into the document information dictionary (value object)
- `Document`: the output PDF; writes bookmarks and metadata via hexapdf
- `Result`: the outcome of a conversion (path, page count, bookmark count)

## How PDF bookmarks work

With `outline: :toc`, the same approach as vivliostyle-cli is used.

Before printing, the TOC links are made visible in the DOM so that Chromium embeds named destinations for them; the tree from `coreViewer.getTOC()` is then written as `/Outlines` with [hexapdf](https://hexapdf.gettalong.org/).
No page numbers are computed.

## License

AGPL-3.0-or-later. See [LICENSE](./LICENSE.txt) for details.

- `vendor/viewer/` bundles [@vivliostyle/viewer](https://www.npmjs.com/package/@vivliostyle/viewer) (AGPL-3.0).
  The corresponding source code is available from the matching version tag of [vivliostyle/vivliostyle.js](https://github.com/vivliostyle/vivliostyle.js).
- Dependency licenses: ferrum is MIT, hexapdf is AGPL-3.0.

Note: PDFs produced with this gem are not subject to the AGPL. The obligations apply only to distributing the software itself or offering it over a network.

## The bundled viewer version

The bundled version is recorded in `vendor/viewer/package.json` and can be read at run time via `Vivlio::PDF::Viewer.default.version`.

The viewer is vendored, not a dependency, so pinning the gem version pins your page layout.
As long as your book's repository keeps its `Gemfile.lock`, rebuilding later produces the same PDF.
Do not `bundle update` right before going to press.

A viewer change can move lines between pages — even when every test passes.
For that reason, a release that updates the viewer is never a patch release (minor at minimum).

To use a different viewer version without waiting for a gem release:

```ruby
Vivlio::PDF.print(source: 'book.opf', output: 'book.pdf',
                  viewer: '/path/to/vivliostyle-viewer')
```

## Updating the viewer

```console
$ rake "viewer:update[2.45.0]"
```

The version is read from the bundled `package.json`, so nothing else needs to be kept in step.
Source maps are not vendored (they are unused at run time and larger than everything else combined).
To read the viewer's TypeScript, place the map into `vendor/viewer/js/` by hand from the npm tarball; `.gitignore` keeps it out of the way.

A GitHub Actions workflow checks for new releases weekly and opens an update pull request
(`.github/workflows/update-viewer.yml`). It never merges automatically.
`test/test_viewer_behavior.rb` pins the viewer's behaviour: a failure there is not a bug —
it means the viewer's behaviour changed, possibly in a way that lets a workaround be
removed, so read what it found.
