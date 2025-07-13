/*
 * Copyright (c) 2011 Matthew Francis
 * Copyright (c) 2025 Sebastian Ritter
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import JavApi

/**
 * An encoder for the BZip2 Huffman encoding stage
 */
class BZip2HuffmanStageEncoder {

	/**
	 * Used in initial Huffman table generation
	 */
	private static let HUFFMAN_HIGH_SYMBOL_COST = 15

	/**
	 * The BZip2BitOutputStream to which the Huffman tables and data is written
	 */
  private let bitOutputStream : BZip2BitOutputStream

	/**
	 * The output of the Move To Front Transform and Run Length Encoding[2] stages
	 */
  private let mtfBlock : [Character];

	/**
	 * The actual number of values contained in the {@link mtfBlock} array
	 */
  private var mtfLength : Int

	/**
	 * The number of unique values in the {@link mtfBlock} array
	 */
  private var mtfAlphabetSize : Int

	/**
	 * The global frequencies of values within the {@link mtfBlock} array
	 */
  private let mtfSymbolFrequencies : [Int]

	/**
	 * The Canonical Huffman code lengths for each table
	 */
  private var huffmanCodeLengths : [[Int]]

	/**
	 * Merged code symbols for each table. The value at each position is ((code length << 24) | code)
	 */
  private var huffmanMergedCodeSymbols : [[Int]]

	/**
	 * The selectors for each segment
	 */
  private var selectors : [UInt8];


	/**
	 * Selects an appropriate table count for a given MTF length
	 * @param mtfLength The length to select a table count for
	 * @return The selected table count
	 */
  private static func selectTableCount (_ mtfLength : Int) -> Int {

    if (mtfLength >= 2400) {
      return 6
    }
    if (mtfLength >= 1200) {
      return 5
    }
    if (mtfLength >= 600) {
      return 4
    }
    if (mtfLength >= 200) {
      return 3
    }
		return 2;

	}


	/**
	 * Generate a Huffman code length table for a given list of symbol frequencies
	 * @param alphabetSize The total number of symbols
	 * @param symbolFrequencies The frequencies of the symbols
	 * @param codeLengths The array to which the generated code lengths should be written
	 */
  private static func generateHuffmanCodeLengths (_ alphabetSize : Int, _ symbolFrequencies : [Int], _ codeLengths : inout [Int]) {

    var mergedFrequenciesAndIndices : [Int] = Array(repeating: 0, count: alphabetSize)
    var sortedFrequencies : [Int] = Array(repeating: 0, count: alphabetSize)

		// The Huffman allocator needs its input symbol frequencies to be sorted, but we need to return code lengths in the same order as the
		// corresponding frequencies are passed in

		// The symbol frequency and index are merged into a single array of integers - frequency in the high 23 bits, index in the low 9 bits.
		//     2^23 = 8,388,608 which is higher than the maximum possible frequency for one symbol in a block
		//     2^9 = 512 which is higher than the maximum possible alphabet size (== 258)
		// Sorting this array simultaneously sorts the frequencies and leaves a lookup that can be used to cheaply invert the sort
    for i in 0..<alphabetSize {
			mergedFrequenciesAndIndices[i] = (symbolFrequencies[i] << 9) | i
		}
    mergedFrequenciesAndIndices.sort()
    for i in 0..<alphabetSize {
			sortedFrequencies[i] = mergedFrequenciesAndIndices[i] >>> 9;
		}

		// Allocate code lengths - the allocation is in place, so the code lengths will be in the sortedFrequencies array afterwards
    HuffmanAllocator.allocateHuffmanCodeLengths (&sortedFrequencies, BZip2Constants.HUFFMAN_ENCODE_MAXIMUM_CODE_LENGTH);

		// Reverse the sort to place the code lengths in the same order as the symbols whose frequencies were passed in
    for i in 0..<alphabetSize {
			codeLengths[mergedFrequenciesAndIndices[i] & 0x1ff] = sortedFrequencies[i];
		}

	}


