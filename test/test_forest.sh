#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# forest test suite
#
# Verifies core functionality without needing Docker or a real project.
# Focuses on pure-bash functions: config detection, worktree parsing, helpers.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FOREST="$SCRIPT_DIR/../forest"

PASS=0
FAIL=0

# ── Test helpers ─────────────────────────────────────────────────────────────

pass() {
    PASS=$((PASS + 1))
    echo -e "  \033[0;32m✓\033[0m $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo -e "  \033[0;31m✗\033[0m $1"
    if [[ -n "${2:-}" ]]; then
        echo -e "    Expected: $2"
        echo -e "    Got:      ${3:0:120}"
    fi
}

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        pass "$desc"
    else
        fail "$desc" "$expected" "$actual"
    fi
}

assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$desc"
    else
        fail "$desc" "contains '$needle'" "$haystack"
    fi
}

# Each test creates its own isolated tmpdir
make_repo() {
    local tmpdir
    tmpdir="$(mktemp -d)"
    git -C "$tmpdir" init --quiet -b main 2>/dev/null
    git -C "$tmpdir" -c user.name="Test" -c user.email="test@test.com" \
        commit --allow-empty -m "init" --quiet 2>/dev/null
    echo "$tmpdir"
}

# ── Tests ────────────────────────────────────────────────────────────────────

echo ""
echo -e "  \033[1m🌲 forest test suite\033[0m"
echo ""

# -- Version ------------------------------------------------------------------

test_version() {
    local output
    output="$(bash "$FOREST" --version 2>/dev/null)"
    assert_contains "version output contains forest" "$output" "forest v"
}
test_version

# -- Help ---------------------------------------------------------------------

test_help() {
    local output
    output="$(bash "$FOREST" help 2>/dev/null)"
    assert_contains "help shows commands" "$output" "Commands"
    assert_contains "help shows boot" "$output" "boot"
    assert_contains "help shows switch" "$output" "switch"
    assert_contains "help shows init" "$output" "init"
    assert_contains "help shows label" "$output" "label"
}
test_help

# -- Doctor (outside a repo) --------------------------------------------------

test_doctor_no_repo() {
    local exit_code=0
    (cd /tmp && bash "$FOREST" doctor) &>/dev/null || exit_code=$?
    assert_eq "doctor fails outside git repo" "1" "$exit_code"
}
test_doctor_no_repo

# -- Config: .cursor/worktrees.json -------------------------------------------

test_config_cursor() {
    local repo
    repo="$(make_repo)"
    mkdir -p "$repo/.cursor"
    echo '{"forest": {"project-name": "test-cursor"}}' > "$repo/.cursor/worktrees.json"

    local output
    output="$(cd "$repo" && bash "$FOREST" doctor 2>&1)" || true
    assert_contains "detects cursor config" "$output" ".cursor/worktrees.json"
    rm -rf "$repo"
}
test_config_cursor

# -- Config: Claude Code ------------------------------------------------------

test_config_claude() {
    local repo
    repo="$(make_repo)"
    mkdir -p "$repo/.claude"
    echo '{"forest": {"project-name": "test-claude"}}' > "$repo/.claude/settings.json"

    local output
    output="$(cd "$repo" && bash "$FOREST" doctor 2>&1)" || true
    assert_contains "detects claude config" "$output" ".claude/settings.json"
    rm -rf "$repo"
}
test_config_claude

# -- Config: Standalone -------------------------------------------------------

test_config_standalone() {
    local repo
    repo="$(make_repo)"
    mkdir -p "$repo/.forest"
    echo '{"project-name": "test-standalone"}' > "$repo/.forest/config.json"

    local output
    output="$(cd "$repo" && bash "$FOREST" doctor 2>&1)" || true
    assert_contains "detects standalone config" "$output" ".forest/config.json"
    rm -rf "$repo"
}
test_config_standalone

# -- Config: Priority (.cursor > .claude) -------------------------------------

test_config_priority() {
    local repo
    repo="$(make_repo)"
    mkdir -p "$repo/.cursor" "$repo/.claude"
    echo '{"forest": {"project-name": "cursor-wins"}}' > "$repo/.cursor/worktrees.json"
    echo '{"forest": {"project-name": "claude-loses"}}' > "$repo/.claude/settings.json"

    local output
    output="$(cd "$repo" && bash "$FOREST" doctor 2>&1)" || true
    assert_contains "cursor config takes priority" "$output" ".cursor/worktrees.json"
    rm -rf "$repo"
}
test_config_priority

# -- List shows main worktree -------------------------------------------------

test_list_main_only() {
    local repo
    repo="$(make_repo)"
    mkdir -p "$repo/.cursor"
    echo '{"forest": {"project-name": "test-list"}}' > "$repo/.cursor/worktrees.json"

    local output
    output="$(cd "$repo" && bash "$FOREST" list 2>&1)" || true
    assert_contains "list shows main" "$output" "main"
    rm -rf "$repo"
}
test_list_main_only

# -- Project name from config -------------------------------------------------

test_project_name_from_config() {
    local repo
    repo="$(make_repo)"
    mkdir -p "$repo/.cursor"
    echo '{"forest": {"project-name": "my-cool-project"}}' > "$repo/.cursor/worktrees.json"

    local output
    output="$(cd "$repo" && bash "$FOREST" list 2>&1)" || true
    assert_contains "project name from config" "$output" "my-cool-project"
    rm -rf "$repo"
}
test_project_name_from_config

# -- Doctor shows all requirement checks --------------------------------------

test_doctor_checks() {
    local repo
    repo="$(make_repo)"
    mkdir -p "$repo/.cursor"
    echo '{"forest": {"project-name": "test-doctor"}}' > "$repo/.cursor/worktrees.json"

    local output
    output="$(cd "$repo" && bash "$FOREST" doctor 2>&1)" || true
    assert_contains "doctor checks git" "$output" "git"
    assert_contains "doctor checks docker" "$output" "docker"
    assert_contains "doctor checks jq" "$output" "jq"
    rm -rf "$repo"
}
test_doctor_checks

# -- Summary -------------------------------------------------------------------

echo ""
echo -e "  ────────────────────────────────"
echo -e "  \033[1mResults:\033[0m ${PASS} passed, ${FAIL} failed"
echo ""

if (( FAIL > 0 )); then
    exit 1
fi
