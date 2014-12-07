# We have obfuscated code
# Use unval.js to unobfuscate, and then just run again on the result
unval="$(dirname "$(readlink -f "$0")")/unval/unval.js"
try_unwise() {
	e=$(echo "$1" | grep "function(w,i,s,e)" | sudo "$unval")
	pick "$e"
}
try_packed() {
	e=$(echo "$1" | grep "function(p,a,c,k,e,d)" | grep "allowfullscreen" | sed 's/<script[^>]*>//' | sudo "$unval")
	pick "$e"
}
