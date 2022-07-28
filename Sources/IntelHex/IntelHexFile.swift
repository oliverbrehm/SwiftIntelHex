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

/**
 IntelHexFile describes the structure of a file in the Inel Hex format.
 Use the parseString function to parse the content of an Intel Hex file.
*/
public struct IntelHexFile {
    // MARK: - Inner types
    /// parse errors
    public enum ParseError: Error, LocalizedError {
        case invalidLength
        case invalidChecksum
        case invalidByteCount
        case invalidAddress
        case invalidType
        case invalidData
        case invalidEndOfFile
        
        public var errorDescription: String? {
            switch self {
            case .invalidLength:
                return "The record's length is invalid."
            case .invalidChecksum:
                return "The record's checksum is invalid."
            case .invalidByteCount:
                return "The record's byte count is invalid."
            case .invalidAddress:
                return "The record's address field is invalid."
            case .invalidType:
                return "The record's type field is invalid."
            case .invalidData:
                return "The record's data field is invalid."
            case .invalidEndOfFile:
                return "The file does not contain an EOF record or contains multiple EOF records."
            }
        }
    }
    
    /// describes an isolated date block in the hex file
    public struct HexBinaryBlock {
        /// the block's start address
        public let startAddress: UInt32
        
        /// the data of the whole block
        public let data: Data
    }
    
    // MARK: - Public Properties
    
    /// a list of all records in the hex file
    public let records: [IntelHexRecord]

    /// a list of all data blocks in the hex file
    public var blocks: [HexBinaryBlock]?

    /// the start address of the first data block
    public var startAddress: UInt32? {
        return blocks?.first?.startAddress
    }
    
    /// the consolidated data of all blocks, assuming there are no empty spaces between blocks
    public var consolidatedData: Data? {
        return blocks?.reduce(Data(), { data, block in
            return data + block.data
        })
    }
    
    // MARK: - Init
    private init(records: [IntelHexRecord]) {
        self.records = records
    }
    
    // MARK: - Functions
    
    /**
     Parses a string in the Intel Hex format.
     - parameter string: The string content of a file in the Intel Hex format.
     - returns: A parsed IntelHexFile describing the file's content.
     */
    public static func parseString(_ string: String) async throws -> IntelHexFile {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue(label: "IntelHexFile_parseString").async {
                var records: [IntelHexRecord] = []
                
                let lines = string.split(separator: ":")
                
                do {
                    try lines.forEach {
                        let record = try IntelHexRecord.parseString(String($0))
                        records.append(record)
                    }
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
                
                if !(records.filter { $0.type == .endOfFile }.count == 1) {
                    continuation.resume(throwing: ParseError.invalidEndOfFile)
                    return
                }
                
                var hexFile = IntelHexFile(records: records)
                hexFile.blocks = hexFile.extractBinaryBlocks()

                continuation.resume(returning: hexFile)
            }
        }
    }
    
    /// Returns a list of all coherent data blocks in the hex file with their start addresses
    private func extractBinaryBlocks() -> [HexBinaryBlock] {
        var blocks: [HexBinaryBlock] = []
        
        var currentStartAddress: UInt16 = 0
        var currentData: Data?
        
        var segmentAddressExtension: UInt16 = 0
        var linearAddressExtension: UInt16 = 0
        var nextAddress = 0
        
        func finishBlock() {
            if let currentData = currentData, !currentData.isEmpty {
                var address: UInt32 = 0
                
                if segmentAddressExtension > 0 {
                    // apply segement adddress extension
                    address = 16 * UInt32(segmentAddressExtension)
                } else if linearAddressExtension > 0 {
                    // apply linear address extension
                    address = UInt32(linearAddressExtension)
                    address <<= 16
                }
                
                address += UInt32(currentStartAddress)
                
                blocks.append(HexBinaryBlock(startAddress: address, data: currentData))
            }
            
            currentStartAddress = 0
            nextAddress = 0
            currentData = Data()
        }
        
        for record in records {
            switch record.type {
            case .data:
                if record.loadAddress != nextAddress {
                    finishBlock()
                    currentStartAddress = record.loadAddress
                    nextAddress = Int(record.loadAddress)
                }
                
                currentData?.append(record.data)

                nextAddress += Int(record.byteCount)
                
            case .endOfFile:
                finishBlock()
                return blocks
                
            case .extendedSegmentAddress:
                finishBlock()
                
                // data is in big endian representation
                segmentAddressExtension = UInt16(bigEndian: record.data.asType(type: UInt16.self))
                linearAddressExtension = 0
                
            case .extendedLinearAddress:
                finishBlock()
                
                // data is in big endian representation
                segmentAddressExtension = 0
                linearAddressExtension = UInt16(bigEndian: record.data.asType(type: UInt16.self))

            default:
                // record types 03 (startSegmentAddress) and 05 (startLinearAddress) are ignored, mostly unsed in microcontroller flashing
                finishBlock()
            }
        }
        
        return blocks
    }
}
