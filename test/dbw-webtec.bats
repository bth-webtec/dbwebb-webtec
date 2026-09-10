#!/usr/bin/env bats
#
# Tests for bin/dbw-webtec.bash, the CLI entry point. All run as real
# subprocesses (this script has no sourcing guard, so it can't safely be
# sourced without triggering its dispatch logic).

setup() {
    BIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../bin" && pwd)"
    TEST_TMPDIR="$(mktemp -d)"
    source "$(dirname "$BATS_TEST_FILENAME")/fixtures/no-realpath-path.bash"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

@test "version prints the package version" {
    run bash "$BIN_DIR/dbw-webtec.bash" version
    [ "$status" -eq 0 ]
    [[ "$output" == *"@dbwebb/webtec version"* ]]
}

@test "--version prints the package version" {
    run bash "$BIN_DIR/dbw-webtec.bash" --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"@dbwebb/webtec version"* ]]
}

@test "with no subcommand, prints usage and exits 1" {
    run bash "$BIN_DIR/dbw-webtec.bash"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "an unknown subcommand prints usage and exits 1" {
    run bash "$BIN_DIR/dbw-webtec.bash" not-a-real-subcommand
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "help dispatches to dbw-help.bash" {
    run bash "$BIN_DIR/dbw-webtec.bash" help
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "check dispatches to dbw-check.bash and forwards arguments" {
    run bash "$BIN_DIR/dbw-webtec.bash" check --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

# --- symlink invocation (regression test for the `realpath` bug) -----------
#
# npm installs the CLI as a symlink in node_modules/.bin (e.g. `webtec` ->
# .../node_modules/@dbwebb/webtec/bin/dbw-webtec.bash). The script used to
# resolve its own directory with `realpath "$0"`, which isn't installed by
# default on macOS ("realpath: command not found"). It must find its real
# directory — and from there its sibling dbw-check.bash / dbw-help.bash —
# using only bash builtins and readlink.

@test "resolves sibling scripts when invoked through an npm-style bin symlink" {
    local link_dir="$TEST_TMPDIR/node_modules-bin"
    mkdir -p "$link_dir"
    ln -s "$BIN_DIR/dbw-webtec.bash" "$link_dir/webtec"

    # PATH here has no `realpath` at all, so this fails exactly like it did
    # on macOS ("realpath: command not found") if the resolver regresses
    # to depending on it again.
    local no_realpath_path
    no_realpath_path="$(build_no_realpath_path "$TEST_TMPDIR/path")"
    run env -i PATH="$no_realpath_path" HOME="$HOME" "$link_dir/webtec" check --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "resolves sibling scripts through a relative symlink" {
    # npm's node_modules/.bin symlinks are relative (e.g.
    # `../foo/bin/foo.js`), exercising the "$SCRIPT_PATH != /*" branch of
    # the resolver. Build a self-contained fixture so the relative target
    # is known ahead of time, instead of computing one with `realpath`.
    local pkg_bin="$TEST_TMPDIR/pkg/bin"
    local bin_link_dir="$TEST_TMPDIR/pkg/.bin"
    mkdir -p "$pkg_bin" "$bin_link_dir"
    cp "$BIN_DIR"/dbw-webtec.bash "$BIN_DIR"/dbw-check.bash "$BIN_DIR"/dbw-help.bash "$pkg_bin/"
    ln -s "../bin/dbw-webtec.bash" "$bin_link_dir/webtec"

    local no_realpath_path
    no_realpath_path="$(build_no_realpath_path "$TEST_TMPDIR/path")"
    run env -i PATH="$no_realpath_path" HOME="$HOME" "$bin_link_dir/webtec" check --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}
