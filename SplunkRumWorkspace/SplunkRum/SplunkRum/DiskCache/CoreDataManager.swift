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
           let  result1 = try managedObject.fetch(fetchRequest) 
           
            //result = try managedObject.fetch(fetchRequest) as! [SpanData]
            for data in result1 {
                print("\(data)")
            }
        } catch {
            print("failed")
            return result
        }
        return result
    }
}

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
