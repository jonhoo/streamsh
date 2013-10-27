#!/bin/bash

<<EOC
Hello,

This script aims to show how simple it is to undo protection that video sharing
sites apply to their code to try and hide the realing underlying streaming url.
A trivial way of doing this would be to open your browser, open the developer
tools and look at the network requests when you start playing a video for a .flv
or .mp4 file.

This script takes that a step further by using curl to obtain the HTML for an
embed page and then extracts the real streaming url (sometimes through several
steps) using mostly standard UNIX tools. If you want to have something more
reliable, comprehensive or well-maintained, have a look at quvi or youtube-dl.
This is just a proof-of-concept showing that in most cases simple UNIX tools can
do the job.

The script is invoked just with the embed URL for the video you want to play.
By default, the video will be downloaded to your home directory, but you can
also set PLAY=1 in your environment to have it play using mpv directly.

If no url can be extracted (if the site isn't supported for example), then a
browser window will be spawned instead.

The script also supports running through a SOCKS5 proxy. Just start your proxy:

    ssh -fND localhost:someport -C me@myserver

And the script should pick it up automatically and use it.
EOC

if [[ $# -ne 1 ]]; then
  echo "$0 <embed-url>"
  exit 1
fi

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

# We need a fallback
give_up() {
  if [[ -z $socks ]]; then
    chromium $url
  else
    chromium "--proxy-server=socks5://$socks" $url
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

  u=`echo "$xml" | sed 's/^.*media:content url="\(http:\/\/cdn\.[^"]\+\)".*/\1/'`
  if [[ -z $u ]]; then
    echo "Could not extract video url from xml:"
    echo "$xml"
  fi

  url="$u"
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

try_jwplayer() {
  url=`echo "$1" | grep -E "file: \"| file: '" | tr "'" '"' | sed 's/.*file: "\([^"]*\)".*/\1/' | sort -u | head -n 1`

  if [[ -z $url ]]; then
    echo "Did not find JW player file argument"
    return
  fi

  title="unknown-series-$$"
  owned="true"
}

# We have obfuscated code
# Use unval.js to unobfuscate, and then just run again on the result
# Get unval.js from https://gist.github.com/jonhoo/7183805
try_unwise() {
  e=$(echo "$1" | grep "function(w,i,s,e)" | sudo ~/bin/unval.js)
  pick "$e"
}

pick() {
  # The good old flashvars/player.api.php combo
  if [[ ! -z $(echo "$1" | grep flashvars) ]]; then
    try_player_api "$1"
  # The very classy protection used by sockshare/putlocker
  elif [[ ! -z $(echo "$1" | grep '#propaganda') ]]; then
    try_share "$1"
  # Gorillavid and others like JWPlayer with plugins
  elif [[ ! -z $(echo "$1" | grep 'jw_plugins') ]]; then
    try_jwplayer "$1"
  # And some sites just had to go and use a JS obfuscator...
  elif [[ ! -z $(echo "$1" | grep ';eval(function(w,i,s,e)') ]]; then
    try_unwise "$1"
  fi
}

pick "$(crl "$1")"

if [[ $owned == 'false' ]]; then
  echo "Found no known protection, running in browser"
  give_up
else
  if [[ -z $PLAY ]]; then
    f=$(printf "%b" "${title//%/\\x}")
    f="${f}.$(echo "$url" | sed 's/.*\.//')"
    echo -n "Downloading "
    printf "%b\n" "${title//%/\\x}"
    echo -n "       from "
    printf "%b\n" "${url//%/\\x}"
    echo -n "         to ~/Downloads/$f"
    if [[ -z $socks ]]; then
      exec curl -C - -L "$url" -o ~/"$f"
    else
      exec curl -C - -L --socks "$socks" "$url" -o ~/"$f"
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
