`v8(1)` — Option reference for V8's debugging shell
===================================================
Manual page for the `--help` output of V8's debugging shell, [D8][].

Reformatted and proof-read with an unrealistic attention to detail,
exhumed from my [dotfiles][] so V8 devs have an elevated chance of
happening across a *possibly* useful document whilst googling.


Installation
------------
Just use [`curl(1)`][] or [`wget(1)`][] `v8.1` into any directory in your `MANPATH`:

~~~console
λ curl https://git.io/Jes6h > /usr/local/share/man/man1/v8.1
~~~

Or clone this repository locally, symlink or prepend it to your `MANPATH`,
print out a [spiffy PDF version][v8.1.pdf], photocopy it a thousand times
and mummify your co-worker... the usual.

> **NOTE:** [`d8.1`](./d8.1) is just an alias for [`v8.1`](./v8.1), so that
> `man d8` displays `man v8` instead of an error. Installing it is optional.


Updating
--------
Updates are semi-automatic; most of the changes to the original `--help` output
are literary in nature. A [Perl script](./update.pl) is used to automate (most)
of the proof-reading and reformatting necessary for the material to flow and
read like an actual man page.

V8's options change very often, so each new release is guaranteed to involve an
ad-hoc bunch of changes to the update-script, as well as manually reviewing and
correcting the diff before (eventually) committing and pushing the results.

**In short, it's a tedious pain-in-the-arse** I don't expect anybody to take
seriously. Or notice/care about, for that matter.


[D8]: https://v8.dev/docs/d8
[dotfiles]: https://github.com/Alhadis/.files
[v8.1.pdf]: https://github.com/Alhadis/V8.man/blob/d5bbafe322/v8.1.pdf
[`curl(1)`]: https://linux.die.net/man/1/curl
[`wget(1)`]: https://linux.die.net/man/1/wget
