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

/// a single record in the hex file
public struct IntelHexRecord {
    // MARK: - Inner types
    enum RecordType: UInt8 {
        case data
        case endOfFile
        case extendedSegmentAddress
        case startSegmentAddress
        case extendedLinearAddress
        case startLinearAddress
    }
    
    // MARK: - Static properties
    private static let byteCountLength = 2
    private static let addressLength = 4
    private static let typeLength = 2
    private static let checksumLength = 2
    private static let minLength = byteCountLength + addressLength + typeLength + checksumLength
    
    // MARK: - Properties
    
    /// the byte count of the record's data
    let byteCount: UInt8
    
    /// the record's 16 bit address offset
    let loadAddress: UInt16
    
    /// the record's type
    let type: RecordType
    
    /// the record's data withe a length defined in byteCount
    let data: Data // big endian
    
    // MARK: - Functions
    static func parseString(_ string: String) throws -> IntelHexRecord {
        let recordString = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        
        if recordString.count < minLength {
            throw IntelHexFile.ParseError.invalidLength
        }
        
        guard
            let byteCountString = recordString.subString(from: 0, count: byteCountLength),
            let addressString = recordString.subString(from: byteCountLength, count: addressLength),
            let typeString = recordString.subString(from: byteCountLength + addressLength, count: typeLength)
        else {
            throw IntelHexFile.ParseError.invalidLength
        }
         
        guard let byteCount = UInt8(byteCountString, radix: 16) else {
            throw IntelHexFile.ParseError.invalidByteCount
        }
        
        guard recordString.count == minLength + Int(byteCount) * 2 else {
            throw IntelHexFile.ParseError.invalidLength
        }
        
        guard let address = UInt16(addressString, radix: 16) else {
            throw IntelHexFile.ParseError.invalidAddress
        }
        
        guard let type = UInt8(typeString, radix: 16), let recordType = RecordType(rawValue: type) else {
            throw IntelHexFile.ParseError.invalidType
        }
        
        guard
            let dataString = recordString.subString(from: byteCountLength + addressLength + typeLength, count: Int(byteCount) * 2),
            let data = Data(hexString: dataString, endianness: .big),
            let checksumData = Data(hexString: recordString, endianness: .big)
        else {
            throw IntelHexFile.ParseError.invalidData
        }
        
        // validate checksum: first byte of sum over all bytes in record must be 0
        let sum = checksumData.reduce(0, { Int($0) + Int($1) })
        guard Data(value: sum).first == 0 else {
            throw IntelHexFile.ParseError.invalidChecksum
        }
        
        return IntelHexRecord(byteCount: byteCount, loadAddress: address, type: recordType, data: data)
    }
}
