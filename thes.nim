# Other NIO file examples/use cases are primarily numerical, but similar ideas
# apply to text-oriented constructions, like this thesaurus program.  If you
# find yourself using this often, set up a ~/.config/thes with a cached build.

import system/ansi_c, std/[tables, os, math, hashes], std/memfiles as mf
let mfop = mf.open                      # Collides with system.open

# Boring boiler plate-y things that should be in stdlib (were that not so hard).
template pua(T: typedesc): untyped = ptr UncheckedArray[T]

proc `+%`[T: SomeInteger](p: pointer, i: T): pointer =
  cast[pointer](cast[int](p) +% i.int)

proc add[T: SomeInteger](f: var MemFile, ch: char, off: var T) =
  if off.int + 1 == f.size: f.resize f.size * 2
  cast[ptr char](f.mem +% off)[] = ch; inc off

proc add[T: SomeInteger](f: var MemFile, ms: MemSlice, off: var T) =
  if off.int + ms.size >= f.size: f.resize f.size * 2
  copyMem f.mem +% off, ms.data, ms.size; inc off, ms.size

proc toMemSlice*(a: string): MemSlice =
  result.data = a.cstring; result.size = a.len

proc removeFiles(paths: seq[string]) =
  for p in paths: (try: p.removeFile except: discard)

type # Core code is the ~108 non-comment lines after this to end of `thOpen`.
  TabEnt* {.packed.} = object   # 11,21 work for Moby; May need >21 for bigger.
    kwH {.bitsize: 11.}: uint16         # Partial keyword hash as cmp prefix
    kwR* {.bitsize: 21.}: uint32        # Ref(byte offset) into uniq words file
  Thes* = object # order: keyPtr, keyData, valPtr, valData
    tabM, uniM, synM, synsM: MemFile    # MemFiles: Tab, Uniq, SynR, SynLists
    tab*: pua TabEnt                    # Keyword Table in mapped memory
    tabSz*: int                         # Size of Table (in TabEnt units)
#NOTE: tabM & synM share indexing.  Separated so that tabM is more cachable.

proc word*(th: Thes, i: int32): (MemSlice, bool) = # len < 0 => a keyword
  ## Return an MemSlice & keywordOrNot bool from a unique word number.
  let len = cast[ptr int8](th.uniM.mem +% i)[].int
  result[0].size = abs(len)
  result[0].data = th.uniM.mem +% (i + 1)
  result[1] = len < 0

proc find*(th: Thes, w: MemSlice, hsp: ptr uint16 = nil): int =
  let msk = th.tabSz - 1                # Vanilla linear probe hash search
  let h  = hashData(w.data, w.size)     # Hash the key
  let hs = uint16(h and ((1 shl 11)-1)) # Comparison prefix mask
  var i  = h and msk                    # Initial probe
  while (let j = th.tab[i].kwR.int; j != 0):
    if th.tab[i].kwH == hs and          # Match masked hash,then len,then memcmp
       abs(cast[ptr int8](th.uniM.mem +% j)[]) == w.size and
       c_memcmp(th.uniM.mem +% (j + 1), w.data, w.size.csize_t) == 0:
         return i
    i = (i + 1) and msk                 # The linear part of linear probing
  if not hsp.isNil: hsp[] = hs          # Optional hash suffix return for `make`
  return -i - 1                         # Not Found, return -(insertion point)-1

iterator synos*(th: Thes, ws: MemSlice): int32 =
  ## Yield word numbers of synonyms; < 0 => synonymity is reciprocal.
  if (let i = th.find(ws); i >= 0):                     # Hash Lookup
    let syn  = cast[pua int32](th.synM.mem)[i.int]      # Get offset(list)
    let syns = cast[pua int32](th.synsM.mem +% syn)     # Get list itself
    for j in 1i32 .. syns[0]: yield syns[j]             # Iterate over elements

proc synsContain(th: Thes, ss: MemSlice, wn: int32): bool = # Check Reciprocal
  for rn in th.synos(ss):               # Linear scans are slow; East to just do
    if rn.abs == wn: return true        #..int not string compares, though.

