# CHANGELOG

## 0.1.0 (2025-01-15)

- Initial release
- RubyGems API client with comprehensive endpoint coverage:
  - Gem versions: `get_latest_versions`, `get_gem_versions` with pagination, sorting, and GraphQL-like field selection
  - Gem information: `get_gem_info` with field selection, `get_gem_reverse_dependencies`, `get_gem_version_downloads`
  - Gem discovery: `get_latest_gems`, `get_recently_updated_gems`, `search_gems` with pagination
  - Gem changelogs: `get_gem_changelog` with automatic parsing from changelog URIs
- Ruby version information from ruby-lang.org:
  - `get_latest_ruby_version` - Latest stable Ruby version
  - `get_ruby_versions` - All Ruby versions with download URLs and release notes URLs, supports pagination and sorting
  - `get_ruby_version_changelog` - Changelog summaries parsed from release notes
  - `get_ruby_maintenance_status` - Maintenance status, EOL dates, and maintenance phases for all Ruby versions
- MCP server integration with 12 tools and 4 resources:
  - Tools: All client methods exposed as MCP tools with full parameter support
  - Resources: Popular gems list, Ruby version compatibility, Ruby maintenance status, latest Ruby version
  - Compatible with Cursor IDE, Claude Desktop, and other MCP-enabled tools
  - Executable: `bundle exec rubygems_mcp` or `rubygems_mcp` (when installed globally)
- Features:
  - In-memory caching with configurable TTL for improved performance
  - Response size limits to protect against crawler protection pages
  - Graceful error handling with custom exceptions
  - GraphQL-like field selection for efficient data retrieval
  - Pagination support for large result sets
  - Sorting options for version and date-based queries
- No authentication required - all endpoints are public
- Complete RBS type signatures for all public APIs
- Comprehensive test suite with RSpec, VCR cassettes, and WebMock
- Requires Ruby 3.1 or higher
- All dependencies use latest compatible versions with pessimistic versioning for security

