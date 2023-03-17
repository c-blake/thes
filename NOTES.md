SYMMETRY
========
As conceived, this program highlights rather than second guesses human
(mis)judgement.  Some users may prefer symmetry of "synonymity" to override.
Such users can use the below small program to pre-process a "words.txt":

```Python
import strutils,tables,sets,algorithm,sugar |from sys import stdin
var th = initTable[string,HashSet[string]]()|th = {}
var kw: string                              |kw = ""
for line in stdin.lines:                    |for line in stdin:
  for w in line.split ',':                  |  for w in line.strip().split(","):
    if w.len > 0: #stray EOL ','s in Moby   |    if len(w) > 0: #stray EOL ','s
      if kw.len == 0: kw = w                |      if len(kw) == 0: kw = w
      else:                                 |      else:
        try   : th[kw].incl w               |        try   : th[kw].add(w)
        except: th[kw] = @[ w ].toHashSet   |        except: th[kw] = set([w]) # strings are iterable!
        try   : th[w].incl kw               |        try   : th[w].add(kw)
        except: th[w] = @[ kw ].toHashSet   |        except: th[w] = set([kw]) # strings are iterable!
  kw.setLen 0                               |  kw = ""
for kw, syns in th:                         |for (kw, syns) in th.items():
  var ssyns = collect(for syn in syns: syn) |  ssyns = [ syn for syn in syns ]
  ssyns.sort                                |  ssyns.sort()
  echo kw, ",", ssyns.join ","              |  print(kw + "," + ",".join(ssyns))
```

This program is basically a special case of util/symmSyn.nim.  Above, the Nim is
barely faster than Py.  Having done this, such users may want plain=on in their
~/.config/thes.  If this winds up being the popular way to conceive the problem,
ditching the <0 checks & highlighting makes more sense.  Symmetry enforcement
makes semantic clusters *more* complete, but not as much as you might like.
Some rule (eg. edit distance) for merging is needed.

COSTS
=====
On more optimizing: for a thesaurus, most lookups are likely for present keys.
While it's possible & maybe pedagogical (but see adix/lptabz), Robin-Hood will
mostly only reduce variance in full tables.  30259 lists w/103307 uniq words =>
indeed 92%Full in 128k w/4B TabEnt.  RH can tolerate 1..2 bits of lost hash, but
15-11=4 => 16-way collisions.  Can recover base case w/1 more file to do wordNum
not byte offset for 21->17 bits.

For Moby & stdlib Murmur base case, 128k=>6.7 avg cmps, 607 max and 256k=>1.43
avg & 17 max; Missing keys are ~ 2X worse.  That may sound bad, but whole table
build time is only 1.3x slower @128 than @256 (not 6.7/1.43=4.7x; Locality & cmp
prefix HELP).  2.5% speed-up from 256k -> 512k indicates current way is already
fast spilling to L3, as it should be (& Intel's moving to 512k L2s..).

Concluding, if worst cases worry you, 256k table is likely "enough", and if
SPACE worries you the biggest boost is words_sL.Ni -> adix/sequint of 18-bit
numbers.  (Latter would shrink 10201912 -> 5738576 bytes, taking total data from
11645237 to 7181901.  For comparison, gzip -9 words.txt gives 9268616, while
zstd -19 => 4264812; 1.3x smaller than gzip is not bad.)
