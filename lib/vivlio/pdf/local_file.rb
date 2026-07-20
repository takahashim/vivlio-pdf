# frozen_string_literal: true

require 'uri'

module Vivlio
  module PDF
    # A file on disk the browser will be pointed at: a path that exists, and
    # the file:// URL naming it.
    #
    # Everything the viewer loads -- the document, its stylesheets, the
    # viewer's own index.html -- is one of these. +kind+ only names the thing
    # in the error raised when it is missing.
    class LocalFile
      attr_reader :path, :url

      def self.coerce(value)
        value.is_a?(self) ? value : new(value)
      end

      def initialize(path, kind: 'file')
        @path = File.expand_path(path.to_s)
        raise Error, "#{kind} not found: #{@path}" unless File.exist?(@path)

        @url = file_url(@path)
        freeze
      end

      def to_s
        path
      end

      private

      # Each segment is escaped separately so that the separators survive.
      def file_url(absolute)
        "file://#{absolute.split('/').map { |segment| URI.encode_uri_component(segment) }.join('/')}"
      end
    end
  end
end
