#!/usr/bin/env bash
# cygwin7-pkg-auto-xz.sh
#
# Find a Windows 7-compatible Cygwin package by name, download its .tar.xz
# archive, test it, back up replaced files, and extract it directly into /.
#
# This script intentionally uses only direct .tar.xz package archives.

set -uo pipefail

PROGRAM=${0##*/}
ARCHIVE_ROOT='http://ctm.crouchingtigerhiddenfruitbat.org/pub/cygwin/circa/64bit/2024/01/30/231215/x86_64/release'
CACHE_DIR=${CYGWIN7_XZ_CACHE:-}
BACKUP_DIR=${CYGWIN7_XZ_BACKUPS:-"$HOME/cygwin7-xz-backups"}
ASSUME_YES=0
KEEP_STAGE=0

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
ok()      { printf '%s[ OK ]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn()    { printf '%s[WARN]%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
fail()    { printf '%s[FAIL]%s %s\n' "$RED" "$RESET" "$*" >&2; }
die()     { fail "$*"; exit 1; }

banner() {
    printf '\n%s============================================================%s\n' "$BLUE" "$RESET"
    printf '%s  Cygwin 3.4 / Windows 7 Direct .tar.xz Package Tool%s\n' "$BOLD" "$RESET"
    printf '%s============================================================%s\n' "$BLUE" "$RESET"
}

usage() {
    cat <<EOF
Usage:
  $PROGRAM install PACKAGE [PACKAGE ...]
  $PROGRAM find PACKAGE [PACKAGE ...]
  $PROGRAM PACKAGE [PACKAGE ...]
  $PROGRAM

Package format:
  name                 Choose the newest .tar.xz in the Windows 7 archive
  name@version-release Choose a specific version, for example gawk@5.3.0-1

Options:
  -y, --yes             Do not ask before extracting
  --keep-stage          Keep the temporary test-extraction folder
  -h, --help            Show this help

Examples:
  $PROGRAM gawk
  $PROGRAM install grep gawk
  $PROGRAM find make
  $PROGRAM install gawk@5.3.0-1
  $PROGRAM --yes install sed

Optional environment variables:
  CYGWIN7_XZ_CACHE      Folder used for downloaded .tar.xz archives
  CYGWIN7_XZ_BACKUPS    Folder used for backups
EOF
}

require_cygwin() {
    case "$(uname -s 2>/dev/null || true)" in
        CYGWIN*) ;;
        *) die "Run this script inside a 64-bit Cygwin Bash terminal." ;;
    esac

    [[ "$(uname -m 2>/dev/null || true)" == x86_64 ]] ||
        die "This script supports only 64-bit Cygwin."

    local dll_version
    dll_version=$(uname -r 2>/dev/null || true)
    if [[ $dll_version != 3.4.10* ]]; then
        warn "Detected Cygwin DLL $dll_version; this archive is pinned for Cygwin 3.4.10 on Windows 7."
    fi

    command -v tar >/dev/null 2>&1 || die "tar is required."
    command -v xz >/dev/null 2>&1 || die "xz is required."
    command -v sed >/dev/null 2>&1 || die "sed is required."
    command -v sort >/dev/null 2>&1 || die "sort is required."
    command -v tail >/dev/null 2>&1 || die "tail is required."
    command -v mktemp >/dev/null 2>&1 || die "mktemp is required."
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

initialize_folders() {
    if [[ -z $CACHE_DIR ]]; then
        CACHE_DIR="$(windows_downloads_dir)/cygwin7-xz"
    fi
    mkdir -p "$CACHE_DIR" "$BACKUP_DIR" ||
        die "Could not create the download or backup folder."
}

download_url() {
    local url=$1
    local destination=$2
    local temporary="${destination}.part"
    local win_destination escaped_destination

    rm -f "$temporary"

    if command -v curl >/dev/null 2>&1; then
        curl --fail --location --retry 2 --connect-timeout 20 \
            --output "$temporary" "$url" || {
                rm -f "$temporary"
                return 1
            }
    elif command -v wget >/dev/null 2>&1; then
        wget --tries=3 --timeout=30 --output-document="$temporary" "$url" || {
            rm -f "$temporary"
            return 1
        }
    elif command -v powershell.exe >/dev/null 2>&1; then
        win_destination=$(cygpath -w "$temporary") || return 1
        escaped_destination=${win_destination//\'/\'\'}
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \
            "\$ErrorActionPreference='Stop'; \$client=New-Object System.Net.WebClient; \$client.DownloadFile('$url','$escaped_destination')" \
            >/dev/null 2>&1 || {
                rm -f "$temporary"
                return 1
            }
    else
        die "A downloader is required: curl, wget, or Windows PowerShell."
    fi

    [[ -s $temporary ]] || {
        rm -f "$temporary"
        return 1
    }

    mv -f "$temporary" "$destination"
}

fetch_text() {
    local url=$1
    local destination=$2
    download_url "$url" "$destination"
}

validate_package_name() {
    [[ $1 =~ ^[A-Za-z][A-Za-z0-9._+-]*$ ]]
}

validate_requested_version() {
    [[ -z $1 || $1 =~ ^[A-Za-z0-9._+~-]+$ ]]
}

split_package_spec() {
    local spec=$1

    if [[ $spec == *@* ]]; then
        PACKAGE_NAME=${spec%%@*}
        REQUESTED_VERSION=${spec#*@}
    else
        PACKAGE_NAME=$spec
        REQUESTED_VERSION=''
    fi

    validate_package_name "$PACKAGE_NAME" ||
        die "Invalid package name: $PACKAGE_NAME"
    validate_requested_version "$REQUESTED_VERSION" ||
        die "Invalid requested version: $REQUESTED_VERSION"
}

extract_tar_xz_links() {
    local html_file=$1

    # Apache-style directory pages place one href on each line.
    # This returns only .tar.xz link targets and does not require grep or awk.
    sed -n \
        -e 's/.*[Hh][Rr][Ee][Ff]="\([^"]*\.tar\.xz\)".*/\1/p' \
        -e "s/.*[Hh][Rr][Ee][Ff]='\([^']*\.tar\.xz\)'.*/\1/p" \
        "$html_file"
}

resolve_package() {
    local spec=$1
    local temp_dir index_file directory_url href filename
    local version_part selected=''
    local -a candidates=()

    split_package_spec "$spec"
    directory_url="$ARCHIVE_ROOT/$PACKAGE_NAME"
    temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/cygwin7-resolve.XXXXXX") ||
        die "Could not create a temporary folder."
    index_file="$temp_dir/index.html"

    info "Searching the Windows 7 archive for: $PACKAGE_NAME"

    if ! fetch_text "$directory_url/" "$index_file"; then
        rm -rf "$temp_dir"
        die "Package folder not found: $PACKAGE_NAME"
    fi

    while IFS= read -r href; do
        href=${href%%\?*}
        filename=${href##*/}

        case $filename in
            "$PACKAGE_NAME"-*.tar.xz) ;;
            *) continue ;;
        esac

        case $filename in
            *-src.tar.xz|*-debuginfo-*.tar.xz|*-debuginfo.tar.xz)
                continue
                ;;
        esac

        if [[ -n $REQUESTED_VERSION ]]; then
            version_part=${filename#"$PACKAGE_NAME"-}
            version_part=${version_part%.tar.xz}
            version_part=${version_part%-x86_64}
            [[ $version_part == "$REQUESTED_VERSION" ]] || continue
        fi

        candidates+=("$filename")
    done < <(extract_tar_xz_links "$index_file")

    rm -rf "$temp_dir"

    ((${#candidates[@]} > 0)) ||
        die "No compatible .tar.xz archive was found for: $spec"

    if ((${#candidates[@]} == 1)); then
        selected=${candidates[0]}
    else
        selected=$(printf '%s\n' "${candidates[@]}" | LC_ALL=C sort -V | tail -n 1)
    fi

    RESOLVED_NAME=$PACKAGE_NAME
    RESOLVED_FILE=$selected
    RESOLVED_URL="$directory_url/$selected"
    RESOLVED_DIR_URL=$directory_url
}

verify_sha512_when_available() {
    local package_dir_url=$1
    local archive_file=$2
    local archive_name=$3
    local checksum_file expected='' hash listed_name actual

    command -v sha512sum >/dev/null 2>&1 || {
        warn "sha512sum is unavailable; skipping checksum comparison."
        return 0
    }

    checksum_file=$(mktemp "${TMPDIR:-/tmp}/cygwin7-sha.XXXXXX") ||
        return 0

    if ! fetch_text "$package_dir_url/sha512.sum" "$checksum_file"; then
        rm -f "$checksum_file"
        warn "No checksum list was available for $archive_name."
        return 0
    fi

    while read -r hash listed_name _; do
        listed_name=${listed_name#\*}
        listed_name=${listed_name#./}
        if [[ $listed_name == "$archive_name" ]]; then
            expected=$hash
            break
        fi
    done < "$checksum_file"

    rm -f "$checksum_file"

    if [[ -z $expected ]]; then
        warn "The checksum list did not contain $archive_name."
        return 0
    fi

    actual=$(sha512sum "$archive_file" | {
        read -r value _
        printf '%s\n' "$value"
    })

    [[ $actual == "$expected" ]] ||
        die "SHA-512 comparison failed for $archive_name."

    ok "SHA-512 comparison passed."
}

check_archive_paths() {
    local archive=$1
    local entry clean

    while IFS= read -r entry; do
        clean=${entry#./}

        [[ -n $clean ]] || continue

        case $clean in
            /*|../*|*/../*|*/..)
                die "Unsafe archive path detected: $entry"
                ;;
        esac
    done < <(tar -tJf "$archive") ||
        die "Could not read the archive."
}

make_backup() {
    local stage_dir=$1
    local package_label=$2
    local timestamp backup_file list_file rel
    local count=0

    timestamp=$(date '+%Y%m%d-%H%M%S')
    backup_file="$BACKUP_DIR/${package_label}-${timestamp}-backup.tar.gz"
    list_file=$(mktemp "${TMPDIR:-/tmp}/cygwin7-backup-list.XXXXXX") ||
        die "Could not create a backup list."

    (
        cd "$stage_dir" || exit 1
        find . \( -type f -o -type l \) -print
    ) | while IFS= read -r rel; do
        rel=${rel#./}
        if [[ -e "/$rel" || -L "/$rel" ]]; then
            printf '%s\n' "$rel"
        fi
    done > "$list_file"

    if [[ -s $list_file ]]; then
        count=$(wc -l < "$list_file" | tr -d ' ')
        info "Backing up $count existing file(s)."
        tar -czpf "$backup_file" -C / -T "$list_file" ||
            die "Could not create the backup."
        LAST_BACKUP=$backup_file
        ok "Backup created: $(cygpath -w "$backup_file" 2>/dev/null || printf '%s' "$backup_file")"
    else
        LAST_BACKUP=''
        info "No existing files need to be backed up."
    fi

    rm -f "$list_file"
}

confirm_apply() {
    local package_name=$1
    local archive_name=$2
    local answer

    ((ASSUME_YES == 1)) && return 0

    printf '\nPackage: %s\nArchive: %s\n' "$package_name" "$archive_name"
    printf 'Extract this archive directly into the current Cygwin root? [y/N] '
    IFS= read -r answer

    case ${answer:-} in
        y|Y|yes|YES) return 0 ;;
        *) info "Skipped $package_name."; return 1 ;;
    esac
}

apply_archive() {
    local package_name=$1
    local archive=$2
    local archive_name=${archive##*/}
    local stage_dir

    tar -tJf "$archive" >/dev/null 2>&1 ||
        die "The downloaded file is not a readable .tar.xz archive: $archive_name"

    check_archive_paths "$archive"

    stage_dir=$(mktemp -d "${TMPDIR:-/tmp}/cygwin7-stage.XXXXXX") ||
        die "Could not create a test-extraction folder."

    info "Testing a complete extraction first."
    if ! tar -xJpf "$archive" -C "$stage_dir"; then
        rm -rf "$stage_dir"
        die "Test extraction failed. Nothing was changed in the Cygwin root."
    fi
    ok "Test extraction passed."

    if ! confirm_apply "$package_name" "$archive_name"; then
        ((KEEP_STAGE == 1)) || rm -rf "$stage_dir"
        return 0
    fi

    make_backup "$stage_dir" "$package_name"

    info "Extracting $archive_name into /"
    if ! tar -xJpf "$archive" -C /; then
        fail "Extraction failed after it began."
        if [[ -n ${LAST_BACKUP:-} ]]; then
            warn "Restore the backup with:"
            printf 'tar -xzpf %q -C /\n' "$LAST_BACKUP" >&2
        fi
        ((KEEP_STAGE == 1)) || rm -rf "$stage_dir"
        return 1
    fi

    ok "$package_name was extracted successfully."

    if [[ -n ${LAST_BACKUP:-} ]]; then
        printf 'Restore command: tar -xzpf %q -C /\n' "$LAST_BACKUP"
    fi

    if ((KEEP_STAGE == 1)); then
        info "Test-extraction folder kept at: $stage_dir"
    else
        rm -rf "$stage_dir"
    fi
}

download_package() {
    local spec=$1
    local destination

    resolve_package "$spec"

    printf '%sResolved:%s %s\n' "$BOLD" "$RESET" "$RESOLVED_FILE"
    printf '%sURL:%s      %s\n' "$BOLD" "$RESET" "$RESOLVED_URL"

    destination="$CACHE_DIR/$RESOLVED_FILE"

    if [[ -s $destination ]]; then
        info "Using the existing downloaded archive."
    else
        info "Downloading $RESOLVED_FILE"
        download_url "$RESOLVED_URL" "$destination" ||
            die "Download failed: $RESOLVED_URL"
        ok "Saved to: $(cygpath -w "$destination" 2>/dev/null || printf '%s' "$destination")"
    fi

    verify_sha512_when_available "$RESOLVED_DIR_URL" "$destination" "$RESOLVED_FILE"
    DOWNLOADED_PACKAGE_NAME=$RESOLVED_NAME
    DOWNLOADED_ARCHIVE=$destination
}

find_packages() {
    local spec
    for spec in "$@"; do
        resolve_package "$spec"
        printf '%s\t%s\n' "$RESOLVED_NAME" "$RESOLVED_URL"
    done
}

install_packages() {
    local spec
    for spec in "$@"; do
        banner
        download_package "$spec"
        apply_archive "$DOWNLOADED_PACKAGE_NAME" "$DOWNLOADED_ARCHIVE" || return $?
    done
}

interactive_menu() {
    local raw
    banner
    printf 'Enter one or more exact package names separated by spaces.\n'
    printf 'Example: grep gawk sed\n\n'
    printf 'Package name(s): '
    IFS= read -r raw

    [[ -n ${raw//[[:space:]]/} ]] || die "No package name was entered."

    # Intentional word splitting for the interactive package list.
    # shellcheck disable=SC2086
    install_packages $raw
}

main() {
    local command='install'
    local -a packages=()

    require_cygwin
    initialize_folders

    while (($# > 0)); do
        case $1 in
            -y|--yes)
                ASSUME_YES=1
                shift
                ;;
            --keep-stage)
                KEEP_STAGE=1
                shift
                ;;
            -h|--help|help)
                usage
                exit 0
                ;;
            install|find)
                command=$1
                shift
                break
                ;;
            --)
                shift
                break
                ;;
            -*)
                usage >&2
                die "Unknown option: $1"
                ;;
            *)
                break
                ;;
        esac
    done

    while (($# > 0)); do
        packages+=("$1")
        shift
    done

    if ((${#packages[@]} == 0)); then
        interactive_menu
        exit $?
    fi

    case $command in
        find) find_packages "${packages[@]}" ;;
        install) install_packages "${packages[@]}" ;;
    esac
}

main "$@"
