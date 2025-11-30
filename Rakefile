require "bundler/gem_tasks"
require 'jars/version'

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
end

task default: "spec"

require 'jars/installer'
desc 'Install the JAR dependencies to vendor/'
task :install_jars do
  # We actually want jar-dependencies will download the jars and place it in
  # vendor/jar-dependencies/runtime-jars
  Jars::Installer.new.vendor_jars!('vendor/jar-dependencies/runtime-jars', write_require_file: false)
end

task build: :install_jars
require "logstash/devutils/rake"
task vendor: :install_jars

