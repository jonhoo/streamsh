try_base64() {
	b64_1=$(echo "$1" | pup 'param[name=FlashVars]' | sed 's/^.*value="setting=\([^"]*\)".*/\1/')
	settings_url=$(echo "$b64_1" | base64 --decode)
	settings=$(crl "$settings_url")
	title=$(echo "$settings" | jq -r .settings.video_details.video.title)
	b64_2=$(echo "$settings" | jq -r .settings.res[0].u)
	url=$(echo "$b64_2" | base64 --decode)
	owned="true"
}
