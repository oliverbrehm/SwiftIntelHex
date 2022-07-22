import XCTest
@testable import IntelHex

final class IntelHexTests: XCTestCase {
    
    static var hexString =
"""
:020000021000EC
:10010000214601360121470136007EFE09D2190140
:100110002146017EB7C20001FF5F16002148011988
:10012000194E79234623965778239EDA3F01B2CAA7
:100130003F0156702B5E712B722B732146013421C7
:00000001FF
"""
    
    func testParseString() throws {
        let expectation = expectation(description: "TaskFinish")

        Task {
            do {
                let hexFile = try await IntelHexFile.parseString(Self.hexString)
                
                DispatchQueue.main.async {
                    XCTAssertEqual(hexFile.records.count, 6, "Invalid number of records in parsed string.")
                    XCTAssertEqual(hexFile.consolidatedData?.count, 64, "Invalid size of consolidated data block.")
                    expectation.fulfill()
                }
            } catch {
                DispatchQueue.main.async {
                    XCTFail(error.localizedDescription)
                }
            }
        }
        
        waitForExpectations(timeout: 10)
    }
}
