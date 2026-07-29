# Cygwin 3.4 / Windows 7 Direct Archive Package Tool

`cygwin7-pkg.sh` downloads and installs Cygwin package archives directly into an existing **64-bit Cygwin 3.4.10 installation on Windows 7**.

It does **not** launch, download, or depend on `setup-x86_64.exe`.

The tool reads package names, versions, dependencies, archive locations, sizes, and SHA-512 hashes from the pinned Windows 7-compatible Cygwin snapshot. It then downloads the exact archive selected by that snapshot—normally a `.tar.xz` file—verifies it, extracts it into the Cygwin root, runs its post-install scripts, and updates `/etc/setup` records.

## Important warning

Cygwin officially recommends its normal Setup program for package management. Cygwin's packaging documentation states that there is no official standalone tool for directly installing package archives; manually extracting packages is mainly described as a testing technique.

This script automates direct extraction as carefully as practical, but it cannot reproduce every safety feature of the official package manager. Use it for ordinary utilities such as `grep`, `gawk`, `sed`, `make`, and similar packages—not for replacing the live Cygwin runtime.

The script refuses to replace these core packages while running inside Cygwin:

```text
cygwin bash coreutils tar xz liblzma5 gzip
```

Replacing `cygwin1.dll`, the active shell, or a loaded runtime DLL from the same running Cygwin session is unsafe.

## What it does

The script:

- Uses the Cygwin 3.4.10 Windows 7 snapshot dated January 30, 2024.
- Downloads `x86_64/setup.xz` directly from the snapshot.
- Builds a local searchable package index.
- Resolves package dependencies.
- Downloads exact package archives without using the Cygwin installer.
- Tries the pinned snapshot first.
- Tries an official Cygwin mirror only for the same exact archive if the snapshot download fails.
- Verifies package size and SHA-512 against the pinned snapshot metadata.
- Extracts the complete archive into `/`.
- Preserves hard links and symbolic links through Cygwin `tar`.
- Runs package-provided post-install scripts.
- Writes `/etc/setup/PACKAGE.lst.gz`.
- Updates `/etc/setup/installed.db`.
- Backs up files recorded for an existing package before replacement.
- Provides interactive and command-line modes.

## What it does not do

The script does not:

- Use `setup-x86_64.exe`.
- Upgrade unrelated installed packages.
- Safely replace the running Cygwin DLL or other loaded core files.
- Remove every stale file left by an older package version.
- Provide a complete uninstall operation.
- Cryptographically authenticate the downloaded `setup.xz` catalogue.
- Guarantee support for packages that require complicated service registration or Windows-specific installer actions.

Package archives are checked against the SHA-512 values in the downloaded catalogue. This detects damaged or mismatched package files. However, because the historical snapshot metadata is fetched over HTTP and is not signature-verified by Cygwin Setup, the check is not equivalent to the official installer's trust model.

## Requirements

You need:

- Windows 7 64-bit.
- An existing 64-bit Cygwin installation.
- Cygwin DLL version 3.4.10.
- Bash.
- `tar`, `xz`, and `gzip`.
- One downloader:
  - `curl`, or
  - `wget`, or
  - Windows PowerShell.
- Permission to write to the Cygwin root and `/etc/setup`.

Check your Cygwin version:

```bash
uname -r
```

The expected result begins with:

```text
3.4.10
```

Check the required commands:

```bash
command -v tar xz gzip
```

## Installation

Download these two files into the same folder:

```text
cygwin7-pkg.sh
README.md
```

Open a Cygwin terminal and go to the folder. For example:

```bash
cd ~/Downloads
```

Make the script executable:

```bash
chmod +x cygwin7-pkg.sh
```

Display its configuration:

```bash
./cygwin7-pkg.sh config
```

## Interactive mode

Run the script without arguments:

```bash
./cygwin7-pkg.sh
```

The menu provides these choices:

```text
1) Download and install package(s)
2) Download package archive(s) only
3) Search the Windows 7 package snapshot
4) Show package information
5) Check installed/snapshot versions
6) Refresh package catalogue
7) Show configuration
8) Exit
```

For installation, enter exact Cygwin package names separated by spaces or commas:

```text
grep gawk sed
```

## Common commands

### Install one package

```bash
./cygwin7-pkg.sh install grep
```

### Install several packages

```bash
./cygwin7-pkg.sh install gawk sed make
```

Comma-separated names also work:

```bash
./cygwin7-pkg.sh install "grep,gawk,sed"
```

### Install without dependencies

This most closely resembles manually downloading one archive and copying its files:

```bash
./cygwin7-pkg.sh install --no-deps grep
```

Use this only when the package's required libraries are already installed.

### Download without installing

```bash
./cygwin7-pkg.sh download gawk
```

The archive is saved under:

