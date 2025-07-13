/*
 * Copyright (c) 2003-2008 Yuta Mori All Rights Reserved.
 * Copyright (c) 2011 Matthew Francis
 * Copyright (c) 2025 Sebastian Ritter
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of self software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and self permission notice shall be included in
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
 * DivSufSort suffix array generator
 * Based on libdivsufsort 1.2.3 patched to support BZip2
 *
 * This is a simple conversion of the original C with two minor bugfixes applied (see "BUGFIX"
 * comments within the class). Documentation within the class is largely absent.
 */
open class BZip2DivSufSort {
  
  /**
   */
  private static let STACK_SIZE = 64
  
  /**
   */
  private static let BUCKET_A_SIZE = 256
  
  /**
   */
  private static let BUCKET_B_SIZE = 65536
  
  /**
   */
  private static let SS_BLOCKSIZE = 1024
  
  /**
   */
  private static let INSERTIONSORT_THRESHOLD = 8
  
  /**
   */
  private static let log2table : [Int] = [
    -1,0,1,1,2,2,2,2,3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,
    5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
    6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
    6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
    7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
    7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
    7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
    7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
  ]
  
  /**
   */
  private var SA : [Int]
  
  /**
   */
  private let T : [UInt8]
  
  /**
   */
  private let n : Int
  
  /**
   * @param array1
   * @param index1
   * @param array2
   * @param index2
   */
  private static func swapElements (_ array1 : inout [Int], _ index1 : Int, _ array2 : inout [Int], _ index2 : Int) {
    let temp : Int = array1[index1]
    array1[index1] = array2[index2]
    array2[index2] = temp
  }
  
  /**
   * @param p1
   * @param p2
   * @param depth
   * @return
   */
  private func ssCompare (_ p1 : Int, _ p2 : Int, _ depth : Int) -> Int {
    
    var U1n : Int
    var U2n : Int // pointers within T
    var U1 : Int
    var U2 : Int
    
    /*#
    for (
      U1 = depth + SA[p1], U2 = depth + SA[p2], U1n = SA[p1 + 1] + 2, U2n = SA[p2 + 1] + 2;
      (U1 < U1n) && (U2 < U2n) && (T[U1] == T[U2]);
      ++U1, ++U2
    ){}
     */
    // Initialization
    U1 = depth + SA[p1]
    U2 = depth + SA[p2]
    U1n = SA[p1 + 1] + 2
    U2n = SA[p2 + 1] + 2
    
    // Comparison loop
    while U1 < U1n && U2 < U2n && T[U1] == T[U2] {
      U1 += 1
      U2 += 1
    }
    //#
    
    return {
      var result : Int = 0
      result ≡ UInt8(U1 < U1n ?
                     Int (U2 < U2n ? (T[U1] & 0xff) - (T[U2] & 0xff) : 1)
                     : (U2 < U2n ? -1 : 0));
      return result
    }()
  }
  
  
  /**
   * @param PA
   * @param p1
   * @param p2
   * @param depth
   * @param size
   * @return
   */
  private func ssCompareLast (_ PA : Int, _ p1 : Int, _ p2 : Int, _ depth : Int, _ size : Int) -> Int {
    var U1 : Int
    var U2 : Int
    var U1n : Int
    var U2n : Int

    /*#
    for (
      U1 = depth + SA[p1], U2 = depth + SA[p2], U1n = size, U2n = SA[(p2 + 1)] + 2;
      (U1 < U1n) && (U2 < U2n) && (T[U1] == T[U2]);
      ++U1, ++U2
    ){}
     */
    U1 = depth + SA[p1]
    U2 = depth + SA[p2]
    U1n = size
    U2n = SA[p2 + 1] + 2
    
    // Comparison loop
    while U1 < U1n && U2 < U2n && T[U1] == T[U2] {
      U1 += 1
      U2 += 1
    }
    //#
    
    if (U1 < U1n) {
      return {
        var result : Int = 0
        result ≡ (U2 < U2n) ? (T[U1] & 0xff) - (T[U2] & 0xff) : 1
        return result
      }()
    } else if (U2 == U2n) {
      return 1;
    }
    
    /*#
    for (
      U1 = U1 % size, U1n = SA[PA] + 2;
      (U1 < U1n) && (U2 < U2n) && (T[U1] == T[U2]);
      ++U1, ++U2
    ){}
     */
    U1 = U1 % size
    U1n = SA[PA] + 2
    
    while U1 < U1n && U2 < U2n && T[U1] == T[U2] {
      U1 += 1
      U2 += 1
    }
    /* //Schneller soll es gehen mit:
     T.withUnsafeBufferPointer { tBuffer in
       while U1 < U1n && U2 < U2n && tBuffer[U1] == tBuffer[U2] {
         U1 += 1
         U2 += 1
       }
     }
     */
    //#
    
    return {
      var result : Int = 0
      result ≡ UInt8(U1 < U1n ?
                     Int (U2 < U2n ? (T[U1] & 0xff) - (T[U2] & 0xff) : 1)
                     : (U2 < U2n ? -1 : 0))
      return result
    }()
    
  }
  
  
  /**
   * @param PA
   * @param first
   * @param last
   * @param depth
   */
  private func ssInsertionSort (_ PA : Int, _ first : Int, _ last : Int, _ depth : Int) {
    
    var i : Int
    var j : Int // pointer within SA
    var t : Int
    var r : Int
    
    /*#
    for (i = last - 2; first <= i; --i) {
      for (t = SA[i], j = i + 1; 0 < (r = ssCompare (PA + t, PA + SA[j], depth));) {
        repeat {
          SA[j - 1] = SA[j];
        } while ((++j < last) && (SA[j] < 0));
        if (last <= j) {
          break;
        }
      }
      if (r == 0) {
        SA[j] = ~SA[j];
      }
      SA[j - 1] = t;
    }
     */
    i = last - 2
    while first <= i {
      t = SA[i]
      j = i + 1
      
      // Innere Vergleichsschleife
      while true {
        r = ssCompare(PA + t, PA + SA[j], depth)
        if !(0 < r) { break }
        
        // Verschiebe-Elemente-Schleife
        repeat {
          SA[j - 1] = SA[j]
          j += 1
        } while j < last && SA[j] < 0
        
        if last <= j { break }
      }
      
      // Sentinel-Markierung
      if r == 0 {
        SA[j] = ~SA[j]
      }
      
      // Wiederherstellung des Elements
      SA[j - 1] = t
      i -= 1
    }
    //#
  }
  
  /**
   * @param Td
   * @param PA
   * @param sa
   * @param i
   * @param size
   */
  private func ssFixdown (_ Td : Int, _ PA : Int, _ sa : Int, _ i : Int, _ size : Int) {
    var i = i
    
    var j : Int
    var k : Int
    var v : Int
    var c : Int
    /*#
    var d : Int
    var e : Int
    
    for (v = SA[sa + i], c = (T[Td + SA[PA + v]]) & 0xff; (j = 2 * i + 1) < size; SA[sa + i] = SA[sa + k], i = k) {
      d = T[Td + SA[PA + SA[sa + (k = j++)]]] & 0xff;
      if (d < (e = T[Td + SA[PA + SA[sa + j]]] & 0xff)) {
        k = j;
        d = e;
      }
      if (d <= c) {
        break
      }
    }
     */
    v = SA[sa + i]
    c = Int(T[Td + SA[PA + v]]) & 0xff
    j = 2 * i + 1
    
    while j < size {
      // 1. Bestimme das kleinere Kind (k)
      k = j
      let d = Int(T[Td + SA[PA + SA[sa + j]]]) & 0xff
      
      if j + 1 < size {
        let e = Int(T[Td + SA[PA + SA[sa + j + 1]]]) & 0xff
        if d < e {
          k = j + 1
        }
      }
      
      // 2. Vergleiche mit Elternknoten (c)
      let d_k = Int(T[Td + SA[PA + SA[sa + k]]]) & 0xff
      if d_k <= c {
        break
      }
      
      // 3. Heap-Operation: Tausche und aktualisiere Indizes
      SA[sa + i] = SA[sa + k]
      i = k
      j = 2 * i + 1
    }
    SA[sa + i] = v
    
  }
  
  /**
   * @param Td
   * @param PA
   * @param sa
   * @param size
   */
  private func ssHeapSort (_ Td : Int, _ PA : Int, _ sa : Int, _ size : Int) {
    
    var m : Int
    var t : Int
    
    m = size;
    if ((size % 2) == 0) {
      m -= 1
      if ((T[Td + SA[PA + SA[sa + (m / 2)]]] & 0xff) < (T[Td + SA[PA + SA[sa + m]]] & 0xff)) {
        BZip2DivSufSort.swapElements (&SA, sa + m, &SA, sa + (m / 2));
      }
    }
    
    //# for (i = m / 2 - 1; 0 <= i; --i) {
    for i in stride(from: m / 2 - 1, through: 0, by: -1) {
      ssFixdown (Td, PA, sa, i, m);
    }
    
    if ((size % 2) == 0) {
      BZip2DivSufSort.swapElements (&SA, sa, &SA, sa + m);
      ssFixdown (Td, PA, sa, 0, m);
    }
    
    //# for (i = m - 1; 0 < i; --i) {
    for i in stride(from: m - 1, through: 1, by: -1) {
      t = SA[sa];
      SA[sa] = SA[sa + i];
      ssFixdown (Td, PA, sa, 0, i);
      SA[sa + i] = t;
    }
  }
  
