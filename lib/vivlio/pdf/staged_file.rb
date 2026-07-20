# frozen_string_literal: true

require 'fileutils'

module Vivlio
  module PDF
    # Builds a file beside where it belongs and moves it into place only once
    # it is finished, so a run that fails part way through never leaves a
    # half-written file where the caller expects a complete one.
    module StagedFile
      module_function

      # Yields the path to build, and returns whatever the block returned.
      def write(destination)
        staged = "#{destination}.part"
        result = yield staged
        File.rename(staged, destination)
        result
      ensure
        FileUtils.rm_f(staged)
      end
    end
  end
end
