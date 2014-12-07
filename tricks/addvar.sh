try_addVar() {
	sep="'"
	if [[ -n $(echo "$1" | grep 'addVariable("') ]]; then
		sep='"'
	fi

	url=$(echo "$1" | sed "s/.*addVariable(${sep}file${sep},${sep}\\([^${sep}]*\\)${sep}).*/\\1/")
	owned="true"
}