  /**
   * @param Td
   * @param PA
   * @param v1
   * @param v2
   * @param v3
   * @return
   */
  private func ssMedian3 (_ Td : Int, _ PA : Int, _ v1 : Int, _ v2 : Int, _ v3 : Int) -> Int {
    var v1 = v1
    var v2 = v2
    
    var T_v1 = T[Td + SA[PA + SA[v1]]] & 0xff
    var T_v2 = T[Td + SA[PA + SA[v2]]] & 0xff
    let T_v3 = T[Td + SA[PA + SA[v3]]] & 0xff
    
    if (T_v1 > T_v2) {
      let temp = v1
      v1 = v2
      v2 = temp
      let T_vtemp = T_v1
      T_v1 = T_v2
      T_v2 = T_vtemp
    }
    if (T_v2 > T_v3) {
      if (T_v1 > T_v3) {
        return v1;
      }
      return v3;
    }
    return v2;
    
  }
  
  
  /**
   * @param Td
   * @param PA
   * @param v1
   * @param v2
   * @param v3
   * @param v4
   * @param v5
   * @return
   */
  private func ssMedian5 (_ Td : Int, _ PA : Int, _ v1 : Int, _ v2 : Int, _ v3 : Int, _ v4 : Int, _ v5 : Int) -> Int {
    var v1 = v1
    var v2 = v2
    var v3 = v3
    var v4 = v4
    var v5 = v5
    
    var T_v1 = T[Td + SA[PA + SA[v1]]] & 0xff
    var T_v2 = T[Td + SA[PA + SA[v2]]] & 0xff
    var T_v3 = T[Td + SA[PA + SA[v3]]] & 0xff
    var T_v4 = T[Td + SA[PA + SA[v4]]] & 0xff
    var T_v5 = T[Td + SA[PA + SA[v5]]] & 0xff
    var temp : Int
    var T_vtemp : Int = 0
    
    if (T_v2 > T_v3) {
      temp = v2;
      v2 = v3;
      v3 = temp;
      T_vtemp ≡ T_v2;
      T_v2 = T_v3;
      T_v3 ≡ T_vtemp;
    }
    if (T_v4 > T_v5) {
      temp = v4;
      v4 = v5;
      v5 = temp;
      T_vtemp ≡ T_v4;
      T_v4 = T_v5;
      T_v5 ≡ T_vtemp;
    }
    if (T_v2 > T_v4) {
      temp = v2;
      v2 = v4;
      v4 = temp;
      T_vtemp ≡ T_v2;
      T_v2 = T_v4;
      T_v4 ≡ T_vtemp;
      temp = v3;
      v3 = v5;
      v5 = temp;
      T_vtemp ≡ T_v3;
      T_v3 = T_v5;
      T_v5 ≡ T_vtemp;
    }
    if (T_v1 > T_v3) {
      temp = v1;
      v1 = v3;
      v3 = temp;
      T_vtemp ≡ T_v1;
      T_v1 = T_v3;
      T_v3 ≡ T_vtemp;
    }
    if (T_v1 > T_v4) {
      temp = v1;
      v1 = v4;
      v4 = temp;
      T_vtemp ≡ T_v1;
      T_v1 = T_v4;
      T_v4 ≡ T_vtemp;
      temp = v3;
      v3 = v5;
      v5 = temp;
      T_vtemp ≡ T_v3;
      T_v3 = T_v5;
      T_v5 ≡ T_vtemp;
    }
    if (T_v3 > T_v4) {
      return v4;
    }
    return v3;
    
  }
  
  
  /**
   * @param Td
   * @param PA
   * @param first
   * @param last
   * @return
   */
  private func ssPivot (_ Td : Int, _ PA : Int, _ first : Int, _ last : Int) -> Int {
    
    var middle : Int
    var t : Int
    
    t = last - first;
    middle = first + t / 2;
    
    if (t <= 512) {
      if (t <= 32) {
        return ssMedian3 (Td, PA, first, middle, last - 1);
      }
      t >>= 2;
      return ssMedian5 (Td, PA, first, first + t, middle, last - 1 - t, last - 1);
    }
    t >>= 3;
    return ssMedian3 (
      Td, PA,
      ssMedian3 (Td, PA, first, first + t, first + (t << 1)),
      ssMedian3 (Td, PA, middle - t, middle, middle + t),
      ssMedian3 (Td, PA, last - 1 - (t << 1), last - 1 - t, last - 1)
    );
  }
  
  
  /**
   * @param n
   * @return
   */
  private func ssLog (_ n : Int) -> Int {
    return ((n & 0xff00) != 0) ?
    8 + BZip2DivSufSort.log2table[(n >> 8) & 0xff]
    : BZip2DivSufSort.log2table[n & 0xff];
  }
  
  
  /**
   * @param PA
   * @param first
   * @param last
   * @param depth
   * @return
   */
  private func ssSubstringPartition (_ PA : Int, _ first : Int, _ last : Int, _ depth : Int) -> Int {
    
    var a : Int
    var b : Int
    var t : Int
    
    /*# begin of Java=>Swift
    for (a = first - 1, b = last;;) {
    */
    a = first - 1
    b = last
    while (true) {
    //# end of Java=>Swift
      a += 1
      while (a < b) && ((SA[PA + SA[a]] + depth) >= (SA[PA + SA[a] + 1] + 1)) {
        SA[a] = ~SA[a];
        a += 1
      }
      b -= 1
      while (a < b) && ((SA[PA + SA[b]] + depth) <  (SA[PA + SA[b] + 1] + 1)) {
        b -= 1
      }
      if (b <= a) {
        break;
      }
      t = ~SA[b];
      SA[b] = SA[a];
      SA[a] = t;
    }
    if (first < a) {
      SA[first] = ~SA[first];
    }
    
    return a;
    
  }
  
  /**
   * @param PA
   * @param first
   * @param last
   * @param depth
   */
  private func ssMultiKeyIntroSort (_ PA : Int, _ first : Int, _ last : Int, _ depth : Int) {
    var first : Int = first
    var last : Int = last
    var depth : Int = depth
    var stack : [StackEntry] = Array(repeating: StackEntry(), count: BZip2DivSufSort.STACK_SIZE)
    
    var Td = 0;
    var a = 0
    var b = 0
    var d = 0
    var e = 0
    var f = 0
    var s = 0
    var t = 0
    var ssize : Int
    var limit : Int
    var v = 0
    var x = 0
    
    ssize = 0
    limit = ssLog (last - first)
    while (true) {
      if ((last - first) <= BZip2DivSufSort.INSERTIONSORT_THRESHOLD) {
        if (1 < (last - first)) {
          ssInsertionSort (PA, first, last, depth);
        }
        if (ssize == 0) {
          return
        }
        ssize -= 1
        let entry = stack[ssize]
        first = entry.a;
        last = entry.b;
        depth = entry.c;
        limit = entry.d;
        continue;
      }
      
      Td = depth;
      if (limit == 0) {
        ssHeapSort (Td, PA, first, last - first);
      }
      limit -= 1
      if (limit < 0) {
        /*#
        for (a = first + 1, v = T[Td + SA[PA + SA[first]]] & 0xff; a < last; ++a) {
          if ((x = (T[Td + SA[PA + SA[a]]] & 0xff)) != v) {
            if (1 < (a - first)) { break; }
            v = x;
            first = a;
          }
        }
         */
        a = first + 1
        v ≡ T[Td + SA[PA + SA[first]]] & 0xff
        
        while a < last {
          let x = T[Td + SA[PA + SA[a]]] & 0xff
          if x != v {
            if 1 < (a - first) {
              break
            }
            v ≡ x
            first = a
          }
          a += 1
        }
        //#
        if ((T[Td + SA[PA + SA[first]] - 1] & 0xff) < v) {
          first = ssSubstringPartition (PA, first, a, depth);
        }
        if ((a - first) <= (last - a)) {
          if (1 < (a - first)) {
            stack[ssize] = StackEntry (a, last, depth, -1);
            ssize += 1
            last = a;
            depth += 1;
            limit = ssLog (a - first);
          } else {
            first = a;
            limit = -1;
          }
        } else {
          if (1 < (last - a)) {
            stack[ssize] = StackEntry (first, a, depth + 1, ssLog (a - first));
            ssize += 1
            first = a;
            limit = -1;
          } else {
            last = a;
            depth += 1;
            limit = ssLog (a - first);
          }
        }
        continue;
      }
      
      a = ssPivot (Td, PA, first, last);
      v ≡ T[Td + SA[PA + SA[a]]] & 0xff;
      BZip2DivSufSort.swapElements (&SA, first, &SA, a);
      
      //# for (b = first; (++b < last) && ((x = (T[Td + SA[PA + SA[b]]] & 0xff)) == v);){}
      b = first
      b += 1  // Simulates ++b before first check
      
      while b < last {
        guard Td + SA[PA + SA[b]] < T.count else { break }
        let x = Int(T[Td + SA[PA + SA[b]]]) & 0xff
        
        if x != v { break }
        
        b += 1
      }
      
      //# if (((a = b) < last) && (x < v)) {
      a = b
      if a < last && x < v {
        //#while (++b < last) && ((x = (T[Td + SA[PA + SA[b]]] & 0xff)) <= v) {
        b += 1  // Pre-increment simulation
        while b < last {
          // Safe array access
          guard Td + SA[PA + SA[b]] < T.count else { break }
          
          // Byte extraction and comparison
          x = Int(T[Td + SA[PA + SA[b]]]) & 0xff
          guard x <= v else { break }
          
          // Loop body here
          
          if (x == v) {
            BZip2DivSufSort.swapElements (&SA, b, &SA, a);
            a += 1
          }

          b += 1  // Increment for next iteration
        }
      }
      //# for (c = last; (b < --c) && ((x = (T[Td + SA[PA + SA[c]]] & 0xff)) == v);){}
      var c = last
      while true {
        c -= 1  // Pre-decrement simulation
        guard b < c else { break }
        
        // Safe array access
        let saPos = PA + SA[c]
        
        // Byte extraction and comparison
        x = Int(T[Td + SA[saPos]]) & 0xff
        guard x == v else { break }
        
        // Loop body would go here
      }
      
      d = c
      if ((b < d) && (x > v)) {
       //# while (b < --c) && ((x = (T[Td + SA[PA + SA[c]]] & 0xff)) >= v) {
        while true {
          c -= 1
          if !(b < c) { break }
          
          x = Int(T[Td + SA[PA + SA[c]]]) & 0xff
          if x < v { break }
          
          if (x == v) {
            BZip2DivSufSort.swapElements (&SA, c, &SA, d);
            d -= 1
          }
        }
      }
      while b < c {
        BZip2DivSufSort.swapElements (&SA, b, &SA, c);
        //# while (++b < c) && ((x = (T[Td + SA[PA + SA[b]]] & 0xff)) <= v) {
        b += 1  // Pre-increment simulation
        while b < c {
          // Safe array access
          let saPos = PA + SA[b]
          guard saPos >= 0 && saPos < SA.count,
                Td + SA[saPos] < T.count else { break }
          
          // Byte extraction and comparison
          let x = Int(T[Td + SA[saPos]]) & 0xff
          guard x <= v else { break }
          
          // Loop body here
          if (x == v) {
            BZip2DivSufSort.swapElements (&SA, b, &SA, a);
            a += 1
          }
          
          b += 1  // Increment for next iteration
        }
        //# while (b < --c) && ((x = (T[Td + SA[PA + SA[c]]] & 0xff)) >= v) {
        while true {
          c -= 1
          if !(b < c) { break }
          
          let x = Int(T[Td + SA[PA + SA[c]]]) & 0xff
          if x < v { break }
          
          // Schleifenkörper
          if (x == v) {
            BZip2DivSufSort.swapElements (&SA, c, &SA, d);
            d -= 1
          }
        }
      }
      
      if (a <= d) {
        c = b - 1;
        
        if ((s = a - first) > (t = b - a)) {
          s = t;
        }
        //# for (e = first, f = b - s; 0 < s; --s, ++e, ++f) {
        e = first
        f = b - s
        while 0 < s {
          BZip2DivSufSort.swapElements (&SA, e, &SA, f);

          s -= 1
          e += 1
          f += 1
        }
        if ((s = d - c) > (t = last - d - 1)) {
          s = t;
        }
        //# for (e = b, f = last - s; 0 < s; --s, ++e, ++f) {
        e = b
        f = last - s
        while s > 0 {
          // Schleifenkörper
          BZip2DivSufSort.swapElements (&SA, e, &SA, f);

          s -= 1
          e += 1
          f += 1
        }
        
        a = first + (b - a);
        c = last - (d - c);
        b = (v <= (T[Td + SA[PA + SA[a]] - 1] & 0xff)) ? a : ssSubstringPartition (PA, a, c, depth);
        
        if ((a - first) <= (last - c)) {
          if ((last - c) <= (c - b)) {
            stack[ssize] = StackEntry (b, c, depth + 1, ssLog (c - b));
            ssize += 1
            stack[ssize] = StackEntry (c, last, depth, limit);
            ssize += 1
            last = a;
          } else if ((a - first) <= (c - b)) {
            stack[ssize] = StackEntry (c, last, depth, limit);
            ssize += 1
            stack[ssize] = StackEntry (b, c, depth + 1, ssLog (c - b));
            ssize += 1
            last = a;
          } else {
            stack[ssize] = StackEntry (c, last, depth, limit);
            ssize += 1
            stack[ssize] = StackEntry (first, a, depth, limit);
            ssize += 1
            first = b;
            last = c;
            depth += 1;
            limit = ssLog (c - b);
          }
        } else {
          if ((a - first) <= (c - b)) {
            stack[ssize] = StackEntry (b, c, depth + 1, ssLog (c - b));
            ssize += 1
            stack[ssize] = StackEntry (first, a, depth, limit);
            ssize += 1
            first = c;
          } else if ((last - c) <= (c - b)) {
            stack[ssize] = StackEntry (first, a, depth, limit);
            ssize += 1
            stack[ssize] = StackEntry (b, c, depth + 1, ssLog (c - b));
            ssize += 1
            first = c;
          } else {
            stack[ssize] = StackEntry (first, a, depth, limit);
            ssize += 1
            stack[ssize] = StackEntry (c, last, depth, limit);
            ssize += 1
            first = b;
            last = c;
            depth += 1;
            limit = ssLog (c - b);
          }
        }
      } else {
        limit += 1;
        if ((T[Td + SA[PA + SA[first]] - 1] & 0xff) < v) {
          first = ssSubstringPartition (PA, first, last, depth);
          limit = ssLog (last - first);
        }
        depth += 1;
      }
    }
  }
  
