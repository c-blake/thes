import std/[strutils, tables, sets, sugar, algorithm]
when not declared(File): import std/syncio
type
  Thes*   = Table[int32, HashSet[int32]]
  Adjust* = enum adjRecip="recip", adjDef="def", adjUndef="undef", adjAny="any"
  Format* = enum fmtKeyed="keyed", fmtOrdered="ordered"

var toStr*: seq[string]
var toNum*: Table[string, int32]
proc getId*(s: string): int32 =
  result = toNum.mGetOrPut(s, toStr.len.int32)
  if result == toStr.len: toStr.add s

iterator synLists*(f: File): (int, string) =
  var n = 0
  for line in f.lines:
    for wd in line.split ',':
      if wd.len > 0:
        yield (n, wd)
        inc n
    n = 0

proc makeSymmetric*(f: File, adjust=adjRecip): Thes =
  const nul = initHashSet[int32](20)
  var kn = 0i32
  for (n, wd) in f.synLists:
    if n == 0: kn = getId(wd)
    else: result.mgetOrPut(kn, nul).incl getId(wd)
  var toIncl: seq[(int32,int32)]        # To not edit `result` *while iterating*
  for kw, synSet in mpairs(result):
    var toExcl: seq[int32]              # To not edit `synSet` *while iterating*
    for syn in synSet:
      case adjust
      of adjRecip: 
        if   syn notin result     : toExcl.add syn
        elif kw  notin result[syn]: toExcl.add syn
      of adjDef  : 
        if   syn notin result     : toExcl.add syn
        elif kw  notin result[syn]: result[syn].incl kw
      of adjUndef: 
        if   syn notin result     : toIncl.add (syn, kw)
        elif kw  notin result[syn]: toExcl.add syn
      of adjAny: toIncl.add (syn, kw)
    for e in toExcl: synSet.excl e      # Apply collected edits in the small
  for (kw, syn) in toIncl:              #..and in the large
    result.mgetOrPut(kw, nul).incl syn
  if adjust == adjAny: return
  var toDel: seq[int32]
  for kw, synSet in result:             # Clean up any empty sets
    if synSet.len == 0: toDel.add kw
  for kw in toDel: result.del kw

proc symmSyn*(input="-", adjust=adjRecip, format=fmtKeyed) =
  ## `adjust` MobyThesaurus-like `input` to be reciprocally symmetric/undirected
  ## graph.  Provide output format to inspect/analyze "nearby" synonym clusters.
  let f  = if input == "-": stdin else: open(input)
  let th = f.makeSymmetric adjust
  for kw, syns in th:                        
    var ssyns = collect(for syn in syns: toStr[syn][0..^1])
    case format
    of fmtKeyed  : ssyns.sort; echo toStr[kw], ",", ssyns.join ","
    of fmtOrdered: ssyns.add toStr[kw][0..^1]; ssyns.sort; echo ssyns.join ","

when isMainModule:
  import cligen; dispatch symmSyn, help={
    "input" :  "Moby-Thesaurus words.txt like input; \"-\"=stdin",
    "adjust":"""recip: keep only as-is reciprocal synonyms
def  : add recip synonyms for defined words
undef: add recip synonyms for undefined words
any  : add recip synonyms for any ref at all""",
    "format":"""keyed  : output is like Moby; kw,syn1,syn2,..
ordered: all synonyms are sorted together"""}
