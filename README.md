# rubygems_mcp

[![Gem Version](https://badge.fury.io/rb/rubygems_mcp.svg?v=0.1.1)](https://badge.fury.io/rb/rubygems_mcp) [![Test Status](https://github.com/amkisko/rubygems_mcp.rb/actions/workflows/test.yml/badge.svg)](https://github.com/amkisko/rubygems_mcp.rb/actions/workflows/test.yml) [![codecov](https://codecov.io/gh/amkisko/rubygems_mcp.rb/graph/badge.svg?token=APQ6AK7EC9)](https://codecov.io/gh/amkisko/rubygems_mcp.rb)

Ruby gem providing RubyGems and Ruby version information via MCP (Model Context Protocol) server tools. Integrates with MCP-compatible clients like Cursor IDE, Claude Desktop, and other MCP-enabled tools.

This gem accesses public RubyGems and Ruby version information, no authentication required.

Sponsored by [Kisko Labs](https://www.kiskolabs.com).

<a href="https://www.kiskolabs.com">
  <img src="kisko.svg" width="200" alt="Sponsored by Kisko Labs" />
</a>

## Requirements

- **Ruby 3.1 or higher** (Ruby 3.0 and earlier are not supported)

## Quick Start

```bash
gem install rubygems_mcp
```

### Cursor IDE Configuration

For Cursor IDE, create or update `.cursor/mcp.json` in your project:

```json
{
  "mcpServers": {
    "rubygems": {
      "command": "bundle",
      "args": ["exec", "rubygems_mcp"]
    }
  }
}
```

Or if installed globally:

```json
{
  "mcpServers": {
    "rubygems": {
      "command": "rubygems_mcp"
    }
  }
}
```

### Claude Desktop Configuration

For Claude Desktop, edit the MCP configuration file:

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`  
**Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "rubygems": {
      "command": "bundle",
      "args": ["exec", "rubygems_mcp"],
      "cwd": "/path/to/your/project"
    }
  }
}
```

Or if installed globally:

```json
{
  "mcpServers": {
    "rubygems": {
      "command": "rubygems_mcp"
    }
  }
}
```

**Note**: After updating the configuration, restart Claude Desktop for changes to take effect.

### Testing with MCP Inspector

You can test the MCP server using the [MCP Inspector](https://github.com/modelcontextprotocol/inspector) tool:

```bash
# Run the MCP inspector with the server
npx @modelcontextprotocol/inspector bundle exec rubygems_mcp
```

The inspector will:
1. Start a proxy server and open a browser interface
2. Connect to your MCP server via STDIO
3. Allow you to test all available tools interactively
4. Display request/response messages and any errors

This is useful for:
- Testing tool functionality before integrating with MCP clients
- Debugging MCP protocol communication
- Exploring available tools and their parameters

### Running the MCP Server manually

After installation, you can start the MCP server immediately:

```bash
# With bundler
gem install rubygems_mcp && bundle exec rubygems_mcp

# Or if installed globally
rubygems_mcp
```

The server will start and communicate via STDIN/STDOUT using the MCP protocol.

## Features

- **RubyGems API Client**: Full-featured client for RubyGems REST API with comprehensive endpoint coverage
- **Ruby Version Information**: Fetch Ruby release information, changelogs, and maintenance status from ruby-lang.org
- **MCP Server Integration**: Ready-to-use MCP server with 12 tools and 4 resources, compatible with Cursor IDE, Claude Desktop, and other MCP-enabled tools
- **Pagination & Sorting**: Support for large result sets with customizable pagination and sorting options
- **Caching**: In-memory caching with configurable TTL for improved performance
- **Error Handling**: Graceful error handling with custom exceptions and response size limits
- **No Authentication Required**: All endpoints are public, no API keys needed
- **Comprehensive API Coverage**: Supports gem versions, latest versions, Ruby versions, gem search, gem information, reverse dependencies, download statistics, changelogs, and more

## Basic Usage

### API Client

```ruby
require "rubygems_mcp"

# Create client
client = RubygemsMcp::Client.new

# Get latest versions for multiple gems
versions = client.get_latest_versions(["rails", "nokogiri", "rack"])
# => [
#   { name: "rails", version: "7.1.0", release_date: #<Date>, license: "MIT" },
#   { name: "nokogiri", version: "1.15.0", release_date: #<Date>, license: "MIT" },
#   { name: "rack", version: "3.0.0", release_date: #<Date>, license: "MIT" }
# ]

# Get all versions for a gem
versions = client.get_gem_versions("rails")
# => [
#   { version: "7.1.0", release_date: #<Date>, license: "MIT" },
#   { version: "7.0.8", release_date: #<Date>, license: "MIT" },
#   ...
# ]

# Get latest Ruby version
ruby_version = client.get_latest_ruby_version
# => { version: "3.3.0", release_date: #<Date> }

# Get all Ruby versions
ruby_versions = client.get_ruby_versions
# => [
#   { version: "3.3.0", release_date: #<Date> },
#   { version: "3.2.0", release_date: #<Date> },
#   ...
# ]

# Get gem information
gem_info = client.get_gem_info("rails")
# => {
#   name: "rails",
#   version: "7.1.0",
#   summary: "Full-stack web application framework.",
#   homepage: "https://rubyonrails.org",
#   source_code: "https://github.com/rails/rails",
#   documentation: "https://api.rubyonrails.org",
#   licenses: ["MIT"],
#   authors: ["David Heinemeier Hansson", ...]
# }

# Search for gems
results = client.search_gems("rails")
# => [
#   { name: "rails", version: "7.1.0", info: "...", ... },
#   { name: "rails_admin", version: "3.0.0", info: "...", ... },
#   ...
# ]

# Get reverse dependencies
reverse_deps = client.get_gem_reverse_dependencies("rails")
# => ["rails_admin", "activeadmin", ...]

# Get download statistics
downloads = client.get_gem_version_downloads("rails", "7.1.0")
# => { version_downloads: 123456, total_downloads: 987654321 }

# Get Ruby maintenance status
maintenance = client.get_ruby_maintenance_status
# => [
#   { version: "3.4", status: "normal maintenance", release_date: "2024-12-25", ... },
#   { version: "3.3", status: "normal maintenance", ... },
#   ...
# ]

# Get Ruby version changelog
changelog = client.get_ruby_version_changelog("3.4.7")
# => { version: "3.4.7", summary: "...", release_notes_url: "..." }

# Get latest/recently updated gems
latest = client.get_latest_gems(limit: 10)
recently_updated = client.get_recently_updated_gems(limit: 10)
```

## API Methods

### Gem Versions

- `get_latest_versions(gem_names, fields: nil)` - Get latest versions for a list of gems with release dates and licenses. Supports GraphQL-like field selection.
- `get_gem_versions(gem_name, limit: nil, offset: 0, sort: :version_desc, fields: nil)` - Get all versions for a single gem with release dates and licenses, sorted by version descending. Supports pagination, sorting, and field selection.

### Ruby Versions

- `get_latest_ruby_version` - Get latest Ruby version with release date
- `get_ruby_versions(limit: nil, offset: 0, sort: :version_desc)` - Get all Ruby versions with release dates, download URLs, and release notes URLs, sorted by version descending. Supports pagination and sorting.
- `get_ruby_version_changelog(version)` - Get changelog summary for a specific Ruby version by fetching and parsing the release notes
- `get_ruby_maintenance_status` - Get maintenance status for all Ruby versions including EOL dates and maintenance phases

### Gem Information

- `get_gem_info(gem_name, fields: nil)` - Get detailed information about a gem (summary, homepage, source code, documentation, licenses, authors, dependencies, downloads). Supports GraphQL-like field selection.
- `get_gem_reverse_dependencies(gem_name)` - Get reverse dependencies - list of gems that depend on the specified gem
- `get_gem_version_downloads(gem_name, version)` - Get download statistics for a specific gem version
- `get_gem_changelog(gem_name, version: nil)` - Get changelog summary for a gem by fetching and parsing the changelog from its changelog_uri
- `search_gems(query, limit: nil, offset: 0)` - Search for gems by name on RubyGems. Supports pagination.

### Gem Discovery

- `get_latest_gems(limit: 30)` - Get latest gems - most recently added gems to RubyGems.org
- `get_recently_updated_gems(limit: 30)` - Get recently updated gems - most recently updated gem versions

## MCP Server Integration

This gem includes a ready-to-use MCP server that can be run directly:

```bash
# After installing the gem
bundle exec rubygems_mcp
```

Or if installed globally:

```bash
gem install rubygems_mcp
rubygems_mcp
```

The server will communicate via STDIN/STDOUT using the MCP protocol. Configure it in your MCP client (e.g., Cursor IDE, Claude Desktop, or other MCP-enabled tools).

## MCP Tools

The MCP server provides the following tools:

1. **get_latest_versions** - Get latest versions for a list of gems with release dates and licenses. Supports GraphQL-like field selection.
   - Parameters: `gem_names` (array of strings), `fields` (optional array of strings)

2. **get_gem_versions** - Get all versions for a single gem with release dates and licenses, sorted by version descending. Supports GraphQL-like field selection.
   - Parameters: `gem_name` (string), `limit` (optional integer), `offset` (optional integer), `sort` (optional string: "version_desc", "version_asc", "date_desc", "date_asc"), `fields` (optional array of strings)

3. **get_latest_ruby_version** - Get latest Ruby version with release date
   - Parameters: none

4. **get_ruby_versions** - Get all Ruby versions with release dates, download URLs, and release notes URLs, sorted by version descending
   - Parameters: `limit` (optional integer), `offset` (optional integer), `sort` (optional string: "version_desc", "version_asc", "date_desc", "date_asc")

5. **get_ruby_version_changelog** - Get changelog summary for a specific Ruby version by fetching and parsing the release notes
   - Parameters: `version` (string, e.g., "3.4.7")

6. **get_gem_info** - Get detailed information about a gem (summary, homepage, source code, documentation, licenses, authors, dependencies, downloads). Supports GraphQL-like field selection.
   - Parameters: `gem_name` (string), `fields` (optional array of strings)

7. **get_gem_reverse_dependencies** - Get reverse dependencies - list of gems that depend on the specified gem
   - Parameters: `gem_name` (string)

8. **get_gem_version_downloads** - Get download statistics for a specific gem version
   - Parameters: `gem_name` (string), `version` (string)

9. **get_latest_gems** - Get latest gems - most recently added gems to RubyGems.org
   - Parameters: `limit` (optional integer, default: 30, max: 50)

10. **get_recently_updated_gems** - Get recently updated gems - most recently updated gem versions
    - Parameters: `limit` (optional integer, default: 30, max: 50)

11. **get_gem_changelog** - Get changelog summary for a gem by fetching and parsing the changelog from its changelog_uri
    - Parameters: `gem_name` (string), `version` (optional string, uses latest if not provided)

12. **search_gems** - Search for gems by name on RubyGems
    - Parameters: `query` (string)

## MCP Resources

The MCP server provides the following resources:

1. **rubygems://popular** - A curated list of popular Ruby gems with their latest versions
   - Resource name: "Popular Ruby Gems"
   - MIME type: application/json

2. **rubygems://ruby/compatibility** - Information about Ruby version compatibility and release dates
   - Resource name: "Ruby Version Compatibility"
   - MIME type: application/json

3. **rubygems://ruby/maintenance** - Detailed maintenance status for all Ruby versions including EOL dates and maintenance phases
   - Resource name: "Ruby Maintenance Status"
   - MIME type: application/json

4. **rubygems://ruby/latest** - The latest stable Ruby version with release date
   - Resource name: "Latest Ruby Version"
   - MIME type: application/json

## Error Handling

The client handles errors gracefully:
- Returns empty arrays for failed requests
- Returns empty hashes for failed gem info requests
- Handles network errors and JSON parsing errors

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run tests across multiple Ruby versions
bundle exec appraisal install
bundle exec appraisal rspec

# Run linting
bundle exec standardrb --fix

# Validate RBS type signatures
bundle exec rbs validate
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/amkisko/rubygems_mcp.rb.

Contribution policy:
- New features are not necessarily added to the gem
- Pull request should have test coverage for affected parts
- Pull request should have changelog entry

Review policy:
- It might take up to 2 calendar weeks to review and merge critical fixes
- It might take up to 6 calendar months to review and merge pull request
- It might take up to 1 calendar year to review an issue

For more information, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

If you discover a security vulnerability, please report it responsibly. See [SECURITY.md](SECURITY.md) for details.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

