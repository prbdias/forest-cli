# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-02-14

### Added

- Initial public release
- Interactive worktree picker with branch context and status
- Docker Compose orchestration per worktree
- Host service management with log redirection to `.forest/logs/`
- Multi-editor config auto-detection (supports multiple AI coding editors)
- Hook system: `pre`, `pre-services`, `post`
- Smart branch memory for detached HEAD worktrees
- Manual worktree labeling (`forest label`)
- Auto issue number extraction from branch names
- Setup wizard (`forest init`)
- Requirements checker (`forest doctor`)
- `-f`/`--follow` flag for log streaming after boot
- `forest logs` command supporting both Docker and host service logs
- Per-worktree `.env` support (prefers worktree `.env`, falls back to main root)
- Bash 3.2+ compatibility (macOS default shell)
- `curl` one-liner installer
