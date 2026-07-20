# frozen_string_literal: true

require 'hexapdf'

module Vivlio
  module PDF
    # A PDF file on disk, opened for post-processing.
    #
    # Everything here happens after Chromium has printed: only the document
    # information dictionary and the bookmark outline are touched. Page
    # positions are never computed -- outline entries point at the named
    # destinations Chromium already embedded for in-document link targets.
    class Document
      # Saves only when the block returns normally: a conversion that raises
      # half way through leaves the file as Chromium printed it rather than
      # committing whichever edits happened to be applied first.
      def self.open(path, &block)
        document = new(path)
        return document unless block

        result = block.call(document)
        document.save
        result
      end

      def initialize(path)
        @path = path
        @pdf = HexaPDF::Document.open(path)
        @dirty = false
      end

      attr_reader :path

      def page_count
        @pdf.pages.count
      end

      # Bookmarks actually present, counted from the PDF itself so the number
      # is right whether we wrote them or Chromium did. Asking HexaPDF for the
      # outline would create one, so a document without bookmarks is answered
      # without touching it.
      def bookmark_count
        return 0 unless @pdf.catalog.key?(:Outlines)

        @pdf.outline.each_item.count
      end

      def metadata=(metadata)
        metadata.write_to(@pdf.trailer.info)
        @dirty = true
      end

      # +entries+ is a TocItem forest; nested items become nested bookmarks.
      def outline=(entries)
        return if entries.empty?

        add_bookmarks(entries, @pdf.outline)
        @dirty = true
      end

      def save
        return false unless @dirty

        @pdf.write(@path, optimize: true)
        @dirty = false
        true
      end

      private

      def add_bookmarks(entries, parent)
        entries.each do |entry|
          bookmark = parent.add_item(entry.label, destination: destination_for(entry))
          add_bookmarks(entry.children, bookmark)
        end
      end

      # Prefer the named destination Chromium created for the anchor; fall back
      # to the first page so an entry never dangles if the anchor was missing
      # from the DOM at print time.
      def destination_for(entry)
        return first_page_destination unless entry.id
        return entry.id if @pdf.destinations.resolve(entry.id)

        first_page_destination
      end

      def first_page_destination
        [@pdf.pages[0], :Fit]
      end
    end
  end
end