```text
~/.cache/cygwin7-direct/packages/
```

### Search for package names

```bash
./cygwin7-pkg.sh search awk
```

Search descriptions too:

```bash
./cygwin7-pkg.sh search "text processing"
```

### Show package details

```bash
./cygwin7-pkg.sh info gawk
```

This shows the snapshot version, installed version, archive path, category, description, and dependencies.

### Compare installed and snapshot versions

```bash
./cygwin7-pkg.sh status grep gawk
```

### Reinstall a matching version

```bash
./cygwin7-pkg.sh install --force grep
```

### Preview without changing anything

```bash
./cygwin7-pkg.sh install --dry-run make
```

### Refresh package metadata

```bash
./cygwin7-pkg.sh refresh
```

Or refresh immediately before an operation:

```bash
./cygwin7-pkg.sh install --refresh sed
```

## Dependency behavior

The default behavior is intentionally conservative:

- Requested packages are installed at the version selected by the Windows 7 snapshot.
- Missing dependencies are downloaded and installed.
- A dependency that is already installed is left alone, even when its version differs from the snapshot.
- Unrelated packages are never changed.

This reduces the chance of unexpectedly replacing many existing libraries.

To synchronize dependency versions with the Windows 7 snapshot, use:

```bash
./cygwin7-pkg.sh install --sync-deps PACKAGE
```

For example:

```bash
./cygwin7-pkg.sh install --sync-deps make
```

Review the plan carefully. Synchronizing dependencies can downgrade or replace libraries used by other programs. The script still refuses to replace designated live core packages.

To ignore dependency resolution completely:

```bash
./cygwin7-pkg.sh install --no-deps PACKAGE
```

## Options

| Option | Meaning |
|---|---|
| `-y`, `--yes` | Continue without the confirmation prompt |
| `-f`, `--force` | Reinstall explicitly requested packages even when the version matches |
| `--no-deps` | Do not resolve or download dependencies |
| `--sync-deps` | Replace mismatched installed dependency versions with snapshot versions |
| `--no-backup` | Do not back up the existing package's recorded files |
| `--dry-run` | Show the planned actions without downloading or installing |
| `--refresh` | Refresh the package catalogue before the operation |

Example:

```bash
./cygwin7-pkg.sh install --dry-run --sync-deps gawk
```

## Download sources

The package catalogue comes from the pinned Cygwin Time Machine snapshot:

```text
http://ctm.crouchingtigerhiddenfruitbat.org/pub/cygwin/circa/64bit/2024/01/30/231215
```

For each package, the script uses the exact archive path, size, and SHA-512 recorded in that catalogue.

If the exact archive cannot be downloaded from the Time Machine, the script tries this official mirror:

```text
https://gcc.gnu.org/ftp/cygwin
```

The fallback file is accepted only when its size and SHA-512 match the pinned snapshot metadata. The script never chooses a newer package version from the fallback mirror.

You can override either source:

```bash
export CYGWIN7_ARCHIVE_BASE='http://your-compatible-snapshot.example/cygwin'
export CYGWIN7_FALLBACK_BASE='https://your-mirror.example/cygwin'
```

Then run the script normally.

## Archive formats

The snapshot catalogue determines the exact package archive. Most packages use:

```text
.tar.xz
```

Some older packages exist only as:

```text
.tar.bz2
.tar.gz
.tar.zst
```

The script does not substitute a newer package merely to obtain an `.xz` file. It downloads the exact compatible archive listed in the Windows 7 snapshot and lets Cygwin `tar` detect the compression format.

## Files created by the tool

### Metadata and package cache

```text
~/.cache/cygwin7-direct/
```

Important files include:

```text
~/.cache/cygwin7-direct/metadata/setup.xz
~/.cache/cygwin7-direct/metadata/setup.ini
~/.cache/cygwin7-direct/metadata/packages.index
~/.cache/cygwin7-direct/packages/
```

### Logs

```text
~/cygwin7-package-logs/
```

Each installation creates a timestamped log.

### Backups

```text
~/cygwin7-package-backups/PACKAGE/
```

Before replacing an installed package, the script reads its existing `/etc/setup/PACKAGE.lst.gz` and creates a compressed backup of those recorded files.

Example:

```text
~/cygwin7-package-backups/gawk/gawk-5.4.0-1-20260728-180000.tar.xz
```

These backups contain files, not a complete package-database rollback.

## How direct installation works

For each requested package, the script performs this sequence:

1. Reads the package's snapshot version and dependency information.
2. Builds dependency-first installation order.
3. Displays the planned actions.
4. Downloads the exact archive.
5. Checks the archive's byte size.
6. Checks its SHA-512 hash.
7. Rejects unsafe archive paths such as `../`.
8. Backs up files recorded for the previous installed version.
9. Extracts the full archive into the current Cygwin root.
10. Creates `/etc/setup/PACKAGE.lst.gz` from the archive contents.
11. Updates `/etc/setup/installed.db`.
12. Runs post-install scripts included by the installed packages.
13. Renames successful post-install scripts with `.done`.

