import ./private/hts_concat
import strutils
import os

type
  BGZ* = ref object of RootObj
    cptr*: ptr BGZF

proc close*(b: BGZ): int =
  ## close the filehandle
  if b.cptr != nil:
    result = int(bgzf_close(b.cptr))
  b.cptr = nil

proc write*(b: BGZ, line: string): int64 {.inline.} =
  ## write a string to the file
  bgzf_write(b.cptr, cstring(line), csize(line.len))

proc write_line*(b: BGZ, line: string): int {.inline.} =
  ## write a string to the file and add a newline.

  var r = int(bgzf_write(b.cptr, cstring(line), csize(line.len)))
  if r > 0:
    if int(bgzf_write(b.cptr, cstring("\n"), csize(1))) < 0:
      return -1
  return r + 1

proc set_threads*(b: BGZ, threads: int) =
  ## set the number of de/compression threads
  discard bgzf_mt(b.cptr, cint(threads), 128)

proc read_line*(b: BGZ, line:var ptr kstring_t): int {.inline.} =
  ## read a line into the kstring t.
  bgzf_getline(b.cptr, cint(10), line)

proc flush*(b: BGZ): int =
  return int(bgzf_flush(b.cptr))

proc tell*(b: BGZ): uint64 {.inline.} =
  return uint64(bgzf_tell(b.cptr))

proc finalize(b: BGZ) =
  if b.cptr != nil:
    discard b.flush()
    discard b.close()

proc open*(b: var BGZ, path: string, mode: string) =
  ## open a BGZF file
  new(b, finalize)
  b.cptr = bgzf_open(cstring(path), cstring(mode))
  if b.cptr == nil:
    raise newException(IOError, "error opening " & path)

iterator items*(b: BGZ): string =
  ## iterates over the file line by line
  var 
    kstr: kstring_t
    r: int

  kstr.l = 0
  kstr.m = 0
  kstr.s = nil
  var p = kstr.addr

  r = b.read_line(p)
  while r >= 0:
    yield $kstr.s
    r = b.read_line(p)
  
  if r <= -2:
    raise newException(IOError, "error while reading bgzip file")

  free(kstr.s)
