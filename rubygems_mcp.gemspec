# frozen_string_literal: true

require_relative "lib/rubygems_mcp/version"

Gem::Specification.new do |spec|
  spec.name = "rubygems_mcp"
  spec.version = RubygemsMcp::VERSION
  spec.authors = ["Andrei Makarov"]
  spec.email = ["contact@kiskolabs.com"]

  spec.summary = "RubyGems MCP (Model Context Protocol) server for Cursor IDE integration"
  spec.description = "Ruby gem providing RubyGems and Ruby version information via MCP server tools. Integrates with Cursor IDE via Model Context Protocol."
  spec.homepage = "https://github.com/amkisko/rubygems_mcp.rb"
  spec.license = "MIT"

  # File inclusion: explicitly include all necessary files
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["lib/**/*", "sig/**/*", "bin/**/*", "README.md", "LICENSE*", "CHANGELOG.md"].select { |f| File.file?(f) }
  end
  spec.bindir = "bin"
  spec.executables = ["rubygems_mcp"]
  spec.require_paths = ["lib"]

  # Enforce Ruby >= 3.1 for modern Ruby features and security
  spec.required_ruby_version = ">= 3.1"

  # Comprehensive metadata following RubyGems best practices
  spec.metadata = {
    "source_code_uri" => "https://github.com/amkisko/rubygems_mcp.rb",
    "changelog_uri" => "https://github.com/amkisko/rubygems_mcp.rb/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/amkisko/rubygems_mcp.rb/issues",
    "documentation_uri" => "https://github.com/amkisko/rubygems_mcp.rb#readme",
    "rubygems_mfa_required" => "true"
  }

  spec.add_runtime_dependency "fast-mcp", ">= 0.1", "< 2.0"
  spec.add_runtime_dependency "nokogiri", "~> 1.15"
  spec.add_runtime_dependency "rack", "~> 3.0"
  # base64 was removed from default gems in Ruby 3.4+, but fast-mcp requires it
  # Adding it unconditionally is safe - it won't conflict on older Ruby versions
  spec.add_runtime_dependency "base64", "~> 0.1"

  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "webmock", "~> 3.26"
  spec.add_development_dependency "vcr", "~> 6.0"
  spec.add_development_dependency "rake", "~> 13.3"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "rspec_junit_formatter", "~> 0.6"
  spec.add_development_dependency "simplecov-cobertura", "~> 3.1"
  spec.add_development_dependency "standard", "~> 1.52"
  spec.add_development_dependency "appraisal", "~> 2.5"
  spec.add_development_dependency "memory_profiler", "~> 1.1"
  spec.add_development_dependency "rbs", "~> 3.9"
end