  /**
   * @param array1
   * @param first1
   * @param array2
   * @param first2
   * @param size
   */
  private func ssBlockSwap (_ array1 : inout [Int], _ first1 : Int, _ array2 : inout [Int], _ first2 : Int, _ size : Int) {
    var a : Int
    var b : Int
    var i : Int
    /*#
    for (i = size, a = first1, b = first2; 0 < i; --i, ++a, ++b) {
      swapElements (array1, a, array2, b);
    }
     */
    i = size
    a = first1
    b = first2
    
    while i > 0 {
      BZip2DivSufSort.swapElements(&array1, a, &array2, b)
      i -= 1
      a += 1
      b += 1
    }
    //#
  }
  
  /**
   * @param PA
   * @param buf
   * @param bufoffset
   * @param first
   * @param middle
   * @param last
   * @param depth
   */
  private func ssMergeForward (_ PA : Int, _ buf : inout [Int], _ bufoffset : Int, _ first : Int, _ middle : Int, _ last : Int, _ depth : Int) {
    
    var bufend : Int
    var i : Int
    var j : Int
    var k : Int
    var t : Int
    var r : Int
    
    bufend = bufoffset + (middle - first) - 1;
    ssBlockSwap (&buf, bufoffset, &SA, first, middle - first);
    
    t = SA[first]
    i = first
    j = bufoffset
    k = middle
    while true {
      r = ssCompare (PA + buf[j], PA + SA[k], depth);
      if (r < 0) {
        repeat {
          SA[i] = buf[j];
          i += 1
          if (bufend <= j) {
            buf[j] = t;
            return;
          }
          buf[j] = SA[i];
          j += 1
        } while (buf[j] < 0);
      } else if (r > 0) {
        repeat {
          SA[i] = SA[k];
          i += 1
          SA[k] = SA[i];
           k += 1
          if (last <= k) {
            while (j < bufend) {
              SA[i] = buf[j];
              i += 1
              buf[j] = SA[i];
              j += 1
            }
            SA[i] = buf[j]; buf[j] = t;
            return;
          }
        } while (SA[k] < 0);
      } else {
        SA[k] = ~SA[k];
        repeat {
          SA[i] = buf[j];
          i += 1
          if (bufend <= j) {
            buf[j] = t;
            return;
          }
          buf[j] = SA[i];
          j += 1
        } while (buf[j] < 0);
        
        repeat {
          SA[i] = SA[k];
          i += 1
          SA[k] = SA[i];
          k += 1
          if (last <= k) {
            while (j < bufend) {
              SA[i] = buf[j];
              i += 1
              buf[j] = SA[i];
              j += 1
            }
            SA[i] = buf[j]; buf[j] = t;
            return;
          }
        } while (SA[k] < 0);
      }
    }
    
  }
  
  
  /**
   * @param PA
   * @param buf
   * @param buf
   * @param bufoffset
   * @param first
   * @param middle
   * @param last
   * @param depth
   */
  private func ssMergeBackward (_ PA : Int, _ buf : inout [Int], _ bufoffset : Int, _ first : Int, _ middle : Int, _ last : Int, _ depth : Int) {
    
    var p1 : Int
    var p2 : Int
    var bufend : Int
    var i : Int
    var j : Int
    var k : Int
    var t : Int
    var r : Int
    var x : Int
    
    bufend = bufoffset + (last - middle);
    ssBlockSwap (&buf, bufoffset, &SA, middle, last - middle);
    
    x = 0;
    if (buf[bufend - 1] < 0) {
      x |=  1;
      p1 = PA + ~buf[bufend - 1];
    } else {
      p1 = PA +  buf[bufend - 1];
    }
    if (SA[middle - 1] < 0) {
      x |=  2;
      p2 = PA + ~SA[middle - 1];
    } else {
      p2 = PA +  SA[middle - 1];
    }
    
    t = SA[last - 1]
    i = last - 1
    j = bufend - 1
    k = middle - 1
    while true {
      
      r = ssCompare (p1, p2, depth);
      if (r > 0) {
        if ((x & 1) != 0) {
          repeat {
            SA[i] = buf[j];
            i -= 1
            buf[j] = SA[i];
            j -= 1
          } while (buf[j] < 0);
          x ^= 1;
        }
        SA[i] = buf[j];
        i -= 1
        if (j <= bufoffset) {
          buf[j] = t;
          return;
        }
        buf[j] = SA[i];
        j -= 1
        
        if (buf[j] < 0) {
          x |=  1;
          p1 = PA + ~buf[j];
        } else {
          p1 = PA +  buf[j];
        }
      } else if (r < 0) {
        if ((x & 2) != 0) {
          repeat {
            SA[i] = SA[k];
            i -= 1
            SA[k] = SA[i];
            k -= 1
          } while (SA[k] < 0);
          x ^= 2;
        }
        SA[i] = SA[k];
        i -= 1
        SA[k] = SA[i];
        k -= 1
        if (k < first) {
          while (bufoffset < j) {
            SA[i] = buf[j];
            i -= 1
            buf[j] = SA[i];
            j -= 1
          }
          SA[i] = buf[j];
          buf[j] = t;
          return;
        }
        
        if (SA[k] < 0) {
          x |=  2;
          p2 = PA + ~SA[k];
        } else {
          p2 = PA +  SA[k];
        }
      } else {
        if ((x & 1) != 0) {
          repeat {
            SA[i] = buf[j];
            i -= 1
            buf[j] = SA[i];
            j -= 1
          } while (buf[j] < 0);
          x ^= 1;
        }
        SA[i] = ~buf[j];
        i -= 1
        if (j <= bufoffset) {
          buf[j] = t;
          return;
        }
        buf[j] = SA[i];
        j -= 1
        
        if ((x & 2) != 0) {
          repeat {
            SA[i] = SA[k];
            i -= 1
            SA[k] = SA[i];
            k -= 1
          } while (SA[k] < 0);
          x ^= 2;
        }
        SA[i] = SA[k];
        i -= 1
        SA[k] = SA[i];
        k -= 1
        if (k < first) {
          while (bufoffset < j) {
            SA[i] = buf[j];
            i -= 1
            buf[j] = SA[i];
            j -= 1
          }
          SA[i] = buf[j];
          buf[j] = t;
          return;
        }
        
        if (buf[j] < 0) {
          x |=  1;
          p1 = PA + ~buf[j];
        } else {
          p1 = PA +  buf[j];
        }
        if (SA[k] < 0) {
          x |=  2;
          p2 = PA + ~SA[k];
        } else {
          p2 = PA +  SA[k];
        }
      }
    }
  }
  
  /**
   * @param a
   * @return
   */
  private static func getIDX (_ a : Int) -> Int {
    return (0 <= a) ? a : ~a;
  }
  
  /**
   * @param PA
   * @param depth
   * @param a
   */
  private func ssMergeCheckEqual (_ PA : Int, _ depth : Int, _ a : Int) {
    if (
      (0 <= SA[a])
      && (ssCompare (PA + BZip2DivSufSort.getIDX (SA[a - 1]), PA + SA[a], depth) == 0)
    )
    {
      SA[a] = ~SA[a];
    }
  }
  
  /**
   * @param PA
   * @param first
   * @param middle
   * @param last
   * @param buf
   * @param bufoffset
   * @param bufsize
   * @param depth
   */
  private func ssMerge (_ PA : Int, _ first : Int, _ middle : Int, _ last : Int, _ buf : inout [Int], _ bufoffset : Int, _ bufsize : Int, _ depth : Int) {
    var first = first
    var middle = middle
    var last = last
    
    var stack : [StackEntry] = Array(repeating: StackEntry(), count: BZip2DivSufSort.STACK_SIZE)

    var i : Int
    var j : Int
    var m : Int
    var len : Int
    var half : Int
    var ssize : Int = 0
    var check : Int = 0
    var next : Int = 0
    
    while true {
      
      if ((last - middle) <= bufsize) {
        if ((first < middle) && (middle < last)) {
          ssMergeBackward (PA, &buf, bufoffset, first, middle, last, depth);
        }
        
        if ((check & 1) != 0) {
          ssMergeCheckEqual (PA, depth, first);
        }
        if ((check & 2) != 0) {
          ssMergeCheckEqual (PA, depth, last);
        }
        if (ssize == 0) {
          return
        }
        ssize -= 1
        let entry = stack[ssize]
        first = entry.a;
        middle = entry.b;
        last = entry.c;
        check = entry.d;
        continue;
      }
      
      if ((middle - first) <= bufsize) {
        if (first < middle) {
          ssMergeForward ( PA, &buf, bufoffset, first, middle, last, depth);
        }
        if ((check & 1) != 0) {
          ssMergeCheckEqual (PA, depth, first);
        }
        if ((check & 2) != 0) {
          ssMergeCheckEqual (PA, depth, last);
        }
        if (ssize == 0) {
          return
        }
        ssize -= 1
        let entry = stack[ssize]
        first = entry.a;
        middle = entry.b;
        last = entry.c;
        check = entry.d;
        continue;
      }
      
      /*#
      for (
        m = 0, len = Math.min (middle - first, last - middle), half = len >> 1;
        0 < len;
        len = half, half >>= 1
      )
      {
        if (ssCompare (PA + getIDX (SA[middle + m + half]),
                       PA + getIDX (SA[middle - m - half - 1]), depth) < 0) {
          m += half + 1;
          half -= (len & 1) ^ 1;
        }
      }
       */
      m = 0
      len = Math.min(middle - first, last - middle)
      half = len >> 1
      
      while len > 0 {
        let compareResult = ssCompare(
          PA + BZip2DivSufSort.getIDX(SA[middle + m + half]),
          PA + BZip2DivSufSort.getIDX(SA[middle - m - half - 1]),
          depth
        )
        
        if compareResult < 0 {
          m += half + 1
          half -= (len & 1) ^ 1
        }
        
        len = half
        half >>= 1
      }
      //#
      
      if (0 < m) {
        ssBlockSwap (&SA, middle - m, &SA, middle, m);
        j = middle
        i = j
        next = 0;
        if ((middle + m) < last) {
          if (SA[middle + m] < 0) {
            while i > 0 && SA[i - 1] < 0 {
              i -= 1
            }
            SA[middle + m] = ~SA[middle + m];
          }
          j = middle
          while SA[j] < 0 {
            j += 1
          }
          next = 1;
        }
        if ((i - first) <= (last - j)) {
          stack[ssize] = StackEntry (j, middle + m, last, (check &  2) | (next & 1));
          ssize += 1
          middle -= m;
          last = i;
          check = (check & 1);
        } else {
          if ((i == middle) && (middle == j)) {
            next <<= 1;
          }
          stack[ssize] = StackEntry (first, middle - m, i, (check & 1) | (next & 2));
          ssize += 1
          first = j;
          middle += m;
          check = (check & 2) | (next & 1);
        }
      } else {
        if ((check & 1) != 0) {
          ssMergeCheckEqual (PA, depth, first);
        }
        ssMergeCheckEqual (PA, depth, middle);
        if ((check & 2) != 0) {
          ssMergeCheckEqual (PA, depth, last);
        }
        if (ssize == 0) {
          return
        }
        ssize -= 1
        let entry = stack[ssize]
        first = entry.a;
        middle = entry.b;
        last = entry.c;
        check = entry.d;
      }
      
    }
    
  }
  
  
  /**
   * @param PA
   * @param first
   * @param last
   * @param buf
   * @param bufoffset
   * @param bufsize
   * @param depth
   * @param lastsuffix
   * @param size
   */
  private func subStringSort (_ PA : Int, _ first : Int, _ last : Int, _ buf : inout [Int], _ bufoffset : Int, _ bufsize : Int, _ depth : Int, _ lastsuffix : Bool, _ size : Int) {
    var first = first
    
    var a : Int
    var b : Int
    var curbuf : [Int]
    var curbufoffset : Int
    var i : Int
    var j : Int
    var k : Int
    var curbufsize : Int
    
    if (lastsuffix) {
      first += 1
    }
    //# for (a = first, i = 0; (a + SS_BLOCKSIZE) < last; a += SS_BLOCKSIZE, ++i) {
    a = first
    i = 0
    while (a + BZip2DivSufSort.SS_BLOCKSIZE) < last {
      ssMultiKeyIntroSort (PA, a, a + BZip2DivSufSort.SS_BLOCKSIZE, depth);
      curbuf = SA;
      curbufoffset = a + BZip2DivSufSort.SS_BLOCKSIZE;
      curbufsize = last - (a + BZip2DivSufSort.SS_BLOCKSIZE);
      if (curbufsize <= bufsize) {
        curbufsize = bufsize;
        curbuf = buf;
        curbufoffset = bufoffset;
      }
      /*#
      for (b = a, k = SS_BLOCKSIZE, j = i; (j & 1) != 0; b -= k, k <<= 1, j >>>= 1) {
        ssMerge (PA, b - k, b, b + k, curbuf, curbufoffset, curbufsize, depth);
      }
       */
      b = a
      k = BZip2DivSufSort.SS_BLOCKSIZE
      j = i
      
      while (j & 1) != 0 {
        ssMerge(PA, b - k, b, b + k, &curbuf, curbufoffset, curbufsize, depth)
        
        // Update variables
        b -= k
        k <<= 1       // Double k using bit shift
        j >>= 1        // Halve j using bit shift
      }
      //#
      
      a += BZip2DivSufSort.SS_BLOCKSIZE
      i += 1

    }
    
    ssMultiKeyIntroSort (PA, a, last, depth);
    
    //# for (k = SS_BLOCKSIZE; i != 0; k <<= 1, i >>= 1) {
    k = BZip2DivSufSort.SS_BLOCKSIZE
    while i != 0 {
      // Schleifenkörper
      if ((i & 1) != 0) {
        ssMerge (PA, a - k, a, last, &buf, bufoffset, bufsize, depth);
        a -= k;
      }
      k <<= 1  // Bitweise Linksverschiebung
      i >>= 1  // Bitweise Rechtsverschiebung
    }
    
    if (lastsuffix) {
      var r : Int
      /*# for (
        a = first, i = SA[first - 1], r = 1;
        (a < last) && ((SA[a] < 0) || (0 < (r = ssCompareLast (PA, PA + i, PA + SA[a], depth, size))));
        ++a
      )
      {
        SA[a - 1] = SA[a];
      }
       */
      a = first
      i = SA[first - 1]
      r = 1
      while true {
        // Bedingungsteil
        guard a < last else { break }
        let current = SA[a]
        if current >= 0 {
          r = ssCompareLast(PA, PA + i, PA + current, depth, size)
          guard r > 0 else { break }
        }
        
        // Schleifenkörper
        SA[a - 1] = SA[a]
        a += 1
      }
      //#
      if (r == 0) {
        SA[a] = ~SA[a];
      }
      SA[a - 1] = i;
    }
    
  }
  
