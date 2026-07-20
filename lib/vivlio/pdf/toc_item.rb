# frozen_string_literal: true

module Vivlio
  module PDF
    # One entry of a publication's table of contents, as reported by
    # window.coreViewer.getTOC(). Immutable value object holding a subtree.
    #
    # +id+ is the anchor id of the heading the entry points at; Chromium turns
    # it into a PDF named destination while printing, and Outline::Toc later
    # references that name. No page numbers are involved.
    class TocItem
      include Enumerable

      attr_reader :id, :title, :children

      # Builds a forest from the viewer's raw TOC array.
      def self.build(raw)
        Array(raw).map do |entry|
          new(id: entry['id'], title: entry['title'], children: build(entry['children']))
        end
      end

      def initialize(id:, title: nil, children: [])
        @id = id
        @title = title
        @children = children.freeze
        freeze
      end

      # Depth-first traversal over self and all descendants.
      def each(&block)
        return enum_for(:each) unless block

        yield self
        children.each { |child| child.each(&block) }
      end

      def leaf?
        children.empty?
      end

      # Falls back to the anchor id so an entry is never blank in a PDF reader.
      def label
        title || id.to_s
      end

      def inspect
        "#<#{self.class} #{label.inspect} children=#{children.size}>"
      end
    end
  end
end
