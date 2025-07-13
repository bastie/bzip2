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
 * <p>An OutputStream wrapper that compresses BZip2 data</p>
 *
 * <p>Instances of this class are not threadsafe.</p>
 */
open class BZip2OutputStream : java.io.OutputStream {

	/**
	 * The stream to which compressed BZip2 data is written
	 */
  private var outputStream : java.io.OutputStream

	/**
	 * An OutputStream wrapper that provides bit-level writes
	 */
  private var bitOutputStream : BZip2BitOutputStream

	/**
	 * (@code true} if the compressed stream has been finished, otherwise {@code false}
	 */
	private var streamFinished = false;

	/**
	 * The declared maximum block size of the stream (before final run-length decoding)
	 */
  private var streamBlockSize : Int

	/**
	 * The merged CRC of all blocks compressed so far
	 */
	private var streamCRC = 0;

	/**
	 * The compressor for the current block
	 */
  private var blockCompressor : BZip2BlockCompressor


	/* (non-Javadoc)
	 * @see java.io.OutputStream#write(int)
	 */
  public override func write (_ value : Int) throws {

		if (self.streamFinished) {
      throw BZip2Exception.IOException("Write beyond end of stream");
		}

		if (!self.blockCompressor.write (value & 0xff)) {
      try closeBlock();
			initialiseNextBlock();
			_ = self.blockCompressor.write (value & 0xff);
		}

	}


	/* (non-Javadoc)
	 * @see java.io.OutputStream#write(byte[], int, int)
	 */
  public override func write (_ data : [UInt8], _ _offset : Int, _ _length : Int) throws {
    var offset = _offset
    var length = _length

		if (self.streamFinished) {
      throw BZip2Exception.IOException("Write beyond end of stream");
		}

    var bytesWritten : Int
		while (length > 0) {
      bytesWritten = self.blockCompressor.write(data, offset, length)
      if bytesWritten < length {
        try closeBlock();
				initialiseNextBlock();
			}
			offset += bytesWritten;
			length -= bytesWritten;
		}

	}


	/* (non-Javadoc)
	 * @see java.io.OutputStream#close()
	 */
  public override func close() throws {
    try finish();
    try self.outputStream.close();
	}


	/**
	 * Initialises a new block for compression
	 */
	private func initialiseNextBlock() {

		self.blockCompressor = BZip2BlockCompressor (self.bitOutputStream, self.streamBlockSize);

	}


	/**
	 * Compress and write out the block currently in progress. If no bytes have been written to the
	 * block, it is discarded
	 * @throws IOException on any I/O error writing to the output stream
	 */
	private func closeBlock() throws {

		if (self.blockCompressor.isEmpty()) {
			return;
		}

    try self.blockCompressor.close();
    let blockCRC : Int = self.blockCompressor.getCRC();
		self.streamCRC = ((self.streamCRC << 1) | (self.streamCRC >>> 31)) ^ blockCRC;

	}


	/**
	 * Compresses and writes out any as yet unwritten data, then writes the end of the BZip2 stream.
	 * The underlying OutputStream is not closed
	 * @throws IOException on any I/O error writing to the output stream
	 */
	public func finish() throws {

		if (!self.streamFinished) {
			self.streamFinished = true;
      try closeBlock();
      try self.bitOutputStream.writeBits (24, BZip2Constants.STREAM_END_MARKER_1);
      try self.bitOutputStream.writeBits (24, BZip2Constants.STREAM_END_MARKER_2);
      try self.bitOutputStream.writeInteger (self.streamCRC);
      try self.bitOutputStream.flush();
      try self.outputStream.flush();
		}

	}


	/**
	 * @param outputStream The output stream to write to
	 * @param blockSizeMultiplier The BZip2 block size as a multiple of 100,000 bytes (minimum 1,
	 * maximum 9). Larger block sizes require more memory for both compression and decompression,
	 * but give better compression ratios. <code>9</code> will usually be the best value to use
	 * @throws IOException on any I/O error writing to the output stream
	 */
  public init (_ outputStream : java.io.OutputStream, _ blockSizeMultiplier : Int) throws  {

		if ((blockSizeMultiplier < 1) || (blockSizeMultiplier > 9)) {
      throw java.lang.Throwable.IllegalArgumentException ("Invalid BZip2 block size \(blockSizeMultiplier)")
		}

		self.streamBlockSize = blockSizeMultiplier * 100000;
		self.outputStream = outputStream;
		self.bitOutputStream = BZip2BitOutputStream (self.outputStream);

    try self.bitOutputStream.writeBits (16, BZip2Constants.STREAM_START_MARKER_1);
    try self.bitOutputStream.writeBits (8,  BZip2Constants.STREAM_START_MARKER_2);
    let charValue = UInt8(ascii: "0") + UInt8(blockSizeMultiplier)
    try self.bitOutputStream.writeBits (8, Int(charValue));

		//initialiseNextBlock();
    self.blockCompressor = BZip2BlockCompressor (self.bitOutputStream, self.streamBlockSize);

	}


	/**
	 * Constructs a BZip2 stream compressor with the maximum (900,000 byte) block size
	 * @param outputStream The output stream to write to
	 * @throws IOException on any I/O error writing to the output stream
	 */
  public convenience init (_ outputStream : java.io.OutputStream) throws {
    try self.init (outputStream, 9);
	}

}
