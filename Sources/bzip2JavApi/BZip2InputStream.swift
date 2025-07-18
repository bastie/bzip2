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
 * <p>An InputStream wrapper that decompresses BZip2 data</p>
 *
 * <p>A BZip2 stream consists of one or more blocks of compressed data. This decompressor reads a
 * whole block at a time, then progressively returns decompressed output.</p>
 *
 * <p>On encountering any error decoding the compressed stream, an IOException is thrown, and
 * further reads will return {@code -1}</p>
 *
 * <p><b>Note:</b> Each BZip2 compressed block contains a CRC code which is verified after the block
 * has been read completely. If verification fails, an exception is thrown on the final read from
 * the block, <b>potentially after corrupt data has already been returned</b>. The compressed stream
 * also contains a final CRC code which is verified once the end of the stream has been reached.
 * <b>This check may fail even if every individual block in the stream passes CRC verification</b>.
 * If this possibility is of concern, you should read and store the entire decompressed stream
 * before further processing.</p>
 *
 * <p>Instances of this class are not threadsafe.</p>
 */
open class BZip2InputStream : java.io.InputStream {

	/**
	 * The stream from which compressed BZip2 data is read and decoded
	 */
  private var inputStream : java.io.InputStream?

	/**
	 * An InputStream wrapper that provides bit-level reads
	 */
  private var bitInputStream : BZip2BitInputStream?

	/**
	 * If {@code true}, the caller is assumed to have read away the stream's leading "BZ" identifier
	 * bytes
	 */
  private var headerless : Bool

	/**
	 * (@code true} if the end of the compressed stream has been reached, otherwise {@code false}
	 */
	private var streamComplete = false;

	/**
	 * The declared block size of the stream (before final run-length decoding). The final block
	 * will usually be smaller, but no block in the stream has to be exactly this large, and an
	 * encoder could in theory choose to mix blocks of any size up to this value. Its function is
	 * therefore as a hint to the decompressor as to how much working space is sufficient to
	 * decompress blocks in a given stream
	 */
  private var streamBlockSize : Int = 0

	/**
	 * The merged CRC of all blocks decompressed so far
	 */
	private var streamCRC = 0;

	/**
	 * The decompressor for the current block
	 */
  private var blockDecompressor : BZip2BlockDecompressor? = nil


	/* (non-Javadoc)
	 * @see java.io.InputStream#read()
	 */
  public override func read() throws -> Int {

		var nextByte = -1;
		if (self.blockDecompressor == nil) {
      _ = try initialiseStream();
		} else {
      nextByte = self.blockDecompressor!.read();
		}

		if (nextByte == -1) {
      if (try initialiseNextBlock()) {
        nextByte = self.blockDecompressor!.read();
			}
		}

		return nextByte;

	}

	/* (non-Javadoc)
	 * @see java.io.InputStream#read(byte[], int, int)
	 */
  public override func read (_ destination : inout [UInt8], _ offset : Int, _ length : Int) throws -> Int {

		var bytesRead = -1;
		if (self.blockDecompressor == nil) {
      _ = try initialiseStream();
		} else {
      bytesRead = self.blockDecompressor!.read (&destination, offset, length);
		}

		if (bytesRead == -1) {
      if (try initialiseNextBlock()) {
        bytesRead = self.blockDecompressor!.read (&destination, offset, length);
			}
		}
		return bytesRead
	}


	/* (non-Javadoc)
	 * @see java.io.InputStream#close()
	 */
  public override func close() throws {
    defer {
      self.inputStream = nil;
    }

		if (self.bitInputStream != nil) {
			self.streamComplete = true;
			self.blockDecompressor = nil;
			self.bitInputStream = nil;

      try  self.inputStream!.close();
		}

	}


	/**
	 * Reads the stream header and checks that the data appears to be a valid BZip2 stream
	 * @throws IOException if the stream header is not valid
	 */
	private func initialiseStream() throws -> Bool {

		/* If the stream has been explicitly closed, throw an exception */
		if (self.bitInputStream == nil) {
      throw BZip2Exception.IOException("Stream closed");
		}

		/* If we're already at the end of the stream, do nothing */
		if (self.streamComplete) {
			return false //return;
		}

		/* Read the stream header */
		do {
      let marker1 : Int = self.headerless ? 0 : try self.bitInputStream!.readBits (16);
      let marker2 : Int = try self.bitInputStream!.readBits (8);
      let blockSize : Int = Int( (try self.bitInputStream!.readBits(8) - Int(UInt8(ascii: "0"))) )

			if (
					   (!self.headerless && (marker1 != BZip2Constants.STREAM_START_MARKER_1))
					|| (marker2 != BZip2Constants.STREAM_START_MARKER_2)
					|| (blockSize < 1) || (blockSize > 9))
			{
        throw BZip2Exception.IOException("Invalid BZip2 header");
			}

			self.streamBlockSize = blockSize * 100000;
    } catch {
			// If the stream header was not valid, stop trying to read more data
			self.streamComplete = true;
			throw error
		}

    return true
	}


	/**
	 * Prepares a new block for decompression if any remain in the stream. If a previous block has
	 * completed, its CRC is checked and merged into the stream CRC. If the previous block was the
	 * final block in the stream, the stream CRC is validated
	 * @return {@code true} if a block was successfully initialised, or {@code false} if the end of
	 *                      file marker was encountered
	 * @throws IOException if either the block or stream CRC check failed, if the following data is
	 *                      not a valid block-header or end-of-file marker, or if the following
	 *                      block could not be decoded
	 */
	private func initialiseNextBlock() throws -> Bool {

		/* If we're already at the end of the stream, do nothing */
		if (self.streamComplete) {
			return false;
		}

		/* If a block is complete, check the block CRC and integrate it into the stream CRC */
		if (self.blockDecompressor != nil) {
      let blockCRC = try self.blockDecompressor!.checkCRC();
			self.streamCRC = ((self.streamCRC << 1) | (self.streamCRC >>> 31)) ^ blockCRC;
		}

		/* Read block-header or end-of-stream marker */
    let marker1 = try self.bitInputStream!.readBits (24);
    let marker2 = try self.bitInputStream!.readBits (24);

		if (marker1 == BZip2Constants.BLOCK_HEADER_MARKER_1 && marker2 == BZip2Constants.BLOCK_HEADER_MARKER_2) {
			// Initialise a new block
			do {
        self.blockDecompressor = try BZip2BlockDecompressor (self.bitInputStream!, self.streamBlockSize);
			} catch {
				// If the block could not be decoded, stop trying to read more data
				self.streamComplete = true;
				throw error
			}
			return true;
		} else if (marker1 == BZip2Constants.STREAM_END_MARKER_1 && marker2 == BZip2Constants.STREAM_END_MARKER_2) {
			// Read and verify the end-of-stream CRC
			self.streamComplete = true;
      let storedCombinedCRC = try self.bitInputStream!.readInteger();
			if (storedCombinedCRC != self.streamCRC) {
        throw BZip2Exception.IOException("BZip2 stream CRC error");
			}
			return false;
		}

		/* If what was read is not a valid block-header or end-of-stream marker, the stream is broken */
		self.streamComplete = true;
    throw BZip2Exception.IOException("BZip2 stream format error");

	}


	/**
	 * @param inputStream The InputStream to wrap
	 * @param headerless If {@code true}, the caller is assumed to have read away the stream's
	 *                   leading "BZ" identifier bytes
	 */
  public init (_ inputStream : java.io.InputStream, _ headerless : Bool) {

		self.inputStream = inputStream;
		self.bitInputStream = BZip2BitInputStream (inputStream);
		self.headerless = headerless;

	}

}
