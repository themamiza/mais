# MAIS

This repository is home to several scripts used to install and configure a Linux system, particularly my own systems.
The repository is currently under development and is not very usable.
Also will be using this 'REAME.md' as documentation on how to use the scripts.

# Scripts 

Here is a list of all the scripts and their options and arguments:
(These scripts are all in development stage, their options and/or arguments will change!)

## mais

`mais` is a wrapper script used to install and configure systems.

### Dependencies

`mais` requires the following as dependencies. You can install these before installation,
or let the script do it for you.
* `rsync` &rarr; For installing the dotfiles.
* `base-devel` &rarr; For making packages.
* `git` &rarr; Used to clone remote repositories.

### Options
* `-h | --help`

    List all options and arguments.

* `-v | --verbose`

    Print everything from every command, do not silence anything. (Useful for debugging)

    Default behavior is to silence everything

* `-c | -color`

    Use colored output. Default behavior is not to use colored output.

* `-n [username] | --username [username]`

    The script requires username for some functionalities, use this option to provide username.
    Otherwise it will be asked when needed.
    Username begins with a letter, with only lowercase letters, - or _.

    The same applies to timezone and hostname:

* `-h [hostname] | --hostname [hostname]`

    Hostname begins with a letter, with only lowercase letters, - or _.

* `-t [timezone] | --timezone [timezone]`

    Valid timezones can be found using: `timedatectl list-timezones`

* `-I | --print-configuration`

    Print all set variables and configurations of the script.

* `-a [preset] | --arch-install [preset]`

    Install ArchLinux using a preset. Preset is used to partition a certain way.
    Available options are:
    * `main`
        * To be implemented!
    * `vm`
        * 1GB &rarr; /efi
        * 32GB &rarr; /
        * All that's left over. &rarr; /home
    * `X220 | x220`
        * 1GB &rarr; /efi
        * 32GB &rarr; /
        * What ever that can be allocated. &rarr; /home
        * 8GB &rarr; swap
        
    You can also use your own partitioning scheme. Make sure you mount your filesystems correctly before installation.
    The script expects these:

    * UEFI &rarr; An efi system directory; defaults to '/efi'.
    * BIOS &rarr; Should specify disk to be installed in the script (No option provided); defaults to '/dev/vda'.

* `-i [environment] | --install-environment [environment]`

    Install specific prorgams for said 'environment' according to 'progarms.csv'
    Defaults to installing all applications and environments.
    Environment can be one of:

    * DWM
    * Hyprland

* `-u | --install-dotfiles`

    Installs dotfiles into user's home directory.
    Will first grab dotfiles from '$HOME/rp/dotfiles' if available. If not there, it will grab the
    remote repository.

* `-p [aurhelper] | --install-aurhelper [aurhelper]`

    Installs said 'aurhelper'.
    AUR helper can be one of:

    * [paru](https://github.com/Morganamilo/paru) (Default)
    * [yay](https://github.com/Jguer/yay)

* `-g | --configure-grub`

    Configures grub to do the following:

    * Set grub timeout to 3 seconds
    * Enable dual booting
    * Save previous selection
    * Be verbose and print messages during boot
    * Enable hibernation if there's a swap larger than 8GBs

* `-d [option] | --debug [option]`

    Some options are more experimental or not worth using a real option for:

    * `-e | --install-essentials`

        Installs programs mentioned in [dependencies](#Dependencies).

    * `-u | --update-package-descriptions`

        Update descriptions field in 'programs.csv'.

    * `-e | --check_installation_environment`

        Check installation environment and report.

# Goals
Here is a list of tasks that I want done. I keep track of them here.

* [ ] Make the script less monolithic.
* [ ] List essential programs using command.
* [ ] Make use of `fzf` when choosing timezone.
