#!/usr/bin/env bash
#
# Check that the repo contains whats expected.
#
# Exit values:
#  0 on success
#  1 on failure
#



# Name of the script
SCRIPT=$( basename "$0" )

# Current version
VERSION="1.2.0"



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
"Work with a course by connecting to Canvas and GitHub."
"Usage: $SCRIPT [options] <command> [arguments]"
""
"Command:"
"  grade                            Grade a submission done through a PR."
"  invite <email | acronym>         Invite a new member to the org using email or GH user acronym."
"  invites                          List all invites."
"  members                          Get all members on the organisation of GitHub."
"  members <team>                   Get all members in a specific team."
"  membership <acronym>             Check if acronym is member of the organisation."
"  pages <repo name>                Get details of GitHub pages for a repo."
"  repo <repo name>                 Get details of a repo."
"  repos                            Get details of all repos."
"  user                             Get details of your own user (troubleshoot the token)."
"  sections                         List current sections using Canvas API"
"  student <acronym>                Get details and urls related to a student work."
"  students                         List current students in each section using Canvas API"
"  info <acronym>                   Get details of user (name, email, section, assignments)."
""
"Options:"
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

        if git ls-remote --heads origin "$branch" | grep -q "$branch"; then
            [[ -n "$verbose" ]] && echo "✅ $branch finns i din remote"
        else
            [[ -n "$verbose" ]] && echo "❌ $branch saknas i din remote"
            success=1
        fi
    done

    return $success
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

    check_paths PATHS_LABBMILJO[@] || ([[ ! $silent ]] && check_paths PATHS_LABBMILJO[@] verbose)
    if (( $? == 0 )); then
        [[ $silent ]] || echo "✅ $kmom alla kataloger/filer finns på plats 😀."
    else
        [[ $silent ]] || echo "🚫 $kmom någon katalog/fil saknas eller har fel namn, fixa det 🔧."
        success=1
    fi

    check_branches || ([[ ! $silent ]] && check_branches verbose)
    if (( $? == 0 )); then
        [[ $silent ]] || echo "✅ $kmom alla branches är på plats 🫡."
    else
        [[ $silent ]] || echo "🚫 $kmom någon branch saknas eller har fel namn, fixa det 🔧."
        success=1
    fi

    # Kolla att repot har rätt namn
    # npx eslint
    # npx http-server ?

    if [[ $silent ]]; then
        if (( success == 0)); then
            echo "✅ $kmom OK 😀."
        else
            echo "🚫 $kmom något saknas, kör en egen rapport för $kmom och fixa det 🔧."
        fi
    fi

    return $success
}



##
# Check a specific kmom.
#
app_kmom01 ()
{
    local silent="$1"
    local success=0
    local previous_kmom="labbmiljo"
    local kmom="kmom01"
    local res=

    app_$previous_kmom silent
    (( $? != 0 )) && success=2

    check_paths PATHS_KMOM01[@] || ([[ ! $silent ]] && check_paths PATHS_KMOM01[@] verbose)
    if (( $? == 0 )); then
        [[ $silent ]] || echo "✅ $kmom alla kataloger/filer finns på plats 😀."
    else
        [[ $silent ]] || echo "🚫 $kmom någon katalog/fil saknas eller har fel namn, fixa det 🔧."
        success=1
    fi

    # Kolla om rätt tagg finns
    # Räkna antalet commits
    # npx eslint
    # npx http-server och testa de routes som skall fungera
    # Kör labben och se till att den är minst 15p, visa även om det är bättre

    if [[ $silent ]]; then
        if (( success == 0)); then
            echo "✅ $kmom OK 😀."
        else
            echo "🚫 $kmom något saknas, kör en egen rapport för $kmom och fixa det 🔧."
        fi
    fi

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
    local res=

    app_$previous_kmom silent
    (( $? != 0 )) && success=2

    check_paths PATHS_KMOM02[@] || ([[ ! $silent ]] && check_paths PATHS_KMOM02[@] verbose)
    if (( $? == 0 )); then
        [[ $silent ]] || echo "✅ $kmom alla kataloger/filer finns på plats 😀."
    else
        [[ $silent ]] || echo "🚫 $kmom någon katalog/fil saknas eller har fel namn, fixa det 🔧."
        success=1
    fi

    # Kolla om rätt tagg finns
    # Räkna antalet commits
    # npx eslint
    # npx http-server och testa de routes som skall fungera
    # Kör labben och se till att den är minst 15p, visa även om det är bättre

    if [[ $silent ]]; then
        if (( success == 0)); then
            echo "✅ $kmom OK 😀."
        else
            echo "🚫 $kmom något saknas, kör en egen rapport för $kmom och fixa det 🔧."
        fi
    fi

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
    local res=

    app_$previous_kmom silent
    (( $? != 0 )) && success=2

    check_paths PATHS_KMOM03[@] || ([[ ! $silent ]] && check_paths PATHS_KMOM03[@] verbose)
    if (( $? == 0 )); then
        [[ $silent ]] || echo "✅ $kmom alla kataloger/filer finns på plats 😀."
    else
        [[ $silent ]] || echo "🚫 $kmom någon katalog/fil saknas eller har fel namn, fixa det 🔧."
        success=1
    fi

    # Kolla om rätt tagg finns
    # Räkna antalet commits
    # npx eslint
    # npx http-server och testa de routes som skall fungera
    # kontrollera att PR är korrekt gjord för kmom03
    # Kör labben och se till att den är minst 15p, visa även om det är bättre

    if [[ $silent ]]; then
        if (( success == 0)); then
            echo "✅ $kmom OK 😀."
        else
            echo "🚫 $kmom något saknas, kör en egen rapport för $kmom och fixa det 🔧."
        fi
    fi

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
