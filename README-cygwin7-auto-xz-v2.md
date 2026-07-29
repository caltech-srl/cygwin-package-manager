# Cygwin 3.4 / Windows 7 Automatic Direct `.tar.xz` Tool — Version 2

This version fixes the `Package folder not found` problem.

The earlier version tried to browse a package directory such as `/release/nano/`. The archived server does not reliably provide browsable directory pages. Version 2 reads the archive's compressed package catalog instead, locates the exact `.tar.xz` path, downloads that package archive, and extracts it directly.

No Windows executable is downloaded or launched.

## What the tool does

Given a package name such as:

```text
nano
```

the script:

1. Reads the Windows 7-compatible package catalog.
2. Finds the normal archived version and exact `.tar.xz` path.
3. Downloads the package archive.
4. Verifies its expected size and SHA-512 value when available.
5. Test-extracts the entire archive.
6. Backs up files that would be replaced.
7. Extracts the package directly into the current Cygwin root.

## Download

Use:

```text
cygwin7-pkg-auto-xz-v2.sh
```

## Prepare it

Put the script in your Windows Downloads folder. In Cygwin, enter:

```bash
WIN_DOWNLOADS="$(cygpath -u "$(cmd.exe /d /c 'echo %USERPROFILE%' | tr -d '\r')")/Downloads"
cd "$WIN_DOWNLOADS"
chmod +x cygwin7-pkg-auto-xz-v2.sh
```

## Check nano

```bash
./cygwin7-pkg-auto-xz-v2.sh find nano
```

It should resolve the archived package version and print the direct `.tar.xz` URL.

## Download and extract nano

```bash
./cygwin7-pkg-auto-xz-v2.sh install nano
```

You can request the known older nano release explicitly:

```bash
./cygwin7-pkg-auto-xz-v2.sh install nano@4.9-1
```

## Install several named packages

```bash
./cygwin7-pkg-auto-xz-v2.sh install grep gawk nano
```

## Refresh the cached catalog

```bash
./cygwin7-pkg-auto-xz-v2.sh --refresh find nano
```

## Skip confirmation

```bash
./cygwin7-pkg-auto-xz-v2.sh --yes install nano
```

## Download location

Package archives and the compressed catalog are stored in:

```text
C:\Users\YOUR_WINDOWS_NAME\Downloads\cygwin7-xz
```

## Backups

Replaced files are backed up under:

```bash
~/cygwin7-xz-backups
```

After extraction, the script prints the exact restore command.

## Dependencies

The script resolves the package you enter. It does not automatically extract dependency packages.

For nano, the relevant runtime library packages include `libintl8` and `libncursesw10`. When nano reports a missing DLL, install the package providing that DLL using the same method.

## Test after extraction

```bash
nano --version
```

## Important warning

Avoid using direct extraction to replace the Cygwin DLL, Bash, `tar`, or `xz` while Cygwin is running. These components may be in use by the current process.
