# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require 'tmpdir'
require 'vivlio/pdf'

class TestTocItem < Minitest::Test
  RAW = [
    { 'id' => 'c1', 'title' => '第1章', 'children' => [
      { 'id' => 'c1s1', 'title' => '1.1', 'children' => [] }
    ] },
    { 'id' => 'c2', 'title' => '第2章', 'children' => [] }
  ].freeze

  def test_build_forest
    items = Vivlio::PDF::TocItem.build(RAW)

    assert_equal 2, items.size
    assert_equal '第1章', items.first.title
    assert_equal 'c1s1', items.first.children.first.id
    assert_predicate items.last, :leaf?
  end

  def test_each_is_depth_first_over_subtree
    items = Vivlio::PDF::TocItem.build(RAW)

    assert_equal %w[第1章 1.1], items.first.map(&:title)
    assert_equal 2, items.first.count
  end

  def test_label_falls_back_to_id
    item = Vivlio::PDF::TocItem.new(id: 'anchor')

    assert_equal 'anchor', item.label
  end

  def test_build_handles_nil
    assert_empty Vivlio::PDF::TocItem.build(nil)
  end
end

class TestMetadata < Minitest::Test
  def test_empty_when_there_is_nothing_to_write
    assert_predicate Vivlio::PDF::Metadata.new, :empty?
    refute_predicate Vivlio::PDF::Metadata.new(title: 'x'), :empty?
    refute_predicate Vivlio::PDF::Metadata.new(creator: 'mine'), :empty?
  end

  def test_with_creator_fills_in_but_never_overrides
    stamped = Vivlio::PDF::Metadata.new(title: 'T').with_creator('vivlio-pdf 9.9')

    assert_equal 'vivlio-pdf 9.9', stamped.creator
    assert_equal 'T', stamped.title

    chosen = Vivlio::PDF::Metadata.new(creator: 'mine')

    assert_same chosen, chosen.with_creator('vivlio-pdf 9.9')
  end

  def test_coerce_from_hash
    metadata = Vivlio::PDF::Metadata.coerce(title: 'T', author: 'A')

    assert_equal 'T', metadata.title
    assert_equal({ title: 'T', author: 'A' }, metadata.to_h)
  end

  def test_coerce_passes_through_and_rejects_junk
    metadata = Vivlio::PDF::Metadata.new(title: 'T')

    assert_same metadata, Vivlio::PDF::Metadata.coerce(metadata)
    assert_raises(ArgumentError) { Vivlio::PDF::Metadata.coerce(42) }
  end

  def test_write_to_only_sets_present_fields
    info = {}
    Vivlio::PDF::Metadata.new(title: 'T').write_to(info)

    assert_equal 'T', info[:Title]
    refute info.key?(:Author)
  end
end

class TestOutline < Minitest::Test
  def test_resolve_modes
    assert_kind_of Vivlio::PDF::Outline::Toc, Vivlio::PDF::Outline.resolve(:toc)
    assert_kind_of Vivlio::PDF::Outline::Toc, Vivlio::PDF::Outline.resolve(nil)
    assert_kind_of Vivlio::PDF::Outline::Headings, Vivlio::PDF::Outline.resolve('headings')
    assert_kind_of Vivlio::PDF::Outline::None, Vivlio::PDF::Outline.resolve(:none)
    assert_raises(ArgumentError) { Vivlio::PDF::Outline.resolve(:nope) }
  end

  def test_resolve_booleans
    assert_kind_of Vivlio::PDF::Outline::Toc, Vivlio::PDF::Outline.resolve(true)
    assert_kind_of Vivlio::PDF::Outline::None, Vivlio::PDF::Outline.resolve(false)
  end

  def test_only_headings_delegates_to_chromium
    refute_predicate Vivlio::PDF::Outline.resolve(:toc), :chromium_generated?
    assert_predicate Vivlio::PDF::Outline.resolve(:headings), :chromium_generated?
  end

  def test_toc_reads_entries_from_session
    session = Object.new
    def session.toc = [:entry]

    assert_equal [:entry], Vivlio::PDF::Outline.resolve(:toc).entries(session)
    assert_empty Vivlio::PDF::Outline.resolve(:none).entries(session)
    assert_empty Vivlio::PDF::Outline.resolve(:headings).entries(session)
  end
end

