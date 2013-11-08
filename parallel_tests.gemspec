$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
name = "parallel_tests"
require "#{name}/version"

Gem::Specification.new name, ParallelTests::VERSION do |s|
  s.summary = "Run Cucumber in parallel"
  s.authors = []
  s.email = ""
  s.homepage = ""
  s.files = `git ls-files`.split("\n")
  s.license = "MIT"
  s.executables = ["parallel_cucumber", "parallel_rspec", "parallel_test"]
  s.add_runtime_dependency "parallel"
  s.add_dependency "win32-dir"
  s.add_dependency "cucumber"
  s.add_dependency "rake"
end
