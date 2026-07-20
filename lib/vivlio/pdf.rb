# frozen_string_literal: true

require 'ferrum'

require_relative 'pdf/version'

module Vivlio
  # HTML, unzipped EPUB, or webpub → PDF, rendered by the Vivliostyle Viewer
  # in a local Chrome/Chromium driven over CDP. No Node.js required.
  module PDF
    class Error < StandardError; end

    # The viewer reported that it could not lay the document out.
    class RenderError < Error; end

    # Rendering did not finish within the configured timeout.
    class TimeoutError < Error; end

    # The browser could not be started, or stopped answering.
    class BrowserError < Error; end

    # How we drive Chrome is an implementation detail, so Ferrum's exceptions
    # are translated at every point they can escape: callers only ever have to
    # rescue Vivlio::PDF::Error.
    def self.translate_browser_errors
      yield
    rescue Ferrum::TimeoutError => e
      raise TimeoutError, e.message
    rescue Ferrum::Error => e
      raise BrowserError, e.message
    end

    # Converts one document, starting and stopping a browser around it.
    # Prefer a Printer when converting several documents in a row.
    #
    # Options are split between the browser session and the conversion by
    # Printer::SETUP_OPTIONS and Printer::PRINT_OPTIONS; anything else is a
    # typo, and saying so beats silently ignoring it.
    #
    #   Vivlio::PDF.print(source: 'book/OEBPS/package.opf', output: 'book.pdf')
    def self.print(source:, output:, **options)
      unknown = options.keys - Printer::SETUP_OPTIONS - Printer::PRINT_OPTIONS
      unless unknown.empty?
        raise ArgumentError, "unknown keyword#{'s' if unknown.size > 1}: " \
                             "#{unknown.map(&:inspect).join(', ')}"
      end

      Printer.open(**options.slice(*Printer::SETUP_OPTIONS)) do |printer|
        printer.print(source: source, output: output, **options.slice(*Printer::PRINT_OPTIONS))
      end
    end
  end
end

require_relative 'pdf/local_file'
require_relative 'pdf/source'
require_relative 'pdf/viewer'
require_relative 'pdf/toc_item'
require_relative 'pdf/metadata'
require_relative 'pdf/outline'
require_relative 'pdf/session'
require_relative 'pdf/staged_file'
require_relative 'pdf/document'
require_relative 'pdf/result'
require_relative 'pdf/printer'