  /**
   * @param ISA
   * @param ISAd
   * @param ISAn
   * @param p
   * @return
   */
  private func trGetC (_ ISA : Int, _ ISAd : Int, _ ISAn : Int, _ p : Int) -> Int {
    
    return (((ISAd + p) < ISAn) ? self.SA[ISAd + p] : self.SA[ISA + ((ISAd - ISA + p) % (ISAn - ISA))]);
    
  }
  
  
  /**
   * @param ISA
   * @param ISAd
   * @param ISAn
   * @param sa
   * @param i
   * @param size
   */
  private func trFixdown (_ ISA : Int, _ ISAd : Int, _ ISAn : Int, _ sa : Int, _ i : Int, _ size : Int) {
    var i = i
    var j : Int
    var k : Int
    var v : Int
    var c : Int
    var d : Int
    var e : Int
    
    //# for (v = SA[sa +i], c = trGetC (ISA, ISAd, ISAn, v); (j = 2 * i + 1) < size; SA[sa + i] = SA[sa + k], i = k) {
    v = SA[sa + i]
    c = trGetC(ISA, ISAd, ISAn, v)
    j = 2 * i + 1
    
    while j < size {
      // Schleifenkörper hier
      
      k = j;
      j += 1
      d = trGetC (ISA, ISAd, ISAn, SA[sa + k]);
      //# if (d < (e = trGetC (ISA, ISAd, ISAn, SA[sa + j]))) {
      e = trGetC(ISA, ISAd, ISAn, SA[sa + j])
      if d < e {
        k = j;
        d = e;
      }
      if (d <= c) {
        break;
      }
      // Update-Ausdrücke am Ende:
      SA[sa + i] = SA[sa + k]
      i = k
      j = 2 * i + 1  // Neuberechnung für nächste Iteration
      v = SA[sa + i]  // Optional, falls v benötigt wird
      c = trGetC(ISA, ISAd, ISAn, v)  // Optional, falls c benötigt wird
    }
    //#
    SA[sa + i] = v;
    
  }
  
  
  /**
   * @param ISA
   * @param ISAd
   * @param ISAn
   * @param sa
   * @param size
   */
  private func trHeapSort (_ ISA : Int, _ ISAd : Int, _ ISAn : Int, _ sa : Int, _ size : Int) {
    
    var m : Int
    var t : Int
    
    m = size;
    if ((size % 2) == 0) {
      m -= 1
      if (trGetC (ISA, ISAd, ISAn, SA[sa + (m / 2)]) < trGetC (ISA, ISAd, ISAn, SA[sa + m])) {
        BZip2DivSufSort.swapElements (&SA, sa + m, &SA, sa + (m / 2));
      }
    }
    
    //# for (i = m / 2 - 1; 0 <= i; --i) {
    for i in stride(from: m / 2 - 1, through: 0, by: -1) {
      trFixdown (ISA, ISAd, ISAn, sa, i, m);
    }
    
    if ((size % 2) == 0) {
      BZip2DivSufSort.swapElements (&SA, sa + 0, &SA, sa + m);
      trFixdown (ISA, ISAd, ISAn, sa, 0, m);
    }
    
    //# for (i = m - 1; 0 < i; --i) {
    for i in stride(from: m - 1, through: 1, by: -1) {
      t = SA[sa + 0];
      SA[sa + 0] = SA[sa + i];
      trFixdown (ISA, ISAd, ISAn, sa, 0, i);
      SA[sa + i] = t;
    }
    
  }
  
  
  /**
   * @param ISA
   * @param ISAd
   * @param ISAn
   * @param first
   * @param last
   */
  private func trInsertionSort (_ ISA : Int, _ ISAd : Int, _ ISAn : Int, _ first : Int, _ last : Int) {
    
    var b : Int
    var t : Int
    var r : Int
    
    //# for (a = first + 1; a < last; ++a) {
    for a in (first + 1)..<last {
      /*#
      for (t = SA[a], b = a - 1; 0 > (r = trGetC (ISA, ISAd, ISAn, t) - trGetC (ISA, ISAd, ISAn, SA[b]));) {
        repeat {
          SA[b + 1] = SA[b];
        } while ((first <= --b) && (SA[b] < 0));
        if (b < first) {
          break;
        }
      }
       */
      t = SA[a]
      b = a - 1
      
      while true {
        r = trGetC(ISA, ISAd, ISAn, t) - trGetC(ISA, ISAd, ISAn, SA[b])
        if !(0 > r) { break }
        
        repeat {
          SA[b + 1] = SA[b]
          b -= 1
        } while first <= b && SA[b] < 0
        
        if b < first {
          break
        }
      }      //#
      if (r == 0) {
        SA[b] = ~SA[b];
      }
      SA[b + 1] = t;
    }
    
  }
  
  
  /**
   * @param n
   * @return
   */
  private func trLog (_ n : Int) -> Int {
    return ((n & 0xffff0000) != 0) ?
    (((n & 0xff000000) != 0) ? 24 + BZip2DivSufSort.log2table[(n >> 24) & 0xff] : 16 + BZip2DivSufSort.log2table[(n >> 16) & 0xff])
    : (((n & 0x0000ff00) != 0) ? 8 + BZip2DivSufSort.log2table[(n >>  8) & 0xff] : 0 + BZip2DivSufSort.log2table[(n >>  0) & 0xff])
  }
  
  
  /**
   * @param ISA
   * @param ISAd
   * @param ISAn
   * @param v1
   * @param v2
   * @param v3
   * @return
   */
  private func trMedian3 (_ ISA : Int, _ ISAd : Int, _ ISAn : Int, _ v1 : Int, _ v2 : Int, _ v3 : Int) -> Int {
    var v1 = v1
    var v2 = v2
    
    var SA_v1 = trGetC (ISA, ISAd, ISAn, SA[v1]);
    var SA_v2 = trGetC (ISA, ISAd, ISAn, SA[v2]);
    let SA_v3 = trGetC (ISA, ISAd, ISAn, SA[v3]);
    
    if (SA_v1 > SA_v2) {
      let temp = v1;
      v1 = v2;
      v2 = temp;
      let SA_vtemp = SA_v1;
      SA_v1 = SA_v2;
      SA_v2 = SA_vtemp;
    }
    if (SA_v2 > SA_v3) {
      if (SA_v1 > SA_v3) {
        return v1;
      }
      return v3;
    }
    
    return v2;
    
  }
  
  
  /**
   * @param ISA
   * @param ISAd
   * @param ISAn
   * @param v1
   * @param v2
   * @param v3
   * @param v4
   * @param v5
   * @return
   */
  private func trMedian5 (_ ISA : Int, _ ISAd : Int, _ ISAn : Int, _ v1 : Int, _ v2 : Int, _ v3 : Int, _ v4 : Int, _ v5 : Int) -> Int {
    var v1 = v1
    var v2 = v2
    var v3 = v3
    var v4 = v4
    var v5 = v5
    
    var SA_v1 = trGetC (ISA, ISAd, ISAn, SA[v1]);
    var SA_v2 = trGetC (ISA, ISAd, ISAn, SA[v2]);
    var SA_v3 = trGetC (ISA, ISAd, ISAn, SA[v3]);
    var SA_v4 = trGetC (ISA, ISAd, ISAn, SA[v4]);
    var SA_v5 = trGetC (ISA, ISAd, ISAn, SA[v5]);
    var temp : Int
    var SA_vtemp : Int
    
    if (SA_v2 > SA_v3) {
      temp = v2;
      v2 = v3;
      v3 = temp;
      SA_vtemp = SA_v2;
      SA_v2 = SA_v3;
      SA_v3 = SA_vtemp;
    }
    if (SA_v4 > SA_v5) {
      temp = v4;
      v4 = v5;
      v5 = temp;
      SA_vtemp = SA_v4;
      SA_v4 = SA_v5;
      SA_v5 = SA_vtemp;
    }
    if (SA_v2 > SA_v4) {
      temp = v2;
      v2 = v4;
      v4 = temp;
      SA_vtemp = SA_v2;
      SA_v2 = SA_v4;
      SA_v4 = SA_vtemp;
      temp = v3;
      v3 = v5;
      v5 = temp;
      SA_vtemp = SA_v3;
      SA_v3 = SA_v5;
      SA_v5 = SA_vtemp;
    }
    if (SA_v1 > SA_v3) {
      temp = v1;
      v1 = v3;
      v3 = temp;
      SA_vtemp = SA_v1;
      SA_v1 = SA_v3;
      SA_v3 = SA_vtemp;
    }
    if (SA_v1 > SA_v4) {
      temp = v1;
      v1 = v4;
      v4 = temp;
      SA_vtemp = SA_v1;
      SA_v1 = SA_v4;
      SA_v4 = SA_vtemp;
      temp = v3;
      v3 = v5;
      v5 = temp;
      SA_vtemp = SA_v3;
      SA_v3 = SA_v5;
      SA_v5 = SA_vtemp;
    }
    if (SA_v3 > SA_v4) {
      return v4;
    }
    return v3;
    
  }
  
  
  /**
   * @param ISA
   * @param ISAd
   * @param ISAn
   * @param first
   * @param last
   * @return
   */
  private func trPivot (_ ISA : Int, _ ISAd : Int, _ ISAn : Int, _ first : Int, _ last : Int) -> Int {
    
    var middle : Int
    var t : Int
    
    t = last - first;
    middle = first + t / 2;
    
    if (t <= 512) {
      if (t <= 32) {
        return trMedian3 (ISA, ISAd, ISAn, first, middle, last - 1);
      }
      t >>= 2;
      return trMedian5 (
        ISA, ISAd, ISAn,
        first, first + t,
        middle,
        last - 1 - t, last - 1
      );
    }
    t >>= 3;
    return trMedian3 (
      ISA, ISAd, ISAn,
      trMedian3 (ISA, ISAd, ISAn, first, first + t, first + (t << 1)),
      trMedian3 (ISA, ISAd, ISAn, middle - t, middle, middle + t),
      trMedian3 (ISA, ISAd, ISAn, last - 1 - (t << 1), last - 1 - t, last - 1)
    );
    
  }
  
