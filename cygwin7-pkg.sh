#!/usr/bin/env bash
# cygwin7-pkg.sh
# Install packages into a 64-bit Cygwin 3.4.10 installation on Windows 7
# using the Windows-7-compatible Cygwin Time Machine snapshot documented by
# the Cygwin project.
#
# This script uses Cygwin's official setup-x86_64.exe so dependencies and the
# installed-package database are handled correctly. It does NOT use current
# Cygwin mirrors and does NOT pass --upgrade-also.

set -uo pipefail

PROGRAM_NAME=${0##*/}
SNAPSHOT_SITE='http://ctm.crouchingtigerhiddenfruitbat.org/pub/cygwin/circa/64bit/2024/01/30/231215'
SETUP_DOWNLOAD_URL='https://cygwin.com/setup-x86_64.exe'
CACHE_DIR="${CYGWIN7_CACHE_DIR:-$HOME/.cache/cygwin7-setup}"
LOG_DIR="${CYGWIN7_LOG_DIR:-$HOME/cygwin7-package-logs}"
SETUP_EXE=${CYGWIN_SETUP_EXE:-}

if [[ -t 1 && ${TERM:-dumb} != dumb ]]; then
    BOLD=$'\033[1m'
    BLUE=$'\033[1;34m'
    GREEN=$'\033[1;32m'
    YELLOW=$'\033[1;33m'
    RED=$'\033[1;31m'
    RESET=$'\033[0m'
else
    BOLD='' BLUE='' GREEN='' YELLOW='' RED='' RESET=''
fi

info()    { printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
success() { printf '%s[ OK ]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn()    { printf '%s[WARN]%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
error()   { printf '%s[FAIL]%s %s\n' "$RED" "$RESET" "$*" >&2; }
die()     { error "$*"; exit 1; }

pause() {
    printf '\nPress Enter to continue...'
    IFS= read -r _
}

banner() {
    printf '\n%s============================================================%s\n' "$BLUE" "$RESET"
    printf '%s  Cygwin 3.4 / Windows 7 Package Installer%s\n' "$BOLD" "$RESET"
    printf '%s============================================================%s\n' "$BLUE" "$RESET"
}

usage() {
    cat <<USAGE
Usage:
  $PROGRAM_NAME                    Open the interactive menu
  $PROGRAM_NAME install PKG...     Install one or more exact package names
  $PROGRAM_NAME gui                Open Cygwin Setup's searchable chooser
  $PROGRAM_NAME status PKG...      Show installed status/version
  $PROGRAM_NAME config             Show detected configuration

Examples:
  $PROGRAM_NAME install make gcc-g++
  $PROGRAM_NAME install "grep,gawk,sed"
  $PROGRAM_NAME status grep gawk

Optional environment variables:
  CYGWIN_SETUP_EXE       Path to setup-x86_64.exe
  CYGWIN7_CACHE_DIR      Package-download cache directory
  CYGWIN7_LOG_DIR        Setup log directory
USAGE
}

require_cygwin() {
    case "$(uname -s 2>/dev/null || true)" in
        CYGWIN*) ;;
        *) die "Run this script inside a Cygwin Bash terminal." ;;
    esac

    if [[ "$(uname -m 2>/dev/null || true)" != x86_64 ]]; then
        die "This script supports only 64-bit Cygwin."
    fi

    local version
    version=$(uname -r 2>/dev/null || true)
    if [[ $version != 3.4.10* ]]; then
        warn "Detected Cygwin DLL $version; this script is designed for 3.4.10 on Windows 7."
        printf 'Continue anyway? [y/N] '
        IFS= read -r answer
        case ${answer:-} in y|Y|yes|YES) ;; *) exit 1 ;; esac
    fi
}

