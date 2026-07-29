#!/usr/bin/env bash
# cygwin7-pkg-auto-xz-v2.sh
#
# Finds a package by name in the Windows 7-compatible Cygwin package catalog,
# downloads the exact .tar.xz archive, tests it, backs up replaced files, and
# extracts the archive directly into the current Cygwin root.

set -uo pipefail

PROGRAM=${0##*/}
SNAPSHOT_ROOT='http://ctm.crouchingtigerhiddenfruitbat.org/pub/cygwin/circa/64bit/2024/01/30/231215'
CATALOG_URL="$SNAPSHOT_ROOT/x86_64/setup.xz"
CACHE_DIR=${CYGWIN7_XZ_CACHE:-}
BACKUP_DIR=${CYGWIN7_XZ_BACKUPS:-"$HOME/cygwin7-xz-backups"}
ASSUME_YES=0
KEEP_STAGE=0
REFRESH_CATALOG=0

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

info() { printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
ok()   { printf '%s[ OK ]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
fail() { printf '%s[FAIL]%s %s\n' "$RED" "$RESET" "$*" >&2; }
die()  { fail "$*"; exit 1; }

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
  name                 Use the catalog's normal package version
  name@version-release Use a specific catalog version

Options:
  -y, --yes             Do not ask before extracting
  --keep-stage          Keep the temporary test-extraction folder
  --refresh             Download a fresh package catalog
  -h, --help            Show this help

Examples:
  $PROGRAM nano
  $PROGRAM install grep gawk nano
  $PROGRAM find nano
  $PROGRAM install nano@4.9-1
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
        warn "Detected Cygwin DLL $dll_version; this source is pinned for Cygwin 3.4.10 on Windows 7."
    fi

    command -v tar >/dev/null 2>&1 || die "tar is required."
    command -v xz >/dev/null 2>&1 || die "xz is required."
    command -v find >/dev/null 2>&1 || die "find is required."
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

    CATALOG_FILE="$CACHE_DIR/package-catalog.xz"
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

prepare_catalog() {
    if ((REFRESH_CATALOG == 1)) || [[ ! -s $CATALOG_FILE ]]; then
        info "Downloading the Windows 7 package catalog."
        download_url "$CATALOG_URL" "$CATALOG_FILE" ||
            die "Could not download the package catalog."
    else
        info "Using the cached package catalog."
    fi

    xz -t "$CATALOG_FILE" >/dev/null 2>&1 ||
        die "The package catalog is damaged. Run again with --refresh."
}

validate_package_name() {
    [[ $1 =~ ^[A-Za-z][A-Za-z0-9._+-]*$ ]]
}

validate_requested_version() {
    [[ -z $1 || $1 =~ ^[A-Za-z0-9._+~:-]+$ ]]
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

resolve_package() {
    local spec=$1
    local line current_package='' current_version='' section='normal'
    local install_data install_path install_size install_hash
    local in_target=0 found_package=0
    local fallback_path='' fallback_version='' fallback_size='' fallback_hash=''

    split_package_spec "$spec"

    RESOLVED_NAME=''
    RESOLVED_VERSION=''
    RESOLVED_PATH=''
    RESOLVED_SIZE=''
    RESOLVED_HASH=''
    RESOLVED_URL=''

    info "Looking up package: $PACKAGE_NAME"

    while IFS= read -r line || [[ -n $line ]]; do
        case $line in
            "@ "*)
                if ((in_target == 1)); then
                    break
                fi

                current_package=${line#@ }
                current_version=''
                section='normal'

                if [[ $current_package == "$PACKAGE_NAME" ]]; then
                    in_target=1
                    found_package=1
                else
                    in_target=0
                fi
                continue
                ;;
        esac

        ((in_target == 1)) || continue

        case $line in
            "[prev]")
                section='prev'
                current_version=''
                ;;
            "[test]")
                section='test'
                current_version=''
                ;;
            "[curr]")
                section='normal'
                current_version=''
                ;;
            "version: "*)
                current_version=${line#version: }
                ;;
            "install: "*)
                install_data=${line#install: }
                read -r install_path install_size install_hash _ <<< "$install_data"

                [[ -n $install_path && -n $current_version ]] || continue

                if [[ -n $REQUESTED_VERSION ]]; then
                    if [[ $current_version == "$REQUESTED_VERSION" ]]; then
                        RESOLVED_VERSION=$current_version
                        RESOLVED_PATH=$install_path
                        RESOLVED_SIZE=$install_size
                        RESOLVED_HASH=$install_hash
                        break
                    fi
                else
                    if [[ $section == normal ]]; then
                        RESOLVED_VERSION=$current_version
                        RESOLVED_PATH=$install_path
                        RESOLVED_SIZE=$install_size
                        RESOLVED_HASH=$install_hash
                        break
                    fi

                    if [[ $section == prev && -z $fallback_path ]]; then
                        fallback_version=$current_version
                        fallback_path=$install_path
                        fallback_size=$install_size
                        fallback_hash=$install_hash
                    fi
                fi
                ;;
        esac
    done < <(xz -dc "$CATALOG_FILE")

    if [[ -z $RESOLVED_PATH && -z $REQUESTED_VERSION && -n $fallback_path ]]; then
        RESOLVED_VERSION=$fallback_version
        RESOLVED_PATH=$fallback_path
        RESOLVED_SIZE=$fallback_size
        RESOLVED_HASH=$fallback_hash
    fi

    ((found_package == 1)) ||
        die "Package name was not found in the catalog: $PACKAGE_NAME"

    [[ -n $RESOLVED_PATH ]] ||
        die "Requested package version was not found: $spec"

    RESOLVED_NAME=$PACKAGE_NAME
    RESOLVED_URL="$SNAPSHOT_ROOT/$RESOLVED_PATH"
}

verify_download() {
    local archive=$1
    local expected_size=$2
    local expected_hash=$3
    local actual_size actual_hash

    if [[ $expected_size =~ ^[0-9]+$ ]]; then
        actual_size=$(wc -c < "$archive" | tr -d ' ')
        [[ $actual_size == "$expected_size" ]] ||
            die "Downloaded file size is wrong for ${archive##*/}."
        ok "File-size check passed."
    fi

    if [[ -n $expected_hash ]] && command -v sha512sum >/dev/null 2>&1; then
        actual_hash=$(sha512sum "$archive")
        actual_hash=${actual_hash%% *}

        [[ $actual_hash == "$expected_hash" ]] ||
            die "SHA-512 check failed for ${archive##*/}."
        ok "SHA-512 check passed."
    elif [[ -n $expected_hash ]]; then
        warn "sha512sum is unavailable; skipping the hash check."
    fi
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
    local timestamp backup_file list_file rel count

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
    local package_version=$2
    local archive_name=$3
    local answer

    ((ASSUME_YES == 1)) && return 0

    printf '\nPackage: %s\nVersion: %s\nArchive: %s\n' \
        "$package_name" "$package_version" "$archive_name"
    printf 'Extract this archive directly into the current Cygwin root? [y/N] '
    IFS= read -r answer

    case ${answer:-} in
        y|Y|yes|YES) return 0 ;;
        *) info "Skipped $package_name."; return 1 ;;
    esac
}

