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
 * A decoder for the BZip2 Huffman coding stage
 */
open class BZip2HuffmanStageDecoder {

	/**
	 * The BZip2BitInputStream from which Huffman codes are read
	 */
  private let bitInputStream : BZip2BitInputStream

	/**
	 * The Huffman table number to use for each group of 50 symbols
	 */
  private let selectors : [UInt8]

	/**
	 * The minimum code length for each Huffman table
	 */
  private var minimumLengths : [Int] = Array(repeating: 0, count: BZip2Constants.HUFFMAN_MAXIMUM_TABLES)

	/**
	 * An array of values for each Huffman table that must be subtracted from the numerical value of
	 * a Huffman code of a given bit length to give its canonical code index
	 */
  private var codeBases : [[Int]] = Array(repeating: Array(repeating: 0, count: BZip2Constants.HUFFMAN_MAXIMUM_TABLES), count: BZip2Constants.HUFFMAN_DECODE_MAXIMUM_CODE_LENGTH + 2)

	/**
	 * An array of values for each Huffman table that gives the highest numerical value of a Huffman
	 * code of a given bit length
	 */
  private var codeLimits : [[Int]] = Array(repeating: Array(repeating: 0, count: BZip2Constants.HUFFMAN_MAXIMUM_TABLES), count: BZip2Constants.HUFFMAN_DECODE_MAXIMUM_CODE_LENGTH + 1)

	/**
	 * A mapping for each Huffman table from canonical code index to output symbol
	 */
  private var codeSymbols : [[Int]] = Array(repeating: Array(repeating: 0, count: BZip2Constants.HUFFMAN_MAXIMUM_TABLES), count: BZip2Constants.HUFFMAN_MAXIMUM_ALPHABET_SIZE)

	/**
	 * The Huffman table for the current group
	 */
  private var currentTable : Int

	/**
	 * The index of the current group within the selectors array
	 */
	private var groupIndex = -1

	/**
	 * The byte position within the current group. A new group is selected every 50 decoded bytes
	 */
	private var groupPosition = -1


	/**
	 * Constructs Huffman decoding tables from lists of Canonical Huffman code lengths
	 * @param alphabetSize The total number of codes (uniform for each table)
	 * @param tableCodeLengths The Canonical Huffman code lengths for each table
	 */
  private func createHuffmanDecodingTables (_ alphabetSize : Int, _ tableCodeLengths : [[UInt8]]) {

    for table in 0..<tableCodeLengths.count {

      // In Java only another reference is created, but Swift make a copy - see end of method for solution
      var tableBases : [Int] = self.codeBases[table];
      var tableLimits : [Int] = self.codeLimits[table];
      var tableSymbols : [Int] = self.codeSymbols[table];

			let codeLengths : [UInt8] = tableCodeLengths[table];
			var minimumLength = BZip2Constants.HUFFMAN_DECODE_MAXIMUM_CODE_LENGTH;
			var maximumLength = 0;

			// Find the minimum and maximum code length for the table
      for i in 0..<alphabetSize {
        maximumLength = java.lang.Math.max (Int(codeLengths[i]), maximumLength);
        minimumLength = java.lang.Math.min (Int(codeLengths[i]), minimumLength);
			}
			self.minimumLengths[table] = minimumLength;

			// Calculate the first output symbol for each code length
      for i in 0..<alphabetSize {
        tableBases[Int(codeLengths[i]) + 1] += 1
			}
      for i in 1..<(BZip2Constants.HUFFMAN_DECODE_MAXIMUM_CODE_LENGTH + 2) {
				tableBases[i] += tableBases[i - 1];
			}

			// Calculate the first and last Huffman code for each code length (codes at a given
			// length are sequential in value)
			var code = 0;
      for i in minimumLength...maximumLength {
        let base : Int = code;
				code += tableBases[i + 1] - tableBases[i];
				tableBases[i] = base - tableBases[i];
				tableLimits[i] = code - 1;
				code <<= 1;
			}

			// Populate the mapping from canonical code index to output symbol
			var codeIndex = 0;
      for bitLength in minimumLength...maximumLength {
        for symbol in 0..<alphabetSize {
					if (codeLengths[symbol] == bitLength) {
						tableSymbols[codeIndex] = symbol;
            codeIndex += 1
					}
				}
			}
      
      // In Java only another reference is created, but Swift make a copy - so solution, set the copy to the array
      self.codeBases[table] = tableBases
      self.codeLimits[table] = tableLimits
      self.codeSymbols[table] = tableSymbols

		}

	}


	/**
	 * Decodes and returns the next symbol
	 * @return The decoded symbol
	 * @throws IOException if the end of the input stream is reached while decoding
	 */
	public func nextSymbol() throws -> Int {

    let bitInputStream : BZip2BitInputStream = self.bitInputStream;

		// Move to next group selector if required
    self.groupPosition += 1
    if (self.groupPosition % BZip2Constants.HUFFMAN_GROUP_RUN_LENGTH) == 0 {
      self.groupIndex += 1
			if (self.groupIndex == self.selectors.count) {
        throw BZip2Exception.IOException("Error decoding BZip2 block");
			}
      self.currentTable = Int(self.selectors[self.groupIndex] & 0xff);
		}

    //let tableLimits : [Int] = self.codeLimits[self.currentTable];
    var codeLength : Int = self.minimumLengths[self.currentTable];

		// Starting with the minimum bit length for the table, read additional bits one at a time
		// until a complete code is recognised
    var codeBits : Int = try bitInputStream.readBits (codeLength);
    while codeLength <= BZip2Constants.HUFFMAN_DECODE_MAXIMUM_CODE_LENGTH {
      if (codeBits <= self.codeLimits[self.currentTable][codeLength]) {
				// Convert the code to a symbol index and return
				return self.codeSymbols[currentTable][codeBits - self.codeBases[currentTable][codeLength]];
			}
      codeBits = (codeBits << 1) | (try bitInputStream.readBits (1));
      codeLength += 1
		}

		// A valid code was not recognised
    throw BZip2Exception.IOException("Error decoding BZip2 block")

	}


	/**
	 * @param bitInputStream The BZip2BitInputStream from which Huffman codes are read
	 * @param alphabetSize The total number of codes (uniform for each table)
	 * @param tableCodeLengths The Canonical Huffman code lengths for each table
	 * @param selectors The Huffman table number to use for each group of 50 symbols
	 */
  public init (_ bitInputStream : BZip2BitInputStream , _ alphabetSize : Int, _ tableCodeLengths : [[UInt8]], _ selectors : [UInt8]) {

		self.bitInputStream = bitInputStream;
		self.selectors = selectors;
    self.currentTable = Int(self.selectors[0]);

		createHuffmanDecodingTables (alphabetSize, tableCodeLengths);

	}

}
