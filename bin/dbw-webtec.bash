#!/usr/bin/env bash

# Name of the script
#SCRIPT=$( basename "$0" )
export SCRIPT="@dbwebb/webtec"

# Current version
export VERSION="1.9.1"



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



#SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

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
