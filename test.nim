import bpm, ccpm, ccpmheap

{.passC: "-D LODEPNG_NO_COMPILE_CPP".}
#{.passL: "-lstdc++" .}
{.compile: "lodepng.c".}

proc lodepng_huffman_code_lengths(lengths, freq: ptr cuint, numcodes: csize, maxbitlen: cuint) {.importc, cdecl.}

proc main() =
  var f = [11,7, 5, 3, 8, 2, 5, 2, 3, 1, 17, 9, 13, 15]
        #@[3, 3, 4, 5, 3, 5, 4, 6, 5, 6, 2, 3]
  let a = bpm.codeLengths(f, 15)
  let b = ccpm.codeLengths(f, 15)
  let c = ccpmheap.codeLengths(f, 15)

  var output: array[14, cuint]
  var input: array[14, cuint]
  for i in 0.. <f.len:
    input[i] = f[i].cuint
  lodepng_huffman_code_lengths(output[0].addr, input[0].addr, f.len.csize, 15.cuint)
  
  echo a
  echo b
  echo c
  
  stdout.write "@["
  for c in output:
    stdout.write c
    stdout.write ", "
  stdout.write "]\x0a"
  
main()