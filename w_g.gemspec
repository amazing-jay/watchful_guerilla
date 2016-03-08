# coding: utf-8
$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "watchful_guerilla/version"

Gem::Specification.new do |s|
  s.name          = "watchful_guerilla"
  s.version       = WatchfulGuerilla::VERSION
  s.authors       = ["The Honest Company", "Jay Crouch"]
  s.email         = ["i.jaycrouch@gmail.com"]

  s.summary       = "Performance Monitors"
  s.description   = "Block Based performance and query counters"
  s.homepage      = "https://github.com/honest/watchful_guerilla"
  s.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if s.respond_to?(:metadata)
    s.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  s.files = Dir["{lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "ruby-prof"

  s.add_development_dependency "rspec"
  s.add_development_dependency "parallel_tests"
  s.add_development_dependency "pry"
  s.add_development_dependency "pry-rails"
  s.add_development_dependency "pry-nav"
  s.add_development_dependency "pry-stack_explorer"
  s.add_development_dependency "rapido"
end
