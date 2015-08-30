try_jwplayer() {
	url=`echo "$1" | grep -P "file: *\"| file: *'" | tr "'" '"' | sed 's/.*file: *"\([^"]*\)".*/\1/' | sort -u | head -n 1`

	if [[ -z "$url" ]]; then
		echo "Did not find JW player file argument" > /dev/stderr
		return
	fi

	m=$(echo "$url" | grep :)
	if [[ -z "$m" ]]; then
		echo "Decoding '$url'" > /dev/stderr

		# get obc.swf which contains the key
		obc=$(echo "$1" | sed 's/.*\(http[^"]*asproject.swf\).*/\1/' | sed 's/asproject.swf/obc.swf/')
		tmp=$(mktemp obc.swf.XXXXXX)
		curl -s "$obc" > "$tmp"

		# extract key
		key=$(swfdump -D "$tmp" 2>/dev/null | grep -A4 'decryptor::h1' | grep String | sed 's/.*= //' | paste -sd' ' | tr -d ' ')
		rm "$tmp"
		echo "$key" > .cache/prev-key

		# get binary data
		(echo -n "$url" | xxd -r -p; echo "") > .cache/prev-enc

		# decode
		dec=$(
			(echo -n "$url" | xxd -r -p; echo "") \
			| base64 --wrap=0 \
			| openssl enc -d -A -base64 -aes-128-ecb -K "$key" \
			2>/dev/null
		)
		m=$(echo "$dec" | grep :)
		if [[ -z "$m" ]]; then
			echo "Damn..." > /dev/stderr
			return
		fi
		url="$dec"
		echo "Decoded to $dec" > /dev/stderr
	fi

	title="unknown-series-$$"
	owned="true"
}
