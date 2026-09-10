#!/usr/bin/env bash

# Name of the script
#SCRIPT=$( basename "$0" )
export SCRIPT="@dbwebb/webtec"

# Current version
export VERSION="2.4.1"



##
# Message to display for version.
#
version ()
{
    local txt=(
"$SCRIPT version $VERSION"
    )

    printf "%s\\n" "${txt[@]}"
}



# Resolve the real path to this script, following symlinks (npm installs
# this as a symlink in node_modules/.bin). Avoid the `realpath` command,
# which isn't installed by default on macOS.
SCRIPT_PATH="$0"
while [ -h "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "$SCRIPT_PATH")"

SUBCOMMAND="$1"
shift

case "$SUBCOMMAND" in
  check)
    "$SCRIPT_DIR/dbw-check.bash" "$@"
    ;;
  help)
    "$SCRIPT_DIR/dbw-help.bash" "$@"
    ;;
  version | --version)
    version
    ;;
  *)
    echo "Usage: npx @dbwebb/webtec {check|help|version}"
    exit 1
    ;;
esac
