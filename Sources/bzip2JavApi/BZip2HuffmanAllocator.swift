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
 * An in-place, length restricted Canonical Huffman code length allocator
 * 
 * Based on the algorithm proposed by R. L. Milidiú, A. A. Pessoa and E. S. Laber in "In-place
 * Length-Restricted Prefix Coding" (see: http://www-di.inf.puc-rio.br/~laber/public/spire98.ps)
 * and incorporating additional ideas from the implementation of "shcodec" by Simakov Alexander
 * (see: http://webcenter.ru/~xander/)
 */
open class HuffmanAllocator {

	/**
	 * FIRST() function
	 * @param array The code length array
	 * @param i The input position
	 * @param nodesToMove The number of internal nodes to be relocated
	 * @return The smallest {@code k} such that {@code nodesToMove <= k <= i} and
	 *         {@code i <= (array[k] % array.length)}
	 */
	private static func first (_ array : [Int], _ _i : Int, _ nodesToMove : Int) -> Int {
    var i = _i
		let length : Int = array.count
		let limit = i
		var k = array.count - 2

		while ((i >= nodesToMove) && ((array[i] % length) > limit)) {
			k = i;
			i -= (limit - i + 1);
		}
		i = java.lang.Math.max (nodesToMove - 1, i);

		while (k > (i + 1)) {
      let temp : Int = (i + k) >> 1;
			if ((array[temp] % length) > limit) {
				k = temp;
			} else {
				i = temp;
			}
		}

		return k;
	}

	/**
	 * Fills the code array with extended parent pointers
	 * @param array The code length array
	 */
	private static func setExtendedParentPointers (_ array : inout[Int]) {

		let length = array.count

		array[0] += array[1];

    var headNode = 0
    var tailNode = 1
    var topNode = 2
    while tailNode < (length - 1) {
			var temp : Int
			if ((topNode >= length) || (array[headNode] < array[topNode])) {
				temp = array[headNode];
				array[headNode] = tailNode;
        headNode += 1
			} else {
				temp = array[topNode];
        topNode += 1
			}

			if ((topNode >= length) || ((headNode < tailNode) && (array[headNode] < array[topNode]))) {
				temp += array[headNode];
				array[headNode] = tailNode + length;
        headNode += 1
			} else {
				temp += array[topNode];
        topNode += 1
			}

			array[tailNode] = temp;
      tailNode += 1
		}
	}

	/**
	 * Finds the number of nodes to relocate in order to achieve a given code length limit
	 * @param array The code length array
	 * @param maximumLength The maximum bit length for the generated codes
	 * @return The number of nodes to relocate
	 */
	private static func findNodesToRelocate (_ array : [Int], _ maximumLength : Int) -> Int{

		var currentNode = array.count - 2
    var currentDepth = 1
    while currentDepth < (maximumLength - 1) && currentNode > 1 {
      currentNode =  first (array, currentNode - 1, 0);
      currentDepth += 1
		}

		return currentNode;
	}

	/**
	 * A final allocation pass with no code length limit
	 * @param array The code length array
	 */
	private static func allocateNodeLengths (_ array : inout [Int]) {

		var firstNode = array.count - 2;
		var nextNode = array.count - 1;

    var currentDepth = 1
    var availableNodes = 2
    while availableNodes > 0 {
      let lastNode = firstNode;
			firstNode = first (array, lastNode - 1, 0);

      for _ in stride(from: availableNodes - (lastNode - firstNode), to: 0, by: -1) {
        array[nextNode] = currentDepth;
        nextNode -= 1
			}

			availableNodes = (lastNode - firstNode) << 1;
		}
    currentDepth += 1
	}

	/**
	 * A final allocation pass that relocates nodes in order to achieve a maximum code length limit
	 * @param array The code length array
	 * @param nodesToMove The number of internal nodes to be relocated
	 * @param insertDepth The depth at which to insert relocated nodes
	 */
	private static func allocateNodeLengthsWithRelocation (_ array : inout [Int], _ nodesToMove : Int, _ insertDepth : Int) {

		var firstNode = array.count - 2
		var nextNode = array.count - 1
		var currentDepth = (insertDepth == 1) ? 2 : 1;
		var nodesLeftToMove = (insertDepth == 1) ? nodesToMove - 2 : nodesToMove;

    var availableNodes = currentDepth << 1  // Bit-Shift bleibt gleich
    while availableNodes > 0 {
    //for (int availableNodes = currentDepth << 1; availableNodes > 0; currentDepth++) {
			let lastNode = firstNode;
			firstNode = (firstNode <= nodesToMove) ? firstNode : first (array, lastNode - 1, nodesToMove);

			var offset = 0;
			if (currentDepth >= insertDepth) {
				offset = Math.min (nodesLeftToMove, 1 << (currentDepth - insertDepth));
			} else if (currentDepth == (insertDepth - 1)) {
				offset = 1;
				if ((array[firstNode]) == lastNode) {
					firstNode += 1
				}
			}

      for _ in stride(from: availableNodes - (lastNode - firstNode + offset), to: 0, by: -1) {
        array[nextNode] = currentDepth;
        nextNode -= 1
			}

			nodesLeftToMove -= offset;
			availableNodes = (lastNode - firstNode + offset) << 1;
      
      currentDepth += 1  // Manuelles Inkrement
      availableNodes = currentDepth << 1  // Neuberechnung für nächste Iteration
		}
	}

	/**
	 * Allocates Canonical Huffman code lengths in place based on a sorted frequency array
	 * @param array On input, a sorted array of symbol frequencies; On output, an array of Canonical
	 *              Huffman code lengths
	 * @param maximumLength The maximum code length. Must be at least {@code ceil(log2(array.length))}
	 */
	public static func allocateHuffmanCodeLengths (_ array : inout [Int], _ maximumLength : Int) {

		switch (array.count) {
			case 2:
				array[1] = 1;
			case 1:
				array[0] = 1;
				return;
      default:
        break
		}

		/* Pass 1 : Set extended parent pointers */
    setExtendedParentPointers (&array);

		/* Pass 2 : Find number of nodes to relocate in order to achieve maximum code length */
    let nodesToRelocate = findNodesToRelocate (array, maximumLength);

		/* Pass 3 : Generate code lengths */
		if ((array[0] % array.length) >= nodesToRelocate) {
      allocateNodeLengths (&array);
		}
    else {
      let insertDepth = maximumLength - (32 - (nodesToRelocate - 1).leadingZeroBitCount);
      allocateNodeLengthsWithRelocation (&array, nodesToRelocate, insertDepth);
		}
	}

	/**
	 * Non-instantiable
	 */
	private init() { }
}
