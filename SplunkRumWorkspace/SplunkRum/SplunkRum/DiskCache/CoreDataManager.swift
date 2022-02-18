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
        let managedObject = persistentContainer.viewContext

        let spanEntity = NSEntityDescription.entity(forEntityName: "Pending", in: managedObject)!
        
        //insert record logic
        let span = NSManagedObject(entity: spanEntity, insertInto: managedObject)
        for pendingSpan in spans {
            let str = String(describing: pendingSpan)
            print(str)
            // add try to convert str in to span data logic here
            span.setValue(String(describing: pendingSpan), forKey: "span")
            
            // new logic
            // convert struct in to jsonstring then save to db
           // let jsonStr = pendingSpan.toJson()
           // print(jsonStr)
           // let spandataFromJSON: SpanData? = instantiate(jsonString: jsonStr)
          //  print(spandataFromJSON!)
        }
       
        do {
            try managedObject.save()
            
        } catch let error as NSError {
            print("could not save. \(error) \(error.userInfo)")
        }
    }
    //MARK:- fetch span from DB
public func fetchSpanFromDB() -> [SpanData] {
        let managedObject = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Pending")
        let result = [SpanData]()
        do {
            //let  result1 = try managedObject.fetch(fetchRequest)
            //print(result1)
           let result1 = try managedObject.fetch(fetchRequest) as! [Pending]
            for data in result1 {
                var d = String(describing: data.span ?? "")
                print("\(d)")
                d.remove(at: d.index(before: d.endIndex))
                d = d.replacingOccurrences(of: "SpanData(", with: "")
                print("now string is ////// \(d)")
                print(d.toJSON() as Any)
            }
        } catch {
            print("failed")
            return result
        }
        return result
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
