try_jwplayer() {
	url=`echo "$1" | grep -P "file: *\"| file: *'" | tr "'" '"' | sed 's/.*file: *"\([^"]*\)".*/\1/' | sort -u | head -n 1`

	if [[ -z "$url" ]]; then
		echo "Did not find JW player file argument" > /dev/stderr
		return
	fi

	m=$(echo "$url" | grep :)
	if [[ -z "$m" ]]; then
		echo "Decrypting filename '$url'" > /dev/stderr

		# get obc.swf which contains the key
		obc=$(echo "$1" | sed 's/.*\(http[^"]*asproject.swf\).*/\1/' | sed 's/asproject.swf/obc.swf/')
		tmp=$(mktemp obc.swf.XXXXXX)
		curl -s "$obc" > "$tmp"

		# extract key
		key=$(swfdump -D "$tmp" 2>/dev/null | grep -A4 'decryptor::h1' | grep String | sed 's/.*= //' | paste -sd' ' | tr -d ' ')
		echo -n "$key" > ~/.cache/streamsh-jwfile.key

		# determine encryption mode
		mode=$(swfdump -D "$tmp" 2>/dev/null \
			| grep -C1 "pushstring" \
			| grep -C3 "setlocal r4" \
			| grep -C2 "setlocal r5" \
			| grep pushstring \
			| sed 's/.*pushstring "\(.*\)"/\1/' \
			| head -n1
		)
		if [[ -z "$mode" ]]; then
			echo "Could not determine encryption mode :'(" > /dev/stderr
			return
		fi
		cipher=$(echo "$mode" | sed 's/simple-//' | awk -F- '{print $1}')
		chain=$(echo "$mode" | awk -F- '{print $NF}')
		bits=$(echo -n "$key" | wc -c)
		bits=$(echo "$bits*4" | bc -l)
		rm "$tmp"

		# get binary data
		(echo -n "$url" | xxd -r -p; echo "") > ~/.cache/streamsh-jwfile.aes

		# decrypt
		echo "Decrypting with $cipher-$bits-$chain and key '$key'" > /dev/stderr
		dec=$(
			(echo -n "$url" | xxd -r -p; echo "") \
			| base64 --wrap=0 \
			| openssl enc -d -A -base64 -${cipher}-${bits}-${chain} -K "$key" \
			2>/dev/null
		)
		m=$(echo "$dec" | grep :)
		if [[ -z "$m" ]]; then
			echo "Damn..." > /dev/stderr
			return
		fi
		url="$dec"
		echo "Decrypted to $dec" > /dev/stderr
	fi

	title="unknown-series-$$"
	owned="true"
}
