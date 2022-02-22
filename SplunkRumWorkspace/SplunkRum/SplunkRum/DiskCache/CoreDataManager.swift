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

let FLUSH_OUT_TIME_SECONDS = 60   // 4 * 60 * 60  // 4 hours


let Entity_name = "Pending"
let TimeStampColumn = "created_at"



public class CoreDataManager {
    public static let shared = CoreDataManager()
    let identifier: String  = "com.splunk.opentelemetry.SplunkRum"       // splunkrum framework bundle ID
    let model: String       = "Rum"                      // Model name
    
    lazy var persistentContainer: NSPersistentContainer = {
    
            let messageKitBundle = Bundle(identifier: self.identifier)
            let modelURL = messageKitBundle!.url(forResource: self.model, withExtension: "momd")!
            let managedObjectModel =  NSManagedObjectModel(contentsOf: modelURL)
            
            let container = NSPersistentContainer(name: self.model, managedObjectModel: managedObjectModel!)
            container.loadPersistentStores { (storeDescription, error) in
                
                if let err = error{
                    fatalError("Loading of store failed:\(err)")
                }
            }
            
            return container
        }()
    
    
    
    //MARK:- Insert span in to DB

public func insertSpanIntoDB(_ spans: [SpanData]) {
    getStoreInformation()
   
    let spanArr : Array = [1,2,3,4]
   // let spanArr : Array = [spans]
    let managedObject = persistentContainer.viewContext

    let spanEntity = NSEntityDescription.entity(forEntityName: Entity_name, in: managedObject)!
    
    //let encodedData = NSKeyedArchiver.archivedData(withRootObject: spanArr)
    let encodedData = NSKeyedArchiver.archivedData(withRootObject: spanArr)
    let span = NSManagedObject(entity: spanEntity, insertInto: managedObject)
    span.setValue(encodedData, forKey: "span")
    span.setValue(Date(), forKey: TimeStampColumn)
    do {
        try managedObject.save()
        
    } catch let error as NSError {
        print("could not save. \(error) \(error.userInfo)")
    }
}
    //MARK:- fetch span from DB
public func fetchSpanFromDB() -> [SpanData] {
    let managedObjectContext = persistentContainer.viewContext
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Entity_name)
    let result = [SpanData]()
    do {
        let result1 = try managedObjectContext.fetch(fetchRequest) as! [Pending]
        for data in result1 {
           // guard let spanDataArray = (try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data.span!)) as? [SpanData] else { return [] }
            guard let spanDataArray = (try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data.span!)) else { return [] }
           
            print("out put is/////////// \(spanDataArray)")
           
          
        }
    } catch {
        print("failed")
        return result
    }
    
    
    
      /*  do {
            //let  result1 = try managedObject.fetch(fetchRequest)
            //print(result1)
           let result1 = try managedObjectContext.fetch(fetchRequest) as! [Pending]
            for data in result1 {
                let d = String(describing: data.span ?? "")
                print("\(d)")
                
                let T = String(describing: data.created_at)
                print("\(T)")
              
            }
        } catch {
            print("failed")
            return result
        }*/
        return result
    }
    /** flush out db after 4 h time out */
    public func flushOutSpanAfterTimePeriod() {
        print("Core Data Store at ......\(NSPersistentContainer.defaultDirectoryURL().absoluteString)")
        let managedObjectContext = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Entity_name)
        // Add Predicate
        let flushDBTime = Date().addingTimeInterval(TimeInterval(-FLUSH_OUT_TIME_SECONDS))
        let predicate = NSPredicate(format: "\(TimeStampColumn) < %@", flushDBTime as CVarArg)
        fetchRequest.predicate = predicate
        
        do {
            let records = try managedObjectContext.fetch(fetchRequest) as! [Pending]

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
    // single spandata delete.
    public func deleteSpanData(spans : [SpanData]) {
        let managedObjectContext = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Entity_name)
        
        for span in spans {
            // Add Predicate
            let predicate = NSPredicate(format: "span == %@", span as! CVarArg)
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
    
    public func timeWiseSorting() {
        
        let managedObjectContext = persistentContainer.viewContext
        // Create Fetch Request
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Entity_name)

        // Add Sort Descriptor
        let sortDescriptor = NSSortDescriptor(key: TimeStampColumn, ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            let records = try managedObjectContext.fetch(fetchRequest) as! [NSManagedObject]

            for record in records {
                print(record.value(forKey: TimeStampColumn) ?? "no time")
            }

        } catch {
            print(error)
        }
    }
    /**get used space and free space information**/
    public func getStoreInformation() {
       // let documentsDirectory = getLibraryDirectory()
        let defaultdirecotry = NSPersistentContainer.defaultDirectoryURL()
        let persistentStorePath = defaultdirecotry.appendingPathComponent("Rum.sqlite").absoluteString.removingPercentEncoding
        
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: persistentStorePath!) as NSDictionary
            print("Persistent store size: \(String(describing: fileAttributes.object(forKey: FileAttributeKey.size))) bytes")
        } catch {
            print("FileAttribute error: \(error)")
        }
        
        do {
            let fileSystemAttributes = try FileManager.default.attributesOfFileSystem(forPath: persistentStorePath!) as NSDictionary
            print("Free space on file system: \(String(describing: fileSystemAttributes.object(forKey:FileAttributeKey.systemFreeSize))) bytes")
        } catch {
            print("FileAttribute error: \(error)")
        }
        
       
    }
    
}
//MARK: -
extension String {
    func toJSON() -> Any? {
        guard let data = self.data(using: .utf8, allowLossyConversion: false) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)
    }
}

