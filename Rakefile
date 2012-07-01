require 'rake'
require 'rspec/core/rake_task'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "sinatra-torrent"
    gem.description = "An extension to Sinatra which will allow you to run a webseeded torrent tracker of files in the folder you specify."
    gem.summary = "A sinatra extension to run webseeded torrent tracker"
    gem.email = "jphastings@gmail.com"
    gem.homepage = "http://github.com/jphastings/sinatra-torrent"
    gem.authors = ["JP Hastings-Spital"]
    
    gem.add_dependency('sinatra','>=1.1.2') # Required for send_file modifications
    gem.add_dependency('bencode')
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

task :default => :test
task :test => :spec

if !defined?(RSpec)
  puts "spec targets require RSpec"
else
  desc "Run all examples"
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = 'spec/**/*_spec.rb'
    t.rspec_opts = ['-cfs']
  end
end