proc make(th: var Thes; input, base: string) = # Make binary files from `input`
  template offGetOrAdd(o, k, uniq, uniO, uniM) =
    if k.size>127: raise newException(ValueError,"overlong word: \"" & $k & "\"")
    try: o = uniq[k]                    # lptabz editOrInit would do only 1 find
    except: o=uniO; uniq[k]=o; uniM.add chr(k.size.int8), uniO; uniM.add k, uniO
  var inp = mfop(input)
  var nL = 0                            # Pass 1: just count lines
  for line in memSlices(inp): inc nL
  let n = nextPowerOfTwo(4*nL div 3)    # Target < 3/4 Hash Table Load Factor
  th.tabM = mfop(base & ".NI", fmReadWrite, newFileSize=4*n)
  th.uniM = mfop(base & ".Lc", fmReadWrite, newFileSize=131072, allowRemap=true)
  th.synM = mfop(base & "_s.NI", fmReadWrite, newFileSize=4*n)
  th.tabSz = n; th.tab = cast[pua TabEnt](th.tabM.mem)
  let synsF = system.open(base & "_sL.Ni", fmWrite)
  var uniq  = initTable[MemSlice, uint32](4*nL)  # `4` here just avg from Moby
  var uniO, wO, synO, synsO: uint32
  th.uniM.add chr(0u8), uniO    # => all offs > 0; So 0 encodes missing in hash
  for line in inp.memSlices:            # Pass 2: build table
    let line = MemFile(mem: line.data, size: line.size)
    var kw: MemSlice
    var syns: seq[uint32]
    for word in memSlices(line, ','):
      if kw.data.isNil:
        kw = word
        offGetOrAdd(wO, kw, uniq, uniO, th.uniM)
      elif word.size > 0:               # Moby has stray EOL ','s
        offGetOrAdd(synO, word, uniq, uniO, th.uniM)
        syns.add synO
    var hs: uint16
    let i = -th.find(kw, hs.addr) - 1   # Lookups MUST fail for inputs w/o dups
    if i < 0: raise newException(ValueError, "duplicate keyword " & $kw)
    th.tab[i].kwH = hs
    th.tab[i].kwR = wO
    cast[pua uint32](th.synM.mem)[i] = synsO
    var synLen = syns.len.uint32        # `var` to quash need for unsafeAddr
    discard synsF.writeBuffer(synLen.addr, 4)
    discard synsF.writeBuffer(syns[0].addr, 4*syns.len)
    synsO += 4*(synLen + 1)             # + 1 for length prefix
  th.uniM.resize uniO.int               # Finalize size of uniq words
  inp.close; synsF.close                # close input,synsF; Make th operational
  th.synsM = mfop(base & "_sL.Ni", fmReadWrite)
  for i in 0 ..< th.tabM.size div 4:    # Pass 3: Mark KW & Reciprocal Synos < 0
    if th.tab[i].kwR != 0:
      let kwn = th.tab[i].kwR
      let kwLen = cast[ptr int8](th.uniM.mem +% kwn)
      kwLen[] = -kwLen[]                # Mark KeyWords in uniM
      let syn  = cast[pua int32](th.synM.mem)[i.int]
      let syns = cast[pua int32](th.synsM.mem +% syn)
      for j in 1i32 .. syns[0]:         # Mark reciprocally synonymous in synsM
        if th.synsContain(th.word(syns[j])[0], kwn.int32):
          syns[j] = -syns[j]

proc close*(th: var Thes) =
  ## Release resources associated with an open thesaurus
  th.uniM.close; th.tabM.close; th.synsM.close; th.synM.close

proc thOpen*(input, base: string): Thes =
  ## Open a thesaurus binary package, building it from "source" if input given.
  if input == "" and base == "":        # Should maybe just HTTPS fetch here
    stderr.write "wget github.com/words/moby/raw/master/words.txt\n"
    raise newException(ValueError, "Missing data")
  let base = if base != "": base else: (let (d, nm, _) = input.splitFile; d/nm)
  if input != "" and base != "":
    removeFiles @[base & ".NI", base & ".Lc", base & "_s.NI", base & "_sL.Ni"]
    result.make(input, base)
    result.close                        # Close read-write to then re-open RO
  result.tabM  = mfop(base & ".NI")     # Key Pointers
  result.uniM  = mfop(base & ".Lc")     # Key Data, but also value data
  result.synM  = mfop(base & "_s.NI")   # Values
  result.synsM = mfop(base & "_sL.Ni")  #..BUT list elts also point to uniM
  result.tab   = cast[pua TabEnt](result.tabM.mem)
  result.tabSz = result.tabM.size div TabEnt.sizeof

proc maxWRef*(th: Thes): uint32 = th.uniM.size.uint32
  ## The largest possible byte offset into the unique word file

iterator words*(th: Thes): int32 =
  ## Iterate over keywords in table yielding references to unique words.
  for i in 0i32 ..< th.tabSz.int32:
    if (let e = th.tab[i].kwR.int32; e != 0): yield e

proc degree*(th: Thes, i: int32): int32 =
  ## The number of synonyms for table slot `i`.
  let syn  = cast[pua int32](th.synM.mem)[i.int]      # Get offset(list)
  let syns = cast[pua int32](th.synsM.mem +% syn)     # Get list itself
  syns[0]

