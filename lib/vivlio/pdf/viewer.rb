# frozen_string_literal: true

require 'json'

module Vivlio
  module PDF
    # The Vivliostyle Viewer installation used for rendering: a directory of
    # static files containing index.html.
    #
    # Defaults to the copy vendored in this gem; pass another path to run a
    # different release without rebuilding the gem.
    class Viewer
      VENDORED_PATH = File.expand_path('../../../vendor/viewer', __dir__)

      attr_reader :path, :version

      def self.default
        @default ||= new(VENDORED_PATH)
      end

      # Accepts a Viewer, a path, or nil (meaning the vendored viewer).
      def self.coerce(value)
        case value
        when Viewer then value
        when nil then default
        else new(value)
        end
      end

      def initialize(path)
        @path = File.expand_path(path.to_s)
        @index = LocalFile.new(File.join(@path, 'index.html'), kind: 'Vivliostyle Viewer')
        @version = read_version
        freeze
      end

      def index_path
        @index.path
      end

      # Viewer URL loading +source+.
      #
      # Fragment parameters:
      #   src              document to load
      #   bookMode         follow the spine/TOC to load the whole publication
      #   renderAllPages   paginate everything up front (required before print)
      #   style            additional stylesheet(s)
      #
      # A stylesheet the viewer cannot find is silently ignored, so the paths
      # are resolved here and a missing one is reported instead.
      def url_for(source, book_mode: true, style: nil)
        parameters = ["src=#{Source.coerce(source).url}"]
        parameters << 'bookMode=true' if book_mode
        parameters << 'renderAllPages=true'
        Array(style).each do |sheet|
          parameters << "style=#{LocalFile.new(sheet, kind: 'stylesheet').url}"
        end
        "#{@index.url}##{parameters.join('&')}"
      end

      def to_s
        path
      end

      private

      # The bundled package.json records which viewer release this is; it is
      # the only statement of that version, so nothing can drift from it.
      def read_version
        manifest = File.join(@path, 'package.json')
        return nil unless File.exist?(manifest)

        JSON.parse(File.read(manifest))['version']
      rescue JSON::ParserError, SystemCallError
        nil
      end
    end
  end
end
