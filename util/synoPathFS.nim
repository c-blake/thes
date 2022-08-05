import std/[os, times, tables, sets], symmSyn, grAlg # synonym path From Scratch
template timeIt(label, stmt) =
  let t0 = epochTime(); stmt; echo epochTime() - t0, " sec ", label

if paramCount() < 2:
  quit "Usage:\n\tsynoPathFS wordA wordB < words.txt\nshows shortest paths\n", 1
timeIt "Thesaurus Build": (let th = stdin.makeSymmetric adjRecip)

iterator nodes(th: Thes): int32 =
  for i in 0i32 ..< toStr.len.int32: yield i

iterator edges(th: Thes, u: int32): int32 =
  for v in th[u]: yield v

iterator wedges1(th: Thes, u: int32): (int32, uint32) =
  for v in th[u]: yield (v, 1u32)

iterator wedges(th: Thes, u: int32): (int32, uint32) =
  for v in th[u]: yield (v, toStr[v].len.uint32)

let b = getId(paramStr(1))
let e = getId(paramStr(2))

timeIt "Dijkstra Shortest Path":
  let pf = th.shortestPathPFS(toStr.len, b, e, nodes, wedges1)
for r in pf: echo "  ", toStr[r]

timeIt "Dijkstra Hot Cache":
  discard th.shortestPathPFS(toStr.len, b, e, nodes, wedges1)

timeIt "Breadth First Search":
  let bf = th.shortestPathBFS(toStr.len, b, e, edges)
for r in bf: echo "  ", toStr[r]

timeIt "Dijkstra Min Chars Path":
  let mc = th.shortestPathPFS(toStr.len, b, e, nodes, wedges)
for r in mc: echo "  ", toStr[r]
