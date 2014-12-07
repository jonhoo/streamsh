#!/bin/bash

if [[ $# -lt 1 ]]; then
	echo "$0 <embed-url> [filename]"
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
	echo "Detected SOCKS proxy on $addr"
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

# We need a fallback
give_up() {
	if [[ -z $socks ]]; then
		chromium $ourl
	else
		chromium "--proxy-server=socks5://$socks" $ourl
	fi
	exit 1
}

try_share() {
	if [[ -n $(echo "$1" | grep -i "File Does not Exist, or Has Been Removed") ]]; then
		echo "Seems this file has been deleted :'("
		exit 2
	fi

	title=`echo "$1" | grep "<title>" | sed 's/^[^-]\+- \(.*\)<\/title>.*/\1/'`
	domain=`echo "$url" | sed 's/^\(https*:\/\/[^\/]*\).*/\1/'`
	token=`echo "$1" | grep 'name="fuck_you"' | sed 's/^.*value="\([^"]*\)".*/\1/'`
	real=$(crl "$url" -d "fuck_you=$token" -d "confirm=Close Ad and Watch as Free User")
	if [[ $? -gt 0 ]]; then
		echo "Failed to post token '$token' from '$1'"
		echo "$real"
		return
	fi

	if [[ -z $real ]]; then
		echo "No data from token post"
		return
	fi

	file=`echo "$real" | grep '/get_file.php' | sed "s/^.*\\(\\/get_file.php[^']*\)'.*/\\1/"`

	if [[ -z $file ]]; then
		if [[ -n $(echo "$real" | grep "You have exceeded") ]]; then
			echo "Ooops - seems we've exceeded our limits for today..."
			exit 2
		fi

		echo "Could not extract get_file.php path from:"
		echo "$real"
		return
	fi

	xml=$(crl "$domain$file")
	if [[ $? -gt 0 ]]; then
		echo "Failed to get xml from '$domain$file'"
		return
	fi

	u=`echo "$xml" | sed 's/^.*media:content url="\(http:\/\/cdn[^"]\+\)".*/\1/'`
	if [[ -z $u ]]; then
		echo "Could not extract video url from xml:"
		echo "$xml"
	fi

	url="$u"
	owned="true"
}

try_close() {
	domain=`echo "$url" | sed 's/^\(https*:\/\/[^\/]*\).*/\1/'`
	file_id=$(echo "$1" | grep "'file_id', '" | sed "s/.*'file_id', '\\([^']*\\)'.*/\1/")
	nurl=$(echo "$url" | sed 's/-[0-9]\+x[0-9]\+\././')
	content=$(
		echo "$1" | pup 'input[name]' | crld | {
			readarray -t fields;
			crl "$nurl" -e "$url" -G "${fields[@]}" --cookie file_id=$file_id
		}
	)

	if [[ -n $(echo "$content" | grep "deleted") ]]; then
		echo "Seems this file has been deleted :'("
		exit 2
	fi

	if [[ -z $(echo "$content" | grep "(p,a,c,k,e,d)") ]]; then
		try_jwplayer "$content"
		return
	fi
	content=$(echo "$content" | grep "function(p,a,c,k,e,d)" | grep "allowfullscreen" | sed 's/<script[^>]*>//' | sudo ~/bin/unval.js)

	sep="'"
	if [[ -n $(echo "$content" | grep ',file:"') ]]; then
		sep='"'
	fi

	url=$(echo "$content" | sed "s/.*,file:${sep}\\([^${sep}]*\\)${sep}.*/\\1/")
	owned="true"
}

try_player_api() {
	fv=$(echo "$1" | grep flashvars | sed 's/;/;\n/g')
	domain=`echo "$fv" | grep domain | sed 's/^.*="\(.*\)";/\1/'`
	file=`echo "$fv" | grep "file=" | sed 's/^.*="\(.*\)";/\1/'`
	filekey=`echo "$fv" | grep -P 'filekey\s*=\s*"' | sed 's/^.*="\(.*\)";/\1/' | sed 's/\./%2E/g'`

	if [[ -z $filekey ]]; then
		var=`echo "$fv" | grep filekey | sed 's/^.*= *\(.*\) *;/\1/'`
		filekey=`echo "$1" | sed 's/;/;\n/g' | grep -P "$var\\s*=" | sed 's/^.*="\(.*\)";/\1/' | sed 's/\./%2E/g'`
	fi

	if [[ -z $domain || -z $file || -z $filekey ]]; then
		echo "Did not find all player.api flash vars :("
		return
	fi

	config=$(crl "$domain/api/player.api.php?key=$filekey&file=$file")
	if [[ $? -gt 0 ]]; then
		echo "Could not contact player api at '$domain/api/player.api.php?key=$filekey&file=$file'"
		return
	fi

	if [[ ${config:0:4} != "url=" ]]; then
		echo "Bad reply from player api at"
		echo "$domain/api/player.api.php?key=$filekey&file=$file"
		echo $config
		return
	fi

	url=`echo "$config" | cut -d'&' -f1 | sed 's/^[^=]*=//'`
	title=`echo "$config" | cut -d'&' -f2 | sed 's/^[^=]*=//'`
	owned="true"
}

try_base64() {
	b64_1=$(echo "$1" | pup 'param[name=FlashVars]' | sed 's/^.*value="setting=\([^"]*\)".*/\1/')
	settings_url=$(echo "$b64_1" | base64 --decode)
	settings=$(crl "$settings_url")
	title=$(echo "$settings" | jq -r .settings.video_details.video.title)
	b64_2=$(echo "$settings" | jq -r .settings.res[0].u)
	url=$(echo "$b64_2" | base64 --decode)
	owned="true"
}

try_jwplayer() {
	url=`echo "$1" | grep -E "file: \"| file: '" | tr "'" '"' | sed 's/.*file: "\([^"]*\)".*/\1/' | sort -u | head -n 1`

	if [[ -z $url ]]; then
		echo "Did not find JW player file argument"
		return
	fi

	title="unknown-series-$$"
	owned="true"
}

try_file_code() {
	fields=$(echo "$1" | pup 'input[name]' | crld)
	content=$(crl "$url" $(echo $fields))
	if [[ -n $(echo "$content" | grep "was deleted") ]]; then
		echo "Seems this file has been deleted :'("
		exit 2
	fi
	if [[ -z $(echo "$content" | grep "function(p,a,c,k,e,d)" | grep "allowfullscreen") ]]; then
		return
	fi
	pick "$content"
}

try_addVar() {
	sep="'"
	if [[ -n $(echo "$1" | grep 'addVariable("') ]]; then
		sep='"'
	fi

	url=$(echo "$1" | sed "s/.*addVariable(${sep}file${sep},${sep}\\([^${sep}]*\\)${sep}).*/\\1/")
	owned="true"
}

# We have obfuscated code
# Use unval.js to unobfuscate, and then just run again on the result
# Get unval.js from https://gist.github.com/jonhoo/7183805
try_unwise() {
	e=$(echo "$1" | grep "function(w,i,s,e)" | sudo ~/bin/unval.js)
	pick "$e"
}
try_packed() {
	e=$(echo "$1" | grep "function(p,a,c,k,e,d)" | grep "allowfullscreen" | sed 's/<script[^>]*>//' | sudo ~/bin/unval.js)
	pick "$e"
}

pick() {
	echo "$1" > .cache/tvo-previous.html
	if [[ -n $(echo "$1" | grep -E "has been (deleted|removed)") ]]; then
		echo "The file has been removed :'("
		exit 2
	fi

	# The very classy protection used by sockshare/putlocker
	if [[ ! -z $(echo "$1" | grep '#propaganda') ]]; then
		echo "Extracting with *share method"
		try_share "$1"
	# 180upload uses a funky "captchaForm" without a captcha
	elif [[ ! -z $(echo "$1" | grep -E "name=('|\")file_code('|\")") ]]; then
		echo "Extracting with file_code method"
		try_file_code "$1"
	# And some sites just had to go and use a JS obfuscator...
	elif [[ ! -z $(echo "$1" | grep ';eval(function(w,i,s,e)') ]]; then
		echo "Extracting with unwise method"
		try_unwise "$1"
	elif [[ ! -z $(echo "$1" | grep 'function(p,a,c,k,e,d)') ]]; then
		echo "Extracting with packed method"
		try_packed "$1"
	# Some providers have a weird addVariable setup
	elif [[ ! -z $(echo "$1" | grep 'addVariable(') ]]; then
		echo "Extracting with addVariable method"
		try_addVar "$1"
	# We also have sites that do a nicer version of the *locker block
	elif [[ ! -z $(echo "$1" | grep "Close Ad and Watch as Free User") ]]; then
		echo "Extracting with close method"
		try_close "$1"
	# And some sites try base64 "encryption"
	elif [[ ! -z $(echo "$1" | grep '<param value="setting=') ]]; then
		echo "Extracting with base64 'decrypt'"
		try_base64 "$1"
	# The good old flashvars/player.api.php combo
	elif [[ ! -z $(echo "$1" | grep flashvars) ]]; then
		echo "Extracting with player_api method"
		try_player_api "$1"
	# Gorillavid and others like JWPlayer with plugins
	elif [[ ! -z $(echo "$1" | grep 'jwplayer(') ]]; then
		echo "Extracting with jwplayer method"
		try_jwplayer "$1"
	fi
}

pick "$(crl "$1")"
if [[ $owned == 'true' && -z $(echo "$url" | sed 's/[a-f0-9]*//') ]]; then
	owned='false'
fi

if [[ $owned == 'false' ]]; then
	echo "Found no known protection, running in browser"
	give_up
else
	if [[ -z $PLAY ]]; then
		ext=$(basename "$url" | sed 's/.*\.//')
		if [[ -z "$ext" || $(expr length "$ext") -gt 3 ]]; then
			ext=mp4
		fi

		f=$(printf "%b" "${title//%/\\x}")
		f="${f}.${ext}"
		echo -n "Downloading "
		printf "%b\n" "${title//%/\\x}"
		echo -n "       from "
		printf "%b\n" "${url//%/\\x}"
		if [[ -n $ofile ]]; then
			f="${ofile}.${ext}"
		fi
		echo -n "         to ./$f"
		if [[ -z $socks ]]; then
			exec curl -C - -L "$url" -o ./"$f"
		else
			exec curl -C - -L --socks "$socks" "$url" -o ./"$f"
		fi
	else
		echo -n "Playing "
		printf "%b\n" "${title//%/\\x}"
		echo -n "   from "
		printf "%b\n" "${url//%/\\x}"
		if [[ -z $socks ]]; then
			exec mpv "$url"
		else
			curl -L -s --socks "$socks" "$url" \
				| mpv --fs \
				--cache 204800 --cache-pause=3 --cache-min 3 --cache-seek-min 20 \
				--softvol=yes --softvol-max 200 -
		fi
	fi
fi
