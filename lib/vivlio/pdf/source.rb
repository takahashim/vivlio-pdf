# frozen_string_literal: true

module Vivlio
  module PDF
    # A document to render: a single HTML file, the OPF of an unzipped EPUB, or
    # a webpub manifest. Beyond being a local file, it knows only whether it
    # brings a spine with it.
    class Source < LocalFile
      OPF_EXTENSIONS = ['.opf'].freeze
      MANIFEST_NAMES = ['publication.json', 'manifest.json'].freeze

      def initialize(path)
        super(path, kind: 'source')
      end

      # A publication (EPUB/webpub) has a spine to follow; a lone HTML file
      # does not. Only used as the default for Printer#print's book_mode:.
      def publication?
        OPF_EXTENSIONS.include?(File.extname(path).downcase) ||
          MANIFEST_NAMES.include?(File.basename(path))
      end
    end
  end
end
