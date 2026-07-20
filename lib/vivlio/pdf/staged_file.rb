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
        claim(staged)
        result = yield staged
        File.rename(staged, destination)
        result
      ensure
        FileUtils.rm_f(staged)
      end

      # Creates the staged file before anyone writes to it. The staged name is
      # predictable, so in a world-writable output directory someone could
      # plant a symlink there and have the PDF bytes written through it into a
      # file of their choosing. Deleting whatever is at the name (unlinking a
      # symlink cannot touch its target) and then creating with EXCL closes
      # that: if something reappears in between, the build fails instead of
      # writing through it. The deletion also clears a stale .part left behind
      # by a killed run.
      def claim(staged)
        FileUtils.rm_f(staged)
        File.open(staged, File::WRONLY | File::CREAT | File::EXCL) {} # rubocop:disable Lint/EmptyBlock
      rescue Errno::EEXIST
        raise Error, "staged file reappeared while claiming it: #{staged}"
      end
    end
  end
end
