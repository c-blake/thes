when not declared(Thread): import std/threads
import std/[os, memfiles, random, parseutils, deques], thes, grAlg, cligen/sysUt
randomize()
if paramCount() != 3:
  quit "Usage:\n\tdiam BASE maxDeg|word [nJobs]\nestimate diameter\n", 1
let th = thOpen("", getEnv("HOME", "/u/cb")/".config/thes/"/paramStr(1))
var maxDeg, nJobs: int
var s = rand(th.tabSz).int32
if parseInt(paramStr(2), maxDeg) == paramStr(2).len:
  while th.tab[s].kwR == 0 or th.degree(s) > maxDeg:
    s = rand(th.tabSz).int32
else:
  s = th.find(paramStr(2).toMemSlice).int32
  if s < 0: quit paramStr(2) & ": not found", 2
s = th.tab[s].kwR.int32
if paramCount() > 2:
  discard parseInt(paramStr(3), nJobs)

iterator edges[I](th: Thes, u: I): I =
  for v in th.synos(th.word(u.I)[0]):
    yield v.abs         # 20% of run-time in `abs`; May just be 1st load

# True diameter is a big calc; Estimate by mx dist from random to all others.
echo "Diameter Estimation"

proc wk(modulus: int) {.thread.} =
  var did  = newSeqNoInit[bool](th.maxWRef.int)
  var pred = newSeqNoInit[int32](th.maxWRef.int)
  var q    = initDeque[int32](32)
  var mx = 0
  for i, e in enumerate(th.words):
    if i mod nJobs == modulus:
      if e != s:
        let p = th.shortestPathBFS(th.maxWRef.int, s, e, edges, did, pred, q)
        if p.len > mx:
          mx = p.len
          echo "max: ",mx," B\\tE: ",th.word(s.abs)[0],"\t",th.word(e.abs)[0]

var ts = newSeq[Thread[int]](nJobs)
for i in 0 ..< nJobs: createThread ts[i], wk, i # spawn workers
joinThreads ts
