//
/*
Copyright 2021 Splunk Inc.

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
import CoreData
import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftUI
import ZipkinExporter

let FLUSH_OUT_TIME_SECONDS = 4 * 60 * 60  // 4 hours
let FLUSH_OUT_MAX_SIZE = 21966080  // 20 MB
let TimeStampColumn = "created_at"
let ENTITY_NAME = "PendingSpans"

/** All database related stuffs */
public class CoreDataManager {
    /** shared instance of class*/
    public static let shared = CoreDataManager()
    let identifier: String  = "com.splunk.opentelemetry.SplunkRum"       // splunkrum framework bundle ID
    let model: String       = "Rum"                      // Model name

    lazy var persistentContainer: NSPersistentContainer = {

            let messageKitBundle = Bundle(identifier: self.identifier)
            let modelURL = messageKitBundle!.url(forResource: self.model, withExtension: "momd")!
            let managedObjectModel =  NSManagedObjectModel(contentsOf: modelURL)

            let storedescription = NSPersistentStoreDescription(url: NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("Rum.sqlite"))
            storedescription.setOption(true as NSNumber, forKey: NSSQLiteManualVacuumOption)

            let container = NSPersistentContainer(name: self.model, managedObjectModel: managedObjectModel!)
            container.persistentStoreDescriptions = [storedescription]
            container.loadPersistentStores { (_, error) in

                if let err = error {
                    fatalError("Loading of store failed:\(err)")
                }
            }

            return container
        }()

    // MARK: - Insert seperate value -
    /** Insert span in to database */
    public func insertSpanValue(_ spans: [SpanData]) {
        let managedObjectContext = persistentContainer.viewContext
        let spanEntity = NSEntityDescription.entity(forEntityName: ENTITY_NAME, in: managedObjectContext)!
        for pendingSpan in spans {
            let span = NSManagedObject(entity: spanEntity, insertInto: managedObjectContext)
            let encoder = JSONEncoder()
            if let jsonData = try? encoder.encode(pendingSpan.attributes) {
                if let jsonString = String(data: jsonData, encoding: . utf8) {
                    span.setValue(jsonString, forKey: "attributes")

                }
            }

            span.setValue(String(describing: pendingSpan.events), forKey: "events")
            span.setValue(pendingSpan.endTime, forKey: "duration")
            span.setValue(String(describing: pendingSpan.kind), forKey: "kind")
            span.setValue(String(describing: pendingSpan.parentSpanId), forKey: "parentSpanId")
            span.setValue(String(describing: pendingSpan.spanId), forKey: "spanId")
            span.setValue(pendingSpan.name, forKey: "spanName")
            span.setValue(pendingSpan.startTime, forKey: "start")
            span.setValue(String(describing: pendingSpan.traceFlags), forKey: "traceFlags")
            span.setValue(String(describing: pendingSpan.traceId), forKey: "traceId")
            span.setValue(String(describing: pendingSpan.traceState), forKey: "traceState")
            span.setValue(Date(), forKey: TimeStampColumn)  // this is used only for flush out

            // save in to db
            do {
                try managedObjectContext.save()
            } catch let error as NSError {
                print("could not save. \(error) \(error.userInfo)")
            }
        }
    }
    /** Fetch span information from database and generate new span from it */
    public func fetchSpanValues() -> [SpanData] {
        let managedObjectContext = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ENTITY_NAME)
        var newSpans = [SpanData]()
        do {
            let spans = try managedObjectContext.fetch(fetchRequest) as! [NSManagedObject]
            for span in spans as [NSManagedObject] {
                newSpans.append(createNewSpan(using: span))
            }
        } catch {
            print(error)
        }
        return newSpans
   }

    func createNewSpan(using spanInfo: NSManagedObject) -> SpanData {
        let tracer = buildTracer()
        // set span kind logic here
         let kind = spanInfo.value(forKey: "kind") as! String
         let span = tracer.spanBuilder(spanName: spanInfo.value(forKey: "spanName") as! String).setSpanKind(spanKind: SpanKind(rawValue: kind)!).setStartTime(time: spanInfo.value(forKey: "start") as! Date).startSpan()
        span.addEvent(name: spanInfo.value(forKey: "events") as! String)
        let attributesDict = convertStringToDictionary(text: spanInfo.value(forKey: "attributes") as! String)
        for dict in attributesDict! {
            let value = dict.value.allValues[0]
            if value is String {
                span.setAttribute(key: dict.key, value: value as! String)
            } else if dict.value is Int {
                span.setAttribute(key: dict.key, value: value as! Int)
            } else if dict.value is Double {
                span.setAttribute(key: dict.key, value: value as! Double)
            } else if dict.value is Bool {
                span.setAttribute(key: dict.key, value: value as! Bool)
            } else if dict.value is [String: Any] {
                span.setAttribute(key: dict.key, value: value as? AttributeValue)
            }
        }
        span.end(time: spanInfo.value(forKey: "duration") as! Date)
        return (span as! RecordEventsReadableSpan).toSpanData()
    }
    func convertStringToDictionary(text: String) -> [String: AnyObject]? {
        if let data = text.data(using: .utf8) {
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: AnyObject]
                return json
            } catch {
                print("Something went wrong")
            }
        }
        return nil
    }
