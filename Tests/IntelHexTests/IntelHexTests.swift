import XCTest
@testable import IntelHex

final class IntelHexTests: XCTestCase {
    
    // MARK: - Static
    static let hexCharacterSet = CharacterSet(charactersIn: "0123456789ABCDEF")
    
    static var testString =
"""
:020000021000EC
:10010000214601360121470136007EFE09D2190140
:100110002146017EB7C20001FF5F16002148011988
:10012000194E79234623965778239EDA3F01B2CAA7
:100130003F0156702B5E712B722B732146013421C7
:00000001FF
"""
    
    // MARK: - Test functions
    func testExampleString() async throws {
        let hexFile = try await IntelHexFile.parseString(Self.testString)

        XCTAssertEqual(hexFile.records.count, 6, "Invalid number of records in parsed string.")
        XCTAssertEqual(hexFile.consolidatedData?.count, 64, "Invalid size of consolidated data block.")
        
        let address = UInt32(16 * 0x1000 + 0x0100)
        XCTAssertEqual(hexFile.startAddress, address, "Invalid start address.")
    }
    
    func testExtendedSegmentAddress() async throws {
        let testString = makeTestString(strings: [
            makeRecordString(address: "0000", type: "02", data: "1234"), // extended segment address
            makeRecordString(address: "1234", type: "00", data: "0000")
        ])
        
        let hexFile = try await IntelHexFile.parseString(testString)

        let address = UInt32(16 * 0x1234 + 0x1234)
        XCTAssertEqual(hexFile.startAddress, address, "Invalid extende segment address.")
    }
    
    func testExtendedLinearAddress() async throws {
        let testString = makeTestString(strings: [
            makeRecordString(address: "0000", type: "04", data: "1234"), // extended linear address
            makeRecordString(address: "1234", type: "00", data: "0000")
        ])
        
        let hexFile = try await IntelHexFile.parseString(testString)
        
        let address = UInt32(0x1234 << 16 + 0x1234)
        XCTAssertEqual(hexFile.startAddress, address, "Invalid extended linear address.")
    }
    
    func testStartAddress() async throws {
        let testString = makeTestString(strings: [
            makeRecordString(address: "0000", type: "03", data: "0000"), // segment start address
            makeRecordString(address: "0000", type: "05", data: "0000") // linear start address
        ])
                
        _ = try await IntelHexFile.parseString(testString)
    }
    
    func testMissingEOF() async throws {
        await assertThrowsError(expectedError: .invalidEndOfFile, message: "Should throw EOF error") {
            _ = try await IntelHexFile.parseString(makeRecordString(address: "0000", type: "00", data: "0000"))
        }
    }
    
    func testMultipleEOF() async throws {
        let testString = makeTestString(strings: [ // makeTestString includes one EOF
            makeRecordString(address: "0000", type: "01", data: "0000") // second EOF
        ])
        
        await assertThrowsError(expectedError: .invalidEndOfFile, message: "Should throw EOF error") {
            _ = try await IntelHexFile.parseString(testString)
        }
    }
    
    func testInvalidLength() async throws {
        let invalidMinLength = makeTestString(strings: [":00"])
        let invalidLengthForData = makeTestString(strings: [":10010000214601360121470136007EFE09D219014000"])
        
        await assertThrowsError(expectedError: .invalidLength, message: "Invalid min length.") {
            _ = try await IntelHexFile.parseString(invalidMinLength)
        }
        
        await assertThrowsError(expectedError: .invalidLength, message: "Invalid exact length.") {
            _ = try await IntelHexFile.parseString(invalidLengthForData)
        }
    }
    
    func testInvalidByteCount() async throws {
        await assertThrowsError(expectedError: .invalidByteCount, message: "Invalid byte count.") {
            _ = try await IntelHexFile.parseString(makeTestString(strings: [":XX010000214601360121470136007EFE09D2190140"]))
        }
    }
    
    func testInvalidAddress() async throws {
        await assertThrowsError(expectedError: .invalidAddress, message: "Invalid address.") {
            _ = try await IntelHexFile.parseString(makeTestString(strings: [":10XXXX00214601360121470136007EFE09D2190140"]))
        }
    }
    
    func testInvalidType() async throws {
        await assertThrowsError(expectedError: .invalidType, message: "Invalid record type.") {
            _ = try await IntelHexFile.parseString(makeTestString(strings: [":10010006214601360121470136007EFE09D2190140"])) // record type 06, only valid 00 to 05
        }
    }
    
    func testInvalidData() async throws {
        await assertThrowsError(expectedError: .invalidData, message: "Invalid data.") {
            _ = try await IntelHexFile.parseString(makeTestString(strings: [":10010000XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX40"]))
        }
    }
    
    func testInvalidChecksum() async throws {
        await assertThrowsError(expectedError: .invalidChecksum, message: "Invalid checksum.") {
            _ = try await IntelHexFile.parseString(makeTestString(strings: [":10010000214601360121470136007EFE09D2190100"])) // checksum 00, should be 40
        }
    }
    
    // MARK: - Private functions
    private func assertThrowsError(expectedError: IntelHexFile.ParseError, message: String, task: () async throws -> ()) async {
        do {
            try await task()
        } catch {
            print("Parse error: \(error.localizedDescription)")
            XCTAssertEqual(error as? IntelHexFile.ParseError, expectedError, message)
        }
    }
    
    private func makeTestString(strings: [String]) -> String {
        let eof = makeRecordString(address: "0000", type: "01", data: "")
        return (strings + [eof]).joined(separator: "\n")
    }
    
    private func makeRecordString(address: String, type: String, data: String) -> String {
        guard isHexString(address), isHexString(type), isHexString(data) else {
            XCTFail("Invalid hex string.")
            return "\n"
        }
        
        guard address.count == 4, type.count == 2 else {
            XCTFail("Invalid test record string.")
            return "\n"
        }
        
        let byteCount = data.count / 2
        
        let sumData = Data(hexString: "\(address)\(type)\(data)", endianness: .big) ?? Data()
        let sum = sumData.reduce(0, { Int($0) + Int($1) }) + byteCount
        let checkSum = UInt8((0x100 - (sum & 0xFF)) & 0xFF)
        
        let byteCountString = Data(value: UInt8(byteCount)).hexString
        let checkSumString = Data(value: checkSum).hexString
        
        return ":\(byteCountString)\(address)\(type)\(data)\(checkSumString)"
    }
    
    private func isHexString(_ string: String) -> Bool {
        return string.count % 2 == 0 && Self.hexCharacterSet.isSuperset(of: CharacterSet(charactersIn: string))
    }
}