class TestSource < Minitest::Test
  FIXTURE = File.expand_path('fixtures/smoke.html', __dir__)

  def test_url_is_absolute_file_url
    assert_equal "file://#{FIXTURE}", Vivlio::PDF::Source.new(FIXTURE).url
  end

  def test_publication_detection
    refute_predicate Vivlio::PDF::Source.new(FIXTURE), :publication?
  end

  def test_missing_file_raises
    assert_raises(Vivlio::PDF::Error) { Vivlio::PDF::Source.new('/nope/missing.html') }
  end
end

class TestViewer < Minitest::Test
  FIXTURE = File.expand_path('fixtures/smoke.html', __dir__)

  def test_vendored_viewer_reports_its_own_version
    viewer = Vivlio::PDF::Viewer.default

    assert_path_exists viewer.index_path
    assert_match(/\A\d+\.\d+\.\d+/, viewer.version)
  end

  def test_url_carries_render_all_pages
    url = Vivlio::PDF::Viewer.default.url_for(FIXTURE, book_mode: true)

    assert_includes url, 'renderAllPages=true'
    assert_includes url, 'bookMode=true'
    assert_includes url, "src=file://#{FIXTURE}"
  end

  def test_book_mode_can_be_disabled
    refute_includes Vivlio::PDF::Viewer.default.url_for(FIXTURE, book_mode: false), 'bookMode'
  end

  def test_unknown_path_raises
    assert_raises(Vivlio::PDF::Error) { Vivlio::PDF::Viewer.new('/nope') }
  end
end

class TestPrintOptions < Minitest::Test
  FIXTURE = File.expand_path('fixtures/smoke.html', __dir__)

  def test_typo_in_option_is_rejected
    error = assert_raises(ArgumentError) do
      Vivlio::PDF.print(source: FIXTURE, output: 'x.pdf', stlye: 'print.css')
    end
    assert_match(/unknown keyword: :stlye/, error.message)
  end

  def test_source_is_required
    assert_raises(ArgumentError) { Vivlio::PDF.print(output: 'x.pdf') }
  end

  # README promises that every conversion failure arrives as a
  # Vivlio::PDF::Error. Spawning a browser that does not exist raises
  # Errno::ENOENT, not a Ferrum error, so it needs translating too.
  def test_missing_browser_becomes_a_browser_error
    error = assert_raises(Vivlio::PDF::BrowserError) do
      Vivlio::PDF.print(source: FIXTURE, output: 'x.pdf',
                        browser_path: '/nonexistent/chrome')
    end
    assert_match(/nonexistent/, error.message)
  end

  # The declared option lists are what Vivlio::PDF.print validates against, so
  # a keyword added to either signature has to be added to its list too.
  def test_option_lists_match_the_signatures
    assert_equal optional_keywords(:initialize), Vivlio::PDF::Printer::SETUP_OPTIONS
    assert_equal optional_keywords(:print), Vivlio::PDF::Printer::PRINT_OPTIONS
  end

  def test_missing_stylesheet_is_reported_before_the_browser_starts
    error = assert_raises(Vivlio::PDF::Error) do
      Vivlio::PDF.print(source: FIXTURE, output: 'x.pdf', style: '/nope/print.css')
    end
    assert_match(%r{stylesheet not found: /nope/print\.css}, error.message)
  end

  private

  def optional_keywords(method)
    Vivlio::PDF::Printer.instance_method(method).parameters
                        .filter_map { |kind, name| name if kind == :key }
  end
end

class TestLocalFile < Minitest::Test
  FIXTURE = File.expand_path('fixtures/smoke.html', __dir__)

  def test_url_is_an_absolute_file_url
    assert_equal "file://#{FIXTURE}", Vivlio::PDF::LocalFile.new(FIXTURE).url
  end

  def test_each_path_segment_is_escaped_separately
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'a b', 'c#d.css')
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, '')
      url = Vivlio::PDF::LocalFile.new(path).url

      # separators survive, the characters inside a segment do not
      assert_includes url, 'a%20b/c%23d.css'
    end
  end

  def test_missing_file_is_named_by_kind
    error = assert_raises(Vivlio::PDF::Error) do
      Vivlio::PDF::LocalFile.new('/nope/x.css', kind: 'stylesheet')
    end
    assert_match(%r{stylesheet not found: /nope/x\.css}, error.message)
  end