## Recommended workflow for a DLL entry-point error

An error such as:

```text
The procedure entry point ... could not be located in cygwin1.dll
```

usually indicates that a program was built for a newer Cygwin runtime than the installed `cygwin1.dll`.

First compare versions:

```bash
./cygwin7-pkg.sh status grep
```

Preview the replacement:

```bash
./cygwin7-pkg.sh install --dry-run --no-deps grep
```

Install the snapshot version:

```bash
./cygwin7-pkg.sh install --no-deps grep
```

Close every Cygwin terminal, reopen Cygwin, and test:

```bash
grep --version
```

For `gawk`:

```bash
./cygwin7-pkg.sh install --no-deps gawk
```

Then reopen Cygwin and test:

```bash
gawk --version
```

## Troubleshooting

### `Cannot write /etc/setup`

The current account cannot modify the Cygwin installation. Close the terminal and start Cygwin with sufficient permission to write `C:\cygwin64`.

Do not run two package operations at the same time.

### `Package was not found in the Windows 7 snapshot`

Confirm the exact package name:

```bash
./cygwin7-pkg.sh search KEYWORD
```

The package may not have existed in the January 2024 snapshot.

### Package catalogue download fails

Check that this address opens in a browser:

```text
http://ctm.crouchingtigerhiddenfruitbat.org/pub/cygwin/circa/64bit/2024/01/30/231215/x86_64/setup.xz
```

The snapshot uses HTTP, not HTTPS.

Also check that `curl`, `wget`, or PowerShell is available:

```bash
command -v curl wget
command -v powershell.exe
```

### SHA-512 mismatch

The downloaded file does not match the snapshot catalogue. The script deletes it and stops. Refresh metadata and try again:

```bash
./cygwin7-pkg.sh refresh
./cygwin7-pkg.sh install PACKAGE
```

Do not disable archive verification.

### Extraction fails

Close all other Cygwin terminals and programs. A running program may have locked a file that the package is trying to replace.

The script cannot safely resolve every Windows file-lock situation.

### Post-install script fails

Read the timestamped log in:

```text
~/cygwin7-package-logs/
```

The package files may have been extracted even though configuration failed.

### A package command is still the old version

Close every Cygwin terminal and reopen it. Then check:

```bash
which PACKAGE_COMMAND
PACKAGE_COMMAND --version
```

Also check for duplicate executables:

```bash
type -a PACKAGE_COMMAND
```

### The package is installed but a DLL is missing

Inspect dependencies:

```bash
./cygwin7-pkg.sh info PACKAGE
```

Then install the missing dependency explicitly:

```bash
./cygwin7-pkg.sh install DEPENDENCY
```

Use `--sync-deps` only after reviewing the planned replacements.

## Restoring a backup

List available backups:

```bash
find ~/cygwin7-package-backups -type f
```

To restore backed-up files manually:

```bash
tar -C / -xJf ~/cygwin7-package-backups/PACKAGE/BACKUP-FILE.tar.xz
```

This restores files only. It does not automatically restore the previous line in `/etc/setup/installed.db` or the previous package list. Keep the original compatible package archive whenever possible, and reinstall that version through this script rather than relying only on file restoration.

## Removing cached downloads

Remove downloaded package archives while keeping metadata:

```bash
rm -rf ~/.cache/cygwin7-direct/packages
```

Remove all downloaded metadata and archives:

```bash
rm -rf ~/.cache/cygwin7-direct
```

The next command will download and rebuild the catalogue again.

## Safety recommendations

- Close other Cygwin programs before installing.
- Preview unfamiliar operations with `--dry-run`.
- Install only exact package names found in the pinned snapshot.
- Prefer the default dependency behavior.
- Avoid `--sync-deps` unless a dependency version is actually causing a problem.
- Do not attempt to replace `cygwin`, Bash, or core runtime libraries with this tool.
- Keep the automatic backups until the new package has been tested.
- Reopen Cygwin before testing newly installed executables or DLLs.

## References

- Cygwin installation guidance for unsupported Windows versions: `https://cygwin.com/install.html`
- Cygwin package archive format: `https://cygwin.com/packaging-package-files.html`
- Cygwin package contributor guidance on direct extraction: `https://cygwin.com/packaging-contributors-guide.html`
- Cygwin package database location and Setup behavior: `https://cygwin.com/cygwin-ug-net/setup-net.html`

## License

This helper script is provided as-is, without warranty. Cygwin packages retain their own licenses and copyright notices.
