/* MIT License (MIT)
 *
 * Copyright (c) 2022 Oliver Brehm
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 */

import Foundation

extension String {
    /// Safely returns a sub string for the given range or nil if the range is out of bounds
    func subString(from: Int, to: Int) -> String? {
        guard from >= 0, to < count else { return nil }
        
        let startIndex = index(self.startIndex, offsetBy: from)
        let endIndex = index(self.startIndex, offsetBy: to)
        return String(self[startIndex ..? endIndex])
    }
    
    /// Safely returns a sub string for the given range or nil if the range is out of bounds
    func subString(from: Int, count: Int) -> String? {
        return subString(from: from, to: from + count - 1)
    }
}

extension Data {
    // MARK: - Initializers
    
    /// Creates a data object from a value of the specified type
    init<T>(value: T) {
        self = withUnsafePointer(to: value) { Data(buffer: UnsafeBufferPointer(start: $0, count: 1)) }
    }
    
    /// Creates a data object from a string of hex bytes e.g. A0B1C3
    init?(hexString: String, endianness: Endianness) {
        var string = hexString
        var data = Data()
        
        while let byteString = endianness == .big ? string.subString(from: 0, to: 1) : string.subString(from: string.count - 2, count: 2) {
            endianness == .big ? string.removeFirst(2) : string.removeLast(2)
            
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
        }
        
        self = data
    }
    
    // MARK: - Functions
    
    /// Returns a data type with specified length by adding padding bytes
    func withLength(_ length: Int, padding: UInt8) -> Data {
        var data = self
        
        while data.count < length {
            data.append(padding)
        }
        
        if data.count > length {
            data = data.prefix(length)
        }
        
        return data
    }
    
    /// Converts the data to a specific type
    func asType<T>(type: T.Type) -> T {
        return withLength(MemoryLayout<T>.size, padding: 0).withUnsafeBytes { $0.load(as: type) }
    }
}
