import std/[os, times, memfiles], thes, grAlg
template timeIt(label, stmt) =
  let t0 = epochTime(); stmt; echo epochTime() - t0, " sec ", label

if paramCount() != 3:
  quit "Usage:\n\tsynoPath BASE wordA wordB\nshows shortest paths\n", 1
let th = thOpen("", getEnv("HOME", "/u/cb")/".config/thes/"/paramStr(1))

iterator edges[I](th: Thes, u: I): I =
  for v in th.synos(th.word(u.I)[0]): yield v.abs

iterator wedges1[I](th: Thes, u: I): (I, uint32) =
  for v in th.synos(th.word(u.I)[0]): yield (v.abs, 1u32)

iterator wedges[I](th: Thes, u: I): (I, uint32) =
  for v in th.synos(th.word(u.I)[0]): yield (v.abs, th.word(v.abs)[0].size.uint32)

var b = th.find(paramStr(2).toMemSlice).int32
if b < 0: quit paramStr(2) & ": not found", 1
b = th.tab[b].kwR.int32

var e = th.find(paramStr(3).toMemSlice).int32
if e < 0: quit paramStr(3) & ": not found", 1
e = th.tab[e].kwR.int32

timeIt "Dijkstra Shortest Path":
  let pf = th.shortestPathPFS(th.maxWRef.int, b, e, words, wedges1)
for r in pf: echo "  ", th.word(r.abs)[0]

timeIt "Dijkstra Hot Cache":
  discard th.shortestPathPFS(th.maxWRef.int, b, e, words, wedges1)

timeIt "Breadth First Search":
  let bf = th.shortestPathBFS(th.maxWRef.int, b, e, edges)
for r in bf: echo "  ", th.word(r.abs)[0]

timeIt "Dijkstra Min Chars Path":
  let mc = th.shortestPathPFS(th.maxWRef.int, b, e, words, wedges)
for r in mc: echo "  ", th.word(r.abs)[0]
