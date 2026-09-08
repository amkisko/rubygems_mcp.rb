# Archival cleanup

## Decisions

Close remaining GitHub issues, leftover pull request branches, and local patch branches before the 0.2.0 cut. Keep FastMcp STDIN proof and changelog redirect following unshipped. Do not follow changelog redirects. Archive GitHub after RubyGems lists 0.2.0 and tag 0.2.0 exists. Leave GitLab and Codeberg writable.

## Effects

GitHub issue 3 is closed. search_gems was already on the gem. GitHub has no open pull requests. GitHub, GitLab, and Codeberg heads are only main. Local dependabot and patch branches are deleted. The leftover dependabot worktree is removed. GitLab and Codeberg dependabot heads are deleted. GitLab and Codeberg main match GitHub.

Quality checks on 2026-09-08: bundle exec rubocop inspected 24 files, no offenses. bundle exec rbs validate succeeded. POLYRUN_COVERAGE=1 bundle exec polyrun parallel-rspec --workers 5 --merge-failures exited 0.

gem search rubygems_mcp --remote --exact listed rubygems_mcp (0.2.0). Tag 0.2.0 points at e401a5e. GitHub release 0.2.0 is published. This note is the last GitHub write before archive.

## Next

FastMcp STDIN proof and changelog redirect following stay unshipped. GitLab and Codeberg stay writable.

## Source

- https://github.com/amkisko/rubygems_mcp.rb/issues/3
- usr/docs/changelogs/20260908113200_release-0-2-0.md
- usr/docs/issues/20260904172000_engineering-and-dependency-audit.md
- usr/docs/issues/20260730141002_changelog-destination-policy.md