  /**
   * @param ISA
   * @param sa
   * @param first
   * @param last
   */
  private func lsUpdateGroup (_ ISA : Int, _ first : Int, _ last : Int) {
    
    var b : Int
    var t : Int
    
    //#for (a = first; a < last; ++a) {
    for var a in first..<last {
      if (0 <= SA[a]) {
        b = a;
        /*#
        repeat {
          SA[ISA + SA[a]] = a;
        } while ((++a < last) && (0 <= SA[a]));
         */
        repeat {
          SA[ISA + SA[a]] = a
          a += 1
        } while a < last && SA[a] >= 0
        //#
        SA[b] = b - a;
        if (last <= a) {
          break;
        }
      }
      b = a;
      repeat {
        SA[a] = ~SA[a];
        a += 1
      }
      while (SA[a] < 0)
      t = a;
      repeat {
        SA[ISA + SA[b]] = t;
        b += 1
      }
      while (b <= a)
    }
    
  }
  
  
  /**
   * @param ISA
   * @param ISAd
   * @param ISAn
   * @param sa
   * @param first
   * @param last
   */
  private func lsIntroSort (_ ISA : Int, _ ISAd : Int, _ ISAn : Int, _ first : Int, _ last : Int) {
    var first = first
    var last = last
    var stack : [StackEntry] = Array(repeating: StackEntry(), count: BZip2DivSufSort.STACK_SIZE)

    var a : Int
    var b : Int
    var c : Int
    var d : Int
    var e : Int
    var f : Int
    var s : Int
    var t : Int
    var limit : Int
    var v : Int
    var x = 0
    var ssize : Int
    
    ssize = 0
    limit = trLog (last - first)
    while true {
      
      if ((last - first) <= BZip2DivSufSort.INSERTIONSORT_THRESHOLD) {
        if (1 < (last - first)) {
          trInsertionSort (ISA, ISAd, ISAn, first, last);
          lsUpdateGroup (ISA, first, last);
        } else if ((last - first) == 1) {
          SA[first] = -1;
        }
        if (ssize == 0) {
          return
        }
        ssize -= 1
        let entry = stack[ssize]
        first = entry.a;
        last = entry.b;
        limit = entry.c;
        continue;
      }
      
      if (limit == 0) {
        trHeapSort (ISA, ISAd, ISAn, first, last - first);
        /*#for (a = last - 1; first < a; a = b) {
          for (
            x = trGetC (ISA, ISAd, ISAn, SA[a]), b = a - 1;
            (first <= b) && (trGetC (ISA, ISAd, ISAn, SA[b]) == x);
            --b
          )
          {
            SA[b] = ~SA[b];
          }
        }
         */
        a = last - 1
        while first < a {
          x = trGetC(ISA, ISAd, ISAn, SA[a])
          b = a - 1
          
          while first <= b && trGetC(ISA, ISAd, ISAn, SA[b]) == x {
            SA[b] = ~SA[b]
            b -= 1
          }
          
          a = b
        }
        //#
        lsUpdateGroup (ISA, first, last);
        if (ssize == 0) {
          return
        }
        ssize -= 1
        let entry = stack[ssize]
        first = entry.a;
        last = entry.b;
        limit = entry.c;
        continue;
      }
      limit -= 1
      
      a = trPivot (ISA, ISAd, ISAn, first, last);
      BZip2DivSufSort.swapElements (&SA, first, &SA, a);
      v = trGetC (ISA, ISAd, ISAn, SA[first]);
      
      //# for (b = first; (++b < last) && ((x = trGetC (ISA, ISAd, ISAn, SA[b])) == v);){}
      b = first
      b += 1  // Pre-increment simulation
      
      while b < last {
        // Safe array access and comparison
        guard b >= 0 && b < SA.count else { break }
        let x = trGetC(ISA, ISAd, ISAn, SA[b])
        
        if x != v { break }
        
        b += 1  // Increment for next iteration
      }
      a = b
      if ((a < last) && (x < v)) {
        //# while (++b < last) && ((x = trGetC (ISA, ISAd, ISAn, SA[b])) <= v) {
        b += 1  // Pre-increment simulation
        while b < last {
          // Safe array access
          guard b >= 0 && b < SA.count else { break }
          
          // Get comparison value
          let x = trGetC(ISA, ISAd, ISAn, SA[b])
          
          // Check comparison condition
          guard x <= v else { break }
          
          // Loop body here
          
          if (x == v) {
            BZip2DivSufSort.swapElements (&SA, b, &SA, a);
            a += 1
          }

          b += 1  // Increment for next iteration
        }
      }
      //# for (c = last; (b < --c) && ((x = trGetC (ISA, ISAd, ISAn, SA[c])) == v);){}
      c = last
      
      while true {
        c -= 1  // Pre-decrement simulation
        
        // Check boundary condition
        guard b < c else { break }
        
        // Safe array access
        guard c >= 0 && c < SA.count else { break }
        
        // Get comparison value
        let x = trGetC(ISA, ISAd, ISAn, SA[c])
        
        // Check comparison condition
        guard x == v else { break }
        
        // Loop body would go here
      }
      
      d = c
      if ((b < d) && (x > v)) {
        //# while (b < --c) && ((x = trGetC (ISA, ISAd, ISAn, SA[c])) >= v) {
        while true {
          c -= 1  // Pre-decrement simulation
          
          // Check boundary condition
          guard b < c else { break }
          
          // Safe array access
          guard c >= 0 && c < SA.count else { break }
          
          // Get comparison value
          let x = trGetC(ISA, ISAd, ISAn, SA[c])
          
          // Check comparison condition
          guard x >= v else { break }
          
          if (x == v) {
            BZip2DivSufSort.swapElements (&SA, c, &SA, d);
            d -= 1
          }
        }
      }
      while b < c {
        BZip2DivSufSort.swapElements (&SA, b, &SA, c);
        b += 1
        /*# while (b < c) && ((x = trGetC (ISA, ISAd, ISAn, SA[b])) <= v) {
          if (x == v) {
            BZip2DivSufSort.swapElements (&SA, b, &SA, a);
            a += 1
          }
        }
         */
        while b < c {
          let x = trGetC(ISA, ISAd, ISAn, SA[b])
          guard x <= v else { break }
          
          if x == v {
            BZip2DivSufSort.swapElements(&SA, b, &SA, a)
            a += 1
          }
          
          b += 1
        }
        //#
        //# while (b < --c) && ((x = trGetC (ISA, ISAd, ISAn, SA[c])) >= v) {
        while true {
          c -= 1 // Manual pre-decrement
          
          // Boundary check
          guard b < c else { break }
          
          // Safe array access
          guard c >= 0 && c < SA.count else { break }
          
          // Get comparison value
          let x = trGetC(ISA, ISAd, ISAn, SA[c])
          
          // Check condition
          guard x >= v else { break }
          
          // --- Loop body here ---
          if (x == v) {
            BZip2DivSufSort.swapElements (&SA, c, &SA, d);
            d -= 1
          }
        }
      }
      
      if (a <= d) {
        c = b - 1;
        
        if ((s = a - first) > (t = b - a)) {
          s = t;
        }
        //# for (e = first, f = b - s; 0 < s; --s, ++e, ++f) {
        e = first
        f = b - s
        
        while s > 0 {
          // --- Schleifenkörper hier ---
          BZip2DivSufSort.swapElements (&SA, e, &SA, f);

          // Manuelle Dekrement/Inkrement-Anpassungen
          s -= 1  // Entspricht --s
          e += 1  // Entspricht ++e
          f += 1  // Entspricht ++f
        }
        //#
        if ((s = d - c) > (t = last - d - 1)) {
          s = t;
        }
        //# for (e = b, f = last - s; 0 < s; --s, ++e, ++f) {
        e = b
        f = last - s
        
        while s > 0 {
          // --- Schleifenkörper hier ---
          BZip2DivSufSort.swapElements (&SA, e, &SA, f);

          // Manuelle Steuerung der Variablen (wie im Java-Code)
          s -= 1  // Entspricht --s
          e += 1  // Entspricht ++e
          f += 1  // Entspricht ++f
        }
        //#
        a = first + (b - a);
        b = last - (d - c);
        
        /*# for (c = first, v = a - 1; c < a; ++c) {
          SA[ISA + SA[c]] = v;
        }
         */
        c = first
        v = a - 1
        
        while c < a {
          SA[ISA + SA[c]] = v
          c += 1  // Equivalent to ++c
        }
        //#
        if (b < last) {
          /*# for (c = a, v = b - 1; c < b; ++c) {
            SA[ISA + SA[c]] = v;
          }
           */
          c = a
          v = b - 1
          
          while c < b {
            SA[ISA + SA[c]] = v
            c += 1  // Equivalent to ++c
          }
          //#
        }
        if ((b - a) == 1) {
          SA[a] = -1
        }
        
        if ((a - first) <= (last - b)) {
          if (first < a) {
            stack[ssize] = StackEntry (b, last, limit, 0);
            ssize += 1
            last = a;
          } else {
            first = b;
          }
        } else {
          if (b < last) {
            stack[ssize] = StackEntry (first, a, limit, 0);
            ssize += 1
            first = b;
          } else {
            last = a;
          }
        }
      } else {
        if (ssize == 0) {
          return
        }
        ssize -= 1
        let entry = stack[ssize]
        first = entry.a;
        last = entry.b;
        limit = entry.c;
      }
    }
  }
  
  
  /**
   * @param ISA
   * @param n
   * @param depth
   */
  private func lsSort (_ ISA : Int, _ n : Int, _ depth : Int) {
    
    var ISAd : Int
    var first : Int
    var last : Int
    var t : Int
    var skip : Int
    
    //# for (ISAd = ISA + depth; -n < SA[0]; ISAd += (ISAd - ISA)) {
    ISAd = ISA + depth
    while -n < SA[0] {
      // Loop body here
      
      first = 0;
      skip = 0;
      repeat {
        t = SA[first]
        if (t < 0) {
          first -= t;
          skip += t;
        } else {
          if (skip != 0) {
            SA[first + skip] = skip;
            skip = 0;
          }
          last = SA[ISA + t] + 1;
          lsIntroSort (ISA, ISAd, ISA + n, first, last);
          first = last;
        }
      } while (first < n);
      if (skip != 0) {
        SA[first + skip] = skip;
      }
      if (n < (ISAd - ISA)) {
        first = 0;
        repeat {
          t = SA[first]
          if (t < 0) {
            first -= t;
          }
          else {
            last = SA[ISA + t] + 1;
            //# for (i = first; i < last; ++i) {
            for i in first..<last {
              SA[ISA + SA[i]] = i;
            }
            first = last;
          }
        } while (first < n);
        break;
      }
      ISAd += (ISAd - ISA)  // Update ISAd
    }
    
  }
  
