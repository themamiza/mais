# MAIS

This repository is home to a script used to install and configure a Linux system, particularly my own systems.
The repository is currently under development and is not very usable.
Also will be using this 'REAME.md' as documentation on how to use the script.

## mais

`mais` is a wrapper script used to install and configure systems.

### Dependencies

`mais` requires the following as dependencies. You can install these before installation,
or let the script do it for you.
* `rsync` &rarr; For installing the dotfiles.
* `base-devel` &rarr; For making packages.
* `git` &rarr; Used to clone remote repositories.

## Running `mais`
You can run this command to get `mais`:
``` bash
curl -LO https://raw.githubusercontent.com/themamiza/mais/refs/heads/main/mais && chmod +x mais
```
You can run `mais install` to install mais locally or you can just use it as it is.

### Partition Modes
#### vm
* 1GB  /efi (Only on UEFI systems)
* 30GB /
* \*   /home

#### main
TODO: To be implemented

#### x220
* 1GB  /efi (Only on UEFI systems)
* 30GB /
* \*    /home

On UEFI systems where hibernation is done there's also an 8GBs swap partition at the end.

### `mais configure`
Here are all the configuration that is done by this command

#### Grub
* Set `GRUB_TIMEOUT` to 3 seconds
* Enable `os-prober` to look for other operating systems
* Save previous selection
* Print log messages during boot

* Enable hibernation only if there's a swap partition larger that 8GBs

#### Pacman
* Enable colors
* Enable VerbosePkgLists
* Enable eye-candy

#### Makepkg
* Use all cpu cores for compilations

#### Proxychains

* Craete SOCKS5 proxy on localhost:6969