windows_downloads_dir() {
    local win_profile posix_profile
    win_profile=$(cmd.exe /d /c "echo %USERPROFILE%" 2>/dev/null || true)
    win_profile=${win_profile//$'\r'/}
    if [[ -n $win_profile ]]; then
        posix_profile=$(cygpath -u "$win_profile" 2>/dev/null || true)
        if [[ -n $posix_profile ]]; then
            printf '%s/Downloads\n' "$posix_profile"
            return
        fi
    fi
    printf '%s/Downloads\n' "$HOME"
}

normalize_setup_path() {
    local input=$1
    input=${input#\"}
    input=${input%\"}
    if [[ $input == *:\\* || $input == *:/* ]]; then
        cygpath -u "$input" 2>/dev/null || printf '%s\n' "$input"
    else
        printf '%s\n' "$input"
    fi
}

find_setup() {
    local downloads candidate
    downloads=$(windows_downloads_dir)

    if [[ -n ${SETUP_EXE:-} ]]; then
        SETUP_EXE=$(normalize_setup_path "$SETUP_EXE")
        [[ -f $SETUP_EXE ]] && return 0
    fi

    for candidate in \
        '/cygdrive/c/tools/cygwin_setup/setup-x86_64.exe' \
        "$downloads/setup-x86_64.exe" \
        "$HOME/Downloads/setup-x86_64.exe" \
        "$PWD/setup-x86_64.exe" \
        '/cygdrive/c/cygwin64/setup-x86_64.exe'
    do
        if [[ -f $candidate ]]; then
            SETUP_EXE=$candidate
            return 0
        fi
    done
    return 1
}

download_setup() {
    local downloads target target_win ps_target
    downloads=$(windows_downloads_dir)
    mkdir -p "$downloads" || return 1
    target="$downloads/setup-x86_64.exe"

    info "Downloading setup-x86_64.exe from cygwin.com..."
    if command -v curl >/dev/null 2>&1; then
        curl --fail --location --retry 2 --connect-timeout 20 \
            --output "$target.part" "$SETUP_DOWNLOAD_URL" || return 1
        mv -f "$target.part" "$target" || return 1
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$target.part" "$SETUP_DOWNLOAD_URL" || return 1
        mv -f "$target.part" "$target" || return 1
    elif command -v powershell.exe >/dev/null 2>&1; then
        target_win=$(cygpath -w "$target")
        ps_target=${target_win//\'/\'\'}
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \
            "\$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('$SETUP_DOWNLOAD_URL','$ps_target')" \
            || return 1
    else
        warn "No curl, wget, or PowerShell downloader was found."
        if command -v cygstart >/dev/null 2>&1; then
            info "Opening the official download in your browser."
            cygstart "$SETUP_DOWNLOAD_URL"
            printf 'Save setup-x86_64.exe in your Downloads folder, then press Enter...'
            IFS= read -r _
        else
            return 1
        fi
    fi

    [[ -s $target ]] || return 1
    SETUP_EXE=$target
    success "Installer saved at $(cygpath -w "$SETUP_EXE")"
}

prompt_for_setup() {
    local answer entered
    while ! find_setup; do
        warn "setup-x86_64.exe was not found."
        printf '\n1) Download the official installer now\n'
        printf '2) Enter its existing path\n'
        printf '3) Exit\n'
        printf 'Choose [1-3]: '
        IFS= read -r answer
        case $answer in
            1)
                download_setup || warn "Automatic download failed. Use Firefox to download $SETUP_DOWNLOAD_URL"
                ;;
            2)
                printf 'Enter the full path to setup-x86_64.exe: '
                IFS= read -r entered
                SETUP_EXE=$(normalize_setup_path "$entered")
                [[ -f $SETUP_EXE ]] || { warn "That file does not exist."; SETUP_EXE=''; }
                ;;
            3) exit 0 ;;
            *) warn "Choose 1, 2, or 3." ;;
        esac
    done
}

setup_supports() {
    local needle=$1
    [[ ${SETUP_HELP:-} == *"$needle"* ]]
}

prepare_setup() {
    prompt_for_setup
    SETUP_HELP=$("$SETUP_EXE" --help 2>&1 || true)
    [[ -n $SETUP_HELP ]] || warn "Could not read Setup help; using widely supported options only."
    mkdir -p "$CACHE_DIR" "$LOG_DIR" || die "Could not create cache or log directories."
}

build_common_options() {
    local root_win cache_win
    root_win=$(cygpath -w /) || die "Could not determine the Cygwin root."
    cache_win=$(cygpath -w "$CACHE_DIR") || die "Could not convert the cache path."

    COMMON_OPTIONS=(
        --root "$root_win"
        --local-package-dir "$cache_win"
        --site "$SNAPSHOT_SITE"
        --no-verify
        --only-site
    )

    setup_supports '--allow-unsupported-windows' && COMMON_OPTIONS+=(--allow-unsupported-windows)
    setup_supports '--no-version-check' && COMMON_OPTIONS+=(--no-version-check)
    setup_supports '--wait' && COMMON_OPTIONS+=(--wait)
    setup_supports '--no-desktop' && COMMON_OPTIONS+=(--no-desktop)
    setup_supports '--no-startmenu' && COMMON_OPTIONS+=(--no-startmenu)
    setup_supports '--no-shortcuts' && COMMON_OPTIONS+=(--no-shortcuts)
}

validate_package_name() {
    [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]]
}

collect_packages() {
    local raw item
    COLLECTED_PACKAGES=()
    for raw in "$@"; do
        raw=${raw//,/ }
        for item in $raw; do
            validate_package_name "$item" || die "Invalid package name: $item"
            COLLECTED_PACKAGES+=("$item")
        done
    done
    ((${#COLLECTED_PACKAGES[@]} > 0)) || die "No package names were supplied."
}

join_packages() {
    local output='' item
    for item in "$@"; do
        if [[ -n $output ]]; then output+=','; fi
        output+=$item
    done
    printf '%s\n' "$output"
}

run_setup() {
    local action=$1
    shift
    local timestamp log_file rc
    timestamp=$(date '+%Y%m%d-%H%M%S')
    log_file="$LOG_DIR/setup-$action-$timestamp.log"

    info "Installer: $(cygpath -w "$SETUP_EXE")"
    info "Cygwin root: $(cygpath -w /)"
    info "Snapshot: $SNAPSHOT_SITE"
    info "Log: $(cygpath -w "$log_file")"
    warn "A Windows administrator/UAC prompt may appear."
    warn "Close other Cygwin terminals before installing core libraries or shells."
    printf '\n'

    "$SETUP_EXE" "$@" > >(tee -a "$log_file") 2> >(tee -a "$log_file" >&2)
    rc=$?
    if ((rc == 0)); then
        success "Cygwin Setup finished successfully."
    else
        error "Cygwin Setup exited with code $rc. See the log above."
    fi
    return "$rc"
}

install_packages() {
    local csv answer package
    collect_packages "$@"
    prepare_setup
    build_common_options
    csv=$(join_packages "${COLLECTED_PACKAGES[@]}")

    banner
    printf '%sPackages requested:%s %s\n' "$BOLD" "$RESET" "$csv"
    printf 'Install them and their required dependencies? [y/N] '
    IFS= read -r answer
    case ${answer:-} in
        y|Y|yes|YES) ;;
        *) info "Cancelled."; return 0 ;;
    esac

    # Deliberately omit --upgrade-also so unrelated installed packages are not upgraded.
    run_setup install \
        "${COMMON_OPTIONS[@]}" \
        --quiet-mode \
        --packages "$csv" || return $?

    printf '\n%sInstalled-package check:%s\n' "$BOLD" "$RESET"
    for package in "${COLLECTED_PACKAGES[@]}"; do
        cygcheck -c "$package" 2>/dev/null || true
    done
    warn "Restart Cygwin before using newly installed DLLs or shell components."
}

open_chooser() {
    prepare_setup
    build_common_options
    banner
    info "Opening the package chooser against the Windows 7 snapshot."
    info "Use the Search box, select package versions, and keep the top-right mode on Keep."
    run_setup chooser "${COMMON_OPTIONS[@]}" --package-manager
}

status_packages() {
    local package
    collect_packages "$@"
    for package in "${COLLECTED_PACKAGES[@]}"; do
        printf '\n%s%s%s\n' "$BOLD" "$package" "$RESET"
        cygcheck -c "$package" 2>/dev/null || true
    done
}

show_config() {
    find_setup || true
    banner
    printf '%-22s %s\n' 'Cygwin DLL:' "$(uname -r 2>/dev/null || echo unknown)"
    printf '%-22s %s\n' 'Architecture:' "$(uname -m 2>/dev/null || echo unknown)"
    printf '%-22s %s\n' 'Cygwin root:' "$(cygpath -w / 2>/dev/null || echo unknown)"
    printf '%-22s %s\n' 'Setup executable:' "${SETUP_EXE:+$(cygpath -w "$SETUP_EXE" 2>/dev/null)}"
    [[ -n ${SETUP_EXE:-} ]] || printf '%-22s %s\n' '' '(not found yet)'
    printf '%-22s %s\n' 'Package snapshot:' "$SNAPSHOT_SITE"
    printf '%-22s %s\n' 'Download cache:' "$(cygpath -w "$CACHE_DIR" 2>/dev/null || echo "$CACHE_DIR")"
    printf '%-22s %s\n' 'Logs:' "$(cygpath -w "$LOG_DIR" 2>/dev/null || echo "$LOG_DIR")"
}

interactive_menu() {
    local choice raw
    while true; do
        banner
        printf '1) Install package(s) by exact name\n'
        printf '2) Open searchable graphical package chooser\n'
        printf '3) Check an installed package/version\n'
        printf '4) Show configuration\n'
        printf '5) Exit\n\n'
        printf 'Choose [1-5]: '
        IFS= read -r choice
        case $choice in
            1)
                printf 'Package names (spaces or commas), for example: make gcc-g++: '
                IFS= read -r raw
                # Intentional word splitting to turn the interactive entry into arguments.
                # shellcheck disable=SC2086
                install_packages $raw
                pause
                ;;
            2)
                open_chooser
                pause
                ;;
            3)
                printf 'Package names (spaces or commas): '
                IFS= read -r raw
                # shellcheck disable=SC2086
                status_packages $raw
                pause
                ;;
            4)
                show_config
                pause
                ;;
            5) printf 'Goodbye.\n'; return 0 ;;
            *) warn "Choose 1, 2, 3, 4, or 5."; pause ;;
        esac
    done
}

main() {
    require_cygwin
    case ${1:-} in
        '') interactive_menu ;;
        install)
            shift
            install_packages "$@"
            ;;
        gui)
            shift
            open_chooser
            ;;
        status)
            shift
            status_packages "$@"
            ;;
        config)
            shift
            show_config
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            usage >&2
            die "Unknown command: $1"
            ;;
    esac
}

main "$@"
