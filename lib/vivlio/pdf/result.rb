# frozen_string_literal: true

module Vivlio
  module PDF
    # The outcome of one conversion.
    #
    # Behaves like the output path in string contexts, so callers that only
    # care where the file landed can keep treating the return value as one.
    class Result
      # +outline+ is the table of contents we read from the viewer, empty when
      # the bookmarks came from Chromium instead. +bookmarks+ counts what the
      # PDF really contains, so it holds for every outline mode.
      attr_reader :path, :pages, :bookmarks, :outline, :warnings

      def initialize(path:, pages:, bookmarks:, outline: [], warnings: [])
        @path = path.to_s
        @pages = pages
        @bookmarks = bookmarks
        @outline = outline.freeze
        @warnings = warnings.freeze
        freeze
      end

      def size
        File.size(path)
      end

      def to_s
        path
      end
      alias to_str to_s

      def inspect
        "#<#{self.class} #{path.inspect} pages=#{pages} bookmarks=#{bookmarks}>"
      end
    end
  end
end
