require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter { |source_file| source_file.lines.count < 5 }
end

require "simplecov-cobertura"
SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter

require "rspec"
require "vcr"
require "webmock/rspec"
require_relative "../lib/rubygems_mcp"

Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require_relative f }

# Configure VCR
VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Do not allow HTTP connections when no cassette is in use
  config.allow_http_connections_when_no_cassette = false

  # Allow WebMock stubs to work when VCR is turned off
  config.ignore_localhost = true

  # Default cassette options
  record_mode = case ENV.fetch("VCR_RECORD", "once")
  when "all"
    :all
  when "new_episodes", "new"
    :new_episodes
  when "none"
    :none
  else
    :once # Default: record new interactions, but don't re-record existing ones
  end

  config.default_cassette_options = {
    record: record_mode,
    match_requests_on: [:method, :uri], # Match requests by method and URI
    preserve_exact_body_bytes: true, # Preserve exact bytes for binary content
    decode_compressed_response: true # Decode compressed responses
  }

  # Filter sensitive data (if any)
  config.filter_sensitive_data("<API_KEY>") { ENV["API_KEY"] } if ENV["API_KEY"]
end

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
