# Cygwin 3.4 / Windows 7 Direct `.tar.xz` Package Installer

`cygwin7-pkg.sh` installs Cygwin packages the same basic way used for the manual `gawk` repair:

1. Find the exact Windows 7-compatible package archive.
2. Download the package’s `.tar.xz` file.
3. Verify the archive when catalog hash information is available.
4. Back up files that will be replaced.
5. Extract the complete archive directly into the Cygwin root with `tar -xJf`.
6. Run package-provided post-install scripts when present.

**It never downloads or launches a Windows package installer.**

The script is intended for an existing **64-bit Cygwin 3.4.10 installation on Windows 7**.

---

## What the script downloads

When you install by package name, the script first downloads a compressed package catalog from the pinned Windows 7 Cygwin snapshot. The catalog is only text metadata compressed with XZ. It supplies:

- Exact package version
- Exact `.tar.xz` path
- Archive size
- SHA-512 hash
- Required dependency names

The actual program is then downloaded as a normal package archive such as:

```text
grep-3.11-1.tar.xz
gawk-5.3.0-1.tar.xz
sed-4.9-1.tar.xz
```

The package is extracted directly into `/`, which is the root of your current Cygwin installation.

---

## Requirements

You need:

- Windows 7 64-bit
- An existing 64-bit Cygwin installation
- Cygwin DLL 3.4.10
- Bash
- `tar`
- `xz`
- `awk`
- `gzip`
- One working downloader:
  - `curl`, or
  - `wget`, or
  - Windows PowerShell
- Permission to write into the Cygwin root

Check your Cygwin version:

```bash
uname -r
```

The output should begin with:

```text
3.4.10
```

Check the main required commands:

```bash
command -v bash tar xz awk gzip
```

---

## Install the script

Place these files in your Windows Downloads folder:

```text
cygwin7-pkg.sh
README.md
```

Open a Cygwin terminal and enter:

```bash
cd ~/Downloads
```

Make the script executable:

```bash
chmod +x cygwin7-pkg.sh
```

Show the script configuration:

```bash
./cygwin7-pkg.sh config
```

---

## Install a package by name

To install or repair `grep`:

```bash
./cygwin7-pkg.sh install grep
```

To install or repair `gawk`:

```bash
./cygwin7-pkg.sh install gawk
```

To install several packages:

```bash
./cygwin7-pkg.sh install grep gawk sed
```

Comma-separated package names also work:

```bash
./cygwin7-pkg.sh install "grep,gawk,sed"
```

The script will display the exact versions and archive filenames before making changes.

---

## Use the manual-style URL mode

This mode most closely matches the procedure used for `gawk`. You give the script a direct `.tar.xz` link, and it downloads and extracts that exact archive.

```bash
./cygwin7-pkg.sh install-url "FULL_TAR_XZ_URL" PACKAGE_NAME
```

Example format:

```bash
./cygwin7-pkg.sh install-url \
  "http://server/path/gawk-5.3.0-1.tar.xz" \
  gawk
```

This mode does **not** resolve dependencies because a single archive URL does not contain dependency metadata.

When the package name can be derived safely from the filename, it can be omitted:

```bash
./cygwin7-pkg.sh install-url \
  "http://server/path/gawk-5.3.0-1.tar.xz"
```

---

## Install a `.tar.xz` already in Downloads

For a file already downloaded manually:

```bash
./cygwin7-pkg.sh install-file \
  ~/Downloads/gawk-5.3.0-1.tar.xz \
  gawk
```

When the filename follows the standard Cygwin package naming format, the package name may be omitted:

```bash
./cygwin7-pkg.sh install-file \
  ~/Downloads/gawk-5.3.0-1.tar.xz
```

---

## Interactive mode

Run the script without arguments:

```bash
./cygwin7-pkg.sh
```

The menu provides:

```text
1) Install package(s) by name
2) Install one .tar.xz from a URL
3) Install one local .tar.xz file
4) Download package archive(s) only
5) Search packages
6) Show package information
7) Check installed/snapshot versions
8) Refresh package catalog
9) Show configuration
0) Exit
```

---

## Dependencies

By default, installing by package name resolves dependencies from the pinned Windows 7 package catalog.

Example:

```bash
./cygwin7-pkg.sh install make
```

The script installs a dependency only when that dependency is not already recorded as installed. It does not intentionally replace every existing dependency with the snapshot version.

To download and extract only the requested package archive:

```bash
./cygwin7-pkg.sh install --no-deps grep
```

This is closest to manually downloading and copying one program, but it will fail at runtime when a required DLL is missing.

---

## Preview changes

Show the installation plan without downloading or extracting anything:

```bash
./cygwin7-pkg.sh install --dry-run make
```

---

## Skip confirmation

```bash
./cygwin7-pkg.sh install -y grep
```

Use this only after reviewing the package and version.

---

## Skip post-install scripts

```bash
./cygwin7-pkg.sh install --no-postinstall PACKAGE
```

This may be useful for troubleshooting a faulty package script, but some packages will not be completely configured without their post-install step.

---

## Download without extracting

```bash
./cygwin7-pkg.sh download gawk
```

Downloaded archives are stored under:

```text
~/.cache/cygwin7-direct/packages/
```

---

## Search available packages

```bash
./cygwin7-pkg.sh search awk
```

Search by a description phrase:

```bash
./cygwin7-pkg.sh search "text processing"
```

The search displays up to 100 matching packages.

---

## Show package information

```bash
./cygwin7-pkg.sh info gawk
```

