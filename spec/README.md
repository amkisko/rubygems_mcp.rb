# Testing

## Commands

Full suite (parallel shards via Polyrun):

```bash
make test
```

Lint (RuboCop and RBS):

```bash
make lint
```

Focused runs:

```bash
bundle exec rspec spec/rubygems_mcp/
```

Across Ruby 3.4 and 4.0:

```bash
bundle exec appraisal install
bundle exec appraisal rspec
```

See `polyrun.yml`. `make test` runs lint, then `polyrun parallel-rspec` with five workers.

## Layout

- `spec/rubygems_mcp/` — client, server, network policy, and MCP tool specs
- `spec/support/` — VCR and WebMock configuration
- `spec/fixtures/vcr_cassettes/` — recorded HTTP for ruby-lang.org, RubyGems, and GitHub

## Guidelines

- Test HTTP contracts and user-facing results, not private helpers.
- Stub or replay HTTP with WebMock and VCR. Do not hit live hosts in the suite.
- Add or update specs before bugfixes. Run `make lint` and focused rspec before a PR.
- Local `make test` uses five workers. CI matrix uses one appraisal Gemfile per Ruby version. Coverage runs with `POLYRUN_COVERAGE=1`; threshold in `config/polyrun_coverage.yml`.
