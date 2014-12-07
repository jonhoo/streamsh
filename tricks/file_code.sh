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