	/**
	 * Generate initial Huffman code length tables, giving each table a different low cost section
	 * of the alphabet that is roughly equal in overall cumulative frequency. Note that the initial
	 * tables are invalid for actual Huffman code generation, and only serve as the seed for later
	 * iterative optimisation in {@link #optimiseSelectorsAndHuffmanTables(int)}.
	 */
	private func generateHuffmanOptimisationSeeds () {

		let mtfAlphabetSize = self.mtfAlphabetSize;

		let totalTables = huffmanCodeLengths.count

		var remainingLength = self.mtfLength;
		var lowCostEnd = -1;

    for i in 0..<totalTables {

      let targetCumulativeFrequency : Int = remainingLength / (totalTables - i);
			let lowCostStart = lowCostEnd + 1;
			var actualCumulativeFrequency = 0;

			while ((actualCumulativeFrequency < targetCumulativeFrequency) && (lowCostEnd < (mtfAlphabetSize - 1))) {
        lowCostEnd += 1
				actualCumulativeFrequency += mtfSymbolFrequencies[lowCostEnd];
			}

			if ((lowCostEnd > lowCostStart) && (i != 0) && (i != (totalTables - 1)) && (((totalTables - i) & 1) == 0)) {
        lowCostEnd -= 1
				actualCumulativeFrequency -= mtfSymbolFrequencies[lowCostEnd];
			}

      var tableCodeLengths : [Int] = huffmanCodeLengths[i];
      for j in 0..<mtfAlphabetSize {
				if ((j < lowCostStart) || (j > lowCostEnd)) {
          tableCodeLengths[j] = BZip2HuffmanStageEncoder.HUFFMAN_HIGH_SYMBOL_COST;
				}
			}
      huffmanCodeLengths[i] = tableCodeLengths

			remainingLength -= actualCumulativeFrequency;

		}

	}


	/**
	 * Co-optimise the selector list and the alternative Huffman table code lengths. This method is
	 * called repeatedly in the hope that the total encoded size of the selectors, the Huffman code
	 * lengths and the block data encoded with them will converge towards a minimum.<br>
	 * If the data is highly incompressible, it is possible that the total encoded size will
	 * instead diverge (increase) slightly.<br>
	 * @param storeSelectors If {@code true}, write out the (final) chosen selectors
	 */
  private func optimiseSelectorsAndHuffmanTables (_ storeSelectors : Bool) {

		let mtfLength = self.mtfLength;
		let mtfAlphabetSize = self.mtfAlphabetSize;

		let totalTables = huffmanCodeLengths.length;
    var tableFrequencies : [[Int]] = Array(repeating: Array(repeating: 0, count: totalTables), count: mtfAlphabetSize)

		var selectorIndex = 0

    // Find the best table for each group of 50 block bytes based on the current Huffman code lengths
    var groupStart = 0
    while groupStart < mtfLength {

      let groupEnd = java.lang.Math.min (groupStart + BZip2Constants.HUFFMAN_GROUP_RUN_LENGTH, mtfLength) - 1;

			// Calculate the cost of this group when encoded by each table
      var cost : [Int16] = Array(repeating: 0, count: totalTables)
      for i in groupStart...groupEnd {
				let value = Int(String( mtfBlock[i]))!
        for j in 0..<totalTables {
					cost[j] += Int16(huffmanCodeLengths[j][value])
				}
			}

			// Find the table with the least cost for this group
      var bestTable : UInt8 = 0;
      var bestCost : Int = Int(cost[0])
      for i in 1..<UInt8(totalTables) as Range<UInt8>{
        let tableCost : Int = Int(cost[Int(i)])
				if (tableCost < bestCost) {
					bestCost = tableCost;
					bestTable = i;
				}
			}

			// Accumulate symbol frequencies for the table chosen for this block
      // Da Arrays in Swift Wertetypen sind, arbeiten wir direkt mit dem Original-Array
      for i in groupStart...groupEnd {
        let mtfValue = mtfBlock[i]
        tableFrequencies[Int(String(mtfValue))!][Int(bestTable)] += 1
      }
      
			// Store a selector indicating the table chosen for this block
			if (storeSelectors) {
				selectors[selectorIndex] = bestTable;
        selectorIndex += 1
			}

			groupStart = groupEnd + 1;
		}

		// Generate new Huffman code lengths based on the frequencies for each table accumulated in this iteration
    for i in 0..<totalTables {
      BZip2HuffmanStageEncoder.generateHuffmanCodeLengths (mtfAlphabetSize, tableFrequencies[i], &huffmanCodeLengths[i]);
		}
	}


	/**
	 * Assigns Canonical Huffman codes based on the calculated lengths
	 */
	private func assignHuffmanCodeSymbols() {

		let totalTables = huffmanCodeLengths.count

    for i in 0..<totalTables {

			let tableLengths = huffmanCodeLengths[i];

			var minimumLength = 32;
			var maximumLength = 0;
      for j in 0..<mtfAlphabetSize {
				let length = tableLengths[j];
				if (length > maximumLength) {
					maximumLength = length;
				}
				if (length < minimumLength) {
					minimumLength = length;
				}
			}

			var code = 0;
      for j in minimumLength...maximumLength {
        for k in 0..<mtfAlphabetSize {
					if ((huffmanCodeLengths[i][k] & 0xff) == j) {
						huffmanMergedCodeSymbols[i][k] = (j << 24) | code;
						code += 1
					}
				}
				code <<= 1;
			}

		}

	}


