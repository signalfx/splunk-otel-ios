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

struct Constants {
    
    struct Globals {
        static let INSTRUMENTATION_NAME = "splunk-ios"
        static let UNKNOWN_APP_NAME = "unknown-app"
    }
    
    struct SpanNames {
        static let SPLUNK_RUM_INITIALIZE = "SplunkRum.initialize"
        static let SESSION_ID_CHANGE = "sessionId.change"
        static let APP_START = "AppStart"
        static let APP_TERMINATING = "AppTerminating"
        static let RESIGNACTIVE = "ResignActive"
        static let ENTER_FOREGROUND = "EnterForeground"
        static let ACTION = "action"
        static let PRESENTATION_TRANSITION = "PresentationTransition"
        static let SCREEN_NAME_CHANGE = "screen name change"
        static let SHOW_VC = "ShowVC"
    }
    
    struct EventNames {
        static let PROCESS_START = "process.start"
    }
    
    struct AttributeNames {
        static let OS_NAME = "os.name"
        static let OS_VERSION = "os.version"
        static let DEVICE_MODEL_NAME = "device.model.name"
        static let APP = "app"
        static let APP_VERSION = "app.version"
        
        static let ERROR = "error"
        static let EXCEPTION_MESSAGE = "exception.message"
        static let EXCEPTION_TYPE = "exception.type"
        static let EXCEPTION_STACKTRACE = "exception.stacktrace"
        
        static let LAST_SCREEN_NAME = "last.screen.name"
        static let SCREEN_NAME = "screen.name"
        static let THREAD_NAME = "thread.name"
        static let CONFIG_SETTINGS = "config_settings"
        static let COMPONENT = "component"
        static let COUNT = "count"
        static let OBJECT_TYPE = "object.type"
        static let EVENT_TYPE = "event.type"
        static let SENDER_TYPE = "sender.type"
        static let TARGET_TYPE = "target.type"
        static let ACTION_NAME = "action.name"
    
        static let LINK_TRACE_ID = "link.traceId"
        static let LINK_SPAN_ID = "link.spanId"
        
        static let HTTP_URL = "http.url"
        static let HTTP_METHOD = "http.method"
        static let HTTP_STATUS_CODE = "http.status_code"
        static let HTTP_RESPONSE_CONTENT_LENGTH_UNCOMPRESSESD = "http.response_content_length_uncompressed"
        static let HTTP_REQUEST_CONTENT_LENGTH = "http.request_content_length"
        
        static let NET_HOST_CONNECTION_TYPE = "net.host.connection.type"
        static let NET_HOST_CONNECTION_SUBTYPE = "net.host.connection.subtype"
        static let NET_HOST_CARRIER_NAME = "net.host.carrier.name"
        static let NET_HOST_CARRIER_MCC = "net.host.carrier.mcc"
        static let NET_HOST_CARRIER_MNC = "net.host.carrier.mnc"
        static let NET_HOST_CARRIER_ICC = "net.host.carrier.icc"
        
        static let SPLUNK_RUM_SESSION_ID = "splunk.rumSessionId"
        static let SPLUNK_RUM_PREVIOUS_SESSION_ID = "splunk.rum.previous_session_id"
        static let SPLUNK_RUM_VERSION = "splunk.rumVersion"
    }
    
}
