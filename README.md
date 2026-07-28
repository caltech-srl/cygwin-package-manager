# Cygwin 3.4 / Windows 7 Package Installer

`cygwin7-pkg.sh` is an interactive and command-line helper for installing packages into an existing **64-bit Cygwin 3.4.10 installation on Windows 7**.

It runs Cygwin’s `setup-x86_64.exe` against a pinned Windows 7-compatible Cygwin Time Machine snapshot, allowing Cygwin Setup to install the requested package and its required dependencies without intentionally upgrading unrelated packages.

> **Important:** This script is intended for legacy Windows 7 systems. It is not needed for supported versions of Windows, where the current Cygwin repository should normally be used.

## Features

- Interactive terminal menu
- Direct installation by exact package name
- Searchable graphical Cygwin package chooser
- Package and version status checks
- Automatic detection of `setup-x86_64.exe`
- Optional automatic download of Cygwin Setup
- Separate package cache and installation logs
- Package-name validation
- No `--upgrade-also`, reducing the risk of unrelated package upgrades
- Warns when the detected Cygwin DLL is not version 3.4.10

## Requirements

- Windows 7
- An existing **64-bit Cygwin** installation
- Cygwin DLL version **3.4.10** is recommended
- Bash
- `cygpath`, `cygcheck`, and standard Cygwin tools
- `setup-x86_64.exe`
- Administrator access when Cygwin Setup requests it
- Internet access to the pinned package snapshot

The script must be run from a **Cygwin Bash terminal**, not from Command Prompt or PowerShell.

## Files

```text
cygwin7-pkg.sh    Package installer script
README.md         Documentation
```

## Installation

Copy `cygwin7-pkg.sh` into a convenient folder, such as your Windows Downloads folder.

Open a Cygwin terminal and go to that folder:

```bash
cd ~/Downloads
```

Make the script executable:

```bash
chmod +x cygwin7-pkg.sh
```

Display the help page:

```bash
./cygwin7-pkg.sh --help
```

## Interactive mode

Start the menu with no arguments:

```bash
./cygwin7-pkg.sh
```

The menu provides these choices:

1. Install packages by exact name
2. Open the graphical package chooser
3. Check an installed package and version
4. Show the current configuration
5. Exit

Package names can be entered with spaces or commas:

```text
make gcc-g++ gawk
```

or:

```text
make,gcc-g++,gawk
```

## Command-line usage

```text
./cygwin7-pkg.sh
./cygwin7-pkg.sh install PACKAGE...
./cygwin7-pkg.sh gui
./cygwin7-pkg.sh status PACKAGE...
./cygwin7-pkg.sh config
./cygwin7-pkg.sh --help
```

### Install packages

Install one package:

```bash
./cygwin7-pkg.sh install gawk
```

Install several packages:

```bash
./cygwin7-pkg.sh install make gcc-g++
```

Comma-separated package names are also accepted:

```bash
./cygwin7-pkg.sh install "grep,gawk,sed"
```

The script asks for confirmation before starting Cygwin Setup.

### Open the graphical chooser

```bash
./cygwin7-pkg.sh gui
```

This opens Cygwin Setup’s searchable package chooser while using the pinned Windows 7-compatible snapshot.

In the chooser:

1. Keep the mode in the upper-right corner set to **Keep**.
2. Search for the package by name.
3. Click the package’s value in the **New** column to select a version.
4. Review dependency changes carefully before continuing.

### Check package status

```bash
./cygwin7-pkg.sh status grep gawk
```

This uses `cygcheck -c` to display the installed status and version of each package.

### Show configuration

```bash
./cygwin7-pkg.sh config
```

The output includes:

- Detected Cygwin DLL version
- Architecture
- Cygwin root directory
- Detected Cygwin Setup executable
- Package snapshot address
- Download-cache directory
- Log directory

## How `setup-x86_64.exe` is found

The script checks the following locations in order:

1. The path set in `CYGWIN_SETUP_EXE`
2. `C:\tools\cygwin_setup\setup-x86_64.exe`
3. The Windows Downloads folder
4. `~/Downloads/setup-x86_64.exe`
5. The current working directory
6. `C:\cygwin64\setup-x86_64.exe`

When the installer is not found, the script offers to:

- Download it from Cygwin’s official website
- Let you enter its full path
- Exit

Both Windows paths and Cygwin paths are accepted when entering the installer location.

## Optional environment variables

### Use a specific Cygwin Setup executable

```bash
export CYGWIN_SETUP_EXE='/cygdrive/c/tools/cygwin_setup/setup-x86_64.exe'
./cygwin7-pkg.sh install make
```

A Windows-style path may also be supplied:

```bash
export CYGWIN_SETUP_EXE='C:\tools\cygwin_setup\setup-x86_64.exe'
```

### Change the package cache

Default:

```text
~/.cache/cygwin7-setup
```

Custom location:

```bash
export CYGWIN7_CACHE_DIR="$HOME/cygwin-package-cache"
```

### Change the log directory

Default:

```text
~/cygwin7-package-logs
```

Custom location:

```bash
export CYGWIN7_LOG_DIR="$HOME/setup-logs"
```

## Package source

The script is pinned to this Cygwin Time Machine snapshot:

