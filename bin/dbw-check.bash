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
"  labbmiljo                        Checks related to the labbmiljö."
"  kmom01                           Checks related to kmom01."
"  kmom02                           Checks related to kmom02."
"  kmom03                           Checks related to kmom03."
""
"Options:"
"  --no-eslint    Ignore checking with eslint."
"  --help, -h     Print help."
"  --version, -h  Print version."
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
# Check if a set of branches exists in the repo.
#
check_branches ()
{
    local verbose="$1"
    local branches=(
        "main"
        "bth/submit/kmom03"
        "bth/submit/kmom06"
        "bth/submit/kmom10"
    )
    local success=0

    for branch in "${branches[@]}"; do
        if git show-ref --verify --quiet "refs/heads/$branch"; then
            [[ -n "$verbose" ]] && echo "✅ $branch finns lokalt"
        else
            [[ -n "$verbose" ]] && echo "❌ $branch saknas lokalt"
            success=1
        fi

        # Remote branches
        # if git ls-remote --heads origin "$branch" | grep -q "$branch"; then
        #     [[ -n "$verbose" ]] && echo "✅ $branch finns i din remote"
        # else
        #     [[ -n "$verbose" ]] && echo "❌ $branch saknas i din remote"
        #     success=1
        # fi
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
        [[ $silent ]] || echo "✅ $kmom alla kataloger/filer finns på plats 😀."
    else
        [[ $silent ]] || echo "🚫 $kmom någon katalog/fil saknas eller har fel namn, fixa det 🔧."
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
        [[ $silent ]] || echo "✅ $kmom repot har tag $res 😀."
    else
        [[ $silent ]] || echo "🚫 $kmom repot saknar tagg >=$2 and <$3, fixa det 🔧."
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

    res=$( npx eslint public )
    if (( $? == 0 )); then
        [[ $silent ]] || echo "✅ $kmom eslint passerar 😀."
    else
        [[ $silent ]] || echo "🚫 $kmom eslint hittade fel, kör eslint mot $path och fixa det 🔧."
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

    app_"$previous_kmom" silent
    (( $? != 0 )) && success=2

    kmom_check_paths "$silent" "$pathArray"
    (( $? != 0 )) && success=1

    kmom_check_tag "$silent" "$kmom" "$versionMin" "$versionMax"
    (( $? != 0 )) && success=1

    if [[ ! $silent ]]; then
        kmom_eslint "$silent" "$kmom" "public/"
        (( $? != 0 )) && success=1
    fi

    # Räkna antalet commits
    # npx http-server och testa de routes som skall fungera
    # Kör labben och se till att den är minst 15p, visa även om det är bättre

    kmom_summary "$silent" $success "$kmom"
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
            echo "✅ $kmom OK 😀."
        else
            echo "🚫 $kmom något saknas, kör en egen rapport för $kmom och fixa det 🔧."
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



##
# Check a specific kmom.
#
app_labbmiljo ()
{
    local silent="$1"
    local kmom="Labbmiljö"
    local success=0

    kmom_check_paths "$silent" PATHS_LABBMILJO[@]
    success=$?

    check_branches || ([[ ! $silent ]] && check_branches verbose)
    if (( $? == 0 )); then
        [[ $silent ]] || echo "✅ $kmom alla branches är på plats 🫡."
    else
        [[ $silent ]] || echo "🚫 $kmom någon branch saknas eller har fel namn, fixa det 🔧."
        success=1
    fi

    if [[ ! $silent ]]; then
        kmom_eslint "$silent" "$kmom" "./"
        (( $? != 0 )) && success=1
    fi

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

    kmom_do "$silent" "$previous_kmom" "$kmom" "$pathArray" "$versionMin" "$versionMax"
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

    kmom_do "$silent" "$previous_kmom" "$kmom" "$pathArray" "$versionMin" "$versionMax"
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

    kmom_do "$silent" "$previous_kmom" "$kmom" "$pathArray" "$versionMin" "$versionMax"
    res=$?
    (( res != 0 )) && success=$res

    # kontrollera att PR är korrekt gjord för kmom03

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

            --no-eslint)
                NO_ESLINT=1
                shift
            ;;

            --help | -h)
                usage
                exit 0
            ;;

            --verbose | -v)
                VERBOSE=1
                shift
            ;;

            --version)
                version
                exit 0
            ;;

            labbmiljo        \
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

main "$@"
