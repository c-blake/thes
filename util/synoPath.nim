import std/[os, times, memfiles], thes, grAlg
template timeIt(label, stmt) =
  let t0 = epochTime(); stmt; echo epochTime() - t0, " sec", label

if paramCount() != 3: quit "Usage:\n\tsynoPath2 BASE wordA wordB\nshows a shortest path\n", 1
let th = thOpen("", getEnv("HOME", "/u/cb")/".config/thes/"/paramStr(1))

iterator edges[I](th: Thes, u: I): I =
  for v in th.synos(th.word(u.I)[0]): yield v.abs

var b = th.find(paramStr(2).toMemSlice).int32
if b < 0: quit paramStr(2) & ": not found", 1
b = th.tab[b].kwR.int32

var e = th.find(paramStr(3).toMemSlice).int32
if e < 0: quit paramStr(3) & ": not found", 1
e = th.tab[e].kwR.int32

timeIt(" Dijkstra Shortest Path"):
  let pf = th.shortestPathPFS(uint32, th.maxWRef.int, b, e, words, edges)
for r in pf: echo "  ", th.word(r.abs)[0]
timeIt(" Breadth First Search"):
  let bf = th.shortestPathBFS(th.maxWRef.int, b, e, edges)
for r in bf: echo "  ", th.word(r.abs)[0]
