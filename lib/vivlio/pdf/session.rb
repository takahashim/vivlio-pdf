# frozen_string_literal: true

module Vivlio
  module PDF
    # One document open in the viewer, inside one browser tab.
    #
    # Wraps the CDP page so callers talk about rendering and printing rather
    # than about JavaScript evaluation, and so Ferrum's exceptions stop here.
    # A Session is single-use: open it, read from it, print it, close it.
    class Session
      READY_STATE = <<~JS
        window.coreViewer ? window.coreViewer.readyState : 'loading'
      JS

      # Reading the TOC has a side effect we depend on: the entries must be in
      # the DOM while printing for Chromium to emit named destinations for
      # them. Same approach as vivliostyle-cli.
      READ_TOC = <<~JS
        const done = arguments[0];
        function listener(payload) {
          if (payload.a !== 'toc') return;
          window.coreViewer.removeListener('done', listener);
          window.coreViewer.showTOC(false);
          done(window.coreViewer.getTOC());
        }
        window.coreViewer.addListener('done', listener);
        window.coreViewer.showTOC(true);
      JS

      POLL_INTERVAL = 0.2

      # Closes the tab if the document never renders, so a Printer reusing one
      # browser does not accumulate tabs across failed conversions.
      def self.open(page, url, timeout:)
        session = new(page, timeout: timeout)
        session.visit(url)
        session
      rescue StandardError
        begin
          session&.close
        rescue StandardError
          nil # whatever went wrong first is the failure worth reporting
        end
        raise
      end

      # Non-fatal problems met while rendering, in the order they happened.
      # Printer hands these to the caller as Result#warnings; nothing here
      # writes to stderr on the caller's behalf.
      attr_reader :warnings

      def initialize(page, timeout:)
        @page = page
        @timeout = timeout
        @warnings = []
      end

      def visit(url)
        PDF.translate_browser_errors { @page.go_to(url) }
        wait_until_ready
        self
      end

      # The publication's table of contents as a TocItem forest.
      #
      # A document that cannot report one still prints; the failure is recorded
      # in +warnings+ rather than aborting the conversion over an outline.
      def toc
        @toc ||= TocItem.build(read_toc)
      rescue Error => e
        @warnings << "could not read the table of contents (#{e.message}); outline skipped"
        @toc = []
      end

      # Renders the paginated document to PDF bytes.
      def to_pdf(generate_outline: false)
        parameters = {
          preferCSSPageSize: true,
          printBackground: true,
          transferMode: 'ReturnAsBase64'
        }
        parameters[:generateDocumentOutline] = true if generate_outline
        printed = PDF.translate_browser_errors { @page.command('Page.printToPDF', **parameters) }
        printed['data'].unpack1('m')
      end

      def close
        PDF.translate_browser_errors { @page.close }
      end

      private

      def read_toc
        PDF.translate_browser_errors { @page.evaluate_async(READ_TOC, @timeout) }
      end

      def wait_until_ready
        deadline = now + @timeout
        loop do
          case state = PDF.translate_browser_errors { @page.evaluate(READY_STATE) }
          when 'complete' then return
          when 'error' then raise RenderError, 'Vivliostyle reported a rendering error'
          end

          if now > deadline
            raise TimeoutError, "rendering did not finish within #{@timeout}s (readyState=#{state})"
          end

          sleep POLL_INTERVAL
        end
      end

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
