# MAIS — Arch Linux Bootstrap and Configuration Scripts

> [!WARNING]
> MAIS is an actively developed personal project and may contain bugs,
> incomplete functionality or destructive behavior. It is not intended for
> production systems or unattended deployments. Review the code, keep backups
> and use it at your own risk.

## Installation

### Bootstrap the latest release

From an Arch Linux shell with root privileges, run:

```bash
curl -fsSL https://github.com/themamiza/mais/releases/latest/download/mais | bash -s -- install
```

That's it.

The bootstrap script downloads the latest published release, verifies its
checksum and installs it to:

```text
/usr/local/bin/mais
```

To update an existing installation:

```bash
sudo mais install
```

### Install the latest release from a cloned repository

The modular development version can also run the installer:

```bash
git clone https://github.com/themamiza/mais.git
cd mais
sudo ./mais install
```

This uses the cloned repository as a launcher, but the installed executable is
still downloaded from the latest published GitHub Release.

### Build and install from source

Clone the repository, build the standalone executable and install that exact
version:

```bash
git clone https://github.com/themamiza/mais.git
cd mais
./tools/build.sh
sudo install -Dm755 release/mais /usr/local/bin/mais
```

This method installs the code from the latest commit instead of
downloading the latest published release.

## What is MAIS?

MAIS is a collection of Bash scripts used to install and configure Arch Linux
systems.

It can bootstrap a fresh Arch installation, install selected groups of
programs, configure the system, install dotfiles, create backups and perform
other repetitive setup tasks.

MAIS is primarily designed for my own machines and preferences, but the
program list, dotfiles repository and individual commands can be changed or
used independently.

Run the following to see the available commands:

```bash
mais help
```

## Arch installation

MAIS can bootstrap an Arch Linux system from the live installation
environment:

```bash
sudo mais arch-install partition_mode
```

The available partition modes are:

* `vm`: partitions `/dev/vda` for a virtual machine.
* `x220`: partitions `/dev/sda` using the layout for my ThinkPad X220.
* `mounted`: uses filesystems that are already mounted under `/mnt`.
* `main`: reserved for the main workstation layout and not implemented yet.

> [!NOTE]
> Automatic partition modes are temporary and may be removed in a future
> release. The `mounted` mode is the recommended general-purpose option.

Values can be provided before installation to avoid some interactive prompts:

```bash
sudo mais arch-install mounted \
    -u username -h hostname -t Region/City
```

> [!CAUTION]
> Do not run `arch-install` on an existing installation.
>
> The automatic partition modes format disks and will destroy existing data.
> Read the relevant partition function before confirming the operation.

## Installing programs

MAIS installs programs from
[`data/programs.csv`](data/programs.csv).

Install every listed program:

```bash
mais install-programs
```

Install only a selected tag:

```bash
mais install-programs hyprland
```

The currently supported tags are:

```text
 x11   wayland        |-dev-|-----|-----|-----|    extra
  |       |           |     |     |     |     |
 dwm   hyprland    python clang  lua   bash  js    virt
```

Programs without a tag are installed with every selection.

### The `programs.csv` file

The programs file has four fields separated by `|`:

```
installation method | tag | package name | description
```

For example:

```
AUR      | extra    | some-package-git | "Description of the package"
Suckless | dwm      | username/dwm     | "A dynamic window manager"
         | hyprland | hyprland         | "A Wayland compositor"
```

The installation method can be:

* Blank or `Pacman` for an official repository package.
* `AUR` for an AUR package.
* `Suckless` for a supported source repository.
* `DoomEmacs` for the Doom Emacs installation method.

Lines beginning with `#` are comments and whitespace around fields is ignored.

Programs are processed from the top of the file to the bottom, so packages may
be ordered when one depends on another.

## Dotfiles

By default, MAIS installs my
[dotfiles](https://github.com/themamiza/dotfiles):

```bash
mais install-dotfiles
```

A different repository can be supplied:

```bash
mais install-dotfiles https://github.com/username/dotfiles
```

When `~/rp/dotfiles` already exists, MAIS uses that local repository instead
of cloning the default or supplied repository.

## Other commands

Install an AUR helper:

```bash
mais install-aurhelper yay
mais install-aurhelper paru
```

Configure GRUB, Pacman, Makepkg and supported optional programs:

```bash
sudo mais configure
```

Update the Arch mirror list:

```bash
sudo mais update-mirrors
```

Create a backup using the predefined backup rules:

```bash
mais backup
```

Give the backup a custom name:

```bash
mais backup backup-name
```

Use `--verbose` or `-v` to display command output:

```bash
mais configure --verbose
```

Use `--quiet` or `-q` to suppress normal MAIS output:

```bash
mais configure --quiet
```

Experimental commands are intentionally not documented here. Review their
implementation before using them.

## The script itself

The development version of MAIS is split into modules for readability,
testing and easier maintenance.

The main entry point is [`mais`](mais), while the implementation is divided
between:

```text
lib/cli/        command-line parsing, help and dispatch
lib/commands/   user commands
lib/core/       shared helpers and configuration
lib/distro/     distribution-specific operations
```

Clone the repository and run the modular version with:

```bash
git clone https://github.com/themamiza/mais.git
cd mais
./mais help
```

The modular `mais` file depends on the accompanying `lib/` directory and
should not be downloaded by itself. Use the published standalone release for
normal installation.

## Testing

Install ShellCheck, then run:

```bash
./tools/run_tests.sh
```

To build and test the standalone release:

```bash
./tools/run_tests.sh --release
```

The checks include Bash syntax validation, focused smoke tests, ShellCheck,
standalone build validation and checks for unsafe shell-string execution.
