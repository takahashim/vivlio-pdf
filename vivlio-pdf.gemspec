# frozen_string_literal: true

require_relative 'lib/vivlio/pdf/version'

Gem::Specification.new do |spec|
  spec.name = 'vivlio-pdf'
  spec.version = Vivlio::PDF::VERSION
  spec.authors = ['Masayoshi Takahashi']
  spec.summary = 'CSS paged-media PDF generation for Ruby, powered by Vivliostyle'
  spec.description = <<~DESC
    Renders HTML, unzipped EPUB, or webpub publications to print-quality PDF
    (running headers, page counters, TOC leaders, PDF bookmarks) by driving a
    local Chrome/Chromium through CDP with the bundled Vivliostyle Viewer.
    No Node.js required.
  DESC
  spec.homepage = 'https://github.com/takahashim/vivlio-pdf'
  spec.license = 'AGPL-3.0-or-later'
  spec.required_ruby_version = '>= 3.1'

  spec.files = Dir['lib/**/*.rb', 'vendor/viewer/**/*', 'LICENSE.txt', 'README.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'ferrum', '~> 0.17'
  spec.add_dependency 'hexapdf', '~> 1.0'
end
