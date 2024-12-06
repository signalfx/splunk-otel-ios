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

extension DiskCache {

    // MARK: - Compute statistics components

    /// Checks if the cache is not corrupted on the filesystem level.
    /// If it is, removes it completely.
    class func checkDiskSpaceAndIntegrity() -> Bool {

        guard statistics.isValid else {
            resetCaches()
            return false
        }

        guard !statistics.capacityOverreached else {
            resetCaches()

            return false
        }

        return true
    }

    class func size(withSubfolders subfolder: Subfolder? = nil) throws -> Int {
        let cacheFolder = try folderUrl(withSubfolder: subfolder)

        let propertyKeys: [URLResourceKey] = [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]

        guard let fileEnumerator = FileManager.default.enumerator(at: cacheFolder,
                                                                  includingPropertiesForKeys: propertyKeys,
                                                                  options: [],
                                                                  errorHandler: nil)
        else {
            throw DiskCacheError.cannotEnumerateCacheContents
        }

        var cacheSize = 0

        for file in fileEnumerator {
            guard let file = file as? URL else {
                continue
            }

            guard let fileProperties = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]) else {
                continue
            }

            guard let isRegularFile = fileProperties.isRegularFile, isRegularFile else {
                continue
            }

            if let fileSize = fileProperties.totalFileAllocatedSize {
                cacheSize += fileSize

            } else if let fileSize = fileProperties.fileAllocatedSize {
                cacheSize += fileSize
            }
        }

        return cacheSize
    }
}

extension DiskCache {

    // MARK: - Compose and store the statistics

    // Private internals vars

    // The queue is just to protect the variable access, should be fast.
    private static let queue = DispatchQueue(label: "com.otel.sdk.disk-cache.stats", qos: .userInteractive)

    // Stores the last computed statistics
    private static var lastStatisticsData: DiskCacheStatistics?

    // Stores current refresh statistics work item
    private static var refreshStatisticsWorkItem: DispatchWorkItem?

    // Define interval for refresh statistics debounce
    private static let debounceRefreshInterval: TimeInterval = 15

    // Public variable that published the statistics.
    static var statistics: DiskCacheStatistics {
        get {
            queue.sync {
                // Make sure there always is some statistics
                lastStatisticsData ?? updateStatisticsData()
            }
        }
        set {
            queue.async {
                lastStatisticsData = newValue
            }
        }
    }


    // Immediately composes the statistics from various components, returns the result and
    // stores it for a future use.
    //
    // Slow, should be run in a background thread.
    @discardableResult static func updateStatisticsData() -> DiskCacheStatistics {

        // get free disk space
        guard let recordsPath = cache()?.path,
              let fileSystemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: recordsPath),
              let freeDiskSpace = fileSystemAttributes[.systemFreeSize] as? Int
        else {
            return DiskCacheStatistics(isValid: false)
        }

        // get occupied cache size
        guard let size = try? DiskCache.size()
        else {
            return DiskCacheStatistics(isValid: false)
        }

        // compute the reset
        let maxAbsoluteDiskCacheSizeInBytes = Int(maxAbsoluteDiskCacheSize.converted(to: .bytes).value)
        let maxAllowedCacheSize = min(maxAbsoluteDiskCacheSizeInBytes, Int(Double(freeDiskSpace) * maxRelativeDiskCacheSize))
        let percentOfAllowedSpaceTaken = Double(size) / Double(maxAllowedCacheSize) * 100.0
        let capacityOverreached = maxAllowedCacheSize < size

        let statistics = DiskCacheStatistics(isValid: true,
                                             freeDiskSpace: freeDiskSpace,
                                             size: size,
                                             maxAllowedCacheSize: maxAllowedCacheSize,
                                             percentOfAllowedSpaceTaken: percentOfAllowedSpaceTaken,
                                             capacityOverreached: capacityOverreached)

        // Cache statistics for the next "fast" use.
        lastStatisticsData = statistics

        return statistics
    }

    /// Refreshes the statistics data by updating the disk cache on a background thread, utilizing a debounce mechanism to prevent frequent updates.
    static func refreshStatistics() {
        guard refreshStatisticsWorkItem == nil else {
            return
        }

        let workItem = DispatchWorkItem {
            DiskCache.updateStatisticsData()
            refreshStatisticsWorkItem = nil
        }

        refreshStatisticsWorkItem = workItem

        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + debounceRefreshInterval, execute: workItem)
    }
}
