# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require 'hexapdf'
require 'vivlio/pdf'

class TestSmoke < Minitest::Test
  FIXTURE = File.expand_path('fixtures/smoke.html', __dir__)
  TMPDIR = File.expand_path('../tmp', __dir__)

  def setup
    FileUtils.mkdir_p(TMPDIR)
  end

  def test_html_to_pdf_with_outline_and_metadata
    out = File.join(TMPDIR, 'test_smoke.pdf')
    result = Vivlio::PDF.print(
      source: FIXTURE,
      output: out,
      book_mode: true,
      metadata: { title: 'Smoke Test', author: 'vivlio-pdf' }
    )

    assert_kind_of Vivlio::PDF::Result, result
    assert_equal out, result.path
    # a Result stands in for its path
    assert_equal out, File.expand_path(result)

    # toc page + 2 chapters (break-before: page)
    assert_equal 3, result.pages
    assert_equal 2, result.bookmarks

    doc = HexaPDF::Document.open(out)

    # @page size: 182mm 257mm (B5)
    media = doc.pages[0].box(:media)
    assert_in_delta 182.0, media.width * 25.4 / 72, 0.5
    assert_in_delta 257.0, media.height * 25.4 / 72, 0.5

    assert_equal 'Smoke Test', doc.trailer.info[:Title]
    # the version of the viewer that actually rendered it, not a constant
    assert_equal "vivlio-pdf #{Vivlio::PDF::VERSION} " \
                 "(Vivliostyle Viewer #{Vivlio::PDF::Viewer.default.version})",
                 doc.trailer.info[:Creator]

    titles = []
    doc.outline.each_item do |item|
      titles << item.title
      refute_nil item.destination, "outline item #{item.title} lacks a destination"
    end
    assert_equal %w[第1章 第2章], titles
  end

  def test_outline_none_skips_bookmarks
    out = File.join(TMPDIR, 'test_no_outline.pdf')
    result = Vivlio::PDF.print(source: FIXTURE, output: out,
                               outline: :none, metadata: { title: 'No outline' })

    assert_equal 0, result.bookmarks
    assert_equal 3, result.pages

    # counting bookmarks must not be what puts an outline in the file
    refute HexaPDF::Document.open(out).catalog.key?(:Outlines)
  end

  # Chromium builds these bookmarks itself, so counting the TocItems we read
  # would report none. Result#bookmarks has to describe the actual PDF.
  def test_outline_headings_counts_the_bookmarks_chromium_wrote
    out = File.join(TMPDIR, 'test_headings.pdf')
    result = Vivlio::PDF.print(source: FIXTURE, output: out, outline: :headings)

    assert_empty result.outline
    assert_equal 3, result.bookmarks

    titles = []
    HexaPDF::Document.open(out).outline.each_item { |item| titles << item.title }
    assert_equal result.bookmarks, titles.size
  end

  def test_failed_conversion_leaves_no_file_behind
    out = File.join(TMPDIR, 'test_never_written.pdf')
    FileUtils.rm_f(out)

    assert_raises(Vivlio::PDF::Error) do
      Vivlio::PDF.print(source: FIXTURE, output: out, style: '/nope/missing.css')
    end

    refute_path_exists out
    refute_path_exists "#{out}.part"
  end

  def test_printer_reuses_one_browser
    first = File.join(TMPDIR, 'test_reuse_a.pdf')
    second = File.join(TMPDIR, 'test_reuse_b.pdf')

    Vivlio::PDF::Printer.open do |printer|
      browser = printer.browser
      printer.print(source: FIXTURE, output: first, outline: :none)
      printer.print(source: FIXTURE, output: second, outline: :none)
      assert_same browser, printer.browser
    end

    assert_operator File.size(first), :>, 0
    assert_operator File.size(second), :>, 0
  end
end