The output includes:

- Package name
- Snapshot version
- Archive path
- File size
- SHA-512 hash
- Dependencies
- Category
- Description

---

## Check installed and available versions

```bash
./cygwin7-pkg.sh status grep gawk
```

The installed version comes from:

```text
/etc/setup/installed.db
```

The snapshot version comes from the pinned Windows 7 package catalog.

---

## Backups

Before extraction, the script checks which archive files already exist and stores those existing files in a backup archive.

Default backup folder:

```text
~/cygwin7-package-backups/
```

A backup looks similar to:

```text
~/cygwin7-package-backups/20260728-173000/gawk-5.3.0-1-before.tar.xz
```

To inspect a backup:

```bash
tar -tJf ~/cygwin7-package-backups/TIMESTAMP/PACKAGE-before.tar.xz
```

To restore a backup manually:

```bash
tar -xJf ~/cygwin7-package-backups/TIMESTAMP/PACKAGE-before.tar.xz -C /
```

Close programs that may be using the affected executable before restoring it.

---

## Package records

After successful extraction, the script writes:

```text
/etc/setup/PACKAGE.lst.gz
```

and updates:

```text
/etc/setup/installed.db
```

This allows commands such as the following to recognize the manually extracted package:

```bash
cygcheck -c PACKAGE
```

---

## Archive verification

For package-name installs, the script verifies:

- Archive file size
- SHA-512 hash from the pinned catalog
- Valid XZ/tar structure
- No absolute paths
- No `..` path traversal entries

For `install-url` and `install-file`, no trusted catalog hash may be available. The script still validates the archive structure and warns that a catalog hash was not checked.

The historical package catalog is retrieved from the Windows 7 snapshot over HTTP and is not signature-authenticated by this script. Hash verification confirms that an archive matches that downloaded catalog; it does not independently authenticate the catalog itself.

Only download direct URLs from a source you trust.

---

## Packages the script refuses to replace

The script will not replace these packages from the running Cygwin session:

```text
cygwin
bash
coreutils
tar
xz
liblzma5
gzip
```

The running shell and extraction tools can be using these files. Replacing them while they are active may corrupt the environment or leave the installation unusable.

For ordinary command-line packages such as `grep`, `gawk`, `sed`, `make`, and similar utilities, direct archive extraction is much more practical.

---

## Important limitations

Direct archive extraction is not a complete replacement for Cygwin’s full package-management process.

Potential limitations include:

- A package may require complicated service registration.
- An older package may leave stale files that are not present in the replacement archive.
- A package may depend on a DLL version that is recorded as installed but is actually damaged.
- A package post-install script may fail.
- A program currently running cannot always be overwritten on Windows.
- Direct URL mode does not resolve dependencies.
- The script intentionally accepts only `.tar.xz` binary packages.

After installing a package, close and reopen the Cygwin terminal before testing it.

---

## Troubleshooting

### Permission denied while extracting

Close Cygwin and reopen the terminal with sufficient permission to modify the Cygwin installation. Also close any program using the executable being replaced.

### Procedure entry point could not be located

This normally indicates that the executable and one of its Cygwin DLL dependencies are from incompatible package generations. Install the Windows 7-compatible package archive and confirm that its required DLL packages are already compatible.

### The package is not found

Refresh the catalog:

```bash
./cygwin7-pkg.sh refresh
```

Then search:

```bash
./cygwin7-pkg.sh search PACKAGE_WORD
```

### Archive is not `.tar.xz`

This script deliberately accepts only `.tar.xz` package files. Use a matching `.tar.xz` version from the Windows 7-compatible snapshot or provide an exact trusted `.tar.xz` URL.

### Download fails from the snapshot server

The script tries the pinned snapshot first and then tries exact-path archive mirrors. It never substitutes a newer filename or version. A newer package could require a newer `cygwin1.dll`, so the script will not guess.

### Post-install script fails

The archive files remain installed. The failed script normally remains under:

```text
/etc/postinstall/
```

You can inspect it and run it manually after correcting the underlying problem.

---

## Optional environment variables

Change the package cache:

```bash
export CYGWIN7_CACHE_DIR="$HOME/my-cygwin-cache"
```

Change the backup folder:

```bash
export CYGWIN7_BACKUP_DIR="$HOME/my-cygwin-backups"
```

Override the historical snapshot root:

```bash
export CYGWIN7_SNAPSHOT_ROOT="http://your-compatible-snapshot-root"
```

Use a snapshot built for Cygwin 3.4.10. Do not point the script at the current Cygwin repository on Windows 7.

---

## Quick examples

Repair `grep`:

```bash
./cygwin7-pkg.sh install --no-deps grep
C:/cygwin64/bin/grep.exe --version
```

Repair `gawk`:

```bash
./cygwin7-pkg.sh install --no-deps gawk
C:/cygwin64/bin/gawk.exe --version
```

Install a package with missing dependencies:

```bash
./cygwin7-pkg.sh install make
```

Download an archive but do not install it:

```bash
./cygwin7-pkg.sh download sed
```

Use an exact manual link:

```bash
./cygwin7-pkg.sh install-url "FULL_TAR_XZ_URL" PACKAGE_NAME
```

---

## Official technical references

- Cygwin package archive format: `https://cygwin.com/packaging-package-files.html`
- Direct untar testing method: `https://cygwin.com/packaging-contributors-guide.html`
- Windows 7 and Cygwin 3.4.10 compatibility information: `https://cygwin.com/install.html`
