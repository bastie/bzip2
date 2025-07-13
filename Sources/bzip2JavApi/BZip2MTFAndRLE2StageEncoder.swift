open class BZip2MTFAndRLE2StageEncoder {
  
  /**
   * The Burrows-Wheeler transformed block
   */
  private let bwtBlock: [Int]
  
  /**
   * Actual length of the data in the {@link bwtBlock} array
   */
  private var bwtLength: Int
  
  /**
   * At each position, {@code true} if the byte value with that index is present within the block,
   * otherwise {@code false}
   */
  private let bwtValuesInUse: [Bool]
  
  /**
   * The output of the Move To Front Transform and Run-Length Encoding[2] stages
   */
  private var mtfBlock: [Character]
  
  /**
   * The actual number of values contained in the {@link mtfBlock} array
   */
  private var mtfLength: Int = 0
  
  /**
   * The global frequencies of values within the {@link mtfBlock} array
   */
  private var mtfSymbolFrequencies = [Int](repeating: 0, count: BZip2Constants.HUFFMAN_MAXIMUM_ALPHABET_SIZE)
  
  /**
   * The encoded alphabet size
   */
  private var alphabetSize: Int = 0
  
  
  /**
   * Performs the Move To Front transform and Run Length Encoding[1] stages
   */
  public func encode() {
    let bwtLength = self.bwtLength
    var huffmanSymbolMap = [UInt8](repeating: 0, count: 256)
    let symbolMTF = MoveToFront()
    
    var totalUniqueValues = 0
    for i in 0..<256 {
      if bwtValuesInUse[i] {
        huffmanSymbolMap[i] = UInt8(totalUniqueValues)
        totalUniqueValues += 1
      }
    }
    
    let endOfBlockSymbol = totalUniqueValues + 1
    
    var mtfIndex = 0
    var repeatCount = 0
    var totalRunAs = 0
    var totalRunBs = 0
    
    for i in 0..<bwtLength {
      // Move To Front
      let mtfPosition = symbolMTF.valueToFront(
        huffmanSymbolMap[Int(bwtBlock[i] & 0xff)]
      )
      
      // Run Length Encode
      if mtfPosition == 0 {
        repeatCount += 1
      } else {
        if repeatCount > 0 {
          repeatCount -= 1
          while true {
            if (repeatCount & 1) == 0 {
              mtfBlock[mtfIndex] = Character(UnicodeScalar(BZip2Constants.HUFFMAN_SYMBOL_RUNA)!)
              mtfIndex += 1
              totalRunAs += 1
            } else {
              mtfBlock[mtfIndex] = Character(UnicodeScalar(BZip2Constants.HUFFMAN_SYMBOL_RUNB)!)
              mtfIndex += 1
              totalRunBs += 1
            }
            
            if repeatCount <= 1 {
              break
            }
            repeatCount = (repeatCount - 2) >> 1
          }
          repeatCount = 0
        }
        
        mtfBlock[mtfIndex] = Character(UnicodeScalar(mtfPosition + 1)!)
        mtfIndex += 1
        mtfSymbolFrequencies[mtfPosition + 1] += 1
      }
    }
    
    if repeatCount > 0 {
      repeatCount -= 1
      while true {
        if (repeatCount & 1) == 0 {
          mtfBlock[mtfIndex] = Character(UnicodeScalar(BZip2Constants.HUFFMAN_SYMBOL_RUNA)!)
          mtfIndex += 1
          totalRunAs += 1
        } else {
          mtfBlock[mtfIndex] = Character(UnicodeScalar(BZip2Constants.HUFFMAN_SYMBOL_RUNB)!)
          mtfIndex += 1
          totalRunBs += 1
        }
        
        if repeatCount <= 1 {
          break
        }
        repeatCount = (repeatCount - 2) >> 1
      }
    }
    
    mtfBlock[mtfIndex] = Character(endOfBlockSymbol)
    mtfSymbolFrequencies[endOfBlockSymbol] += 1
    mtfSymbolFrequencies[BZip2Constants.HUFFMAN_SYMBOL_RUNA] += totalRunAs
    mtfSymbolFrequencies[BZip2Constants.HUFFMAN_SYMBOL_RUNB] += totalRunBs
    
    self.mtfLength = mtfIndex + 1
    self.alphabetSize = endOfBlockSymbol + 1
  }
  
  /**
   * @return The encoded MTF block
   */
  public func getMtfBlock() -> [Character] {
    return self.mtfBlock
  }
  
  /**
   * @return The actual length of the MTF block
   */
  public func getMtfLength() -> Int {
    return self.mtfLength
  }
  
  /**
   * @return The size of the MTF block's alphabet
   */
  public func getMtfAlphabetSize() -> Int {
    return self.alphabetSize
  }
  
  /**
   * @return The frequencies of the MTF block's symbols
   */
  public func getMtfSymbolFrequencies() -> [Int] {
    return self.mtfSymbolFrequencies
  }
  
  /**
   * @param bwtBlock The Burrows Wheeler Transformed block data
   * @param bwtLength The actual length of the BWT data
   * @param bwtValuesPresent The values that are present within the BWT data. For each index,
   *            {@code true} if that value is present within the data, otherwise {@code false}
   */
  public init(_ bwtBlock: [Int], _ bwtLength: Int, _ bwtValuesPresent: [Bool]) {
    self.bwtBlock = bwtBlock
    self.bwtLength = bwtLength
    self.bwtValuesInUse = bwtValuesPresent
    self.mtfBlock = Array(repeating: "\u{0000}", count: bwtLength + 1)
  }
}
