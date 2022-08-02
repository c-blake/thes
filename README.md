Overview
--------

This is a Nim thesaurus CLI/library & suite of analyzer utilities inspired by
[Moby Thesaurus input data](https://github.com/words/moby/raw/master/words.txt).

Setup
-----

Basic usage is to compile `thes` (which depends on `grAlg` & `cligen`) and put
it somewhere in your $PATH.  `nimble install thes` may do this.  Then, you
download & save the mentioned `words.txt` file and:
```sh
$ mkdir $HOME/.config/thes
$ cat > $HOME/.config/thes/config <<EOF
base  = "/u/cb/.config/thes/m"   # m for Moby
limit = 150     # Past this many matches..
types = xRef    #..only show these types.
EOF
# The /dev/null blocks "server/shell/CLI mode"
$ thes -i words.txt -b $HOME/.config/thes/m </dev/null
```

Usage
-----

With all of the above, you are now ready for various use cases.  The basic
functionality is seen by something like just:
```
$ thes amuse
beguile    entertain    please    tickle      charm      interest       recreate
convulse   exhilarate   refresh   titillate   cheer      quicken
delight    kill         regale    while       enchant    wile
distract   knock dead   relax     wow         engross    fracture one
divert     loosen up    slay      absorb      fascinate  raise a laugh
enliven    occupy       solace    animate     fleet      raise a smile
```
The (note -- *alphabetical*) block from "absorb".."wile" is hopefully rendered
differently than each before/after block.  This rendering shows the various
kinds of synonym that Moby defines: **reciprocal** ("beguile" lists "amuse" as a
synonym), **defined** ("absorb" has synonyms, but "amuse" is not one of them),
and **undefined** ("recreate" has no synonym list in Moby).

Deeper
------

To do deeper analysis, one can also `nimble install`
[grAlg](https://github.com/c-blake/gralg) and use utility programs in `util/`.

E.g., to create 4 undirected/reciprocal variants of the pre-parsed data (you
could, of course, also pre-compile `symmSyn`):
```sh
$ for kind in r d u a; do
  nim r -d:danger util/symmSyn -a $kind < words.txt > adj.txt
  thes -i adj.txt -b $HOME/.config/thes/$kind < /dev/null
  rm adj.txt
done
```
Now you can point `thes` or various `util/` programs to `--base
~/.config/thes/[rdua]` for various styles of undirected thesaurus.  For
example..

compon
------

```sh
nim r -d:danger util/compon r
```
shows connected components of the reciprocally synonymous thesaurus.  That means
words are reachable from each other via multiple "hops" like the 3 hops for:
"hello" is synonymous with "address" is synonymous with "valedictory" is
synonymous with "farewell".

synoPath
--------

The simple "hello"-"farewell" example, connecting something to its *opposite*,
begins to explain why almost the entire thesaurus is in one large connected
component.  You can find many such examples of short synonymity paths (by two
different graph algorithms) by running:
```sh
nim r -d:danger util/synoPath bad good
```
(I get just 2 hops here: "bad"-"OK"-"good".)  Besides
[random graph theory](https://en.wikipedia.org/wiki/Random_graph) and the high
connectivity in a typical thesaurus, this is probably due to something deep
about sarcasm in human language (especially applied to extremes like "very
something") as well as the aims of thesaurus construction.

diam
----

The short paths between words and their literal opposites may make you curious
about the diameter of the giant component of the undirected graph.  This maximum
shortest path is akin to the "6" in the "six" degrees of separation game ("Kevin
Bacon starred in a movie with XYZ").

Finding the guaranteed correct diameter is expensive since the number of pairs
of words is quite large, but you can get a quick approximation (running in
parallel) with:
```sh
nim r -d:danger util/diam r 20 4
```
The approximation is to pick a random word with at least 20 synonyms (which is
overwhelmingly likely to be in the giant component) and then find the length of
the shortest path from that word to every other word.  The program prints out
word pairs which you can then look at in more detail with `synoPath`.  You can
also use a first run as the basis for "seed" further runs starting with the
words you ended with last time - and as such more likely than random to be on
a "thin fringe" in the graph, like `diam r niacin 4` gives me a diameter
estimate of 9.
