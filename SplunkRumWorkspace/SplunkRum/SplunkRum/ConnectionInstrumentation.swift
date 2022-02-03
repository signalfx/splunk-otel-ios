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
import OpenTelemetryApi


//MARK: - NSURLConnection Instrumentation -
class ConnectionObserver: NSObject {
    var span: Span?
    // Observers aren't kept alive by observing...
    var extraRefToSelf: ConnectionObserver?
    var lock: NSLock = NSLock()
    override init() {
        super.init()
        extraRefToSelf = self
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        lock.lock()
        defer {
            lock.unlock()
        }
        let connection = object as? NSURLConnection
        if connection == nil {
            return
        }
        if span == nil {
            span = startConnectionSpan(request: connection!.originalRequest)
            span?.setAttribute(key: "component", value: "NSURLConnection")
            OpenTelemetry.instance.contextProvider.setActiveSpan(span!)
        }
        // FIXME possibly also allow .canceling to close the span?
        if connection != nil  && extraRefToSelf != nil {
            extraRefToSelf = nil
        }
    }
}
func startConnectionSpan(request: URLRequest?) -> Span? {
    if request == nil || request?.url == nil {
        return nil
    }
    let url = request!.url!
    if !(url.scheme?.lowercased().starts(with: "http") ?? false) {
        return nil
    }
    let method = request!.httpMethod ?? "GET"
    // Don't loop reporting on communication with the beacon
    let absUrlString = url.absoluteString
    if SplunkRum.theBeaconUrl != nil && absUrlString.starts(with: SplunkRum.theBeaconUrl!) {
        return nil
    }
    if SplunkRum.configuredOptions?.ignoreURLs != nil {
        let result = SplunkRum.configuredOptions?.ignoreURLs?.matches(in: absUrlString, range: NSRange(location: 0, length: absUrlString.utf16.count))
        if result?.count != 0 {
            return nil
        }
    }
    let tracer = buildTracer()
    let span = tracer.spanBuilder(spanName: "HTTP "+method).setSpanKind(spanKind: .client).startSpan() //CONNECTION
    span.setAttribute(key: "component", value: "http")  //"NSURLConnection"
    span.setAttribute(key: "http.url", value: url.absoluteString)
    span.setAttribute(key: "http.method", value: method)
    
    if let body = request?.httpBody{
        span.setAttribute(key: "http.request_content_length", value: Int(body.count))
    }
    
     
    return span
}
func endConnectionSpan(connection: NSURLConnection? ,status:String ,hr:HTTPURLResponse?,error: Error?,span : Span = OpenTelemetry.instance.contextProvider.activeSpan!) {
    if hr != nil {
        span.setAttribute(key: "http.status_code", value: hr!.statusCode)
        // Blerg, looks like an iteration here since it is case sensitive and the case insensitive search assumes single value
        for (key, val) in hr!.allHeaderFields {
            let keyStr = key as? String
            if keyStr != nil {
                if keyStr?.caseInsensitiveCompare("server-timing") == .orderedSame {
                    let valStr = val as? String
                    if valStr != nil {
                        if valStr!.starts(with: "traceparent") {
                            addLinkToSpan(span: span, valStr: valStr!)
                        }
                    }
                }
            }
        }
    }
    if error != nil {
        span.setAttribute(key: "error", value: true)
        span.setAttribute(key: "exception.message", value: error!.localizedDescription)
        span.setAttribute(key: "exception.type", value: String(describing: type(of: error!)))
    }
    
  
    span.setAttribute(key: "http.response_content_length_uncompressed", value: Int(hr?.expectedContentLength ?? 0))
  
    if hostConnectionType != nil {
        span.setAttribute(key: "net.host.connection.type", value: hostConnectionType!)
    }
    span.end()
}




func wireUpConnectionObserver(connection: NSURLConnection) {
    connection.addObserver(ConnectionObserver(), forKeyPath: "start", options: .initial, context: nil)
    
}

func swizzleClassMethod(clazz: AnyClass, orig: Selector, swizzled: Selector){
    let origM = class_getClassMethod(clazz, orig)
    let swizM = class_getClassMethod(clazz, swizzled)
    if origM != nil && swizM != nil {
        method_exchangeImplementations(origM!, swizM!)
    } else {
        debug_log("warning: could not swizzle "+NSStringFromSelector(orig))
    }
    
}

func initalizeConnectionInstrumentation() {
    let connection = NSURLConnection.self
    
   swizzleClassMethod(clazz: connection, orig: #selector(NSURLConnection.sendAsynchronousRequest(_:queue:completionHandler:)), swizzled: #selector((NSURLConnection.splunk_swizzled_connection_sendAsynchronousRequest(request:queue:completionHandler:))))
    
    swizzleClassMethod(clazz: connection, orig: #selector(NSURLConnection.sendSynchronousRequest(_:returning:)), swizzled: #selector(NSURLConnection.splunk_swizzled_connection_sendSynchronousRequest(_:returning:)))
    
    

}

// Convert from NSData to json object
public func dataToJSON(data: Data) -> Any? {
     guard let deserializedValues = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) else { return false}
        return deserializedValues
}
extension NSURLConnection {
    
  
    @objc open class func splunk_swizzled_connection_sendSynchronousRequest(_ request: URLRequest?, returning response: AutoreleasingUnsafeMutablePointer<URLResponse?> ) throws -> Data{
        print("inside swizzle sendSynchronous method")
        let span = startConnectionSpan(request: request)
        var status = "Sucess"
        var data = Data()
       
        do{
            data = try splunk_swizzled_connection_sendSynchronousRequest(request, returning: response)
            if let httpResponse = response.pointee as? HTTPURLResponse {
                print(httpResponse.statusCode)
                if httpResponse.statusCode != 200 {
                    status = "Failure"
                }
                endConnectionSpan(connection: nil, status: status, hr: httpResponse, error: nil,span: span!)
            }
        
        }
        catch let error {
            print(error)
            endConnectionSpan(connection: nil, status: status, hr: nil, error: error ,span: span!)
    
        }
        
      return data
       
    }
    
    @objc open class func splunk_swizzled_connection_sendAsynchronousRequest(request: URLRequest, queue: OperationQueue,completionHandler: @escaping (URLResponse?, Data?, Error?) -> Void ){
        print("inside swizzle sendAsynchronous method")
        let span = startConnectionSpan(request: request)
        return splunk_swizzled_connection_sendAsynchronousRequest(request: request, queue: queue) { response, data, error in
            var status = "Sucess"
            if error != nil {
                status = "Failure"
                endConnectionSpan(connection: nil, status: status, hr: nil, error: error,span: span!)
            }
            else if response != nil {
                guard let hr = response as? HTTPURLResponse else {return}
                endConnectionSpan(connection: nil, status: status, hr: hr, error: nil,span: span!)
            }
            
        }
    }
   
}



