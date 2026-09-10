#!/usr/bin/env bash
#
# Check that the repo contains whats expected.
#
# Exit values:
#  0 on success
#  1 on failure
#



# Name of the script
#SCRIPT=$( basename "$0" )

# Directory this script lives in, used to locate sibling helper scripts.
# Resolve symlinks manually (npm installs this as a symlink in
# node_modules/.bin) instead of relying on `realpath`, which isn't
# installed by default on macOS.
_source="$0"
while [ -h "$_source" ]; do
    _dir="$(cd -P "$(dirname "$_source")" && pwd)"
    _source="$(readlink "$_source")"
    [[ "$_source" != /* ]] && _source="$_dir/$_source"
done
SCRIPT_DIR="$(cd -P "$(dirname "$_source")" && pwd)"
unset _source _dir

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



##
# Message to display for usage and help.
#
usage ()
{
    local txt=(
"Check that your repo contains the essentials for each part of the course."
"Usage: $SCRIPT check [options] <command> [arguments]"
""
"Command:"
"  eslint                            Checks executed by eslint."
"  lab <lab_01 lab_02 lab_03 lab_04> Checks and prints the specified labs."
"  labbmiljo                         Checks related to the labbmiljö."
"  kmom01                            Checks related to kmom01."
"  kmom02                            Checks related to kmom02."
"  kmom03                            Checks related to kmom03."
"  kmom04                            Checks related to kmom04."
"  kmom05                            Checks related to kmom05."
"  kmom06                            Checks related to kmom06."
"  kmom10                            Checks related to kmom10."
""
"Options:"
"  --eslint-fix        Run eslint fix to see if some validation errors disappear."
"  --only-this         Check only the specific kmom, no previous ones."
"  --no-color          Do not colourize the output."
"  --no-eslint         Ignore checking with eslint."
"  --pass-lab          Run the lab towards the solution file to pass the check."
"  --help, -h          Print help."
"  --version, -h       Print version."
    )

    printf "%s\\n" "${txt[@]}"
}



##
# Message to display when bad usage.
#
badUsage ()
{
    local message="$1"
    local txt=(
"For an overview of the command, execute:"
"$SCRIPT --help"
    )

    [[ -n $message ]] && printf "%s\\n" "$message"

    printf "%s\\n" "${txt[@]}" >&2
    exit 1
}



##
# Error while processing
#
# @param string $* error message to display.
#
fail ()
{
    local color
    local normal

    color=$(tput setaf 1)
    normal=$(tput sgr0)

    printf "%s $*\\n" "${color}[FAILED]${normal}"
    exit 2
}



##
# Open an url in the default browser
#
# @arg1 the url
#
function openUrl {
    local url="$1"

    #printf "$url\n"
    eval "$WEB_BROWSER \"$url\"" 2>/dev/null &
    sleep 0.5
}



##
# Check if the git tag is between two versions
# >=@arg2 and <@arg3
#
# @arg1 string the path to the dir to check.
# @arg2 string the lowest version number to check.
# @arg3 string the highest version number to check.
#
hasGitTagBetween()
{
    local where="$1"
    local low=
    local high=
    local semTag=

    low=$( getSemanticVersion "$2" )
    high=$( getSemanticVersion "$3" )
    #echo "Validate that tag exists >=$2 and <$3 ."

    local success=false
    local highestTag=0
    local highestSemTag=0

    if [ -d "$where" ]; then
        while read -r tag; do
            semTag=$( getSemanticVersion "$tag" )
            #echo "trying tag $tag = $semTag"
            if [ $semTag -ge $low -a $semTag -lt $high ]; then
                #echo "success with $tag"
                success=
                if [ $semTag -gt $highestSemTag ]; then
                    highestTag=$tag
                    highestSemTag=$semTag
                fi
            fi
        done < <( cd "$where" && git tag )
    fi

    if [ "$success" = "false" ]; then
        printf "$MSG_FAILED Failed to validate tag exists >=%s and <%s." "$2" "$3"
        return 1
    fi

    echo "$highestTag"
}



##
# Convert version to a comparable string
# Works for 1.0.0 and v1.0.0
#
# @arg1 string the version to check.
#
function getSemanticVersion
{
    #local version=${1:1}
    local version=
    
    version=$( echo $1 | sed s/^[vV]// )
    echo "$version" | awk -F. '{ printf("%03d%03d%03d\n", $1,$2,$3); }'
}



##
# Check if paths (files and dirs) exists.
#
# param array of paths
#
check_paths ()
{
    local array_name="$1"
    local verbose="$2"
    local paths=("${!array_name}")
    local success=0

    for path in "${paths[@]}"; do
        if [[ -e "$path" ]]; then
            [[ -n "$verbose" ]] && echo "✅ $path"
        else
            [[ -n "$verbose" ]] && echo "❌ $path"
            success=1
        fi
    done

    return $success
}



##
# Check paths for a kmom
#
kmom_check_paths ()
{
    local silent="$1"
    local pathArray="$2"
    local success=0

    check_paths "$pathArray" || ([[ ! $silent ]] && check_paths "$pathArray" verbose)
    if (( $? == 0 )); then
        [[ $silent ]] || echo "✅ 😀 $kmom alla kataloger/filer finns på plats."
    else
        [[ $silent ]] || echo "🚫 🔧 $kmom någon katalog/fil saknas eller har fel namn, fixa det."
        success=1
    fi

    return $success
}



##
# Check git repo has a tag
#
kmom_check_tag ()
{
    local silent="$1"
    local kmom="$2"
    local tagMin="$3"
    local tagMax="$4"
    local dir="."
    local success=0
    local res=

    res=$( hasGitTagBetween "$dir" "$tagMin" "$tagMax" )
    if (( $? == 0 )); then
        [[ $silent ]] || echo "✅ 😀 $kmom repot har tagg $res."
    else
        [[ $silent ]] || echo "🚫 🔧 $kmom repot saknar tagg >=$3 and <$4, fixa det."
        success=1
    fi

    return $success
}



##
# Fetch and cache the tags that exist on the origin remote, so a full
# chained check (kmom06 -> kmom05 -> ... -> labbmiljo) only hits the
# network once.
#
getRemoteTags ()
{
    if [[ ! $REMOTE_TAGS_FETCHED ]]; then
        REMOTE_TAGS=$( git ls-remote --tags origin 2>/dev/null )
        REMOTE_TAGS_FETCHED=1
    fi

    echo "$REMOTE_TAGS"
}



##
# Check that the tag found for the kmom has actually been pushed to origin.
#
kmom_check_tag_pushed ()
{
    local silent="$1"
    local kmom="$2"
    local tagMin="$3"
    local tagMax="$4"
    local dir="."
    local success=0
    local tag=

    tag=$( hasGitTagBetween "$dir" "$tagMin" "$tagMax" 2>/dev/null )
    (( $? != 0 )) && return 0

    if getRemoteTags | grep -q "refs/tags/${tag}\$"; then
        [[ $silent ]] || echo "✅ 😀 $kmom taggen $tag är pushad till GitHub."
    else
        [[ $silent ]] || echo "🚫 🔧 $kmom taggen $tag finns lokalt men är inte pushad, kör 'git push --tags'."
        success=1
    fi

    return $success
}



##
# Check repo passes eslint
#
kmom_eslint ()
{
    local silent="$1"
    local kmom="$2"
    local path="$3"
    local success=0
    local res=

    (( NO_ESLINT )) && return 0

    res=$( npx eslint "$path" )
    if (( $? == 0 )); then
        [[ $silent ]] || echo "✅ 😀 $kmom eslint passerar."
    else
        [[ $silent ]] || echo "🚫 🔧 $kmom eslint hittade fel, kör eslint mot $path och fixa det."
        if [[ $ESLINT_FIX ]]; then
            [[ $silent ]] || echo "$res" | tail -1
            [[ $silent ]] || printf "\n🙈 🔧 Försöker laga felen med 'eslint --fix och provar igen...\n"
            res=$( npx eslint "$path" --fix )
            res=$( npx eslint "$path" )
            if (( $? == 0 )); then
                [[ $silent ]] || echo "✅ 😀 $kmom eslint passerar."
            fi
        fi
        [[ $VERBOSE ]] && echo "$res"
        success=1
    fi

    return $success
}



##
# Check labs in a kmom
#
kmom_check_lab ()
{
    local silent="$1"
    local kmom="$2"
    local lab="$3"
    local success=0
    local res=

    [[ -d  lab/$lab ]] || return 0
    res=$( cd "lab/$lab" || return 0; node lab "$PASS_LAB" )
    res=$?
    if (( res >= 21 )); then
        [[ $silent ]] || echo "✅ 🙌 $kmom $lab imponerar med ${res}p."
    elif (( res >= 19 )); then
        [[ $silent ]] || echo "✅ 😍 $kmom $lab väl godkänd med ${res}p."
    elif (( res >= 15 )); then
        [[ $silent ]] || echo "✅ 😁 $kmom $lab passerar med ${res}p."
    else
        [[ $silent ]] || echo "🚫 🔧 $kmom $lab med ${res}p passerar inte gränsen för godkänt, fixa det."
        success=1
    fi

    return $success
}



##
# Check that the report text for a kmom exists and has some substance
#
kmom_check_report_text ()
{
    local silent="$1"
    local kmom="$2"
    local success=0
    local res=

    res=$( node "$SCRIPT_DIR/dbw-check-report-text.js" "public/report.html" "$kmom" )
    if (( $? == 0 )); then
        [[ $silent ]] || echo "✅ 😀 $kmom redovisningstexten finns och är tillräckligt lång."
    else
        [[ $silent ]] || echo "🚫 🔧 $kmom redovisningstexten saknas eller är för kort, fyll i den i public/report.html."
        [[ $VERBOSE ]] && echo "$res"
        success=1
    fi

    return $success
}



##
# Do tests for a kmom.
#
kmom_do ()
{
    local success=0
    local silent="$1"
    local previous_kmom="$2"
    local kmom="$3"
    local pathArray="$4"
    local versionMin="$5"
    local versionMax="$6"
    local lab="$7"

    if [[ ! $ONLY_THIS ]]; then
        app_"$previous_kmom" silent
        (( $? != 0 )) && success=2
    fi

    kmom_check_paths "$silent" "$pathArray"
    (( $? != 0 )) && success=1

    kmom_check_tag "$silent" "$kmom" "$versionMin" "$versionMax"
    (( $? != 0 )) && success=1

    kmom_check_tag_pushed "$silent" "$kmom" "$versionMin" "$versionMax"
    (( $? != 0 )) && success=1

    if [[ $lab ]]; then
        kmom_check_lab "$silent" "$kmom" "$lab"
        (( $? != 0 )) && success=1
    fi

    kmom_check_report_text "$silent" "$kmom"
    (( $? != 0 )) && success=1

    if [[ ! $silent ]]; then
        if [[ $kmom != "labbmiljo" ]]; then
            kmom_eslint "$silent" "$kmom" "public/"
            (( $? != 0 )) && success=1
        fi
    fi

    # Räkna antalet commits
    # npx http-server och testa de routes som skall fungera

    kmom_summary "$silent" $success "$kmom"

    return $success
}



##
# Print the summary for each kmom.
#
kmom_summary ()
{
    local silent="$1"
    local success=$2
    local kmom="$3"

    if [[ $silent ]]; then
        if (( success == 0)); then
            echo "✅ 😎 $kmom OK."
        else
            echo "🚫 🔧 $kmom något saknas, kör en egen rapport för $kmom och fixa det."
        fi
    fi
}



##
# Define paths needed for each kmom
#
PATHS_LABBMILJO=(
    ".editorconfig"
    ".gitignore"
    "package.json"
    "README.md"
)

PATHS_KMOM01=(
    "lab/"
    "lab/lab_01/"
    "public/"
    "public/css/"
    "public/css/style.css"
    "public/js/"
    "public/js/hello.js"
    "public/about.html"
    "public/me.html"
    "public/report.html"
)

PATHS_KMOM02=(
    "lab/"
    "lab/lab_02/"
    "public/css/responsive-design.css"
    "public/js/responsive-design.js"
)

PATHS_KMOM03=(
    "lab/"
    "lab/lab_03/"
    "public/onepage.html"
    "public/css/onepage.css"
    "public/js/onepage.js"
)

PATHS_KMOM04=(
    "lab/"
    "lab/lab_04/"
    "public/dom.html"
    "public/css/dom.css"
    "public/js/dom.js"
)

PATHS_KMOM05=(
    "public/fetch.html"
    "public/css/fetch.css"
    "public/js/fetch.js"
)

PATHS_KMOM06=(
    "public/duckhunt.html"
    "public/css/duckhunt.css"
    "public/js/duckhunt.js"
)

PATHS_KMOM10=(
    "public/project.html"
    "public/css/project.css"
    "public/js/project.js"
)



##
# Check using eslint.
#
app_eslint ()
{
    local target="${1:-public}"

    kmom_eslint "" "" "$target"
    return $?
}



##
# Check the labs.
#
app_lab ()
{
    local success=0
    local res=
    local ret=

    for lab in "$@"; do
        if [[ -d lab/$lab ]]; then
            res=$( cd "lab/$lab" || return 0; node lab "$PASS_LAB" )
            ret=$?
            res=$(echo "$res" | tail -3 | head -1)
            res=${res:2}
        else
            res="directory is missing"
            ret=0
        fi

        [[ $NO_COLOR ]] && res=$( echo "$res" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" )

        if (( ret >= 21 )); then
            echo "✅ 🙌 $lab $res ${ret}p."
        elif (( ret >= 19 )); then
            echo "✅ 😍 $lab $res ${ret}p."
        elif (( ret >= 15 )); then
            echo "✅ 😁 $lab $res ${ret}p."
        else
            echo "🚫 🔧 $lab $res ${ret}p."
            success=1
        fi

    done

    return $success
}



##
# Check a specific part of the course.
#
app_labbmiljo ()
{
    local silent="$1"
    local kmom="Labbmiljö"
    local success=0

    kmom_check_paths "$silent" PATHS_LABBMILJO[@]
    success=$?

    # Kolla att repot har rätt namn
    # npx http-server ?

    kmom_summary "$silent" $success "$kmom"

    return $success
}



##
# Check a specific kmom.
#
app_kmom01 ()
{
    local success=0
    local silent="$1"
    local previous_kmom="labbmiljo"
    local kmom="kmom01"
    local pathArray="PATHS_KMOM01[@]"
    local versionMin="v1.0.0"
    local versionMax="v2.0.0"
    local lab="lab_01"

    kmom_do "$silent" "$previous_kmom" "$kmom" "$pathArray" "$versionMin" "$versionMax" "$lab"
    res=$?
    (( res != 0 )) && success=$res

    return $success
}



##
# Check a specific kmom.
#
app_kmom02 ()
{
    local silent="$1"
    local success=0
    local previous_kmom="kmom01"
    local kmom="kmom02"
    local pathArray="PATHS_KMOM02[@]"
    local versionMin="v2.0.0"
    local versionMax="v3.0.0"
    local lab="lab_02"

    kmom_do "$silent" "$previous_kmom" "$kmom" "$pathArray" "$versionMin" "$versionMax" "$lab"
    res=$?
    (( res != 0 )) && success=$res

    return $success
}



##
# Check a specific kmom.
#
app_kmom03 ()
{
    local silent="$1"
    local success=0
    local previous_kmom="kmom02"
    local kmom="kmom03"
    local pathArray="PATHS_KMOM03[@]"
    local versionMin="v3.0.0"
    local versionMax="v4.0.0"
    local lab="lab_03"

    kmom_do "$silent" "$previous_kmom" "$kmom" "$pathArray" "$versionMin" "$versionMax" "$lab"
    res=$?
    (( res != 0 )) && success=$res

    # kontrollera att PR är korrekt gjord för kmom03

    return $success
}



##
# Check a specific kmom.
#
app_kmom04 ()
{
    local success=0
    local silent="$1"
    local previous_kmom="labbmiljo"
    local kmom="kmom04"
    local pathArray="PATHS_KMOM04[@]"
    local versionMin="v4.0.0"
    local versionMax="v5.0.0"
    local lab="lab_04"

    kmom_do "$silent" "$previous_kmom" "$kmom" "$pathArray" "$versionMin" "$versionMax" "$lab"
    res=$?
    (( res != 0 )) && success=$res

    return $success
}



##
# Check a specific kmom.
#
app_kmom05 ()
{
    local success=0
    local silent="$1"
    local previous_kmom="kmom04"
    local kmom="kmom05"
    local pathArray="PATHS_KMOM05[@]"
    local versionMin="v5.0.0"
    local versionMax="v6.0.0"
    local lab="no"

    kmom_do "$silent" "$previous_kmom" "$kmom" "$pathArray" "$versionMin" "$versionMax" "$lab"
    res=$?
    (( res != 0 )) && success=$res

    return $success
}



##
# Check a specific kmom.
#
app_kmom06 ()
{
    local success=0
    local silent="$1"
    local previous_kmom="kmom05"
    local kmom="kmom06"
    local pathArray="PATHS_KMOM06[@]"
    local versionMin="v6.0.0"
    local versionMax="v7.0.0"
    local lab=""

    kmom_do "$silent" "$previous_kmom" "$kmom" "$pathArray" "$versionMin" "$versionMax" "$lab"
    res=$?
    (( res != 0 )) && success=$res

    return $success
}



##
# Check a specific kmom.
#
app_kmom10 ()
{
    local success=0
    local silent="$1"
    local previous_kmom="no"
    local kmom="kmom10"
    local pathArray="PATHS_KMOM10[@]"
    local versionMin="v7.0.0"
    local versionMax="v11.0.0"
    local lab=""

    kmom_do "$silent" "$previous_kmom" "$kmom" "$pathArray" "$versionMin" "$versionMax" "$lab"
    res=$?
    (( res != 0 )) && success=$res

    return $success
}



##
# Always have a main
# 
main ()
{
    local command
    local args

    while (( $# ))
    do
        case "$1" in

            --eslint-fix)
                ESLINT_FIX=1
                shift
            ;;

            --help | -h)
                usage
                exit 0
            ;;

            --only-this)
                ONLY_THIS=1
                shift
            ;;

            --no-color)
                NO_COLOR=1
                shift
            ;;

            --no-eslint)
                NO_ESLINT=1
                shift
            ;;

            --pass-lab)
                PASS_LAB="-s"
                shift
            ;;

            --verbose | -v)
                VERBOSE=1
                shift
            ;;

            --version)
                version
                exit 0
            ;;

            eslint           \
            | lab            \
            | labbmiljo      \
            | kmom01         \
            | kmom02         \
            | kmom03         \
            | kmom04         \
            | kmom05         \
            | kmom06         \
            | kmom10         \
            )
                if [[ ! $command ]]; then
                    command=$1
                else
                    args+=("$1")
                fi
                shift
            ;;

            -*)
                badUsage "Unknown option '$1'."
            ;;

            *)
                if [[ ! $command ]]; then
                    badUsage "Unknown command '$1'."
                else
                    args+=("$1")
                    shift
                fi
            ;;

        esac
    done

    # Execute the command 
    if type -t app_"$command" | grep -q function; then
        app_"$command" "${args[@]}"
    else
        badUsage "Missing option or command."
    fi
}

# Guard so the test suite can source this file (to unit-test the helper
# functions above) without triggering a full CLI run.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
