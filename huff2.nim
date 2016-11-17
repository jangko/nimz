import sequtils, strutils
#[typedef struct huffman_node_t


huffman_node_t root;
build_huffman_tree( &root );
huffman_node_t node = &root;
while ( !eof )
{
  if ( next_bit( stream ) )
  {
    node = node->one;
  }
  else
  {
    node = node->zero;
  }
  if ( node->code != -1 )
  {
    printf( "%c", node->code );
    node = &root;
  }
}]#

type
  huffmanNode = ref object
    code: int # -1 for non-leaf nodes
    zero: huffmanNode
    one : huffmanNode

  huffmanRange = object
    endPoint: int
    bitLength: int
 
  treeNode = object
    len: int
    code: int

proc initRange(): seq[huffmanRange] =
  result = newseq[huffmanRange](7)
  result[ 0 ].endPoint  = 1
  result[ 0 ].bitLength = 4
  result[ 1 ].endPoint  = 4
  result[ 1 ].bitLength = 6
  result[ 2 ].endPoint  = 6
  result[ 2 ].bitLength = 4
  result[ 3 ].endPoint  = 14
  result[ 3 ].bitLength = 5
  result[ 4 ].endPoint  = 18
  result[ 4 ].bitLength = 6
  result[ 5 ].endPoint  = 21
  result[ 5 ].bitLength = 4
  result[ 6 ].endPoint  = 26
  result[ 6 ].bitLength = 6

proc getMaxBitlength(ranges: seq[huffmanRange]): int =
  result = 0
  for it in ranges:
    if it.bitLength > result:
      result = it.bitLength

proc getBitLengthCount(maxBitLength: int, ranges: seq[huffmanRange]): seq[int] =
  result = newSeqWith(maxBitLength + 1, 0)
  for n in 0.. <ranges.len:
    let k = ranges[ n ].endPoint - (if n > 0: ranges[ n - 1 ].endPoint else: -1)
    inc(result[ ranges[ n ].bitLength ], k)

proc getNextCode(maxBitLength: int, blCount: seq[int]): seq[int] =
  result = newSeqWith(maxBitLength + 1, 0)
  var code = 0
  for bits in 1..maxBitLength:
    code = ( code + blCount[ bits - 1 ] ) shl 1
    if blCount[ bits ] != 0:
      result[ bits ] = code
    
proc getTree(ranges: seq[huffmanRange], nextCode: var seq[int]): seq[treeNode] =
  let lastPoint = ranges[ ranges.len - 1 ].endPoint
  result = newSeqWith(lastPoint + 1, treeNode(len: 0, code: 0))
  var activeRange = 0
  for n in 0..lastPoint:
    if n > ranges[ activeRange ].endPoint:
      inc activeRange
    if ranges[ activeRange ].bitLength != 0:
      result[ n ].len = ranges[ activeRange ].bitLength
      if result[ n ].len != 0:
        result[ n ].code = nextCode[ result[ n ].len ]
        inc nextCode[ result[ n ].len ]
    
proc buildHuffmanTree(ranges: seq[huffmanRange]): huffmanNode =
  let maxBitLength = getMaxBitLength(ranges)
  let blCount      = getBitLengthCount(maxBitLength, ranges)
  var nextCode     = getNextCode(maxBitLength, blCount)
  let tree         = getTree(ranges, nextCode)
  
  var root = huffmanNode(code: -1, zero: nil, one: nil)
  let lastPoint = ranges[ ranges.len - 1 ].endPoint
  
  for n in 0..lastPoint:
    var node = root
    if tree[ n ].len == 0: continue
    
    echo n, " : ", toBin(tree[n].code, tree[n].len)
    
    for bits in countdown(tree[ n ].len, 1):
      if (tree[ n ].code and (1 shl (bits - 1))) != 0:
        if node.one == nil:
          node.one = huffmanNode(code: -1, zero: nil, one: nil)          
        node = node.one
      else:
        if node.zero == nil:
          node.zero = huffmanNode(code: -1, zero: nil, one: nil)          
        node = node.zero
    assert( node.code == -1 )
    node.code = n
    
  result = root
  
var x = initRange()
var node = buildHuffmanTree(x)