```text
http://ctm.crouchingtigerhiddenfruitbat.org/pub/cygwin/circa/64bit/2024/01/30/231215
```

The snapshot is used because current Cygwin packages may require a newer Cygwin DLL and a newer version of Windows. Installing current packages into Cygwin 3.4.10 can cause errors such as:

```text
The procedure entry point ... could not be located in the dynamic link library cygwin1.dll
```

Only packages and versions present in the pinned snapshot can be installed.

## What the script changes

When an installation is approved, the script allows Cygwin Setup to:

- Download the selected packages
- Install the selected packages into the current Cygwin root
- Install required dependencies
- Update Cygwin’s installed-package database
- Write a setup log

The script deliberately does **not** pass `--upgrade-also`, so it does not intentionally request an upgrade of every installed package. Cygwin Setup may still need to change a dependency required by the selected package. Always review the proposed changes.

## Safety notes

- Back up important files before modifying a legacy system.
- Close other Cygwin terminals before installing or replacing core DLLs, shells, or runtime libraries.
- Do not download individual DLL files from unofficial DLL websites.
- Avoid combining packages from the current Cygwin repository with the pinned Windows 7 snapshot.
- Do not change the snapshot address unless you understand Cygwin package compatibility.
- The script uses `--no-verify` because archived snapshots may not have metadata that current Cygwin Setup can verify. This reduces package-verification protection, so use only a trusted snapshot.
- Review Cygwin Setup’s dependency summary before approving an installation.

## Logs

Each setup run creates a timestamped log such as:

```text
~/cygwin7-package-logs/setup-install-20260728-163000.log
```

Graphical chooser runs use names similar to:

```text
~/cygwin7-package-logs/setup-chooser-20260728-163500.log
```

Use the log when diagnosing a failed installation or unexpected dependency change.

## Troubleshooting

### “Run this script inside a Cygwin Bash terminal”

You launched the script from Command Prompt, PowerShell, Git Bash, or another shell. Open the Cygwin terminal and run it there.

### “This script supports only 64-bit Cygwin”

The script detected a non-`x86_64` Cygwin installation. It does not support 32-bit Cygwin.

### Warning about a Cygwin DLL other than 3.4.10

The script was designed for Cygwin 3.4.10 on Windows 7. Continuing with another DLL version may install incompatible packages. Cancel unless you have confirmed that the snapshot is appropriate for your version.

### `setup-x86_64.exe` cannot be found

Place the installer in:

```text
C:\tools\cygwin_setup\setup-x86_64.exe
```

or set its path explicitly:

```bash
export CYGWIN_SETUP_EXE='/cygdrive/c/path/to/setup-x86_64.exe'
```

Then run the script again.

### Automatic installer download fails

Download `setup-x86_64.exe` manually from the official Cygwin website using Firefox, save it to Downloads, and rerun the script.

### A package cannot be found

Check that:

- The package name is exact
- The package existed in the pinned snapshot
- The snapshot server is reachable
- The package is not merely a command supplied by a differently named package

Use the graphical chooser to search available package names:

```bash
./cygwin7-pkg.sh gui
```

### Setup proposes removing a Base package

Do not accept the change until you understand why it is proposed. Click **Back** or cancel the setup run. A mixed package cache or incompatible package selection can cause unsafe dependency proposals.

You can clear the script’s package cache and try again:

```bash
rm -rf "$HOME/.cache/cygwin7-setup"
```

This removes downloaded setup files only; it does not remove installed Cygwin packages.

### Installed executable still reports a DLL entry-point error

Restart all Cygwin terminals. Then check the package and DLL versions:

```bash
uname -r
cygcheck -c package-name
```

Also check whether Windows is loading more than one `cygwin1.dll`:

```cmd
where /r C:\ cygwin1.dll
```

Run the `where` command from Windows Command Prompt, not Cygwin.

### Installation failed

Read the most recent log:

```bash
ls -lt ~/cygwin7-package-logs
```

Then open it with:

```bash
less ~/cygwin7-package-logs/setup-install-YYYYMMDD-HHMMSS.log
```

## Limitations

- Supports only 64-bit Cygwin
- Designed specifically for Cygwin 3.4.10 on Windows 7
- Installs only packages available in the pinned snapshot
- Does not provide package removal
- Does not automatically select older package versions in the GUI
- Does not guarantee that every archived package is compatible with every existing mixed installation
- Depends on the continued availability of the snapshot server
- Current versions of `setup-x86_64.exe` may eventually stop running on Windows 7

## Example workflow

Check the current setup:

```bash
./cygwin7-pkg.sh config
```

Check whether `gawk` is installed:

```bash
./cygwin7-pkg.sh status gawk
```

Install it:

```bash
./cygwin7-pkg.sh install gawk
```

Close and reopen Cygwin, then verify:

```bash
gawk --version
```

Test it:

```bash
echo 'hello world' | gawk '{print $1}'
```

Expected output:

```text
hello
```

## License

No license is included with this script. Add a license file before redistributing it publicly.

## Disclaimer

This is a legacy-system maintenance utility. Use it at your own risk. Windows 7 and Cygwin 3.4.10 are no longer the current supported platform combination, and archived packages do not receive current security updates.
