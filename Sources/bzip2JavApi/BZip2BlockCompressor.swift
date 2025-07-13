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

/*
 * Block encoding consists of the following stages:
 * 1. Run-Length Encoding[1] - write()
 * 2. Burrows Wheeler Transform - close() (through BZip2DivSufSort)
 * 3. Write block header - close()
 * 4. Move To Front Transform - close() (through BZip2HuffmanStageEncoder)
 * 5. Run-Length Encoding[2] - close()  (through BZip2HuffmanStageEncoder)
 * 6. Create and write Huffman tables - close() (through BZip2HuffmanStageEncoder)
 * 7. Huffman encode and write data - close() (through BZip2HuffmanStageEncoder)
 */
/**
 * Compresses and writes a single BZip2 block
 */
open class BZip2BlockCompressor {

	/**
	 * The stream to which compressed BZip2 data is written
	 */
  private let bitOutputStream : BZip2BitOutputStream

	/**
	 * CRC builder for the block
	 */
	private let crc = BZip2CRC32()

	/**
	 * The RLE'd block data
	 */
  private var block : [UInt8]

	/**
	 * Current length of the data within the {@link block} array
	 */
	private var blockLength = 0

	/**
	 * A limit beyond which new data will not be accepted into the block
	 */
  private let blockLengthLimit : Int

	/**
	 * The values that are present within the RLE'd block data. For each index, {@code true} if that
	 * value is present within the data, otherwise {@code false}
	 */
  private var blockValuesPresent : [Bool] = Array(repeating: Bool(), count: 256)

	/**
	 * The Burrows Wheeler Transformed block data
	 */
  private let bwtBlock : [Int]

	/**
	 * The current RLE value being accumulated (undefined when {@link #rleLength} is 0)
	 */
	private var rleCurrentValue = -1

	/**
	 * The repeat count of the current RLE value
	 */
	private var rleLength = 0

	/**
	 * Write the Huffman symbol to output byte map
	 * @throws IOException on any I/O error writing the data
	 */
	private func writeSymbolMap() throws {

		let bitOutputStream = self.bitOutputStream;

		let blockValuesPresent = self.blockValuesPresent;
    var condensedInUse : [Bool] = Array (Array(repeating: Bool(), count: 16))

    for i in  0..<16 {
      var k = i << 4
      for _ in 0..<16 {
        if blockValuesPresent[k] {
          condensedInUse[i] = true
        }
        k += 1
      }
    }

    for i in 0..<16 {
			try bitOutputStream.writeBoolean (condensedInUse[i]);
		}

    /* Alternative 1
    for i in 0..<16 {
      if condensedInUse[i] {
        var k = i * 16
        for _ in 0..<16 {
          try bitOutputStream.writeBoolean(blockValuesPresent[k])
          k += 1
        }
      }
    } */
    /* Alternative 2
    for i in 0..<16 where condensedInUse[i] {
      for k in (i * 16)..<(i * 16 + 16) {
        try bitOutputStream.writeBoolean(blockValuesPresent[k])
      }
    }
     */
    /* Alternative 3
    for i in 0..<16 {
      guard condensedInUse[i] else { continue }
      let start = i * 16
      let end = start + 16
      for k in start..<end {
        try bitOutputStream.writeBoolean(blockValuesPresent[k])
      }
    }
    */
    // Alternative 3.1
    for i in 0..<16 where condensedInUse[i] {
      let start = i * 16
      for k in start..<start + 16 {
        try bitOutputStream.writeBoolean(blockValuesPresent[k])
      }
    }
  }

	/**
	 * Writes an RLE run to the block array, updating the block CRC and present values array as required
	 * @param value The value to write
	 * @param runLength The run length of the value to write
	 */
  private func writeRun (_ value : Int, _ _runLength : Int) {
    var runLength = _runLength
    
    let blockLength : Int = self.blockLength;
    var block : [UInt8] = self.block;

		self.blockValuesPresent[value] = true;
		self.crc.updateCRC (value, runLength)

    let byteValue : UInt8 = UInt8(value)
		switch (runLength) {
			case 1:
				block[blockLength] = byteValue;
				self.blockLength = blockLength + 1;
				break;

			case 2:
				block[blockLength] = byteValue;
				block[blockLength + 1] = byteValue;
				self.blockLength = blockLength + 2;
				break;

			case 3:
				block[blockLength] = byteValue;
				block[blockLength + 1] = byteValue;
				block[blockLength + 2] = byteValue;
				self.blockLength = blockLength + 3;
				break;

			default:
				runLength -= 4;
				self.blockValuesPresent[runLength] = true;
				block[blockLength] = byteValue;
				block[blockLength + 1] = byteValue;
				block[blockLength + 2] = byteValue;
				block[blockLength + 3] = byteValue;
				block[blockLength + 4] = UInt8(runLength)
				self.blockLength = blockLength + 5;
				break;
		}
	}

