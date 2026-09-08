# Engineering and dependency audit

## Decisions

Scope was rubygems_mcp 0.1.4 engineering plus a full-depth dependency audit. Product-surface mode was skipped because there is no person-facing UI. Database, queue, and worker stages were skipped because the process has none. Resource and identity numbers stay inference until benched. Implementation stayed on patch/audit-fixes. Gem version stayed 0.1.4. NetworkPolicy from the working tree stayed.

## Effects

Audit-time bundle-audit failed on json 2.21.1 CVE-2026-71847. After the lock refresh, json is 2.21.2 on Gemfile.lock, gemfiles/ruby34.gemfile.lock, and gemfiles/ruby40.gemfile.lock.

A second bundle-audit check then failed on addressable 2.8.7 CVE-2026-35611, concurrent-ruby 1.3.5 CVE-2026-54904 through CVE-2026-54906, and rack 3.2.4 (several 2026 Rack advisories). Those pins moved to addressable 2.9.0, concurrent-ruby 1.3.8, and rack 3.2.7. public_suffix moved to 7.0.5 with addressable. Root Gemfile.lock BUNDLED WITH was restored to 4.0.16 after Ruby 3.4 bundler rewrote it to 2.7.2.

get_ruby_versions writes the full list to the 24 hour cache on miss, then applies limit, offset, and sort. The stubbed pagination example clears that cache so later VCR examples do not reuse fake release-notes URLs. get_ruby_version_github_changelog uses make_request with the GitHub Accept header. Empty or invalid GitHub JSON raises CorruptedDataError. Oversized GitHub bodies raise ResponseSizeExceededError. 404 still returns the not-found hash and is not cached. get_latest_versions and the MCP tool reject more than 20 gem names before HTTP.

fast-mcp floor is 1.6. nokogiri floor is 1.19. dependency-audit.yml finds Gemfile.lock and *.gemfile.lock. Dependabot watches /gemfiles. README, badge, gemspec comment, and Unreleased CHANGELOG match Ruby 3.4, 0.1.4, and raised errors. spec/README.md documents the suite.

Validation on 2026-09-04 with env -u BUNDLE_PATH -u BUNDLE_BIN -u BUNDLE_USER_CONFIG and RBENV_VERSION=3.4.10:

bundle exec rspec spec/rubygems_mcp --format progress. 222 examples, 0 failures.

make lint. rubocop inspected 21 files, no offenses. rbs validate succeeded.

bundle-audit update. ruby-advisory-db 1241 advisories, last updated 2026-09-04, commit 478717d12497338b42f77c0e237f5f6b83d94127.

bundle-audit check --no-update --gemfile-lock Gemfile.lock. No vulnerabilities found.

bundle-audit check --no-update --gemfile-lock gemfiles/ruby34.gemfile.lock. No vulnerabilities found.

bundle-audit check --no-update --gemfile-lock gemfiles/ruby40.gemfile.lock. No vulnerabilities found.

## Next

Confirm whether FastMcp STDIN parsing uses JSON::ResumableParser before treating CVE-2026-71847 as a live crash on MCP input.

## Source

- lib/rubygems_mcp/client.rb
- lib/rubygems_mcp/server.rb
- lib/rubygems_mcp/network_policy.rb
- spec/rubygems_mcp/client_spec.rb
- rubygems_mcp.gemspec
- Gemfile.lock
- gemfiles/ruby34.gemfile.lock
- gemfiles/ruby40.gemfile.lock
- .github/workflows/dependency-audit.yml
- .github/workflows/test.yml
- .github/dependabot.yml
- README.md
- CHANGELOG.md
- usr/docs/issues/20260730141002_changelog-destination-policy.md
- usr/docs/dependencies/20260904172000_json-cve-2026-71847.md
- usr/docs/dependencies/20260904174500_lockfile-advisories-after-json.md
- https://github.com/advisories/GHSA-9hj4-r449-hfvc
