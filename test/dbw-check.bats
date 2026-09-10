#!/usr/bin/env bats
#
# Tests for bin/dbw-check.bash: both the pure helper functions (sourced
# directly, thanks to the BASH_SOURCE guard around `main "$@"`) and the
# script's behaviour when run as a real subprocess.

setup() {
    BIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../bin" && pwd)"
    TEST_TMPDIR="$(mktemp -d)"
    source "$(dirname "$BATS_TEST_FILENAME")/fixtures/no-realpath-path.bash"
    # Source the script for unit tests. This defines every function above
    # but does not run main(), since $0 here isn't the script itself.
    source "$BIN_DIR/dbw-check.bash"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# --- getSemanticVersion --------------------------------------------------

@test "getSemanticVersion pads a plain x.y.z version" {
    run getSemanticVersion "1.2.3"
    [ "$status" -eq 0 ]
    [ "$output" = "001002003" ]
}

@test "getSemanticVersion strips a leading v" {
    run getSemanticVersion "v2.10.5"
    [ "$status" -eq 0 ]
    [ "$output" = "002010005" ]
}

# --- check_paths -----------------------------------------------------------

@test "check_paths succeeds when every path exists" {
    touch "$TEST_TMPDIR/a" "$TEST_TMPDIR/b"
    local paths=("$TEST_TMPDIR/a" "$TEST_TMPDIR/b")
    run check_paths paths[@]
    [ "$status" -eq 0 ]
}

@test "check_paths fails when a path is missing" {
    touch "$TEST_TMPDIR/a"
    local paths=("$TEST_TMPDIR/a" "$TEST_TMPDIR/missing")
    run check_paths paths[@]
    [ "$status" -eq 1 ]
}

# --- hasGitTagBetween / kmom_check_tag -------------------------------------

make_tagged_repo() {
    git -C "$TEST_TMPDIR" init -q
    git -C "$TEST_TMPDIR" -c user.email=test@example.com -c user.name=test commit -q --allow-empty -m init
    git -C "$TEST_TMPDIR" tag "$1"
}

@test "hasGitTagBetween finds a tag inside the range" {
    make_tagged_repo "v1.5.0"
    run hasGitTagBetween "$TEST_TMPDIR" "1.0.0" "2.0.0"
    [ "$status" -eq 0 ]
    [ "$output" = "v1.5.0" ]
}

@test "hasGitTagBetween fails when the only tag is outside the range" {
    make_tagged_repo "v2.0.0"
    run hasGitTagBetween "$TEST_TMPDIR" "1.0.0" "2.0.0"
    [ "$status" -eq 1 ]
}

@test "hasGitTagBetween picks the highest matching tag" {
    git -C "$TEST_TMPDIR" init -q
    git -C "$TEST_TMPDIR" -c user.email=test@example.com -c user.name=test commit -q --allow-empty -m init
    git -C "$TEST_TMPDIR" tag "v1.1.0"
    git -C "$TEST_TMPDIR" tag "v1.5.0"
    run hasGitTagBetween "$TEST_TMPDIR" "1.0.0" "2.0.0"
    [ "$status" -eq 0 ]
    [ "$output" = "v1.5.0" ]
}

@test "kmom_check_tag reports success for a tag in range" {
    make_tagged_repo "v1.5.0"
    cd "$TEST_TMPDIR"
    run kmom_check_tag "" "kmom01" "1.0.0" "2.0.0"
    [ "$status" -eq 0 ]
    [[ "$output" == *"v1.5.0"* ]]
}

@test "kmom_check_tag reports failure for a tag out of range" {
    make_tagged_repo "v0.5.0"
    cd "$TEST_TMPDIR"
    run kmom_check_tag "" "kmom01" "1.0.0" "2.0.0"
    [ "$status" -eq 1 ]
}

# --- kmom_check_tag_pushed --------------------------------------------------

@test "kmom_check_tag_pushed succeeds when the tag exists on origin" {
    local origin="$TEST_TMPDIR/origin"
    local clone="$TEST_TMPDIR/clone"
    git init -q --bare "$origin"
    git clone -q "$origin" "$clone"
    git -C "$clone" -c user.email=test@example.com -c user.name=test commit -q --allow-empty -m init
    git -C "$clone" tag "v1.5.0"
    git -C "$clone" push -q origin --tags

    cd "$clone"
    run kmom_check_tag_pushed "" "kmom01" "1.0.0" "2.0.0"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pushad"* ]]
}

@test "kmom_check_tag_pushed fails when the tag is only local" {
    local origin="$TEST_TMPDIR/origin"
    local clone="$TEST_TMPDIR/clone"
    git init -q --bare "$origin"
    git clone -q "$origin" "$clone"
    git -C "$clone" -c user.email=test@example.com -c user.name=test commit -q --allow-empty -m init
    git -C "$clone" tag "v1.5.0"
    # deliberately not pushed

    cd "$clone"
    run kmom_check_tag_pushed "" "kmom01" "1.0.0" "2.0.0"
    [ "$status" -eq 1 ]
    [[ "$output" == *"inte pushad"* ]]
}

# --- CLI behaviour (subprocess, black-box) ----------------------------------

@test "--help prints usage and exits 0" {
    run bash "$BIN_DIR/dbw-check.bash" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "--version prints the version" {
    run bash "$BIN_DIR/dbw-check.bash" --version
    [ "$status" -eq 0 ]
}

@test "an unknown command exits 1 with a usage hint" {
    run bash "$BIN_DIR/dbw-check.bash" not-a-real-command
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown command"* ]]
}

@test "an unknown option exits 1 with a usage hint" {
    run bash "$BIN_DIR/dbw-check.bash" --not-a-real-option
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

# --- symlink invocation (regression test for the `realpath` bug) -----------
#
# The stronger version of this test, which also asserts that SCRIPT_DIR
# resolves to the real bin/ dir (not the symlink's dir), lives in
# test/dbw-webtec.bats — that's the scenario npm actually creates.

@test "still runs when invoked through a symlink, without realpath" {
    local link_dir="$TEST_TMPDIR/bin-link"
    mkdir -p "$link_dir"
    ln -s "$BIN_DIR/dbw-check.bash" "$link_dir/dbw-check.bash"

    local no_realpath_path
    no_realpath_path="$(build_no_realpath_path "$TEST_TMPDIR/path")"
    run env -i PATH="$no_realpath_path" HOME="$HOME" "$link_dir/dbw-check.bash" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}