apply_archive() {
    local package_name=$1
    local package_version=$2
    local archive=$3
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

    if ! confirm_apply "$package_name" "$package_version" "$archive_name"; then
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

    ok "$package_name $package_version was extracted successfully."

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
    local archive_name destination

    resolve_package "$spec"
    archive_name=${RESOLVED_PATH##*/}
    destination="$CACHE_DIR/$archive_name"

    printf '%sResolved:%s %s %s\n' \
        "$BOLD" "$RESET" "$RESOLVED_NAME" "$RESOLVED_VERSION"
    printf '%sArchive:%s  %s\n' "$BOLD" "$RESET" "$archive_name"
    printf '%sURL:%s      %s\n' "$BOLD" "$RESET" "$RESOLVED_URL"

    if [[ -s $destination ]]; then
        info "Using the existing downloaded archive."
    else
        info "Downloading $archive_name"
        download_url "$RESOLVED_URL" "$destination" ||
            die "Download failed: $RESOLVED_URL"

        ok "Saved to: $(cygpath -w "$destination" 2>/dev/null || printf '%s' "$destination")"
    fi

    verify_download "$destination" "$RESOLVED_SIZE" "$RESOLVED_HASH"

    DOWNLOADED_PACKAGE_NAME=$RESOLVED_NAME
    DOWNLOADED_PACKAGE_VERSION=$RESOLVED_VERSION
    DOWNLOADED_ARCHIVE=$destination
}

find_packages() {
    local spec

    prepare_catalog

    for spec in "$@"; do
        resolve_package "$spec"
        printf '%s\t%s\t%s\n' \
            "$RESOLVED_NAME" "$RESOLVED_VERSION" "$RESOLVED_URL"
    done
}

install_packages() {
    local spec

    prepare_catalog

    for spec in "$@"; do
        banner
        download_package "$spec"
        apply_archive \
            "$DOWNLOADED_PACKAGE_NAME" \
            "$DOWNLOADED_PACKAGE_VERSION" \
            "$DOWNLOADED_ARCHIVE" || return $?
    done
}

interactive_menu() {
    local raw

    banner
    printf 'Enter one or more exact package names separated by spaces.\n'
    printf 'Example: grep gawk nano\n\n'
    printf 'Package name(s): '
    IFS= read -r raw

    [[ -n ${raw//[[:space:]]/} ]] ||
        die "No package name was entered."

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
            --refresh)
                REFRESH_CATALOG=1
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
