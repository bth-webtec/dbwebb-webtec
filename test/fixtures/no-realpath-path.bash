# Build a minimal PATH that has every tool the scripts under test need,
# but deliberately omits `realpath` — this is what actually reproduced
# the "realpath: command not found" bug report on macOS. Restricting PATH
# to /usr/bin:/bin isn't enough on Linux dev/CI boxes, since GNU coreutils
# ships realpath there too.
build_no_realpath_path() {
    local dir="$1"
    mkdir -p "$dir"
    local tool
    for tool in bash sh env readlink dirname basename cat mkdir mktemp \
                grep sed awk git printf tput cp rm mv chmod ls node npx; do
        local resolved
        resolved=$(command -v "$tool" 2>/dev/null) || continue
        ln -s "$resolved" "$dir/$tool" 2>/dev/null
    done
    echo "$dir"
}
