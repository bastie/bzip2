/*
 * Copyright (c) 2003-2008 Yuta Mori All Rights Reserved.
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

// extract inner class from BZIP2DivSufSort

/**
 */
internal class TRBudget {
  
  /**
   */
  var budget : Int
  
  /**
   */
  var chance : Int
  
  /**
   * @param size
   * @param n
   * @return something
   */
  public func update(_ size: Int, _ n: Int) -> Bool {
    budget -= n
    
    if budget <= 0 {
      chance -= 1
      guard chance != 0 else { return false }
      budget += size
    }
    
    return true
  }
  
  /**
   * @param budget
   * @param chance
   */
  public init (_ budget : Int, _ chance : Int) {
    self.budget = budget;
    self.chance = chance;
  }
}