  /**
   * @param ISA
   * @param ISAd
   * @param ISAn
   * @param first
   * @param last
   * @param v
   * @return
   */
  private func trPartition (_ ISA : Int, _ ISAd : Int, _ ISAn : Int, _ first : Int, _ last : Int, _ v : Int) -> PartitionResult {
    
    var first = first
    var last = last
    
    var a : Int
    var b : Int
    var c : Int
    var d : Int
    var e : Int
    var f : Int
    var t : Int
    var s : Int
    var x = 0;
    
    //# for (b = first - 1; (++b < last) && ((x = trGetC (ISA, ISAd, ISAn, SA[b])) == v);){}
    b = first - 1
    
    while true {
      b += 1  // Pre-increment simulation
      
      // Check boundary condition
      guard b < last else { break }
      
      // Safe array access
      guard b >= 0 && b < SA.count else { break }
      
      // Get comparison value
      x = trGetC(ISA, ISAd, ISAn, SA[b])
      
      // Check comparison condition
      guard x == v else { break }
    }
    //#
    a = b
    if ((a < last) && (x < v)) {
      b += 1
      //# while (b < last) && ((x = trGetC (ISA, ISAd, ISAn, SA[b])) <= v) {
      while b < last {
        // Safe array access
        guard b >= 0 && b < SA.count else { break }
        
        // Get comparison value
        x = trGetC(ISA, ISAd, ISAn, SA[b])
        
        // Check condition
        guard x <= v else { break }
        
        // --- Loop body here ---
        if (x == v) {
          BZip2DivSufSort.swapElements (&SA, b, &SA, a);
          a += 1
        }
        
        b += 1  // Manual increment
      }
    }
    //# for (c = last; (b < --c) && ((x = trGetC (ISA, ISAd, ISAn, SA[c])) == v);){}
    c = last
    
    while true {
      c -= 1  // Pre-decrement simulation
      
      // Boundary check
      guard b < c else { break }
      
      // Safe array access
      guard c >= 0 && c < SA.count else { break }
      
      // Get comparison value
      x = trGetC(ISA, ISAd, ISAn, SA[c])
      
      // Check condition
      guard x == v else { break }
    }
    //#
    d = c
    if ((b < d) && (x > v)) {
      //# while (b < --c) && ((x = trGetC (ISA, ISAd, ISAn, SA[c])) >= v) {
      while true {
        c -= 1 // Manual pre-decrement
        
        // Boundary check
        guard b < c else { break }
        
        // Safe array access
        guard c >= 0 && c < SA.count else { break }
        
        // Value comparison
        x = trGetC(ISA, ISAd, ISAn, SA[c])
        guard x >= v else { break }
        
        // --- Loop body here ---
        if (x == v) {
          BZip2DivSufSort.swapElements (&SA, c, &SA, d)
          d -= 1
        }
      }
      //#
    }
    while b < c {
      BZip2DivSufSort.swapElements (&SA, b, &SA, c)
      //#while (++b < c) && ((x = trGetC (ISA, ISAd, ISAn, SA[b])) <= v) {
      b += 1  // Manual pre-increment (replaces ++b)
      
      while b < c {
        // Safe array access
        guard b >= 0 && b < SA.count else { break }
        
        // Get comparison value
        x = trGetC(ISA, ISAd, ISAn, SA[b])
        
        // Check condition
        guard x <= v else { break }
        
        // --- Loop body here ---
        if (x == v) {
          BZip2DivSufSort.swapElements (&SA, b, &SA, a)
          a += 1
        }
        b += 1
      }
      //#
      //while (b < --c) && ((x = trGetC (ISA, ISAd, ISAn, SA[c])) >= v) {
      while true {
        c -= 1 // Manual pre-decrement (replaces --c)
        
        // Boundary check
        guard b < c else { break }
        
        // Safe array access
        guard c >= 0 && c < SA.count else { break }
        
        // Value comparison
        let x = trGetC(ISA, ISAd, ISAn, SA[c])
        guard x >= v else { break }
        
        // --- Loop body here ---
        if (x == v) {
          BZip2DivSufSort.swapElements (&SA, c, &SA, d)
          d -= 1
        }
      }
      //#
    }
    
    if (a <= d) {
      c = b - 1;
      if ((s = a - first) > (t = b - a)) {
        s = t;
      }
      //# for (e = first, f = b - s; 0 < s; --s, ++e, ++f) {
      e = first
      f = b - s
      
      while s > 0 {
        // --- Loop body here ---
        
        // Manual variable updates
        s -= 1  // Equivalent to --s
        e += 1  // Equivalent to ++e
        f += 1  // Equivalent to ++f
        
        BZip2DivSufSort.swapElements (&SA, e, &SA, f);
      }
      if ((s = d - c) > (t = last - d - 1)) {
        s = t;
      }
      //# for (e = b, f = last - s; 0 < s; --s, ++e, ++f) {
      e = b
      f = last - s
      
      while s > 0 {
        // --- Loop body here ---
        
        // Manual variable updates
        s -= 1  // Equivalent to --s
        e += 1  // Equivalent to ++e
        f += 1  // Equivalent to ++f
      
        BZip2DivSufSort.swapElements (&SA, e, &SA, f);
      }
      first += (b - a);
      last -= (d - c);
    }
    
    return PartitionResult (first, last);
    
  }
  
  
  /**
   * @param ISA
   * @param ISAn
   * @param first
   * @param a
   * @param b
   * @param last
   * @param depth
   */
  private func trCopy (_ ISA : Int, _ ISAn : Int, _ first : Int, _ a : Int, _ b : Int, _ last : Int, _ depth : Int) {
    
    var c : Int
    var d : Int
    var e : Int
    var s : Int
    var v : Int
    
    v = b - 1;
    
    //# for (c = first, d = a - 1; c <= d; ++c) {
    d = a - 1
    for c in first...d {
      // Schleifenkörper
      // Kein manuelles Inkrement nötig
      s = SA[c] - depth
      if (s < 0) {
        s += ISAn - ISA;
      }
      if (SA[ISA + s] == v) {
        d += 1
        SA[d] = s;
        SA[ISA + s] = d;
      }
    }
    //# for (c = last - 1, e = d + 1, d = b; e < d; --c) {
    c = last - 1
    e = d + 1
    d = b  // Überschreibt den ursprünglichen d-Wert
    
    while e < d {
      // --- Schleifenkörper hier ---
      s = SA[c] - depth
      if (s < 0) {
        s += ISAn - ISA;
      }
      if (SA[ISA + s] == v) {
        d -= 1
        SA[d] = s;
        SA[ISA + s] = d;
      }
      c -= 1  // Manuelles Dekrement (ersetzt --c)
    }
    
  }
  
  
  /**
   * @param ISA
   * @param ISAd
   * @param ISAn
   * @param first
   * @param last
   * @param budget
   * @param size
   */
  private func trIntroSort (_ ISA : Int, _ ISAd : Int, _ ISAn : Int, _ first : Int, _ last : Int, _ budget : inout TRBudget, _ size : Int) {
    let ISA = ISA
    var ISAd = ISAd
    let ISAn = ISAn
    var first = first
    var last = last
    
    var stack : [StackEntry] = Array(repeating: StackEntry(), count: BZip2DivSufSort.STACK_SIZE)
    
    var a : Int
    var b : Int
    var c : Int
    var d : Int
    var e : Int
    var f : Int
    var s : Int
    var t : Int
    var v : Int
    var x = 0
    var limit : Int
    var next : Int
    var ssize : Int
    
    ssize = 0
    limit = trLog (last - first)
    while true {
      if (limit < 0) {
        if (limit == -1) {
          if (!budget.update (size, last - first)) {
            break
          }
          let result = trPartition (ISA, ISAd - 1, ISAn, first, last, last - 1);
          a = result.first;
          b = result.last;
          if ((first < a) || (b < last)) {
            if (a < last) {
              //# for (c = first, v = a - 1; c < a; ++c) {
              v = a - 1
              for c in first..<a {
                // Schleifenkörper hier
                SA[ISA + SA[c]] = v;
              }
            }
            if (b < last) {
              //# for (c = a, v = b - 1; c < b; ++c) {
              c = a
              v = b - 1
              
              while c < b {
                // --- Schleifenkörper hier ---
                SA[ISA + SA[c]] = v;

                c += 1  // Manuelles Inkrement (ersetzt ++c)
              }
            }
            
            stack[ssize] = StackEntry (0, a, b, 0);
            ssize += 1
            stack[ssize] = StackEntry (ISAd - 1, first, last, -2);
            ssize += 1
            if ((a - first) <= (last - b)) {
              if (1 < (a - first)) {
                stack[ssize] = StackEntry (ISAd, b, last, trLog (last - b));
                ssize += 1
                last = a; limit = trLog (a - first);
              } else if (1 < (last - b)) {
                first = b; limit = trLog (last - b);
              } else {
                if (ssize == 0) {
                  return
                }
                ssize -= 1
                let entry = stack[ssize]
                ISAd = entry.a;
                first = entry.b;
                last = entry.c;
                limit = entry.d;
              }
            } else {
              if (1 < (last - b)) {
                stack[ssize] = StackEntry (ISAd, first, a, trLog (a - first));
                ssize += 1
                first = b;
                limit = trLog (last - b);
              } else if (1 < (a - first)) {
                last = a;
                limit = trLog (a - first);
              } else {
                if (ssize == 0) {
                  return
                }
                ssize -= 1
                let entry = stack[ssize]
                ISAd = entry.a;
                first = entry.b;
                last = entry.c;
                limit = entry.d;
              }
            }
          } else {
            //# for (c = first; c < last; ++c) {
            for c in first..<last {
              SA[ISA + SA[c]] = c;
            }
            if (ssize == 0) {
              return
            }
            ssize -= 1
            let entry = stack[ssize]
            ISAd = entry.a;
            first = entry.b;
            last = entry.c;
            limit = entry.d;
          }
        } else if (limit == -2) {
          ssize -= 1
          a = stack[ssize].b;
          b = stack[ssize].c;
          trCopy (ISA, ISAn, first, a, b, last, ISAd - ISA);
          if (ssize == 0) {
            return
          }
          ssize -= 1
          let entry = stack[ssize]
          ISAd = entry.a;
          first = entry.b;
          last = entry.c;
          limit = entry.d;
        } else {
          if (0 <= SA[first]) {
            a = first;
            repeat {
              SA[ISA + SA[a]] = a;
              a += 1
            } while ((a < last) && (0 <= SA[a]));
            first = a;
          }
          if (first < last) {
            a = first;
            repeat {
              SA[a] = ~SA[a];
              a += 1
            } while (SA[a] < 0);
            next = (SA[ISA + SA[a]] != SA[ISAd + SA[a]]) ? trLog (a - first + 1) : -1;
            a += 1
            if (a < last) {
              //# for (b = first, v = a - 1; b < a; ++b) {
                b = first
                v = a - 1
                while b < a {
                  // Loop body here
                  SA[ISA + SA[b]] = v;

                  b += 1  // Equivalent to ++b
                }
            }
            
            if ((a - first) <= (last - a)) {
              stack[ssize] = StackEntry (ISAd, a, last, -3);
              ssize += 1
              ISAd += 1; last = a; limit = next;
            } else {
              if (1 < (last - a)) {
                stack[ssize] = StackEntry (ISAd + 1, first, a, next);
                ssize += 1
                first = a; limit = -3;
              } else {
                ISAd += 1; last = a; limit = next;
              }
            }
          } else {
            if (ssize == 0) {
              return
            }
            ssize -= 1
            let entry = stack[ssize]
            ISAd = entry.a;
            first = entry.b;
            last = entry.c;
            limit = entry.d;
          }
        }
        continue;
      }
      
      if ((last - first) <= BZip2DivSufSort.INSERTIONSORT_THRESHOLD) {
        if (!budget.update (size, last - first)) {
          break
        }
        trInsertionSort (ISA, ISAd, ISAn, first, last);
        limit = -3;
        continue;
      }
      
      if (limit == 0) {
        if (!budget.update (size, last - first)) {
          break
        }
        trHeapSort (ISA, ISAd, ISAn, first, last - first);
        /*# begin of Java=>Swift
         for (a = last - 1; first < a; a = b) {
         for (
         x = trGetC (ISA, ISAd, ISAn, SA[a]), b = a - 1;
         (first <= b) && (trGetC (ISA, ISAd, ISAn, SA[b]) == x);
         --b
         )
         {
         SA[b] = ~SA[b];
         }
         }
         */
        a = last - 1
        while first < a {
          x = trGetC(ISA, ISAd, ISAn, SA[a])
          b = a - 1
          
          while first <= b && trGetC(ISA, ISAd, ISAn, SA[b]) == x {
            SA[b] = ~SA[b]  // Bitwise NOT operation
            b -= 1          // Decrement (equivalent to --b)
          }
          
          a = b  // Update outer loop variable
        }
        //# end of Java=>Swift
        limit = -3;
        continue;
      }
      limit -= 1
      
      a = trPivot (ISA, ISAd, ISAn, first, last);
      
      BZip2DivSufSort.swapElements (&SA, first, &SA, a);
      v = trGetC (ISA, ISAd, ISAn, SA[first]);
      //# for (b = first; (++b < last) && ((x = trGetC (ISA, ISAd, ISAn, SA[b])) == v);){}
      b = first - 1  // Weil ++b zuerst ausgeführt wird
      while true {
        b += 1
        guard b < last else { break }
        
        x = trGetC(ISA, ISAd, ISAn, SA[b])
        guard x == v else { break }
      }
      //#
      a = b
      if ((a < last) && (x < v)) {
        //# while (++b < last) && ((x = trGetC (ISA, ISAd, ISAn, SA[b])) <= v) {
        b = first - 1  // Startwert, weil ++b zuerst kommt
        
        while true {
          b += 1         // Entspricht ++b
          guard b < last else { break }
          
          x = trGetC(ISA, ISAd, ISAn, SA[b])
          guard x <= v else { break }
          
          // Schleifenkörper (falls benötigt)
          if (x == v) {
            BZip2DivSufSort.swapElements (&SA, b, &SA, a)
            a += 1
          }
        }
      }
      //# for (c = last; (b < --c) && ((x = trGetC (ISA, ISAd, ISAn, SA[c])) == v);){}
      c = last
      
      while true {
        c -= 1  // Decrement first (matches --c in Java)
        guard b < c else { break }
        
        x = trGetC(ISA, ISAd, ISAn, SA[c])
        guard x == v else { break }
        
        // Loop body (empty in original)
      }
      //#
      d = c
      if ((b < d) && (x > v)) {
        //# while (b < --c) && ((x = trGetC (ISA, ISAd, ISAn, SA[c])) >= v) {
        var c = last // Assuming 'last' was the initial value in Java
        var x: Int // Adjust type according to trGetC's return type
        
        while true {
          c -= 1 // Equivalent to --c in Java (pre-decrement)
          guard b < c else { break }
          
          x = trGetC(ISA, ISAd, ISAn, SA[c])
          guard x >= v else { break }
          
          // Loop body goes here
          if (x == v) {
            BZip2DivSufSort.swapElements (&SA, c, &SA, d);
            d -= 1
          }
        }
        //#
      }
      while b < c {
        BZip2DivSufSort.swapElements (&SA, b, &SA, c);
        b += 1
        //# while (b < c) && ((x = trGetC (ISA, ISAd, ISAn, SA[b])) <= v) {
        while b < c {
          x = trGetC(ISA, ISAd, ISAn, SA[b])
          guard x <= v else { break }
          
          // Loop body goes here
          
          if (x == v) {
            BZip2DivSufSort.swapElements (&SA, b, &SA, a);
            a += 1
          }
          b += 1 // Only increment if conditions are met
        }
        //#
        c -= 1
        //# while (b < c) && ((x = trGetC (ISA, ISAd, ISAn, SA[c])) >= v) {
        while b < c {
          c -= 1 // Decrement first since we're using SA[c]
          x = trGetC(ISA, ISAd, ISAn, SA[c])
          guard x >= v else {
            c += 1 // Undo the decrement if we're breaking
            break
          }
          
          // Loop body goes here
          if (x == v) {
            BZip2DivSufSort.swapElements (&SA, c, &SA, d);
            d -= 1
          }
          // No increment needed since we decremented c at start
        }
        //#
      }
      
      if (a <= d) {
        c = b - 1;
        
        if ((s = a - first) > (t = b - a)) {
          s = t;
        }
        //# for (e = first, f = b - s; 0 < s; --s, ++e, ++f) {
        e = first
        f = b - s
        while s > 0 {
          s -= 1
          e += 1
          f += 1
          
          // Loop body goes here
          BZip2DivSufSort.swapElements (&SA, e, &SA, f);
        }
        //#
        if ((s = d - c) > (t = last - d - 1)) {
          s = t;
        }
        //# for (e = b, f = last - s; 0 < s; --s, ++e, ++f) {
        e = b
        f = last - s
        while s > 0 {
          // Loop body goes here
          
          s -= 1
          e += 1
          f += 1
          BZip2DivSufSort.swapElements (&SA, e, &SA, f);
        }
        
        a = first + (b - a);
        b = last - (d - c);
        next = (SA[ISA + SA[a]] != v) ? trLog (b - a) : -1;
        
        //# for (c = first, v = a - 1; c < a; ++c) {
        c = first
        v = a - 1
        while c < a {
          // Loop body goes here
          SA[ISA + SA[c]] = v;

          c += 1
        }
        if (b < last) {
          //# for (c = a, v = b - 1; c < b; ++c) {
          c = a
          v = b - 1  // Constant since it doesn't change in the loop
          while c < b {
            // Loop body goes here
            SA[ISA + SA[c]] = v;
            c += 1  // Swift doesn't have ++ operator
          }
        }
        
        if ((a - first) <= (last - b)) {
          if ((last - b) <= (b - a)) {
            if (1 < (a - first)) {
              stack[ssize] = StackEntry (ISAd + 1, a, b, next);
              ssize += 1
              stack[ssize] = StackEntry (ISAd, b, last, limit);
              ssize += 1
              last = a;
            } else if (1 < (last - b)) {
              stack[ssize] = StackEntry (ISAd + 1, a, b, next);
              ssize += 1
              first = b;
            } else if (1 < (b - a)) {
              ISAd += 1;
              first = a;
              last = b;
              limit = next;
            } else {
              if (ssize == 0) {
                return
              }
              ssize -= 1
              let entry = stack[ssize]
              ISAd = entry.a;
              first = entry.b;
              last = entry.c;
              limit = entry.d;
            }
          } else if ((a - first) <= (b - a)) {
            if (1 < (a - first)) {
              stack[ssize] = StackEntry (ISAd, b, last, limit);
              ssize += 1
              stack[ssize] = StackEntry (ISAd + 1, a, b, next);
              ssize += 1
              last = a;
            } else if (1 < (b - a)) {
              stack[ssize] = StackEntry (ISAd, b, last, limit);
              ssize += 1
              ISAd += 1;
              first = a;
              last = b;
              limit = next;
            } else {
              first = b;
            }
          } else {
            if (1 < (b - a)) {
              stack[ssize] = StackEntry (ISAd, b, last, limit);
              ssize += 1
              stack[ssize] = StackEntry (ISAd, first, a, limit);
              ssize += 1
              ISAd += 1;
              first = a;
              last = b;
              limit = next;
            } else {
              stack[ssize] = StackEntry (ISAd, b, last, limit);
              ssize += 1
              last = a;
            }
          }
        } else {
          if ((a - first) <= (b - a)) {
            if (1 < (last - b)) {
              stack[ssize] = StackEntry (ISAd + 1, a, b, next);
              ssize += 1
              stack[ssize] = StackEntry (ISAd, first, a, limit);
              ssize += 1
              first = b;
            } else if (1 < (a - first)) {
              stack[ssize] = StackEntry (ISAd + 1, a, b, next);
              ssize += 1
              last = a;
            } else if (1 < (b - a)) {
              ISAd += 1;
              first = a;
              last = b;
              limit = next;
            } else {
              stack[ssize] = StackEntry (ISAd, first, last, limit);
              ssize += 1
            }
          } else if ((last - b) <= (b - a)) {
            if (1 < (last - b)) {
              stack[ssize] = StackEntry (ISAd, first, a, limit);
              ssize += 1
              stack[ssize] = StackEntry (ISAd + 1, a, b, next);
              ssize += 1
              first = b;
            } else if (1 < (b - a)) {
              stack[ssize] = StackEntry (ISAd, first, a, limit);
              ssize += 1
              ISAd += 1;
              first = a;
              last = b;
              limit = next;
            } else {
              last = a;
            }
          } else {
            if (1 < (b - a)) {
              stack[ssize] = StackEntry (ISAd, first, a, limit);
              ssize += 1
              stack[ssize] = StackEntry (ISAd, b, last, limit);
              ssize += 1
              ISAd += 1;
              first = a;
              last = b;
              limit = next;
            } else {
              stack[ssize] = StackEntry (ISAd, first, a, limit);
              ssize += 1
              first = b;
            }
          }
        }
      } else {
        if (!budget.update (size, last - first)) {break} // BUGFIX : Added to prevent an infinite loop in the original code
        limit += 1; ISAd += 1;
      }
    }
    
    //# for (s = 0; s < ssize; ++s) {
    for s in 0 ..< ssize {
      if (stack[s].d == -3) {
        lsUpdateGroup (ISA, stack[s].b, stack[s].c);
      }
    }
    
  }
  
