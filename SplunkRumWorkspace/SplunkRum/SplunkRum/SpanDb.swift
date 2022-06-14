//
/*
Copyright 2022 Splunk Inc.

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
import SQLite3

fileprivate func sqliteError(code: Int32) -> String {
    return String(cString: sqlite3_errstr(code))
}

fileprivate let DB_FILE = "SplunkRum.sqlite"

fileprivate let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

class SpanDb {
    let databasePath: String
    private var lock: NSLock = NSLock()
    internal var db_: OpaquePointer?
    private var insertStmt_: OpaquePointer?
    private var fetchStmt_: OpaquePointer?
    private var sizeStmt_: OpaquePointer?
    private var initialized: Bool = false

    init(path: String? = nil) {
        self.databasePath = path ?? SpanDb.makeDatabasePath() ?? ":memory:"

        var status = sqlite3_open(databasePath, &db_)

        if status != SQLITE_OK {
            log("failure opening \(databasePath): \(sqliteError(code: status))")
            return
        }

        let db = db_!

        status = sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS span (timestamp INTEGER NOT NULL, data TEXT NOT NULL)", nil, nil, nil)

        if status != SQLITE_OK {
            log("unable to create span table: \(sqliteError(code: status))")
            return
        }

        status = sqlite3_exec(db, "CREATE INDEX IF NOT EXISTS span_timestamp ON span (timestamp)", nil, nil, nil)

        if status != SQLITE_OK {
            log("unable to create span_timestamp index: \(sqliteError(code: status))")
            return
        }

        status = sqlite3_prepare_v2(db, "INSERT INTO span (timestamp, data) VALUES (?, ?)", -1, &insertStmt_, nil)

        if status != SQLITE_OK {
            log("unable to create span insert statement: \(sqliteError(code: status))")
            return
        }

        status = sqlite3_prepare_v2(db, "SELECT rowid, data FROM span ORDER BY timestamp ASC LIMIT ?", -1, &fetchStmt_, nil)

        if status != SQLITE_OK {
            log("unable to create span fetch statement: \(sqliteError(code: status))")
            return
        }

        status = sqlite3_prepare_v2(db,
                                    "SELECT page_count * page_size FROM pragma_page_count(), pragma_page_size()",
                                    -1,
                                    &sizeStmt_,
                                    nil)

        if status != SQLITE_OK {
            log("unable to create DB size fetch statement: \(sqliteError(code: status))")
            return
        }

        initialized = true
    }

    deinit {
        initialized = false
        let stmts = [sizeStmt_, fetchStmt_, insertStmt_]

        for stmt in stmts where stmt != nil {
            sqlite3_finalize(stmt!)
        }

        if db_ != nil {
            sqlite3_close(db_!)
        }
    }

    func ready() -> Bool {
        return initialized
    }

    func store(spans: [ZipkinSpan]) -> Bool {
        if !ready() {
            return false
        }

        if spans.isEmpty {
            return true
        }

        let encoder = JSONEncoder()
        let maybeEncodedSpans = spans.map { ($0.timestamp, try? encoder.encode($0)) }
        let jsonSpans = maybeEncodedSpans.compactMap { (ts, maybeSpan) in
            maybeSpan != nil ? (ts, maybeSpan!) : nil
        }

        let db = db_!
        let insertStmt = insertStmt_!

        lock.lock()
        defer {
            lock.unlock()
        }

        var status = sqlite3_exec(db, "BEGIN", nil, nil, nil)

        if status != SQLITE_OK {
            log("unable to begin span insertion: \(sqliteError(code: status))")
            return false
        }

        for (ts, span) in jsonSpans {
            sqlite3_reset(insertStmt)
            span.withUnsafeBytes {
                let spanJson = $0.baseAddress!.assumingMemoryBound(to: CChar.self)
                sqlite3_bind_int64(insertStmt, 1, Int64(ts))
                sqlite3_bind_text(insertStmt, 2, spanJson, Int32(span.count), SQLITE_TRANSIENT)
            }
            sqlite3_step(insertStmt)
        }

        status = sqlite3_exec(db, "COMMIT", nil, nil, nil)

        if status != SQLITE_OK {
            log("span insertion failed: \(sqliteError(code: status))")
            return false
        }

        return true
    }

    func fetch(count: Int) -> [(Int64, String)] {
        if !ready() {
            return []
        }

        lock.lock()
        defer {
            lock.unlock()
        }

        let stmt = fetchStmt_!
        sqlite3_reset(stmt)
        sqlite3_bind_int(stmt, 1, Int32(count))

        var spans: [(Int64, String)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let rawData = sqlite3_column_text(stmt, 1)
            let data = rawData != nil ? String(cString: rawData!) : ""
            spans.append((id, data))
        }

        return spans
    }

    func erase(ids: [Int64]) -> Bool {
        if !ready() {
            return false
        }

        if ids.isEmpty {
            return true
        }

        let predicate = ids.map { String($0) }.joined(separator: ",")
        let query = "DELETE FROM span WHERE rowid IN (\(predicate))"

        lock.lock()
        defer {
            lock.unlock()
        }

        let status = sqlite3_exec(db_!, query, nil, nil, nil)

        if status != SQLITE_OK {
            log("unable to delete spans: \(sqliteError(code: status))")
            return false
        }

        return true
    }

    func truncate() -> Bool {
        if !ready() {
            return false
        }

        lock.lock()
        defer {
            lock.unlock()
        }

        // Delete the oldest 20% of spans
        let query = """
          DELETE FROM span WHERE rowid IN (
            SELECT rowid FROM span ORDER BY timestamp ASC LIMIT (
              SELECT COUNT(*) / 5 FROM span
            )
          )
        """

        let db = db_!

        var status = sqlite3_exec(db, query, nil, nil, nil)

        if status != SQLITE_OK {
            log("span deletion failed on truncate: \(sqliteError(code: status))")
            return false
        }

        status = sqlite3_exec(db, "VACUUM;", nil, nil, nil)

        if status != SQLITE_OK {
            log("span database vacuum failed: \(sqliteError(code: status))")
            return false
        }

        return true
    }

    func getSize() -> Int? {
        if !ready() {
            return nil
        }

        lock.lock()
        defer {
            lock.unlock()
        }

        let stmt = sizeStmt_!
        sqlite3_reset(stmt)

        var dbSize = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            dbSize = Int(sqlite3_column_int(stmt, 0))
        }

        return dbSize
    }

    static func deleteAtDefaultLocation() {
        let dir_ = SpanDb.defaultDirectory()

        if dir_ == nil {
            return
        }

        let path = dir_!.appendingPathComponent(DB_FILE).path

        if FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                log("failed to delete span database at path \(path): \(error)")
            }
        }
    }

    static func defaultDirectory() -> URL? {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)

        if paths.isEmpty {
            return nil
        }

        return paths[0]
    }

    static func makeDatabasePath() -> String? {
        let dir_ = SpanDb.defaultDirectory()

        if dir_ == nil {
            return nil
        }

        let dir = dir_!

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            log("unable to create application support directory \(dir): \(error)")
            return nil
        }

        return dir.appendingPathComponent(DB_FILE).path
    }
}