end

class TestStagedFile < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @destination = File.join(@dir, 'out.pdf')
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_moves_the_finished_file_into_place
    returned = Vivlio::PDF::StagedFile.write(@destination) do |staged|
      File.write(staged, 'done')
      refute_path_exists @destination, 'nothing should appear at the destination until it is finished'
      :result
    end

    assert_equal :result, returned
    assert_equal 'done', File.read(@destination)
  end

  def test_leaves_nothing_behind_when_the_block_raises
    assert_raises(RuntimeError) do
      Vivlio::PDF::StagedFile.write(@destination) do |staged|
        File.write(staged, 'partial')
        raise 'boom'
      end
    end

    refute_path_exists @destination
    assert_empty Dir.children(@dir)
  end

  def test_cleans_up_a_stale_staged_file_from_a_killed_run
    File.write("#{@destination}.part", 'stale')

    Vivlio::PDF::StagedFile.write(@destination) { |staged| File.write(staged, 'done') }

    assert_equal 'done', File.read(@destination)
  end

  # The staged path is claimed (created empty, exclusively) before the block
  # runs, so nothing can slip a symlink in under a predictable name.
  def test_claims_the_staged_path_before_yielding
    Vivlio::PDF::StagedFile.write(@destination) do |staged|
      assert_path_exists staged
      File.write(staged, 'x')
    end
  end

  def test_a_planted_symlink_cannot_redirect_the_write
    victim = File.join(@dir, 'victim.txt')
    File.write(victim, 'untouched')
    File.symlink(victim, "#{@destination}.part")

    Vivlio::PDF::StagedFile.write(@destination) { |staged| File.binwrite(staged, 'pdf bytes') }

    assert_equal 'untouched', File.read(victim), 'the write must not go through the symlink'
    assert_equal 'pdf bytes', File.read(@destination)
  end
end

class TestSession < Minitest::Test
  # A page that never renders, standing in for a Ferrum page.
  class BrokenPage
    attr_reader :closed

    def initialize(error)
      @error = error
      @closed = false
    end

    def go_to(_url) = raise(@error)
    def close = @closed = true
  end

  def test_open_closes_the_tab_when_the_document_never_renders
    page = BrokenPage.new(Ferrum::TimeoutError)

    assert_raises(Vivlio::PDF::TimeoutError) do
      Vivlio::PDF::Session.open(page, 'file:///x', timeout: 1)
    end
    assert page.closed, 'a failed conversion must not leak its tab'
  end

  # Callers should have to rescue one namespace, not ferrum's as well.
  def test_ferrum_errors_are_translated
    assert_raises(Vivlio::PDF::TimeoutError) do
      Vivlio::PDF::Session.open(BrokenPage.new(Ferrum::TimeoutError), 'file:///x', timeout: 1)
    end
    assert_raises(Vivlio::PDF::BrowserError) do
      Vivlio::PDF::Session.open(BrokenPage.new(Ferrum::DeadBrowserError), 'file:///x', timeout: 1)
    end
  end
end

class TestDocument < Minitest::Test
  def setup
    @path = File.expand_path('../tmp/test_document.pdf', __dir__)
    FileUtils.mkdir_p(File.dirname(@path))
    pdf = HexaPDF::Document.new
    pdf.pages.add
    pdf.write(@path)
    @original = File.binread(@path)
  end

  def test_block_form_saves_on_success
    Vivlio::PDF::Document.open(@path) do |document|
      document.metadata = Vivlio::PDF::Metadata.new(title: 'Saved')
    end

    assert_equal 'Saved', HexaPDF::Document.open(@path).trailer.info[:Title]
  end

  def test_block_form_leaves_the_file_alone_when_the_block_raises
    assert_raises(RuntimeError) do
      Vivlio::PDF::Document.open(@path) do |document|
        document.metadata = Vivlio::PDF::Metadata.new(title: 'Half written')
        raise 'boom'
      end
    end

    assert_equal @original, File.binread(@path)
  end

  def test_bookmark_count_reads_the_pdf_itself
    Vivlio::PDF::Document.open(@path) do |document|
      assert_equal 0, document.bookmark_count
      document.outline = Vivlio::PDF::TocItem.build(TestTocItem::RAW)
      # two chapters, one section
      assert_equal 3, document.bookmark_count
    end
  end
end