  /**
   * @param ISA
   * @param n
   * @param depth
   */
  private func trSort (_ ISA : Int, _ n : Int, _ depth : Int) {
    
    var first = 0
    var last : Int
    var t : Int
    
    if (-n < SA[0]) {
      var budget = TRBudget (n, trLog (n) * 2 / 3 + 1)
      repeat {
        t = SA[first]
        if (t < 0) {
          first -= t;
        }
        else {
          last = SA[ISA + t] + 1;
          if (1 < (last - first)) {
            trIntroSort (ISA, ISA + depth, ISA + n, first, last, &budget, n);
            if (budget.chance == 0) {
              /* Switch to Larsson-Sadakane sorting algorithm. */
              if (0 < first) {
                SA[0] = -first;
              }
              lsSort (ISA, n, depth);
              break;
            }
          }
          first = last;
          
        }
      } while (first < n);
    }
    
  }
  
  /**
   * @param bucketB
   * @param c0
   * @param c1
   * @return
   */
  private static func BUCKET_B (_ c0 : Int, _ c1 : Int) -> Int{
    return (c1 << 8) | c0
  }
  
  
  /**
   * @param bucketB
   * @param c0
   * @param c1
   * @return
   */
  private static func BUCKET_BSTAR (_ c0 : Int, _ c1 : Int) -> Int {
    return (c0 << 8) | c1
  }
  
  
  /**
   * @param bucketA
   * @param bucketB
   * @return
   */
  private func sortTypeBstar (_ bucketA : inout [Int], _ bucketB : inout [Int]) -> Int {
    
    let n = self.n;
    let tempbuf : [Int] = Array(repeating: 0, count: 256)
    
    var buf : [Int]
    var PAb : Int
    var ISAb : Int
    var bufoffset : Int
    var i : Int
    var j : Int
    var k : Int
    var t : Int
    var m : Int
    var bufsize : Int
    var c0 : Int
    var c1 : Int = 0
    var flag : Int
    
    //# for (i = 1, flag = 1; i < n; ++i) {
    i = 1
    flag = 1
    while i < n {
      // Loop body goes here
      if (T[i - 1] != T[i]) {
        if ((T[i - 1] & 0xff) > (T[i] & 0xff)) {
          flag = 0;
        }
        break;
      }

      i += 1  // Swift doesn't have ++ operator
    }
    i = n - 1;
    m = n;
    
    var ti : Int = 0
    var t0 : Int = 0
    if (((ti ≡ (T[i] & 0xff)) < (t0 ≡ (T[0] & 0xff))) || ((T[i] == T[0]) && (flag != 0))) {
      if (flag == 0) {
        bucketB[BZip2DivSufSort.BUCKET_BSTAR (ti, t0)] += 1
        m -= 1
        SA[m] = i;
      } else {
        bucketB[BZip2DivSufSort.BUCKET_B (ti, t0)] += 1
      }
      /*# for (--i; (0 <= i) && ((ti = (T[i] & 0xff)) <= (ti1 = (T[i + 1] & 0xff))); --i) {
        bucketB[BUCKET_B (ti, ti1)] += 1
      }
      */
      i -= 1  // Initial decrement (--i in Java)
      while i >= 0 {
        let ti = Int(T[i]) & 0xff
        let ti1 = Int(T[i + 1]) & 0xff
        
        guard ti <= ti1 else { break }
        
        bucketB[BZip2DivSufSort.BUCKET_B(ti, ti1)] += 1
        
        i -= 1  // Decrement at end of loop (--i in Java)
      }
      //#
    }
    
    while 0 <= i {
      repeat {
        bucketA[Int(T[i] & 0xff)] += 1
        i -= 1
      } while ((0 <= i) && ((T[i] & 0xff) >= (T[i + 1] & 0xff)));
      if (0 <= i) {
        bucketB[BZip2DivSufSort.BUCKET_BSTAR (Int(T[i]) & 0xff, Int(T[i + 1]) & 0xff)] += 1
        m -= 1
        SA[m] = i;
        /*# for (--i; (0 <= i) && ((ti = (T[i] & 0xff)) <= (ti1 = (T[i + 1] & 0xff))); --i) {
          bucketB[BUCKET_B (ti, ti1)] += 1
        }
         */
        i -= 1  // Initial decrement (--i in Java)
        while i >= 0 {
          let ti = Int(T[i]) & 0xff
          let ti1 = Int(T[i + 1]) & 0xff
          
          guard ti <= ti1 else { break }
          
          bucketB[BZip2DivSufSort.BUCKET_B(ti, ti1)] += 1
          
          i -= 1  // Decrement at end of loop
        }
        //#
      }
    }
    m = n - m;
    if (m == 0) {
      //# for (i = 0; i < n; ++i) {
      for i in 0..<n {
        SA[i] = i;
      }
      return 0;
    }
    
    //# for (c0 = 0, i = -1, j = 0; c0 < 256; ++c0) {
    c0 = 0
    i = -1
    j = 0
    while c0 < 256 {
      // Loop body goes here
      
      t = i + bucketA[c0];
      bucketA[c0] = i + j;
      i = t + bucketB[BZip2DivSufSort.BUCKET_B (c0, c0)];
      //# for (c1 = c0 + 1; c1 < 256; ++c1) {
      c1 = c0 + 1  // Initialization
      while c1 < 256 {  // Condition
                        // Loop body goes here
      
        j += bucketB[BZip2DivSufSort.BUCKET_BSTAR (c0, c1)];
        bucketB[(c0 << 8) | c1] = j;
        i += bucketB[BZip2DivSufSort.BUCKET_B (c0, c1)];
        c1 += 1  // Increment (Swift doesn't have ++ operator)
      }
      c0 += 1  // Swift doesn't have ++ operator
    }
    
    PAb = n - m;
    ISAb = m;
    //# for (i = m - 2; 0 <= i; --i) {
    i = m - 2
    while i >= 0 {
      // Loop body goes here
      t = SA[PAb + i];
      c0 ≡ T[t] & 0xff;
      c1 ≡ T[t + 1] & 0xff;
      
      bucketB[BZip2DivSufSort.BUCKET_BSTAR (c0, c1)] -= 1
      SA[bucketB[BZip2DivSufSort.BUCKET_BSTAR (c0, c1)]] = i;
      
      i -= 1  // Decrement (Swift doesn't have -- operator)
    }
    t = SA[PAb + m - 1];
    c0 ≡ T[t] & 0xff;
    c1 ≡ T[t + 1] & 0xff;
    bucketB[BZip2DivSufSort.BUCKET_BSTAR (c0, c1)] -= 1
    SA[bucketB[BZip2DivSufSort.BUCKET_BSTAR (c0, c1)]] = m - 1;
    
    buf = SA;
    bufoffset = m;
    bufsize = n - (2 * m);
    if (bufsize <= 256) {
      buf = tempbuf;
      bufoffset = 0;
      bufsize = 256;
    }
    
    //# for (c0 = 255, j = m; 0 < j; --c0) {
    c0 = 255
    j = m
    while j > 0 {
      // #  for (c1 = 255; c0 < c1; j = i, --c1) {
      c1 = 255
      while c0 < c1 {
        // Inner loop body
        
        i = bucketB[BZip2DivSufSort.BUCKET_BSTAR (c0, c1)];
        if (1 < (j - i)) {
          subStringSort (PAb, i, j, &buf, bufoffset, bufsize, 2, SA[i] == (m - 1), n);
        }

        j = i       // Assignment from outer scope
        c1 -= 1     // Decrement c1
        
      }
      c0 -= 1         // Decrement c0
    }
    
    //# for (i = m - 1; 0 <= i; --i) {
    i = m - 1
    while i >= 0 {
      // Loop body goes here
      
      if (0 <= SA[i]) {
        j = i;
        repeat {
          SA[ISAb + SA[i]] = i;
          i -= 1
        } while ((0 <= i) && (0 <= SA[i]));
        SA[i + 1] = i - j;
        if (i <= 0) {
          break;
        }
      }
      j = i;
      repeat {
        //# SA[ISAb + (SA[i] = ~SA[i])] = j;
        SA[i] = ~SA[i]
        SA[ISAb + SA[i]] = j
        //#
        i -= 1
      } while (SA[i] < 0);
      SA[ISAb + SA[i]] = j;

      i -= 1  // Decrement i (Swift doesn't have -- operator)
    }
    
    trSort (ISAb, m, 1);
    
    i = n - 1; j = m;
    if (((T[i] & 0xff) < (T[0] & 0xff)) || ((T[i] == T[0]) && (flag != 0))) {
      if (flag == 0) {
        j -= 1
        SA[SA[ISAb + j]] = i;
      }
      //# for (--i; (0 <= i) && ((T[i] & 0xff) <= (T[i + 1] & 0xff)); --i){}
      i -= 1 // Initial decrement equivalent to --i
      while i >= 0 {
        let current = Int(T[i]) & 0xff
        let next = Int(T[i + 1]) & 0xff
        guard current <= next else { break }
        
        i -= 1 // End-of-loop decrement
      }
    }
    while 0 <= i {
      //# for (--i; (0 <= i) && ((T[i] & 0xff) >= (T[i + 1] & 0xff)); --i){}
      i -= 1  // Initial decrement (replaces --i in for-loop init)
      while i >= 0 {
        let current = Int(T[i]) & 0xff
        let next = Int(T[i + 1]) & 0xff
        
        guard current >= next else { break }
        
        i -= 1  // End-of-loop decrement
      }
      if (0 <= i) {
        j -= 1
        SA[SA[ISAb + j]] = i;
        //# for (--i; (0 <= i) && ((T[i] & 0xff) <= (T[i + 1] & 0xff)); --i){}
        i -= 1  // Initial decrement (replaces --i)
        while i >= 0 {
          let current = Int(T[i]) & 0xff
          let next = Int(T[i + 1]) & 0xff
          
          guard current <= next else { break }
          
          i -= 1  // End of loop decrement
        }
      }
    }
    
    //# for (c0 = 255, i = n - 1, k = m - 1; 0 <= c0; --c0) {
    c0 = 255
    i = n - 1
    k = m - 1
    while c0 >= 0 {
      // Loop body goes here
      
      //# for (c1 = 255; c0 < c1; --c1) {
      for c1 in stride(from: 255, through: c0 + 1, by: -1) {
        t = i - bucketB[BZip2DivSufSort.BUCKET_B (c0, c1)];
        bucketB[BZip2DivSufSort.BUCKET_B (c0, c1)] = i + 1;
        
        /*# for (i = t, j = bucketB[BUCKET_BSTAR (c0, c1)]; j <= k; --i, --k) {
          SA[i] = SA[k];
        }
         */
        i = t
        j = bucketB[BZip2DivSufSort.BUCKET_BSTAR(c0, c1)]
        
        while j <= k {
          SA[i] = SA[k]
          
          i -= 1
          k -= 1
        }
        //#
      }
      t = i - bucketB[BZip2DivSufSort.BUCKET_B (c0, c0)];
      bucketB[BZip2DivSufSort.BUCKET_B (c0, c0)] = i + 1;
      if (c0 < 255) {
        bucketB[BZip2DivSufSort.BUCKET_BSTAR (c0, c0 + 1)] = t + 1;
      }
      i = bucketA[c0];
      
      c0 -= 1  // Decrement c0
    }
    
    return m;
  }
  
