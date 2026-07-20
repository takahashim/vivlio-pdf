# frozen_string_literal: true

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/test_*.rb']
end

task default: :test

namespace :viewer do
  desc 'Update vendor/viewer to a @vivliostyle/viewer release'
  task :update, [:version] do |_t, args|
    version = args[:version] or abort 'usage: rake "viewer:update[2.44.1]"'
    ruby "tools/update_viewer.rb #{version}"
  end
end
