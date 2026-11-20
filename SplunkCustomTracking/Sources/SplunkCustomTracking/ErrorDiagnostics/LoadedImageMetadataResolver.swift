//
/*
Copyright 2026 Splunk Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import Darwin
import Foundation
import MachO

struct LoadedImage {
    let baseAddress: UInt64
    let imageSize: UInt64
    let imagePath: String
    let imageUUID: String?
}

struct LoadedImageIdentity {
    let baseAddress: UInt64
    let imagePath: String
    let header: UnsafePointer<mach_header_64>
}

protocol LoadedImageMetadataResolving {
    func image(containing instructionPointer: UInt64) -> LoadedImage?
    func images(containing instructionPointers: [UInt64]) -> [LoadedImage]
}

final class LoadedImageMetadataCache: LoadedImageMetadataResolving {

    private let lock = NSLock()
    private var imagesByBaseAddress: [UInt64: LoadedImage] = [:]

    private let imageIdentityResolver: (UInt64) -> LoadedImageIdentity?
    private let imageMetadataReader: (LoadedImageIdentity) -> LoadedImage

    init(
        imageIdentityResolver: @escaping (UInt64) -> LoadedImageIdentity? = LoadedImageMetadataCache.imageIdentity,
        imageMetadataReader: @escaping (LoadedImageIdentity) -> LoadedImage = LoadedImageMetadataCache.loadedImage
    ) {
        self.imageIdentityResolver = imageIdentityResolver
        self.imageMetadataReader = imageMetadataReader
    }

    func image(containing instructionPointer: UInt64) -> LoadedImage? {
        guard let imageIdentity = imageIdentityResolver(instructionPointer) else {
            return nil
        }

        lock.lock()
        defer { lock.unlock() }

        if let cachedImage = imagesByBaseAddress[imageIdentity.baseAddress],
            cachedImage.imagePath == imageIdentity.imagePath
        {
            return cachedImage
        }

        let image = imageMetadataReader(imageIdentity)
        imagesByBaseAddress[image.baseAddress] = image
        return image
    }

    func images(containing instructionPointers: [UInt64]) -> [LoadedImage] {
        var imagesByBaseAddress: [UInt64: LoadedImage] = [:]

        for instructionPointer in instructionPointers {
            guard let image = image(containing: instructionPointer) else {
                continue
            }

            imagesByBaseAddress[image.baseAddress] = image
        }

        return imagesByBaseAddress.values.sorted { lhs, rhs in
            lhs.baseAddress < rhs.baseAddress
        }
    }

    static func imageIdentity(containing instructionPointer: UInt64) -> LoadedImageIdentity? {
        guard
            instructionPointer <= UInt64(UInt.max),
            let address = UnsafeRawPointer(bitPattern: UInt(instructionPointer))
        else {
            return nil
        }

        var info = Dl_info()
        guard
            dladdr(address, &info) != 0,
            let imageBase = info.dli_fbase,
            let imageName = info.dli_fname
        else {
            return nil
        }

        let header = imageBase.assumingMemoryBound(to: mach_header_64.self)
        guard header.pointee.magic == MH_MAGIC_64 else {
            return nil
        }

        return LoadedImageIdentity(
            baseAddress: UInt64(UInt(bitPattern: imageBase)),
            imagePath: String(cString: imageName),
            header: UnsafePointer(header)
        )
    }

    static func loadedImage(from identity: LoadedImageIdentity) -> LoadedImage {
        LoadedImage(
            baseAddress: identity.baseAddress,
            imageSize: textSegmentSize(from: identity.header),
            imagePath: identity.imagePath,
            imageUUID: machOUUID(from: identity.header)
        )
    }

    private static func textSegmentSize(from header: UnsafePointer<mach_header_64>) -> UInt64 {
        var textSize: UInt = 0

        SEG_TEXT.withCString { segmentName in
            _ = getsegmentdata(header, segmentName, &textSize)
        }

        return UInt64(textSize)
    }
}

final class LoadedImageMetadataFormatter {

    func imagesJSON(from images: [LoadedImage]) -> String? {
        guard !images.isEmpty else {
            return nil
        }

        let imageDictionaries: [[ErrorDiagnosticKeys: Any]] = images.map { image in
            var imageDictionary: [ErrorDiagnosticKeys: Any] = [
                .baseAddress: image.baseAddress,
                .imageSize: image.imageSize,
                .imagePath: image.imagePath
            ]

            if let imageUUID = image.imageUUID {
                imageDictionary[.imageUUID] = imageUUID
            }

            return imageDictionary
        }

        return ErrorDiagnosticJSON.convertToJSONString(imageDictionaries)
    }
}

func machOUUID(from header: UnsafePointer<mach_header_64>) -> String? {
    guard header.pointee.magic == MH_MAGIC_64 else {
        return nil
    }

    var cursor = UnsafeRawPointer(header)
        .advanced(by: MemoryLayout<mach_header_64>.size)
    let commandsEnd = cursor.advanced(by: Int(header.pointee.sizeofcmds))

    for _ in 0 ..< header.pointee.ncmds {
        guard cursor.advanced(by: MemoryLayout<load_command>.size) <= commandsEnd else {
            return nil
        }

        let command = cursor.load(as: load_command.self)
        guard
            command.cmdsize >= UInt32(MemoryLayout<load_command>.size),
            cursor.advanced(by: Int(command.cmdsize)) <= commandsEnd
        else {
            return nil
        }

        if command.cmd == LC_UUID {
            guard command.cmdsize >= MemoryLayout<uuid_command>.size else {
                return nil
            }

            let uuidCommand = cursor.load(as: uuid_command.self)
            let uuidBytes = withUnsafeBytes(of: uuidCommand.uuid) { bytes in
                let hexadecimalCharacters = Array("0123456789abcdef".utf8)

                return bytes.flatMap { byte in
                    [
                        hexadecimalCharacters[Int(byte >> 4)],
                        hexadecimalCharacters[Int(byte & 0x0F)]
                    ]
                }
            }

            return String(bytes: uuidBytes, encoding: .ascii)
        }

        cursor = cursor.advanced(by: Int(command.cmdsize))
    }

    return nil
}
