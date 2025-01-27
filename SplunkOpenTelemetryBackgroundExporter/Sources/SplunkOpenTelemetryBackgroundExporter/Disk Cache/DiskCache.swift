//
/*
Copyright 2024 Splunk Inc.

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

import Foundation

enum DiskCacheError: Error {
    case cannotEnumerateCacheContents
}

class DiskCache {

    enum Subfolder: String {
        case uploadFiles
    }

    // MARK: - Static constants

    static let maxAbsoluteDiskCacheSize = Measurement(value: 200, unit: UnitInformationStorage.megabytes)
    static let maxRelativeDiskCacheSize = 0.2 // 20%

    // Root paths for cache
    private static let cacheFolder = "com.otel.sdk"

    // MARK: - Reset caches

    class func resetCaches() {
        resetCache()
    }

    class func resetCache(onlySubfolder subfolder: Subfolder? = nil) {
        if let folder = try? folderUrl(withSubfolder: subfolder) {
            try? FileManager.default.removeItem(at: folder)
        }

        DiskCache.refreshStatistics()
    }
}


// MARK: - Dedicated Folders

extension DiskCache {

    // These vars and methods create the respective folders if they do not exist

    class func cache(subfolder: Subfolder? = nil, item: String? = nil) -> URL? {
        var cacheItem = try? DiskCache.folderUrl(withSubfolder: subfolder)

        if let item = item {
            cacheItem = cacheItem?.appendingPathComponent(item)
        }

        return cacheItem
    }

    class func clean(item: String, in subfolder: Subfolder? = nil) {
        guard let itemFile = cache(subfolder: subfolder, item: item) else {
            return
        }

        // Delete the item in any case
        try? FileManager.default.removeItem(at: itemFile)

        DiskCache.refreshStatistics()
    }
}


// MARK: - Verifying file existence

extension DiskCache {

    class func fileExists(at url: URL) -> Bool {
        let filePath = url.path

        return FileManager.default.fileExists(atPath: filePath)
    }
}


// MARK: - Create and get cache folders

extension DiskCache {

    class func folderUrl(withSubfolder subfolder: Subfolder? = nil) throws -> URL {
        let searchPathDirectory: FileManager.SearchPathDirectory = .cachesDirectory

        var directory = try FileManager.default.url(for: searchPathDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        directory.appendPathComponent(cacheFolder)

        if let subfolder {
            directory.appendPathComponent(subfolder.rawValue)
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try directory.setResourceValues(resourceValues)

        return directory
    }
}
