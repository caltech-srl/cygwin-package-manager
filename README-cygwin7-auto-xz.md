# Cygwin 3.4 / Windows 7 Direct `.tar.xz` Package Tool

`cygwin7-pkg-auto-xz.sh` lets you type a package name such as `gawk`, `grep`, or `sed`. It then:

1. Searches the pinned Windows 7-compatible Cygwin archive.
2. Finds the newest matching binary `.tar.xz` file.
3. Downloads that archive automatically.
4. Checks the archive and compares its SHA-512 value when a checksum list is available.
5. Performs a complete test extraction in a temporary folder.
6. Backs up files that would be replaced.
7. Extracts the entire `.tar.xz` archive directly into the current Cygwin root.

This is the same direct archive approach used to replace `gawk`: download the compatible `.tar.xz` package and extract its complete contents. A full extraction also handles packages in which an ordinary command name is a hard link to a versioned file.

## What it does not use

The tool uses direct `.tar.xz` package downloads and `tar -xJf`. It does not launch or depend on any separate Windows package-management program.

## Compatibility target

The package source is pinned to the archived 64-bit package collection from January 30, 2024, intended for Cygwin 3.4.10 on Windows 7.

The script warns when the detected Cygwin DLL is not 3.4.10.

## Requirements

Run it from a **64-bit Cygwin Bash terminal**. These commands must already work:

```text
bash
tar
xz
sed
sort
tail
find
mktemp
```

For downloading, at least one of these must be available:

```text
curl
wget
Windows PowerShell
```

You also need permission to write into your Cygwin root, normally `C:\cygwin64`.

## Put the files in Downloads

Keep these two files together in your Windows Downloads folder:

```text
cygwin7-pkg-auto-xz.sh
README-cygwin7-auto-xz.md
```

## First-time preparation

Open Cygwin and enter:

```bash
WIN_DOWNLOADS="$(cygpath -u "$(cmd.exe /d /c 'echo %USERPROFILE%' | tr -d '\r')")/Downloads"
cd "$WIN_DOWNLOADS"
chmod +x cygwin7-pkg-auto-xz.sh
```

## Easiest use

Run:

```bash
./cygwin7-pkg-auto-xz.sh
```

Type one or more exact package names:

```text
gawk
```

or:

```text
grep gawk sed
```

The script finds the matching `.tar.xz` file and asks before extracting it.

## Install directly by package name

```bash
./cygwin7-pkg-auto-xz.sh gawk
```

The following form does the same thing:

```bash
./cygwin7-pkg-auto-xz.sh install gawk
```

Install several packages in order:

```bash
./cygwin7-pkg-auto-xz.sh install grep gawk sed
```

## Find the archive without extracting it

```bash
./cygwin7-pkg-auto-xz.sh find gawk
```

This prints the exact `.tar.xz` URL selected for the package.

## Request a specific version

Use `name@version-release`:

```bash
./cygwin7-pkg-auto-xz.sh install gawk@5.3.0-1
```

The version must exist in the pinned archive.

## Skip the confirmation question

```bash
./cygwin7-pkg-auto-xz.sh --yes install gawk
```

## Keep the temporary test-extraction folder

```bash
./cygwin7-pkg-auto-xz.sh --keep-stage install gawk
```

## Where downloads and backups are stored

Downloaded package archives are saved under:

```text
C:\Users\YOUR_WINDOWS_NAME\Downloads\cygwin7-xz
```

Backups are saved under:

```bash
~/cygwin7-xz-backups
```

You can change these folders:

```bash
export CYGWIN7_XZ_CACHE="$HOME/package-downloads"
export CYGWIN7_XZ_BACKUPS="$HOME/package-backups"
```

## Backup restoration

After a successful extraction, the script prints a restore command resembling:

```bash
tar -xzpf "$HOME/cygwin7-xz-backups/gawk-DATE-TIME-backup.tar.gz" -C /
```

Run the printed command to restore files that existed before the package was extracted.

A backup contains only files that were replaced. Newly added package files are not removed by restoring that backup.

## Package selection rules

For a package such as `gawk`, the script opens the corresponding package directory in the pinned archive and selects binary files matching:

```text
gawk-*.tar.xz
```

It excludes source and debugging archives. When several binary versions exist, it chooses the newest filename using version sorting.

## Dependencies

The script finds and extracts the package you name. It does **not** automatically determine or install dependency packages.

When a command reports a missing Cygwin DLL after extraction, install the package that provides that DLL using the same command pattern:

```bash
./cygwin7-pkg-auto-xz.sh install DEPENDENCY_PACKAGE_NAME
```

Install dependency packages before retrying the main command.

## Important limitations

Direct archive extraction does not maintain a complete package ownership database and does not automatically perform package-specific configuration actions.

Avoid replacing components actively used by the running shell, particularly the Cygwin DLL, Bash, `tar`, or `xz`. Replacing a running core component can leave the current environment unusable.

The tool can only find packages whose binary `.tar.xz` archive exists under its exact package-name directory in the pinned archive. It reports a clear error when no matching archive is found.

## Troubleshooting

### `Package folder not found`

Confirm that the package name is exact:

```bash
./cygwin7-pkg-auto-xz.sh find gawk
```

Package names are case-sensitive on the archive. Use lowercase unless the package is officially named otherwise.

### `No compatible .tar.xz archive was found`

The package folder exists, but it has no matching binary `.tar.xz` file in the pinned archive. It may use a different package name or may not have existed in that snapshot.

### `Download failed`

Check internet access and verify that one downloader works:

```bash
curl --version
```

or:

```bash
wget --version
```

When neither is present, the script tries Windows PowerShell automatically.

### `Permission denied`

Close other Cygwin windows and reopen Cygwin with sufficient permission to write into `C:\cygwin64`.

### A newly extracted command reports a missing DLL

The main archive was extracted, but a required library package is absent or incompatible. Extract the matching Windows 7-compatible dependency package by name, then test the command again.

## View built-in help

```bash
./cygwin7-pkg-auto-xz.sh --help
```
