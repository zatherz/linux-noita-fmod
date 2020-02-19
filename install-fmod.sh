#!/bin/bash

#Copyright 2020 Zatherz
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

HELPER_SCRIPT='#!/bin/bash
echo "Starting FMOD Studio..."
prefix="$(dirname $(realpath $0))"
echo $prefix
cd "$prefix/drive_c/Program Files/FMOD Studio"
# We use a pipe to workaround a bug where closing the FMOD Studio window
# triggers a stack overflow and causes WINE to get stuck, never quitting
rm -f .fmod-studio-fifo
mkfifo .fmod-studio-fifo
env WINEPREFIX="$prefix" WINEARCH=win64 wine "FMOD Studio.exe" 2> .fmod-studio-fifo &
pid=$!
while IFS= read -r line < .fmod-studio-fifo; do
        if [[ "$line" == *"err:seh:setup_exception stack overflow"* ]]; then
                kill -9 $pid
                break
        fi
done'

GLOBAL_SCRIPT='#!/bin/bash
if ! [ -e "$HOME/.config/fmod-studio" ]; then
	cp -r /usr/share/fmod-studio "$HOME/.config/fmod-studio"
fi
"$HOME/.config/fmod-studio/fmod.sh"'

BITS=64
if [[ $1 = "32" ]]; then
	BITS=32
fi
	

FMOD_LOGIN_API_URL="https://fmod.com/api-login"
FMOD_DL_LINK_API_URL="https://fmod.com/api-get-download-link"

MAGENTA="\e[35m"
YELLOW="\e[33m"
CYAN="\e[36m"
RED="\e[31m"
WHITE="\e[37m"
RESET="\e[0m"

colorecho() {
	echo -e $1$2${RESET}
}

prefix() {
	echo "[$(colorecho $CYAN fmod-installer) $1] "
}

info() {
	echo "$(prefix $(colorecho $MAGENTA INFO))$@"
}

debug() {
	echo "$(prefix DEBUG)$@"
}

error() {
	echo "$(prefix $(colorecho $RED ERROR))$@"
}

warn() {
	echo "$(prefix $(colorecho $YELLOW WARN))$@"
}

loginprefix() {
	echo -n "$(prefix $(colorecho $WHITE LOGIN))$1: "
}

fmodenv() {
	env WINEPREFIX="$wine_dir" WINEARCH=win$BITS $@
}

info Starting...
mkdir -p .fmod-dl-tmp
rm -f .fmod-dl-tmp/curl_cookies
skip_dl=no
if [ -e fmod-wine/bits.txt ] && [ "$(cat fmod-wine/bits.txt)" = "$BITS" ]; then
	skip_dl=yes
else
	rm -rf fmod-wine
	mkdir -p fmod-wine
fi

warn Please note that FMOD Studio is not open source software.
warn This tool installs FMOD Studio under the Indie license, which assumes that you have a development budget under 500 thousand USD.
warn You can read more about FMOD licensing over at https://www.fmod.com/licensing.
warn Do you understand the licensing scheme of FMOD Studio and fall under the limits of the Indie license?
while true; do
	echo -n "$(prefix $(colorecho $WHITE ANSWER))(yes/no): "
	read license_result
	if [ "$license_result" = "yes" ]; then
		info "Alright."
		break
	elif [ "$license_result" = "no" ]; then
		info "You may not install FMOD Studio using this tool."
		exit
	else
		error "Please answer the question. (yes/no)"
	fi
done

