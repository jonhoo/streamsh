try_downloadForm() {
	form=$(echo "$1" | pup 'form[method=POST],form[method=post]')

	if [ -z "$form" ]; then
		return 0
	fi

	# Accumulate form data
	args=()

	# Some sites like to inject extra fields through JS
	while read -r L; do
		key=$(echo "$L" | sed "s/^.*name['\"]* *: *['\"]\([^'\"]*\).*/\1/")
		val=$(echo "$L" | sed "s/^.*value['\"]* *: *['\"]\([^'\"]*\).*/\1/")
		args=("${args[@]}" "-F$key=$val")
	done < <(echo "$1" | grep "<input/>" | grep "hidden")

	i=1
	while :; do
		key=$(echo "$form" | pup "input[type=hidden]:nth-of-type($i) attr{name}")
		val=$(echo "$form" | pup "input[type=hidden]:nth-of-type($i) attr{value}")

		if [ -z "$key" ]; then
			break
		fi
		args=("${args[@]}" "-F$key=$val")
		i=$(echo "$i+1" | bc -l)
	done

	sub=$(echo "$form" | pup '[type=submit] attr{name}')
	if [ -n "$sub" ]; then
		subv=$(echo "$form" | pup '[type=submit] attr{value}')
		args=("${args[@]}" "-F$sub=$subv")
	fi

	action="$(echo "$form" | pup 'form attr{action}')"
	if [ -z "$action" ]; then
		action="$url"
	elif grep -P '^https?://' <(echo "$action"); then
		# absolute
		:
	elif grep -E '^/' <(echo "$action"); then
		# relative to root
		action="$(echo "$url" | sed 's@^\(https\?://[^/]*\).*@\1@')$action"
	else
		# relative
		action="$(dirname "$url")/$action"
	fi
	pick "$(crl "${args[@]}" "$action")"
}
