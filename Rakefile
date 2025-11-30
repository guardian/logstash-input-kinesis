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
  # Monkey-patch jar-dependencies to strip ANSI escape codes and module info from file paths
  # This is needed because Java's module system adds colored output and module info that breaks path parsing
  # Example problematic output: "/path/to/file.jar[36m -- module foo.bar[0;1;33m (auto)[m"
  module Jars
    class Installer
      class Dependency
        alias_method :original_initialize, :initialize
        def initialize(line)
          # Strip ANSI escape codes before parsing
          line = line.gsub(/\e\[[0-9;]*m/, '')
          # Strip Java module system info (e.g., " -- module name", " -- module name (auto)", " -- module name [auto]")
          line = line.gsub(/ -- module \S+( [\[\(][^\]\)]+[\]\)])?/, '')
          original_initialize(line)
        end
      end
    end
  end

  # We actually want jar-dependencies will download the jars and place it in
  # vendor/jar-dependencies/runtime-jars
  # Use positional arguments for compatibility with jar-dependencies 0.4.x and 0.5.x
  # 0.4.x API: vendor_jars!(write_require_file, vendor_dir)
  # 0.5.x API: vendor_jars!(vendor_dir, write_require_file:)
  installer = Jars::Installer.new
  method = installer.method(:vendor_jars!)
  if method.parameters.any? { |type, name| type == :key || type == :keyreq }
    # 0.5.x API with keyword arguments
    installer.vendor_jars!('vendor/jar-dependencies/runtime-jars', write_require_file: false)
  else
    # 0.4.x API with positional arguments
    installer.vendor_jars!(false, 'vendor/jar-dependencies/runtime-jars')
  end
end

task build: :install_jars
require "logstash/devutils/rake"
task vendor: :install_jars

