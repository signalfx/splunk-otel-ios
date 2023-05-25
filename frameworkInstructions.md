# How to Build an XCFramework

If you would like to import Splunk Otel as a framework into your project, follow these steps:

## 1. Ensure the correct build settings.

Clone the splunk-otel-ios repo onto your local environment and open the SplunkRumWorkspace.xcworkspace file in XCode. Navigate to the Build Settings tab on the SplunkOtel target and ensure the following two settings are set:
* Skip Install: No
* Build Libraries for Distribution: Yes

## 2. Make Archives

Open the terminal and navigate to the SplunkRumWorkspace/SplunkRum directory. You should be in the same directory as the SplunkRum.xcodeproj file. Paste the following code into the terminal.

    xcodebuild archive -project SplunkRum.xcodeproj -scheme SplunkOtel -destination "generic/platform=iOS" -archivePath "archives/SplunkRum-iOS"

This should create a new archives directory with the file `SplunkRum-iOS.xcarchive` inside it.

Now repeat the process for the simulator platform:

    xcodebuild archive -project SplunkRum.xcodeproj -scheme SplunkOtel -destination "generic/platform=iOS Simulator" -archivePath "archives/SplunkRum-iOS_Simulator"
    
## 3. Make XCFramework

Paste the following code into the terminal:

    xcodebuild -create-xcframework -archive archives/SplunkRum-iOS.xcarchive -framework SplunkOtel.framework -archive archives/SplunkRum-iOS_Simulator.xcarchive -framework SplunkOtel.framework -output xcframeworks/SplunkOtel.xcframework

This will create a new xcframeworks directory with the SplunkOtel.xcframework file inside of it.

## 4. Importing the XCFramework into your project

Open your project in XCode and drag and drop the SplunkOtel.xcframework into the project navigator. This should automatically import the framework. 