// MARK: - Flush out logic -
    /** flush out db after 4 h time out */
    public func flushOutSpanAfterTimePeriod() {
        let managedObjectContext = persistentContainer.newBackgroundContext()
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ENTITY_NAME)
        // Add Predicate
        let flushDBTime = Date().addingTimeInterval(TimeInterval(-FLUSH_OUT_TIME_SECONDS))
        let predicate = NSPredicate(format: "\(TimeStampColumn) < %@", flushDBTime as CVarArg)
        fetchRequest.predicate = predicate

        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
           try managedObjectContext.executeAndMergeChanges(using: batchDeleteRequest)
        } catch {
            print(error)
        }
    }
    /** delete record of db if db size exceed then max size*/
    public func flushDbIfSizeExceed() {
        if fileExistAtPath() {
            let dbsize = getPersistentStoreSize() as! Int
            if dbsize > FLUSH_OUT_MAX_SIZE {
                deleteSpanInFifoManner()
            }
        }
    }
    /**delete db record in FIFO manner and vaccume space**/
    public func deleteSpanInFifoManner() {
        let managedObjectContext = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ENTITY_NAME)

        // Add Sort Descriptor
        let sortDescriptor = NSSortDescriptor(key: TimeStampColumn, ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.fetchLimit = 1000

        do {
            let records = try managedObjectContext.fetch(fetchRequest) as! [NSManagedObject]
            for record in records {
                managedObjectContext.delete(record)
            }

        } catch {
            print(error)
        }

        do {
            try managedObjectContext.save()

        } catch let error as NSError {
            print("could not save. \(error) \(error.userInfo)")

        }
    }
    /** Delete single Span Data from DB*/
    public func deleteSpanData(spans: [SpanData]) {
        let managedObjectContext = persistentContainer.newBackgroundContext()
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ENTITY_NAME)

        for span in spans {
            // Add Predicate
            let starttime = span.startTime
            let endtime = span.endTime
            let p1 = NSPredicate(format: "start == %@", starttime as CVarArg)
            let p2 = NSPredicate(format: "duration == %@", endtime as CVarArg)
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [p1, p2])
            // let predicate = NSPredicate(format: "start == %@ && duration == %@", starttime as CVarArg, endtime as CVarArg)
            fetchRequest.predicate = predicate

            do {
                let records = try managedObjectContext.fetch(fetchRequest) as! [NSManagedObject]

                for record in records {
                    managedObjectContext.delete(record)
                }

            } catch {
                print(error)
            }
        }

        // save context.
        do {
            try managedObjectContext.save()

        } catch let error as NSError {
            print("could not save. \(error) \(error.userInfo)")
        }
    }

    /** Check that db is exist at given path */
    public func fileExistAtPath() -> Bool {
        let defaultdirecotry = NSPersistentContainer.defaultDirectoryURL()
        let persistentStorePath = defaultdirecotry.appendingPathComponent("Rum.sqlite").path
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: persistentStorePath)
    }

    /**get  size  information */
    public func getPersistentStoreSize()-> Any {
        let defaultdirecotry = NSPersistentContainer.defaultDirectoryURL()
        let persistentStorePath = defaultdirecotry.appendingPathComponent("Rum.sqlite").path

        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: persistentStorePath) as NSDictionary
            return fileAttributes.object(forKey: FileAttributeKey.size) as Any
        } catch {
            print("FileAttribute error: \(error)")
            return error
        }

    }

    /**get count  of records */
    public func getRecordsCount() -> Int {
        var count = 0
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ENTITY_NAME)
        do {
            let managedObjectContext = persistentContainer.viewContext
            count = try managedObjectContext.count(for: fetchRequest)
            return count
        } catch {
            print(error.localizedDescription)
        }
       return count
    }
}
// MARK: -
func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let documentsDirectory = paths[0]
    return documentsDirectory
}
extension NSManagedObjectContext {
    /// Executes the given `NSBatchDeleteRequest` and directly merges the changes to bring the given managed object context up to date.
    /// - Parameter batchDeleteRequest: The `NSBatchDeleteRequest` to execute.
    /// - Throws: An error if anything went wrong executing the batch deletion.
    public func executeAndMergeChanges(using batchDeleteRequest: NSBatchDeleteRequest) throws {
        batchDeleteRequest.resultType = .resultTypeObjectIDs
        do {
            let result = try execute(batchDeleteRequest) as? NSBatchDeleteResult
            let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: result?.result as? [NSManagedObjectID] ?? []]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self])
        } catch {
            print(error)
        }

    }
}
