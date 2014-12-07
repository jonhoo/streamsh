#!/bin/bash

if [[ $# -lt 1 ]]; then
	echo "$0 <embed-url> [filename]" > /dev/stderr
	exit 1
fi

ofile=""
if [[ -n $2 ]]; then
	ofile="$2"
fi

ourl="$1"
url="$1"
title="Unknown"
owned="false"
ua="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.$$.52 Safari/537.36"

# Locate running SOCKS5 proxy (if any)
socks=""
if [[ -n $(ss -tpln | grep ssh | grep -v ":22 ") ]]; then
	addr=$(ss -tpln | grep ssh | grep -v ":22 " | awk '{ print $4 }' | head -n1)
	echo "Detected SOCKS proxy on $addr" > /dev/stderr
	socks="$addr"
fi

# Wrapper for SOCKS or non-SOCKS curl
crl() {
	url="$1"
	shift
	if [[ -z $socks ]]; then
		curl "$@" -L -A "$ua" -s "$url"
	else
		curl "$@" -L -A "$ua" --socks $socks -s "$url"
	fi
}

# Convert input fields to --data-urlencode pairs
crld() {
	sed 's/.*name="\([^"]*\)".*value="\([^"]*\).*/--data-urlencode\n\1=\2/' | \
	sed 's/.*value="\([^"]*\)".*name="\([^"]*\).*/--data-urlencode\n\2=\1/'
}

for f in "$(dirname "$(readlink -f $0)")/tricks"/*; do
	source "$f"
done

pick() {
	echo "$1" > .cache/streamsh-previous.html
	if [[ -n $(echo "$1" | grep -E "has been (deleted|removed)") ]]; then
		echo "The file has been removed :'(" > /dev/stderr
		exit 2
	fi

	# The very classy protection used by sockshare/putlocker
	if [[ ! -z $(echo "$1" | grep '#propaganda') ]]; then
		echo "Extracting with *share method" > /dev/stderr
		try_share "$1"
	# 180upload uses a funky "captchaForm" without a captcha
	elif [[ ! -z $(echo "$1" | grep -E "name=('|\")file_code('|\")") ]]; then
		echo "Extracting with file_code method" > /dev/stderr
		try_file_code "$1"
	# And some sites just had to go and use a JS obfuscator...
	elif [[ ! -z $(echo "$1" | grep ';eval(function(w,i,s,e)') ]]; then
		echo "Extracting with unwise method" > /dev/stderr
		try_unwise "$1"
	elif [[ ! -z $(echo "$1" | grep 'function(p,a,c,k,e,d)') ]]; then
		echo "Extracting with packed method" > /dev/stderr
		try_packed "$1"
	# Some providers have a weird addVariable setup
	elif [[ ! -z $(echo "$1" | grep 'addVariable(') ]]; then
		echo "Extracting with addVariable method" > /dev/stderr
		try_addVar "$1"
	# We also have sites that do a nicer version of the *locker block
	elif [[ ! -z $(echo "$1" | grep "Close Ad and Watch as Free User") ]]; then
		echo "Extracting with close method" > /dev/stderr
		try_close "$1"
	# And some sites try base64 "encryption"
	elif [[ ! -z $(echo "$1" | grep '<param value="setting=') ]]; then
		echo "Extracting with base64 'decrypt'" > /dev/stderr
		try_base64 "$1"
	# The good old flashvars/player.api.php combo
	elif [[ ! -z $(echo "$1" | grep flashvars) ]]; then
		echo "Extracting with player_api method" > /dev/stderr
		try_player_api "$1"
	# Gorillavid and others like JWPlayer with plugins
	elif [[ ! -z $(echo "$1" | grep 'jwplayer(') ]]; then
		echo "Extracting with jwplayer method" > /dev/stderr
		try_jwplayer "$1"
	fi
}

pick "$(crl "$1")"
if [[ $owned == 'true' && -z $(echo "$url" | sed 's/[a-f0-9]*//') ]]; then
	owned='false'
fi

if [[ $owned == 'false' ]]; then
	echo "Found no streaming vider on $ourl" > /dev/stderr
else
	if [[ -z $ofile ]]; then
		if [[ -z $socks ]]; then
			exec curl -C - -L "$url"
		else
			exec curl -C - -L --socks "$socks" "$url"
		fi
	fi

	ext=$(basename "$url" | sed 's/.*\.//')
	if [[ -z "$ext" || $(expr length "$ext") -gt 3 ]]; then
		ext=mp4
	fi

	f=$(printf "%b" "${title//%/\\x}")
	f="${f}.${ext}"
	echo -n "Downloading " > /dev/stderr
	printf "%b\n" "${title//%/\\x}"
	echo -n "       from " > /dev/stderr
	printf "%b\n" "${url//%/\\x}"
	if [[ -n $ofile ]]; then
		f="${ofile}.${ext}"
	fi
	echo -n "         to ./$f" > /dev/stderr
	if [[ -z $socks ]]; then
		exec curl -C - -L "$url" -o ./"$f"
	else
		exec curl -C - -L --socks "$socks" "$url" -o ./"$f"
	fi
fi
