This script aims to show how simple it is to undo protection that video sharing
sites apply to their code to try and hide the realing underlying streaming url.
A trivial way of doing this would be to open your browser, open the developer
tools and look at the network requests when you start playing a video for a
`.flv` or `.mp4` file.

This script takes that a step further by using `curl` to obtain the HTML for an
embed page and then extracts the real streaming url (sometimes through several
steps) using mostly standard UNIX tools
([`pup`](https://github.com/EricChiang/pup) is probably the odd one out). If
you want to have something more reliable, comprehensive or well-maintained,
have a look at [quvi](http://quvi.sourceforge.net/) or
[youtube-dl](https://rg3.github.io/youtube-dl/). This is mostly just a
proof-of-concept showing that in most cases simple UNIX tools can do the job.

The script is invoked just with the embed URL for the video you want to play,
and optionally a filename (without the extension) to use for the resulting
file. By default, the video will be downloaded to the current directory, but
you can also set `PLAY=1` in your environment to have it play using mpv
directly.

If no url can be extracted (if the site isn't supported for example), then a
browser window will be spawned instead.

The script also supports running through a SOCKS5 proxy. Just start your proxy:

    ssh -fND localhost:someport -C me@myserver

And the script should pick it up automatically and use it.