proc count*(th: Thes, w: string): tuple[nSyn, nAlso, nKeyW: int] =
  ## Return a count of synonyms in various categories.  Undefined=nSyn-others.
  for sn in th.synos(w.toMemSlice):
    let (_, keyw) = th.word(sn.abs)
    if   sn<0: inc result.nAlso
    elif keyw: inc result.nKeyW
    inc result.nSyn

import std/[strutils, terminal, times], cligen/[tab, humanUt]

type K = enum KxRef="xRef", KkwOnly="kwOnly", KunDef="unDef"
proc thes(input="", base="", alpha=false, flush=false, gap=1, types:seq[K]= @[],
          limit=0, xRef="bold", kwOnly="plain", unDef="italic", plain=false,
          count=false, measure=false, words: seq[string]) = # import{.all.}able
  ## List synonyms maybe with various ANSI SGR embellishments.  With no words on
  ## the command line, this instead runs as a stdin-stdout filter.
  ##
  ## Moby has a 300-2000 ms NPM prog to CLquery w/ugly, less informative output.
  ## To enable sub-usec query, we compile data to binary files; View w/`nio pr`.
  let pfx = if words.len > 1: "  " else: ""
  let ttyWidth = terminalWidth()  # Filter mode COULD change qry-to-qry,but eh..
  let plain = plain or existsEnv("NO_COLOR")
  let hlX = textAttrOn(xRef.split, plain)
  let hlK = textAttrOn(kwOnly.split, plain)
  let hlU = textAttrOn(unDef.split, plain)
  let hl0 = if plain: "" else: textAttrOff
  var th = thOpen(input, base)    # This builds data files if needed
  template ok(kind: K, counts): untyped =
    limit == 0 or counts.nSyn < limit or kind in types
  template doWord(w) =
    if count:
      var t0: float
      if words.len > 1: stdout.write "Word: ", w, ": "
      if measure: t0 = epochTime()
      let (nSyn, nAlso, nKeyW) = th.count(w)
      if measure: stderr.write epochTime() - t0, " seconds\n"
      echo nSyn, " syns ", nAlso, " alsos ", nSyn - (nKeyW + nAlso), " missing"
    else:
      if words.len > 1: echo "Word: ", w
      var strs: seq[string]       #NOTE: reciprocal => keyw, but NOT vice versa
      var wids: seq[int]          # unembellished lens
      let cnts = th.count(w)
      if alpha:
        for sn in th.synos(w.toMemSlice):
          let (ms, keyw) = th.word(sn.abs)
          let wid = -ms.size        # < 0 => left-aligned
          if   sn<0 and ok(KxRef  , cnts): strs.add hlX & $ms & hl0;wids.add wid
          elif keyw and ok(KkwOnly, cnts): strs.add hlK & $ms & hl0;wids.add wid
          elif          ok(KunDef , cnts): strs.add hlU & $ms & hl0;wids.add wid
      else:     # 3 passes is still fast; Eg., makes same num of strings
        if ok(KxRef, cnts):
          for sn in th.synos(w.toMemSlice):
            let (ms, _) = th.word(sn.abs)         # < 0 => left-aligned
            if sn<0: strs.add hlX & $ms & hl0; wids.add -ms.size
        if ok(KkwOnly, cnts):
          for sn in th.synos(w.toMemSlice):
            let (ms, keyw) = th.word(sn.abs)
            if sn >= 0 and keyw: strs.add hlK & $ms & hl0; wids.add -ms.size
        if ok(KunDef, cnts):
          for sn in th.synos(w.toMemSlice):
            let (ms, keyw) = th.word(sn.abs)
            if sn >= 0 and not keyw: strs.add hlU & $ms & hl0; wids.add -ms.size
      if gap >= 0: stdout.format ttyWidth - pfx.len, wids, strs, gap, pfx
      else: (for s in strs: echo s)
  if words.len == 0:
    for w in stdin.lines:
      doWord(w)
      if flush: flushFile stdout
  else:
    for w in words: doWord(w)
  th.close

when isMainModule:
  import cligen; include cligen/mergeCfgEnv; dispatch thes, help={
    "input" : "a Moby-like words.txt file; \"\"->use cached",
    "base"  : "path pfx w/base sfx to output data files",
    "alpha" : "fully alphabetical order, not block sorted",
    "flush" : "flush after every response in filter mode",
    "gap"   : "minimum inter-column gap; <0 = 1 column",
    "types" : "limit output to: xRef, kwOnly, unDef",
    "limit" : "total count limit @which to enforce `types`",
    "xRef"  : "highlight for reciprocally synonymous",
    "kwOnly": "highlight for defined but irreciprocal",
    "unDef" : "highlight for undefined in thesaurus",
    "plain" : "disable ANSI SGR Escape highlighting",
    "count" : "only count synonyms; do not render",
    "measure":"time query in count mode"}
