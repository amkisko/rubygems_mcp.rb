# Lockfile advisories after json bump

## Dependency

Found on the post-json bundle-audit check of Gemfile.lock. Same names were on gemfiles/ruby34.gemfile.lock and gemfiles/ruby40.gemfile.lock at older pins until this pass.

addressable 2.8.7, from fast-mcp addressable ~> 2.8 and webmock. CVE-2026-35611 / GHSA-h27x-rffw-24p4. Solution >= 2.9.0.

concurrent-ruby 1.3.5 on the root lock, from dry-* concurrent-ruby ~> 1.0. CVE-2026-54904, CVE-2026-54905, CVE-2026-54906. Solution >= 1.3.7.

rack 3.2.4 on the root lock, from the gemspec rack ~> 3.0 and fast-mcp rack >= 2.0, < 4.0. Multiple 2026 Rack advisories. Solutions named ~> 3.1.21 or >= 3.2.5 / >= 3.2.6.

## Symptom

bundle-audit check failed after json 2.21.2 was already locked. CI dependency-audit.yml would fail on the same scanner output.

## Evidence

bundle-audit check --no-update --gemfile-lock Gemfile.lock on 2026-09-04 after the json bump. Fail. addressable 2.8.7, concurrent-ruby 1.3.5, rack 3.2.4.

bundle update addressable concurrent-ruby rack with env -u BUNDLE_PATH -u BUNDLE_BIN -u BUNDLE_USER_CONFIG. Root and ruby34 used RBENV_VERSION=3.4.10. ruby40 used RBENV_VERSION=4.0.2.

Pins after the update: addressable 2.9.0, concurrent-ruby 1.3.8, rack 3.2.7, public_suffix 7.0.5. Root Gemfile.lock BUNDLED WITH restored to 4.0.16.

bundle-audit check --no-update on Gemfile.lock, gemfiles/ruby34.gemfile.lock, and gemfiles/ruby40.gemfile.lock. No vulnerabilities found.

This process is an MCP stdio server. rack is still a production gemspec dependency. addressable is on the fast-mcp hot path. concurrent-ruby is on the dry-schema hot path used by tool argument schemas.

## Suggested fix

Refresh the three locks. Done in this pass. No gemspec floor change. rack ~> 3.0 already allows 3.2.7. fast-mcp addressable ~> 2.8 allows 2.9.0. dry-* concurrent-ruby ~> 1.0 allows 1.3.8.

## Next

None for these pins. FastMcp STDIN versus JSON::ResumableParser stays on the json note.

## Source

- Gemfile.lock
- gemfiles/ruby34.gemfile.lock
- gemfiles/ruby40.gemfile.lock
- rubygems_mcp.gemspec
- usr/docs/issues/20260904172000_engineering-and-dependency-audit.md
- https://github.com/sporkmonger/addressable/security/advisories/GHSA-h27x-rffw-24p4
- https://nvd.nist.gov/vuln/detail/CVE-2026-54904
- https://github.com/rack/rack/security/advisories/GHSA-mxw3-3hh2-x2mh
