import lz77uzLib, zerror, lz77util, lz77hash

let text = """1 In the beginning God created the heavens and the earth.
2 Now the earth was formless and desolate, and there was darkness upon the surface of the watery deep, and God's active force was moving about over the surface of the waters.
3 And God said: "Let there be light." Then there was light.
4 After that God saw that the light was good, and God began to divide the light from the darkness. 5 God called the light Day, but the darkness he called Night. And there was evening and there was morning, a first day.
6 Then God said: "Let there be an expanse between the waters, and let there be a division between the waters and the waters." 7 Then God went on to make the expanse and divided the waters beneath the expanse from the waters above the expanse. And it was so. 8 God called the expanse Heaven. And there was evening and there was morning, a second day.
9 Then God said: "Let the waters under the heavens be collected together into one place, and let the dry land appear." And it was so. 10 God called the dry land Earth, but the collecting of the waters, he called Seas. And God saw that it was good. 11 Then God said: "Let the earth cause grass to sprout, seed-bearing plants and fruit trees according to their kinds, yielding fruit along with seed on the earth." And it was so. 12 And the earth began to produce grass, seed-bearing plants and trees yielding fruit along with seed, according to their kinds. Then God saw that it was good. 13 And there was evening and there was morning, a third day.
14 Then God said: "Let there be luminaries in the expanse of the heavens to make a division between the day and the night, and they will serve as signs for seasons and for days and years. 15 They will serve as luminaries in the expanse of the heavens to shine upon the earth." And it was so. 16 And God went on to make the two great luminaries, the greater luminary for dominating the day and the lesser luminary for dominating the night, and also the stars. 17 Thus God put them in the expanse of the heavens to shine upon the earth 18 and to dominate by day and by night and to make a division between the light and the darkness. Then God saw that it was good. 19 And there was evening and there was morning, a fourth day."""

proc LZ77Decode(input: seq[int16]): string =
  result = newStringOfCap(input.len)
  var idx = 0
  while idx < input.len:
    let code = input[idx].int
    if code <= 255:
      result.add code.chr
      inc idx
    elif code >= FIRST_LENGTH_CODE_INDEX and code <= LAST_LENGTH_CODE_INDEX:

      let lengthCode   = code - FIRST_LENGTH_CODE_INDEX
      let length       = LENGTHBASE[lengthCode] + input[idx + 1].int
      let distanceCode = input[idx + 2].int
      let distance     = DISTANCEBASE[distanceCode] + input[idx + 3].int
      inc(idx, 4)

      var prevIdx = result.len - distance
      for i in 0.. <length:
        result.add result[prevIdx + i]

    else:
      nzerror(ERR_BAD_CODE_OR_WRONG_TABLE)

var opts = initLZOpts()
var res = lz77hash.LZ77Encode(opts, text.cstring, text.len)
var output = LZ77Decode(res)

assert(output == text)

# LZ77 todo:
# -gzip
# -zopfli
# -nimz

# hash todo:


# test:
# gzip,zopfli,nimz,uzlib
# fixed, dynamic
# deflate, inflate
# basic_huff, lookup_huff, seq_huff
# bpm, ccpm, ccpmheap
# lazy, greedy

