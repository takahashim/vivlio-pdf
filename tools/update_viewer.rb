# frozen_string_literal: true

# Updates vendor/viewer to a given @vivliostyle/viewer release, fetching the
# npm tarball over plain HTTPS (no npm required).
#
#   ruby tools/update_viewer.rb 2.44.1
#   rake "viewer:update[2.44.1]"
#
# The vendored package.json is the only record of which release this is, so
# there is nothing else to keep in step afterwards.
#
# Source maps are dropped: they are four times the size of everything else put
# together, they ship in the built gem, and nothing needs them at run time.
# To read the viewer's TypeScript while debugging, fetch the map by hand into
# vendor/viewer/js/ -- .gitignore keeps it out of the way.

require 'fileutils'
require 'open-uri'
require 'tmpdir'

version = ARGV[0] or abort 'usage: ruby tools/update_viewer.rb VERSION'
root = File.expand_path('..', __dir__)
dest = File.join(root, 'vendor/viewer')
url = "https://registry.npmjs.org/@vivliostyle/viewer/-/viewer-#{version}.tgz"
# From the matching tag, not master: the vendored viewer and its license text
# have to describe the same release, as README tells readers they do.
license_url = "https://raw.githubusercontent.com/vivliostyle/vivliostyle.js/v#{version}/LICENSE"

Dir.mktmpdir do |tmp|
  tarball = File.join(tmp, 'viewer.tgz')
  File.binwrite(tarball, URI.open(url).read) # rubocop:disable Security/Open
  system('tar', 'xzf', tarball, '-C', tmp, exception: true)

  FileUtils.rm_rf(dest)
  FileUtils.mkdir_p(dest)
  FileUtils.cp_r(Dir[File.join(tmp, 'package/lib/*')], dest)
  FileUtils.cp(File.join(tmp, 'package/package.json'), dest)
  FileUtils.rm_f(Dir[File.join(dest, '**', '*.map')])
  File.binwrite(File.join(dest, 'LICENSE'), URI.open(license_url).read) # rubocop:disable Security/Open
end

puts "vendor/viewer updated to #{version}"