if [ "$skip_dl" = "no" ]; then
	info Please sign into your FMOD account to download FMOD Studio.

	while true; do
		loginprefix Username
		read username
		loginprefix Password

		# https://stackoverflow.com/a/24600839
		password_charcount=0
		password=
		while IFS= read -s -n 1 password_char; do
			if [[ "$password_char" == $'\0' ]]; then
				break	
			fi

			if [[ "$password_char" == $'\177' ]]; then
				if [ "$password_charcount" -gt 0 ]; then
					echo -ne "\b \b"
					password_charcount=$((password_charcount - 1))
					password="${password%?}"
				fi
			else
				password_charcount=$((password_charcount + 1))
				password+="$password_char"
				echo -n "*"
			fi
		done

		echo
		base64_auth="$(echo "$username:$password" | base64 | tr -d "\n")"
		login_result="$(curl -s -c .fmod-dl-tmp/curl_cookies -X POST "$FMOD_LOGIN_API_URL" -H "Authorization: Basic $base64_auth")"
		if [[ "$login_result" == *"\"token\""* ]]; then
			token="$(echo -n "$login_result" | sed -r 's/.*"token":"([^"]*)".*/\1/')"
			user_id="$(echo -n "$login_result" | sed -r 's/.*"user":"([^"]*)".*/\1/')"
			# turns out user_id isn't actually necessary
			# but the website uses it so I will use it too just in case
			info Login successful.
			break
		else
			if [[ "$login_result" == "" ]]; then
				error "Login failed. Username or password is incorrect."
			else
				error "Login failed with an unknown error. Result from API: $login_result."
			fi
		fi
	done

	dl_link_url="$FMOD_DL_LINK_API_URL"
	dl_link_url="$dl_link_url?path=files/fmodstudio/tool/Win$BITS/"
	dl_link_url="$dl_link_url&filename=fmodstudio11019win$BITS-installer.exe"
	dl_link_url="$dl_link_url&user_id=$user_id"

	dl_link_result="$(curl -s -c .fmod-dl-tmp/curl_cookies -X GET "$dl_link_url" -H "Authorization: FMOD $token")"
	dl_link="$(echo -n "$dl_link_result" | sed -r 's/.*"url":"([^"]*)".*/\1/')"

	info Downloading FMOD Studio 1.10.19 for Win$BITS...

	curl -s -c .fmod-dl-tmp/curl_cookies "$dl_link" > .fmod-dl-tmp/FMODStudio.exe

	info "Preparing WINE prefix..."

	wine_dir="$PWD/fmod-wine"
	fmodenv wineboot -i &>/dev/null

	info "WINE prefix created."
	echo $BITS > fmod-wine/bits.txt
fi

exe_path="$PWD/.fmod-dl-tmp/FMODStudio.exe"
info "Unpacking the FMOD Studio installer..."
pushd fmod-wine/drive_c &>/dev/null
mkdir -p "Program Files/FMOD Studio"
cd "Program Files/FMOD Studio"
7z x "$exe_path" -aoa &>/dev/null
popd &>/dev/null

info "Writing helper script..."
echo "$HELPER_SCRIPT" > fmod-wine/fmod.sh
chmod +x fmod-wine/fmod.sh

info "Would you want to install FMOD Studio globally, so that you can create desktop shortcuts to it and run it from anywhere?"

echo -n "$(prefix $(colorecho $WHITE ANSWER))(yes/no): "
read global_install_answer
if [[ "$global_install_answer" == "yes" ]]; then
	info "Authenticate with sudo."
	sudo -v

	info "Note: FMOD Studio will be installed to /usr/bin and /usr/share."
	sudo mkdir -p /usr/share
	sudo rm -rf /usr/share/fmod-studio
	sudo cp -r fmod-wine /usr/share/fmod-studio
	sudo rm -f /usr/bin/fmod-studio
	echo "$GLOBAL_SCRIPT" | sudo tee /usr/bin/fmod-studio &>/dev/null
	sudo chmod -R 755 /usr/share/fmod-studio
	sudo chmod +x /usr/bin/fmod-studio

	info "Note: Desktop entry will be installed to /usr/share/applications."
	sudo cp fmod-studio.desktop /usr/share/applications

	info "Note: Icon will be installed to /usr/share/icons."
	curl -s "https://www.fmod.com/favicon.ico" > fmod-studio.ico
	sudo convert -scale 48x48 fmod-studio.ico /usr/share/icons/hicolor/48x48/apps/fmod-studio.png

	info "Done! You can now run: fmod-studio"
else
	info "Done! You can now run: fmod-wine/fmod.sh"
fi