	/**
	 * Write out the selector list and Huffman tables
	 * @throws IOException on any I/O error writing the data
	 */
	private func writeSelectorsAndHuffmanTables() throws {

		let totalSelectors = selectors.count

		let totalTables = huffmanCodeLengths.count

    try bitOutputStream.writeBits (3, totalTables);
    try bitOutputStream.writeBits (15, totalSelectors);

		// Write the selectors
		let selectorMTF = MoveToFront();
    for i in 0..<totalSelectors {
      try bitOutputStream.writeUnary (selectorMTF.valueToFront (selectors[i]));
		}

		// Write the Huffman tables
    for i in 0..<totalTables {
			let tableLengths = huffmanCodeLengths[i];
			var currentLength = tableLengths[0];

      try bitOutputStream.writeBits (5, currentLength);

      for j in 0..<mtfAlphabetSize {
				let codeLength = tableLengths[j];
				let value = (currentLength < codeLength) ? 2 : 3;
        var delta = java.lang.Math.abs (codeLength - currentLength);
        while delta > 0 {
          try bitOutputStream.writeBits(2, value)
          delta -= 1
        }
        try bitOutputStream.writeBoolean (false);
				currentLength = codeLength;
			}
		}

	}


	/**
	 * Writes out the encoded block data
	 * @throws IOException on any I/O error writing the data
	 */
	private func writeBlockData() throws {

		var selectorIndex = 0;
    var mtfIndex = 0;
    
		while  mtfIndex < mtfLength{
      let groupEnd : Int = java.lang.Math.min (mtfIndex + BZip2Constants.HUFFMAN_GROUP_RUN_LENGTH, mtfLength) - 1;
      let tableMergedCodeSymbols : [Int] = huffmanMergedCodeSymbols[Int(selectors[selectorIndex])];
      selectorIndex += 1

			while (mtfIndex <= groupEnd) {
        let mergedCodeSymbol : Int = tableMergedCodeSymbols[Int(String(mtfBlock[mtfIndex]))!];
        mtfIndex += 1
        try bitOutputStream.writeBits (mergedCodeSymbol >>> 24, mergedCodeSymbol);
			}
		}

	}


	/**
	 * Encodes and writes the block data
	 * @throws IOException on any I/O error writing the data
	 */
	public func encode() throws {

		// Create optimised selector list and Huffman tables
		generateHuffmanOptimisationSeeds();
    for i in stride(from: 3, through: 0, by: -1) {
			optimiseSelectorsAndHuffmanTables (i == 0);
		}
		assignHuffmanCodeSymbols();

		// Write out the tables and the block data encoded with them
    try writeSelectorsAndHuffmanTables();
    try writeBlockData();

	}


	/**
	 * @param bitOutputStream The BZip2BitOutputStream to write to
	 * @param mtfBlock The MTF block data
	 * @param mtfLength The actual length of the MTF block
	 * @param mtfAlphabetSize The size of the MTF block's alphabet
	 * @param mtfSymbolFrequencies The frequencies the MTF block's symbols
	 */
  public init (_ bitOutputStream : BZip2BitOutputStream, _ mtfBlock : [Character], _ mtfLength : Int, _ mtfAlphabetSize : Int, _ mtfSymbolFrequencies : [Int]) {

		self.bitOutputStream = bitOutputStream;
		self.mtfBlock = mtfBlock;
		self.mtfLength = mtfLength;
		self.mtfAlphabetSize = mtfAlphabetSize;
		self.mtfSymbolFrequencies = mtfSymbolFrequencies;

    let totalTables = BZip2HuffmanStageEncoder.selectTableCount (mtfLength);

		self.huffmanCodeLengths = Array(repeating: Array(repeating: 0, count: totalTables), count: mtfAlphabetSize)
		self.huffmanMergedCodeSymbols = Array(repeating: Array(repeating: 0, count: totalTables), count: mtfAlphabetSize)
    
    self.selectors = Array(repeating: 0, count: (mtfLength + BZip2Constants.HUFFMAN_GROUP_RUN_LENGTH - 1) / BZip2Constants.HUFFMAN_GROUP_RUN_LENGTH)
	}

}
