# WINE FMOD Studio Installer for Noita

[Noita](https://noitagame.com/) uses FMOD Studio to handle audio related tasks. This extends to mods which also have to use FMOD Studio - unfortunately, only Windows and Mac versions exist. This script sets up a fresh WINE prefix, downloads FMOD Studio, installs it and creates a shell script to easily launch the program.

# Dependencies

### Things you'll almost certainly already have
* `bash` and `coreutils` - difficult not to already have these
* `sudo` - for privilege elevation if you want to install FMOD Studio globally
* `curl` - for using the fmod.com API and downloading files

### Things you might not have
* `7z` - required to extract the FMOD Studio NSIS installer
* `imagemagick` - for converting the FMOD icon to PNG if you want to install it globally

# Usage

To download and use FMOD Studio you need to first [create an account on the FMOD website](https://www.fmod.com/profile/register).

Once that's done, simply run `./install-fmod.sh`. The interactive program will ask you if you understand the FMOD license terms, then it will request your username and password, which are needed to download FMOD Studio (the username/password pair isn't stored anywhere). Afterwards a new WINE prefix will be created in `fmod-wine`, the program will be installed and a script will be created in `fmod-wine/fmod.sh`. You can move the folder anywhere you want, create a symlink to fmod-wine/fmod.sh, etc.

Additionally, the script will ask if you if you would like to install FMOD Studio globally. If you answer yes, it will create an fmod-studio script in /usr/bin as well as a desktop entry.
