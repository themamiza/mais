#!/usr/bin/env bash

# shellcheck disable=2034

##### Global variables are set here

# Saving to a variable for easy use in messages.
program_name="$(basename "$0")"

install_path="/usr/local/bin"

bootloader_id="ArchLinux"  # Only matters when using "UEFI".
efi_directory="/efi"

aurhelper="yay"

# 'verbose=false' should only print messages from the script and suppress all
# the commands that are being executed.
# 'verbose=true' should be as verbose as possible; printing the output
# of all commands that get run.
verbose=false
# When 'verbose=false' where should the suppressed output go?
# You can change the output path through "lib/core/run.sh - run_cmd()".
# 'quite=true' should silence any output from the script.
quiet=false

# URL to dotfiles repository.
dotfiles_url="https://github.com/themamiza/dotfiles"
# Dotfiles repository can have different name e.g. voidrice <https://github.com/lukesmithxyz/voidrice>.
dotfiles_name="$(basename "$dotfiles_url")"

# TODO: Document the csv file specs.
# The development repository stores the programs file under data/.
programs_filename="programs.csv"
programs_file="$MAIS_ROOT/data/$programs_filename"

# Path to a tmp file which will just contain name of programs to install.
programs_to_install="/tmp/programs.tmp"
# Remote programs file used by the standalone release.
programs_file_url="https://raw.githubusercontent.com/themamiza/mais/refs/heads/main/data/programs.csv"
