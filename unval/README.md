This file undoes any JavaScript obfuscation done by the [PHP JavaScript
Obfuscator produced by
Wiseloop](http://www.wiseloop.com/product/php-javascript-obfuscator) and
similar obfuscators.

Code obfuscated by this tool can easily be recognized by looking for any code
that starts with:

    ;eval(function(w,i,s,e){

and is followed by some JS code and then a long string. Other code obfuscation
tools that use similar constructs can also be decoded by this tool.

It does this to show that trying to hide JavaScript code is a futile effort
which is trivially countered by simply executing the code.

This script uses eval through NodeJS, which is a potentially harmful operation.
To counter the possible security implications of this, this script attempts to
drop its privileges to the user 'nobody'. Unfortunately, this requires root
privileges, and so, unintuitively, *you should run this script as root for
maximum security!*

To ensure nothing fishy is going on, you may want to change your sudoers file
to allow non-password sudo execution of this file ONLY when the file matches a
hash. Look at the manpage for `sudoers(5)` for details on how to do this.
