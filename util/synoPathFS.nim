import std/[os, times, tables, sets], symmSyn, grAlg # synonym path From Scratch
template timeIt(label, stmt) =
  let t0 = epochTime(); stmt; echo epochTime() - t0, " sec", label

if paramCount() < 2: quit "Usage:\n\tpathSyno word1 word2 < wordsX.txt", 1
let th = stdin.makeSymmetric adjRecip

iterator nodes(th: Thes): int32 =
  for i in 0i32 ..< toStr.len.int32: yield i

iterator edges(th: Thes, u: int32): int32 =
  for v in th[u]: yield u

let b = getId(paramStr(1))
let e = getId(paramStr(2))
timeIt(" Dijkstra Shortest Path"):
  let pf = th.shortestPathPFS(uint32, toStr.len, b, e, nodes, edges)
for r in pf: echo "  ", toStr[r]
timeIt(" Breadth First Search"):
  let bf = th.shortestPathBFS(toStr.len, b, e, edges)
for r in bf: echo "  ", toStr[r]
