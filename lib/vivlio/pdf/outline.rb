# frozen_string_literal: true

module Vivlio
  module PDF
    # How PDF bookmarks are produced. Each strategy answers two questions:
    # whether Chromium should build the outline itself while printing, and
    # which TOC entries (if any) we write afterwards with HexaPDF.
    module Outline
      # Accepts a Strategy, a mode name, or a boolean for callers who think of
      # bookmarks as something they simply turn on or off.
      def self.resolve(mode)
        case mode
        when Strategy then mode
        when :toc, 'toc', nil, true then Toc.new
        when :headings, 'headings' then Headings.new
        when :none, 'none', false then None.new
        else raise ArgumentError, "unknown outline mode: #{mode.inspect}"
        end
      end

      class Strategy
        # Set Page.printToPDF's generateDocumentOutline.
        def chromium_generated?
          false
        end

        # TocItems to write into the PDF after printing.
        def entries(_session)
          []
        end

        def to_s
          self.class.name.split('::').last.downcase
        end
      end

      # Bookmarks mirroring the publication's own table of contents, resolved
      # through the named destinations Chromium embeds for the TOC links.
      class Toc < Strategy
        def entries(session)
          session.toc
        end
      end

      # Bookmarks Chromium derives from the h1-h6 outline. Cheaper, but the
      # depth cannot be controlled.
      class Headings < Strategy
        def chromium_generated?
          true
        end
      end

      class None < Strategy
      end
    end
  end
end
