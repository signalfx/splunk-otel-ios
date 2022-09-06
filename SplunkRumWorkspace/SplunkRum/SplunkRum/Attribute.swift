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

    enum Attribute {

       static let DEPLOYMENT_ENVIRONMENT      = "environment"
       static let COMPONENT_KEY               = "component"
       static let SCREEN_NAME_KEY             = "screen.name"
       static let LAST_SCREEN_NAME_KEY        = "last.screen.name"
       static let ERROR_TYPE_KEY              = "exception.type"
       static let LOCATION_LATITUDE_KEY       = "location.lat"
       static let LOCATION_LONGITUDE_KEY      = "location.long"
       static let ERROR_MESSAGE_KEY           = "exception.message"
       static let ERROR_STACKTRACE_KEY        = "exception.stacktrace"
       static let RUM_TRACER_NAME             = "SplunkRum"

        static let LINK_TRACE_ID_KEY          = "link.traceId"
        static let LINK_SPAN_ID_KEY           = "link.spanId"

       static let COMPONENT_APP_START         = "appstart"
       static let COMPONENT_CRASH             = "crash"
       static let COMPONENT_ERROR             = "error"
       static let COMPONENT_UI                = "ui"
       static let COMPONENT_APP_LIFECYCLE     = "app-lifecycle"
       static let COMPONENT_UNKNOWN           = "unknown"
       static let COMPONENT_HTTP              = "http"

       static let SPAN_NAME_PRESENTATION_TRANSITION  = "PresentationTransition"
       static let SPAN_NAME_APP_TERMINATING          = "AppTerminating"
       static let SPAN_NAME_APP_RESIGNACTIVE         = "ResignActive"
       static let SPAN_NAME_APP_ENTERFOREGROUND      = "EnterForeground"
       static let SPAN_NAME_SCREEN_NAME_CHANGE       = "screen name change"
       static let SPAN_NAME_APP_START                = "AppStart"
       static let SPAN_NAME_SESSIONID_CHANGE         = "sessionId.change"
       static let SPAN_NAME_SHOWVC                   = "ShowVC"
       static let SPAN_NAME_ACTION                   = "action"
       static let SPAN_NAME_SPLUNKRUM_INITIALIZE     = "SplunkRum.initialize"
       static let SPAN_NAME_MANUAL_SPAN              = "manualSpan"
       static let SPAN_NAME_SLOWRENDERS              = "slowRenders"
       static let SPAN_NAME_FROZENRENDERS            = "frozenRenders"

    }
