# SwiftIntelHex

SwiftIntelHex is a parser for the Intel hexadecimal object file format (.hex), https://en.wikipedia.org/wiki/Intel_HEX.
The extracted data can for example be used for programming the memory of a microcontroller or EPROM.

## Features

The library includes all basic features for handling hex files, such as:
- Parsing a hex string into an IntelHexFile object
- Extracting byte data and the data's start address
- Splitting of non-adjacent data blocks, including start address and byte data for each block
- Support for 16-bit segment addresses and 32-bit address spaces

## Usage

The `IntelHexFile.parseString` function parses the whole file. The file must be provided as a string and the function must be called in an async context. Parse errors can be thrown as `IntelHexFile.ParseError`.

```swift
let testString =
    """
    :020000021000EC
    :10010000214601360121470136007EFE09D2190140
    :100110002146017EB7C20001FF5F16002148011988
    :10012000194E79234623965778239EDA3F01B2CAA7
    :100130003F0156702B5E712B722B732146013421C7
    :00000001FF
    """

Task {
    do {
        let hexFile = try await IntelHexFile.parseString(testString)
    } catch {
        // Error handling of IntelHexFile.ParseError
        print(error.localizedDescription)
    }
}
```

The `IntelHexFile` object contains all the information about the records and extracted blocks in the hex file.

```swift
/* the first start address in the file */
hexFile.startAddress

/* contains the concatinated data of all data records
 * in the file (assuming they are all adjacent, starting at the same address)
 */
hexFile.consolidatedData

/* the start address of the first data block */
hexFile.blocks?.first?.startAddress

/* the data of the first data block */
hexFile.blocks?.first?.data

/* the second data block
 * (data records are split into blocks wherever the start address
 * of the next data record is not adjacent to the data of the previous record)
 */
hexFile.blocks?[1]

/* array of all records (lines) in the hex file */
hexFile.records
```

## Installation

The library can be used with [Swift Package Manager](https://swift.org/package-manager/) in XCode or manually added as a package dependency.
