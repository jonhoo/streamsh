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
