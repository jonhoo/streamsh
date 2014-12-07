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
		echo "Did not find all player.api flash vars :(" > /dev/stderr
		return
	fi

	config=$(crl "$domain/api/player.api.php?key=$filekey&file=$file")
	if [[ $? -gt 0 ]]; then
		echo "Could not contact player api at
		'$domain/api/player.api.php?key=$filekey&file=$file'" > /dev/stderr
		return
	fi

	if [[ ${config:0:4} != "url=" ]]; then
		echo "Bad reply from player api at" > /dev/stderr
		echo "$domain/api/player.api.php?key=$filekey&file=$file" > /dev/stderr
		echo $config > /dev/stderr
		return
	fi

	url=`echo "$config" | cut -d'&' -f1 | sed 's/^[^=]*=//'`
	title=`echo "$config" | cut -d'&' -f2 | sed 's/^[^=]*=//'`
	owned="true"
}
