import std/[os, times, memfiles], thes, grAlg

if paramCount() != 1:
  quit "Usage:\n\tmst BASE\nshow min chars spanning tree\n", 1
let th = thOpen("", getEnv("HOME", "/u/cb")/".config/thes/"/paramStr(1))

iterator wedges[I](th: Thes, u: I): (I, uint32) =
  for v in th.synos(th.word(u.I)[0]):
    yield (v.abs, th.word(v.abs)[0].size.uint32)

echo "Min Cost Spanning Tree"
for arc in minSpanTree(th, th.maxWRef.int, words, wedges):
  echo th.word(arc.src.abs)[0], "  ", th.word(arc.dst.abs)[0]