	/**
	 * Writes a byte to the block, accumulating to an RLE run where possible
	 * @param value The byte to write
	 * @return {@code true} if the byte was written, or {@code false} if the block is already full
	 */
  public func write (_ value : Int) -> Bool {

		if (self.blockLength > self.blockLengthLimit) {
			return false;
		}

		let rleCurrentValue = self.rleCurrentValue;
		let rleLength = self.rleLength;

		if (rleLength == 0) {
			self.rleCurrentValue = value;
			self.rleLength = 1;
		}
    else if (rleCurrentValue != value) {
			// This path commits us to write 6 bytes - one RLE run (5 bytes) plus one extra
			writeRun (rleCurrentValue & 0xff, rleLength);
			self.rleCurrentValue = value;
			self.rleLength = 1;
		}
    else {
			if (rleLength == 254) {
				writeRun (rleCurrentValue & 0xff, 255);
				self.rleLength = 0;
			} else {
				self.rleLength = rleLength + 1;
			}
		}

		return true;
	}

	/**
	 * Writes an array to the block
	 * @param data The array to write
	 * @param offset The offset within the input data to write from
	 * @param length The number of bytes of input data to write
	 * @return The actual number of input bytes written. May be less than the number requested, or
	 *         zero if the block is already full
	 */
  public func write (_ data : [UInt8], _ _offset : Int, _ _length : Int) -> Int {
    var length = _length
    var offset = _offset
		var written = 0;

    while length > 0 {
      length -= 1
      if !write(Int(data[offset])) {
        break
      }
      offset += 1
      written += 1
    }
    
		return written;
	}

	/**
	 * Compresses and writes out the block
	 * @throws IOException on any I/O error writing the data
	 */
	public func close() throws {

		// If an RLE run is in progress, write it out
		if (self.rleLength > 0) {
			writeRun (self.rleCurrentValue & 0xff, self.rleLength);
		}

		// Apply a one byte block wrap required by the BWT implementation
		self.block[self.blockLength] = self.block[0];

		// Perform the Burrows Wheeler Transform
    let divSufSort = BZip2DivSufSort (self.block, self.bwtBlock, self.blockLength);
    let bwtStartPointer : Int = divSufSort.bwt();

		// Write out the block header
    try self.bitOutputStream.writeBits (24, BZip2Constants.BLOCK_HEADER_MARKER_1);
    try self.bitOutputStream.writeBits (24, BZip2Constants.BLOCK_HEADER_MARKER_2);
    try self.bitOutputStream.writeInteger (self.crc.getCRC());
    try self.bitOutputStream.writeBoolean (false); // Randomised block flag. We never create randomised blocks
    try self.bitOutputStream.writeBits (24, bwtStartPointer);

		// Write out the symbol map
    try writeSymbolMap();

		// Perform the Move To Front Transform and Run-Length Encoding[2] stages 
    let mtfEncoder = BZip2MTFAndRLE2StageEncoder (self.bwtBlock, self.blockLength, self.blockValuesPresent);
		mtfEncoder.encode();

		// Perform the Huffman Encoding stage and write out the encoded data
    let huffmanEncoder = BZip2HuffmanStageEncoder (self.bitOutputStream, mtfEncoder.getMtfBlock(), mtfEncoder.getMtfLength(), mtfEncoder.getMtfAlphabetSize(), mtfEncoder.getMtfSymbolFrequencies());
    try huffmanEncoder.encode();
	}

	/**
	 * Determines if any bytes have been written to the block
	 * @return {@code true} if one or more bytes has been written to the block, otherwise
	 *         {@code false}
	 */
	public func isEmpty() -> Bool {
		return ((self.blockLength == 0) && (self.rleLength == 0));
	}

	/**
	 * Gets the CRC of the completed block. Only valid after calling {@link #close()}
	 * @return The block's CRC
	 */
	public func getCRC() -> Int {
		return self.crc.getCRC();
	}

	/**
	 * @param bitOutputStream The BZip2BitOutputStream to which compressed BZip2 data is written
	 * @param blockSize The declared block size in bytes. Up to this many bytes will be accepted
	 *                  into the block after Run-Length Encoding is applied
	 */
  public init (_ bitOutputStream : BZip2BitOutputStream, _ blockSize : Int) {
		self.bitOutputStream = bitOutputStream;

		// One extra byte is added to allow for the block wrap applied in close()
    self.block = Array.init(repeating: 0, count: blockSize + 1)
		self.bwtBlock = Array.init(repeating: 0, count: blockSize + 1)
		self.blockLengthLimit = blockSize - 6; // 5 bytes for one RLE run plus one byte - see {@link #write(int)}
	}
}
