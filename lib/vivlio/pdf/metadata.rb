# frozen_string_literal: true

module Vivlio
  module PDF
    # Values written into the PDF document information dictionary.
    class Metadata
      FIELDS = { title: :Title, author: :Author, subject: :Subject,
                 keywords: :Keywords, creator: :Creator,
                 creation_date: :CreationDate }.freeze

      attr_reader :title, :author, :subject, :keywords, :creator, :creation_date

      # Accepts a Metadata, a Hash of the fields above, or nil.
      def self.coerce(value)
        case value
        when Metadata then value
        when nil then new
        when Hash then new(**value)
        else raise ArgumentError, "cannot coerce #{value.class} into Metadata"
        end
      end

      def initialize(title: nil, author: nil, subject: nil, keywords: nil,
                     creator: nil, creation_date: nil)
        @title = title
        @author = author
        @subject = subject
        @keywords = keywords
        @creator = creator
        @creation_date = creation_date
        freeze
      end

      def to_h
        FIELDS.keys.to_h { |name| [name, public_send(name)] }.compact
      end

      # True when there is nothing to write, i.e. no reason to rewrite the PDF
      # for metadata alone.
      def empty?
        to_h.empty?
      end

      # Names what produced the PDF, unless the caller named it themselves.
      # Deciding that string is Printer's job: only it knows which viewer
      # actually did the rendering.
      def with_creator(creator)
        return self if @creator

        Metadata.new(**to_h, creator: creator)
      end

      # +info+ is a HexaPDF document information dictionary.
      def write_to(info)
        FIELDS.each do |name, key|
          value = public_send(name)
          info[key] = value if value
        end
        info
      end
    end
  end
end
