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
		echo "Seems this file has been deleted :'(" > /dev/stderr
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
