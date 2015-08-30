try_file_code() {
	fields=$(echo "$1" | pup 'input[name]' | crld)
	content=$(crl "$url" $(echo $fields))
	if [[ -n $(echo "$content" | grep "was deleted") ]]; then
		echo "Seems this file has been deleted :'(" > /dev/stderr
		exit 2
	fi
	pick "$content"
}
