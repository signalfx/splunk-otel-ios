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

import XCTest
@testable import SplunkRum

func testDbPath(_ fileName: String = "SplunkRum.sqlite") -> String {
    FileManager.default.temporaryDirectory.appendingPathComponent("SplunkRum.sqlite").path
}

fileprivate var idgen = RandomIdGenerator()

func makeSpan(name: String, timestamp: UInt64, tags: [String: String], duration: UInt64?) -> ZipkinSpan {
    ZipkinSpan(
        traceId: idgen.generateTraceId().hexString,
        parentId: nil,
        id: idgen.generateSpanId().hexString,
        kind: "CLIENT",
        name: name,
        timestamp: timestamp,
        duration: duration,
        remoteEndpoint: nil,
        annotations: [],
        tags: tags
    )
}

func toTestSpan(json: String) -> TestZipkinSpan {
    try! JSONDecoder().decode(TestZipkinSpan.self, from: json.data(using: .utf8)!)
}

func deleteFile(_ path: String) throws {
    if FileManager.default.fileExists(atPath: path) {
        try FileManager.default.removeItem(atPath: path)
    }
}

class SpanDbTest: XCTestCase {
    var dbPath: String?

    override func setUpWithError() throws {
        try super.setUpWithError()
        dbPath = nil
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        if dbPath != nil {
            try deleteFile(dbPath!)
        }
        try deleteFile(testDbPath())
    }

    func testDefaultOpening() throws {
        let db = SpanDb()
        dbPath = db.databasePath
        XCTAssertTrue(db.ready())
        XCTAssertEqual(db.fetch(count: 32).count, 0)
    }

    func testSpanReadWrite() {
        let db = SpanDb(path: testDbPath())
        let zipkinSpans = [
            makeSpan(name: "s1", timestamp: 0, tags: ["foo": "42"], duration: 5),
            makeSpan(name: "s2", timestamp: 3, tags: ["bar": "ios"], duration: 8)
        ]

        XCTAssertTrue(db.store(spans: zipkinSpans))

        let storedSpans = db.fetch(count: 32)
        XCTAssertEqual(storedSpans.count, 2)

        let spans = storedSpans.map { (_, spanJson) in
            toTestSpan(json: spanJson)
        }

        XCTAssertEqual(spans[0].name, "s1")
        XCTAssertEqual(spans[0].tags, ["foo": "42"])
        XCTAssertEqual(spans[1].name, "s2")
        XCTAssertEqual(spans[1].tags, ["bar": "ios"])

    }

    func testErase() {
        let db = SpanDb(path: testDbPath())
        let zipkinSpans = [
            makeSpan(name: "s1", timestamp: 0, tags: [:], duration: 5),
            makeSpan(name: "s2", timestamp: 3, tags: [:], duration: 8),
            makeSpan(name: "s3", timestamp: 6, tags: [:], duration: 4)
        ]

        XCTAssertTrue(db.store(spans: zipkinSpans))
        var storedSpans = db.fetch(count: 2)
        XCTAssertEqual(storedSpans.count, 2)

        let (id, json) = storedSpans[1]
        let span = toTestSpan(json: json)
        XCTAssertEqual(span.name, "s2")

        XCTAssertTrue(db.erase(ids: [id]))

        storedSpans = db.fetch(count: 10)
        XCTAssertEqual(storedSpans.count, 2)

        let spans = storedSpans.map({ (_, json) in
            toTestSpan(json: json)
        })

        XCTAssertEqual(spans[0].name, "s1")
        XCTAssertEqual(spans[1].name, "s3")

        let ids = storedSpans.map({ (id, _) in
            id
        })

        XCTAssertTrue(db.erase(ids: ids))
        storedSpans = db.fetch(count: 10)
        XCTAssertEqual(storedSpans.count, 0)
    }

    func testNonexistentIdErase() {
        let db = SpanDb(path: testDbPath())
        let zipkinSpans = [
            makeSpan(name: "s1", timestamp: 0, tags: [:], duration: 5)
        ]

        XCTAssertTrue(db.store(spans: zipkinSpans))
        XCTAssertEqual(db.fetch(count: 10).count, 1)
        XCTAssertTrue(db.erase(ids: [947539]))

        let storedSpans = db.fetch(count: 10)
        XCTAssertEqual(storedSpans.count, 1)
    }

    func testTruncate() {
        let db = SpanDb(path: testDbPath())
        let initialSize = db.getSize()!

        var zipkinSpans: [ZipkinSpan] = []
        for id in 1...10_000 {
            zipkinSpans.append(makeSpan(name: "s\(id)", timestamp: UInt64(id), tags: [:], duration: 2))
        }

        XCTAssertTrue(db.store(spans: zipkinSpans))
        let sizeAfterInsert = db.getSize()!
        XCTAssertGreaterThan(sizeAfterInsert, initialSize)

        XCTAssertTrue(db.truncate())

        // Should now have 20% fewer rows
        let storedSpans = db.fetch(count: 10_000)
        XCTAssertEqual(storedSpans.count, 8_000)

        let spans = storedSpans.map({ (_, json) in
            toTestSpan(json: json)
        })
        XCTAssertEqual(spans.first!.name, "s2001")
        XCTAssertEqual(spans.last!.name, "s10000")

        let sizeAfterTruncate = db.getSize()!

        XCTAssertLessThan(sizeAfterTruncate, sizeAfterInsert)
    }

    func testMemoryDb() throws {
        let db = SpanDb(path: ":memory:")
        XCTAssertTrue(db.ready())

        guard let path = SpanDb.makeDatabasePath() else {
            XCTFail("Unable to create database path")
            return
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: path))

        let zipkinSpans = [
            makeSpan(name: "s1", timestamp: 0, tags: [:], duration: 5),
            makeSpan(name: "s2", timestamp: 3, tags: [:], duration: 8)
        ]

        XCTAssertTrue(db.store(spans: zipkinSpans))

        let storedSpans = db.fetch(count: 32)
        XCTAssertEqual(storedSpans.count, 2)

        let spans = storedSpans.map { (_, spanJson) in
            toTestSpan(json: spanJson)
        }

        XCTAssertEqual(spans[0].name, "s1")
        XCTAssertEqual(spans[1].name, "s2")
    }

    func testDatabaseDeletion() throws {
        let db = SpanDb()
        let defaultDir = SpanDb.defaultDirectory()
        XCTAssertTrue(defaultDir != nil)
        XCTAssertEqual(
            URL(fileURLWithPath: db.databasePath).deletingLastPathComponent(),
            defaultDir!
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: db.databasePath))
        SpanDb.deleteAtDefaultLocation()
        XCTAssertFalse(FileManager.default.fileExists(atPath: db.databasePath))
    }

}