/*class ManagedSpan: NSManagedObject {

    @NSManaged var traceId: String
    @NSManaged var spanId: String
    @NSManaged var name: String
    @NSManaged var kind: String
    @NSManaged var startTime: String
    @NSManaged var endTime: String

    var spandata: SpanData {
       get {
            return SpanData(traceId: traceId, spanId: spanId, name: name, kind: kind, startTime: startTime, endTime: endTime)
       }
       set {
            self.name = newValue.name
       }
     }
}*/
/*class DecodedSpanData: Decodable {
    var spandata: SpanData
    
    init(spandata: SpanData) {
        self.spandata = spandata
    }
    required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let traceId = try container.decode(String.self, forKey: .traceId)
            spandata = SpanData(traceId:traceId )
            
        }
        
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(spandata.traceId, forKey: .traceId) // Might want to make sure that the name is not nil here
    }
        
        enum CodingKeys: String, CodingKey {
            case traceId
            
        }
}*/
/*extension SpanData: Codable {
   
   public func encode(to encoder: Encoder) throws {
        print("Encode")
    }
    
    func toJson()->String {
        let jsonEncoder = JSONEncoder()
        let jsonData = try! jsonEncoder.encode(self)
        let jsonString = String(data: jsonData, encoding: .utf8)
        return jsonString!
    }
}

extension Encodable {
    
    func toJSONString() -> String {
        let jsonData = try! JSONEncoder().encode(self)
        return String(data: jsonData, encoding: .utf8)!
    }
    
}

func instantiate<T: Decodable>(jsonString: String) -> T? {
    return try? JSONDecoder().decode(T.self, from: jsonString.data(using: .utf8)!)
}*/
func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let documentsDirectory = paths[0]
    return documentsDirectory
}
func getLibraryDirectory() -> URL {
    let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
    let librarysDirectory = paths[0]
    return librarysDirectory
}
/*extension SpanData {
   init(record: SpanData) {
       self.settingTraceId(record.traceId)
       self.settingSpanId(record.spanId)
       self.settingTraceFlags(record.traceFlags)
       self.settingTraceState(record.traceState)
       self.settingParentSpanId(record.parentSpanId!)
       self.settingResource(record.resource)
       self.settingName(record.name)
       self.settingKind(record.kind)
       self.settingStartTime(record.startTime)
       self.settingAttributes(record.attributes)
       self.settingEvents(record.events)
       self.settingLinks(record.links)
       self.settingEndTime(record.endTime)
       self.settingStatus(record.status)
       self.settingHasRemoteParent(record.hasRemoteParent)
       self.settingHasEnded(record.hasEnded)
       self.settingTotalRecordedEvents(record.totalRecordedEvents)
       self.settingTotalRecordedLinks(record.totalRecordedLinks)
       self.settingTotalAttributeCount(record.totalAttributeCount)
       // self.instrumentationLibraryInfo = InstrumentationLibraryInfo()
 }
}*/
