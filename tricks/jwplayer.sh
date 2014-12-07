try_jwplayer() {
	url=`echo "$1" | grep -E "file: \"| file: '" | tr "'" '"' | sed 's/.*file: "\([^"]*\)".*/\1/' | sort -u | head -n 1`

	if [[ -z $url ]]; then
		echo "Did not find JW player file argument"
		return
	fi

	title="unknown-series-$$"
	owned="true"
}