  /**
   * @param bucketA
   * @param bucketB
   * @return
   */
  private func constructBWT (_ bucketA : inout [Int], _ bucketB : inout [Int]) -> Int {
    
    let n : Int = self.n;
    
    var i : Int
    var j : Int
    var t = 0;
    var s : Int
    var s1 : Int
    var c0 = 0
    var c2 = 0
    var orig = -1;
    /*#
    for (c1 = 254; 0 <= c1; --c1) {
      for (
        i = bucketB[BUCKET_BSTAR (c1, c1 + 1)], j = bucketA[c1 + 1], t = 0, c2 = -1;
        i <= j;
        --j
      )
      {
     */
    for c1 in stride(from: 254, through: 0, by: -1) {
      i = bucketB[BZip2DivSufSort.BUCKET_BSTAR(c1, c1 + 1)]
      j = bucketA[c1 + 1]
      t = 0
      c2 = -1
      
      while i <= j {
        //# if (0 <= (s1 = s = SA[j])) {
        s = SA[j]
        s1 = s
        if 0 <= s1 {
          s -= 1
          if (s < 0) {
            s = n - 1;
          }
          //# if ((c0 = (T[s] & 0xff)) <= c1) {
          c0 = Int(T[s]) & 0xff
          if c0 <= c1 {
            SA[j] = ~s1;
            if ((0 < s) && ((T[s - 1] & 0xff) > c0)) {
              s = ~s;
            }
            if (c2 == c0) {
              t -= 1
              SA[t] = s;
            } else {
              if (0 <= c2) {
                bucketB[BZip2DivSufSort.BUCKET_B (c2, c1)] = t;
              }
              //# SA[t = bucketB[BZip2DivSufSort.BUCKET_B (c2 = c0, c1)] - 1] = s;
              c2 = c0
              let bucketIndex = BZip2DivSufSort.BUCKET_B(c2, c1)
              t = bucketB[bucketIndex] - 1
              SA[t] = s
            }
          }
        } else {
          SA[j] = ~s;
        }
        
        j -= 1
      }
    }
    //#
    
    //# for (i = 0; i < n; ++i) {
    for i in 0..<n {
      //# if (0 <= (s1 = s = SA[i])) {
      s = SA[i]
      s1 = s
      if 0 <= s1 {
        s -= 1
        if (s < 0) {
          s = n - 1;
        }
        //# if ((c0 = (T[s] & 0xff)) >= (T[s + 1] & 0xff)) {
        let c0 = Int(T[s]) & 0xff
        let nextByte = Int(T[s + 1]) & 0xff
        if c0 >= nextByte {
          if ((0 < s) && ((T[s - 1] & 0xff) < c0)) {
            s = ~s;
          }
          if (c0 == c2) {
            t += 1
            SA[t] = s;
          } else {
            if (c2 != -1) {// BUGFIX: Original code can write to bucketA[-1]
              bucketA[c2] = t
            }
            //# SA[t = bucketA[c2 = c0] + 1] = s;
            c2 = c0
            let bucketValue = bucketA[c2]
            t = bucketValue + 1
            SA[t] = s
          }
        }
        
      }
      else {
        s1 = ~s1;
      }
      
      if (s1 == 0) {
        SA[i] ≡ T[n - 1];
        orig = i;
      } else {
        SA[i] ≡ T[s1 - 1];
      }
    }
    
    return orig;
  }
  
  /**
   * Performs a Burrows Wheeler Transform on the input array
   * @return the index of the first character of the input array within the output array
   */
  open func bwt() -> Int {
    
    let n = self.n
    
    var bucketA : [Int] = Array(repeating: 0, count: BZip2DivSufSort.BUCKET_A_SIZE)
    var bucketB : [Int] = Array(repeating: 0, count: BZip2DivSufSort.BUCKET_B_SIZE)
    
    if (n == 0) {
      return 0
    } else if (n == 1) {
      SA[0] ≡ T[0]
      return 0
    }
    
    let m = sortTypeBstar (&bucketA, &bucketB);
    if (0 < m) {
      return constructBWT (&bucketA, &bucketB);
    }
    return 0
  }
  
  /**
   * @param T The input array
   * @param SA The output array
   * @param n The length of the input data
   */
  public init (_ T : [UInt8], _ SA : [Int], _ n : Int) {
    self.T = T
    self.SA = SA
    self.n = n
  }
}
