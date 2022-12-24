{.push hint[Performance]: off.}
import std/[os, memfiles], thes, grAlg
if paramCount() < 1:
  quit "Usage:\n\tcompon BASE\nshow graph components", 1

let th = thOpen("", getEnv("HOME", "/u/cb")/".config/thes/"/paramStr(1))

iterator edges[I](th: Thes, u: I): I =
  for v in th.synos(th.word(u.I)[0]): yield v.abs

for cc in values(th.unDirCompons(th.maxWRef.int,words,edges)):
  if cc.len < 100:
    echo "Component:"
    for elt in cc: echo "  ", th.word(elt.int32.abs)[0]
  else:
    echo "Component: ", cc.len, " words"

echo th.unDirComponSizes(th.maxWRef.int, words, edges)
