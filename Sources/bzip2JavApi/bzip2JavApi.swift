/*
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

public enum BZip2Exception : Error {
  /// - Since: JavaApi &gt; 0.16.0 (Java 1.0)
  case IOException (_ message : String = "IOException")
  case BZip2Exception (_ message : String = "BZip2Exception")
}

infix operator ≡ : AssignmentPrecedence
extension Int {
  static func ≡ (left: inout Int, right: UInt8) {
    left = Int(right)
  }
}

extension UInt8 {
  static func ≡ (left: inout UInt8, right: Int) {
    left = UInt8(right)
  }
}
