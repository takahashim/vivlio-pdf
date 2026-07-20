# frozen_string_literal: true

require 'ferrum'

module Vivlio
  module PDF
    # Renders documents to PDF through a browser running the Vivliostyle Viewer.
    #
    # A Printer owns one browser instance. Reuse it across conversions and
    # close it when done, or use the block form which closes it for you:
    #
    #   Vivlio::PDF::Printer.open do |printer|
    #     printer.print(source: 'a.html', output: 'a.pdf')
    #     printer.print(source: 'b.html', output: 'b.pdf')
    #   end
    class Printer
      DEFAULT_TIMEOUT = 300

      # Chromium refuses XHR against file:// without this, and the viewer
      # fetches the source document that way. Build-tool usage only.
      BROWSER_OPTIONS = { 'allow-file-access-from-files' => nil }.freeze

      # The optional keywords of .new and of #print: the option surface
      # Vivlio::PDF.print routes and validates against. Spelled out rather
      # than derived from the signatures, because these are public API and a
      # parameter rename should not quietly become an API change. A unit test
      # fails if either signature drifts away from its list.
      SETUP_OPTIONS = %i[viewer browser_path timeout].freeze
      PRINT_OPTIONS = %i[outline metadata book_mode style].freeze

      # What one pass through the viewer produced, besides the PDF bytes.
      Rendering = Struct.new(:entries, :warnings)

      attr_reader :viewer, :timeout

      def self.open(**options)
        printer = new(**options)
        return printer unless block_given?

        begin
          yield printer
        ensure
          printer.close
        end
      end

      def initialize(viewer: nil, browser_path: nil, timeout: DEFAULT_TIMEOUT)
        @viewer = Viewer.coerce(viewer)
        @timeout = timeout
        @browser_path = browser_path
      end

      # Renders +source+ and writes a PDF to +output+, returning a Result.
      def print(source:, output:, outline: :toc, metadata: nil, book_mode: nil, style: nil)
        source = Source.coerce(source)
        strategy = Outline.resolve(outline)
        metadata = Metadata.coerce(metadata)
        book_mode = source.publication? if book_mode.nil?
        url = @viewer.url_for(source, book_mode: book_mode, style: style)

        StagedFile.write(output) do |staged|
          rendering = render(url, strategy, staged)
          pages, bookmarks = finalize(staged, metadata: metadata, entries: rendering.entries)
          Result.new(path: output, pages: pages, bookmarks: bookmarks,
                     outline: rendering.entries, warnings: rendering.warnings)
        end
      end

      def browser
        @browser ||= PDF.translate_browser_errors do
          Ferrum::Browser.new(
            headless: true,
            timeout: @timeout,
            browser_path: @browser_path,
            browser_options: BROWSER_OPTIONS
          )
        end
      end

      def close
        PDF.translate_browser_errors { @browser&.quit }
        @browser = nil
      end

      private

      # Lays the document out and writes the printed bytes to +staged+.
      def render(url, strategy, staged)
        with_session(url) do |session|
          entries = strategy.entries(session)
          File.binwrite(staged, session.to_pdf(generate_outline: strategy.chromium_generated?))
          Rendering.new(entries, session.warnings)
        end
      end

      def with_session(url)
        page = PDF.translate_browser_errors { browser.create_page }
        session = Session.open(page, url, timeout: @timeout)
        begin
          yield session
        ensure
          session.close
        end
      end

      # Applies metadata and bookmarks, and reports what the finished PDF holds.
      def finalize(output, metadata:, entries:)
        Document.open(output) do |document|
          document.metadata = metadata.with_creator(creator) unless metadata.empty?
          document.outline = entries
          [document.page_count, document.bookmark_count]
        end
      end

      # How the PDF says it was made. The viewer version is read off the viewer
      # actually in use, so it stays true when a caller supplies their own.
      def creator
        "vivlio-pdf #{VERSION} (Vivliostyle Viewer #{@viewer.version || 'unknown'})"
      end
    end
  end
end
