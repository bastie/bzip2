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
 * <p>An OutputStream wrapper that allows the writing of single bit booleans, unary numbers, bit
 * strings of arbitrary length (up to 24 bits), and bit aligned 32-bit integers. A single byte at a
 * time is written to the wrapped stream when sufficient bits have been accumulated
 */
open class BZip2BitOutputStream {

	/**
	 * The stream to which bits are written
	 */
  private let outputStream : java.io.OutputStream

	/**
	 * A buffer of bits waiting to be written to the output stream
	 */
  private var bitBuffer : Int = 0

	/**
	 * The number of bits currently buffered in {@link #bitBuffer}
	 */
  private var bitCount : Int = 0

	/**
	 * Writes a single bit to the wrapped output stream
	 * @param value The bit to write
	 * @throws IOException if an error occurs writing to the stream
	 */
  public func writeBoolean (_ value : Bool) throws {
		var bitCount = self.bitCount + 1;
		var bitBuffer = self.bitBuffer | ((value ? 1 : 0) << (32 - bitCount));

		if (bitCount == 8) {
			try self.outputStream.write (bitBuffer >>> 24);
			bitBuffer = 0;
			bitCount = 0;
		}

		self.bitBuffer = bitBuffer;
		self.bitCount = bitCount;
	}

	/**
	 * Writes a zero-terminated unary number to the wrapped output stream
	 * @param value The number to write (must be non-negative)
	 * @throws IOException if an error occurs writing to the stream
	 */
  public func writeUnary (_ _value : Int) throws {
    var value = _value
    while value > 0 { value -= 1 //while (value-- > 0) {
			try writeBoolean (true);
		}
		try writeBoolean (false);
	}

	/**
	 * Writes up to 24 bits to the wrapped output stream
	 * @param count The number of bits to write (maximum 24)
	 * @param value The bits to write
	 * @throws IOException if an error occurs writing to the stream
	 */
  public func writeBits (_ count : Int, _ value : Int) throws {
		var bitCount = self.bitCount;
		var bitBuffer = self.bitBuffer | ((value << (32 - count)) >>> bitCount);
		bitCount += count;

		while (bitCount >= 8) {
      let byte : Int = bitBuffer >>> 24
			try self.outputStream.write (byte);
			bitBuffer <<= 8;
			bitCount -= 8;
		}

		self.bitBuffer = bitBuffer;
		self.bitCount = bitCount;
	}

	/**
	 * Writes an integer as 32 bits of output
	 * @param value The integer to write
	 * @throws IOException if an error occurs writing to the stream
	 */
  public func writeInteger (_ value : Int) throws {
		try writeBits (16, (value >>> 16) & 0xffff);
		try writeBits (16, value & 0xffff);
	}

	/**
	 * Writes any remaining bits to the output stream, zero padding to a whole byte as required
	 * @throws IOException if an error occurs writing to the stream
	 */
	public func flush() throws {
		if (self.bitCount > 0) {
			try writeBits (8 - self.bitCount, 0);
		}
	}

	/**
	 * @param outputStream The OutputStream to wrap
	 */
  public init (_ outputStream : java.io.OutputStream) {
		self.outputStream = outputStream;
	}
}
