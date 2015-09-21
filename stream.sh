#!/bin/bash

if [[ $# -lt 1 ]]; then
	echo "$0 <embed-url> [filename]" > /dev/stderr
	exit 1
fi

ofile=""
if [[ -n $2 ]]; then
	ofile="$2"
	ofile=$(echo "$ofile" | sed 's@/@--@g')
fi

ourl="$1"
url="$1"
title=""
owned="false"
ua="Mozilla/5.0 (X11; Linux x86_64; rv:42.0) Gecko/20100101 Firefox/42.0"

sec() { echo -e "\e[1;34m:: \e[0m\e[1m$1\e[0m"; }
comp() { echo -e "\e[1;32m==> \e[0m\e[1m$1\e[0m"; }
task() { echo -e "\e[1;34m  -> \e[0m\e[1m$1\e[0m"; }
err() { echo -e "\e[1;31m==> ERROR: \e[0m\e[1m$1\e[0m"; }
inp() { echo -en "\e[1;33m==> \e[0m\e[1m$1\e[0m"; }

comp "Fetching embed page" > /dev/stderr

# Locate running SOCKS5 proxy (if any)
socks=""
if [[ -n $(ss -tpln | grep ssh | grep -v ":22 ") ]]; then
	addr=$(ss -tpln | grep ssh | grep -v ":22 " | awk '{ print $4 }' | head -n1)
	task "Detected SOCKS proxy on $addr" > /dev/stderr
	socks="$addr"
fi

# Wrapper for SOCKS or non-SOCKS curl
crl() {
	url="$1"
	shift

	for i in $(seq 1 3); do
		if [[ -z $socks ]]; then
			x=$(curl "$@" -L -A "$ua" -s "$url")
		else
			x=$(curl "$@" -L -A "$ua" --socks $socks -s "$url")
		fi
		if [[ -n "$x" ]]; then
			echo "$x"
			break
		fi
	done
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
	echo "$1" > ~/.cache/streamsh-previous.html
	if [[ -n $(echo "$1" | grep -E "has been (deleted|removed)") ]]; then
		err "The file has been removed :'(" > /dev/stderr
		exit 2
	fi
	if [[ -n $(echo "$1" | grep -i "not found") ]]; then
		err "The file is gone :'(" > /dev/stderr
		exit 2
	fi
	if [[ -n $(echo "$1" | grep -E "maintenance mode") ]]; then
		err "The streaming server is unavailable" > /dev/stderr
		exit 3
	fi

	# The very classy protection used by sockshare/putlocker
	if [[ ! -z $(echo "$1" | grep '#propaganda') ]]; then
		task "Extracting with *share method" > /dev/stderr
		try_share "$1"
	# 180upload uses a funky "captchaForm" without a captcha
	elif [[ ! -z $(echo "$1" | grep -E "name=('|\")file_code('|\")") ]]; then
		task "Extracting with file_code method" > /dev/stderr
		try_file_code "$1"
	# And some sites just had to go and use a JS obfuscator...
	elif [[ ! -z $(echo "$1" | grep ';eval(function(w,i,s,e)') ]]; then
		task "Extracting with unwise method" > /dev/stderr
		try_unwise "$1"
	elif [[ ! -z $(echo "$1" | grep 'function(p,a,c,k,e,d)') ]]; then
		task "Extracting with packed method" > /dev/stderr
		try_packed "$1"
	# Some providers have a weird addVariable setup
	elif [[ ! -z $(echo "$1" | grep 'addVariable(') ]]; then
		task "Extracting with addVariable method" > /dev/stderr
		try_addVar "$1"
	# We also have sites that do a nicer version of the *locker block
	elif [[ ! -z $(echo "$1" | grep "Close Ad and Watch as Free User") ]]; then
		task "Extracting with close method" > /dev/stderr
		try_close "$1"
	# And some sites try base64 "encryption"
	elif [[ ! -z $(echo "$1" | grep '<param value="setting=') ]]; then
		task "Extracting with base64 'decrypt'" > /dev/stderr
		try_base64 "$1"
	# The good old flashvars/player.api.php combo
	elif [[ ! -z $(echo "$1" | grep flashvars) ]]; then
		task "Extracting with player_api method" > /dev/stderr
		try_player_api "$1"
	# Gorillavid and others like JWPlayer with plugins
	elif [[ ! -z $(echo "$1" | grep 'jwplayer(') ]]; then
		task "Extracting with jwplayer method" > /dev/stderr
		try_jwplayer "$1"
	# Form you have to click through maybe?
	elif [[ ! -z $(echo "$1" | grep 'input type="hidden"') ]]; then
		task "Bypassing form" > /dev/stderr
		try_downloadForm "$1"
	fi
}

edata=$(crl "$ourl")

comp "Parsing embed page $ourl" > /dev/stderr
pick "$edata"
if [[ $owned == 'true' && -z $(echo "$url" | sed 's/[a-f0-9]*//') ]]; then
	owned='false'
fi

if [[ $owned == 'false' ]]; then
	err "Found no streaming video on $ourl" > /dev/stderr
else
	if [[ -z $ofile ]]; then
		comp "Streaming video \e[1;36m$url" > /dev/stderr
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

	if [[ -z "$title" ]]; then
		title="unknown"
	fi
	f=$(printf "%b" "${title//%/\\x}")
	f="${f}.${ext}"

	if [[ $title == "unknown" ]]; then
		title="unknown title"
	fi
	title=$(printf "%b\n" "${title//%/\\x}")
	comp "Dowloading \e[1;36m$title" > /dev/stderr

	purl=$(printf "%b\n" "${url//%/\\x}")
	task "from \e[1;36m$purl" > /dev/stderr

	if [[ -n $ofile ]]; then
		f="${ofile}.${ext}"
	fi
	task "to \e[1;36m$f" > /dev/stderr
	if [[ -z $socks ]]; then
		exec curl -C - -L "$url" -o ./"$f"
	else
		exec curl -C - -L --socks "$socks" "$url" -o ./"$f"
	fi
fi
