# How to build an XCFramework

If you want to import Splunk Otel as a framework into your project, follow these steps:

## 1. Check build settings

Clone the `splunk-otel-ios` repo and open the `SplunkRumWorkspace.xcworkspace` file in Xcode. Navigate to the **Build Settings** tab on the `SplunkOtel` target and make sure the following settings are present:

* Skip Install: No
* Build Libraries for Distribution: Yes

## 2. Make archives

Open the terminal and navigate to the directory where the `SplunkRum.xcodeproj` file is located, for example `SplunkRumWorkspace/SplunkRum`. 

Run the following command to create a new archives directory with the file `SplunkRum-iOS.xcarchive` inside:

```bash
    xcodebuild archive -project SplunkRum.xcodeproj -scheme SplunkOtel -destination "generic/platform=iOS" -archivePath "archives/SplunkRum-iOS"
```

Repeat the process for the simulator platform:

```bash
    xcodebuild archive -project SplunkRum.xcodeproj -scheme SplunkOtel -destination "generic/platform=iOS Simulator" -archivePath "archives/SplunkRum-iOS_Simulator"
```
    
## 3. Make XCFramework

Run the following command to create a new archives directory with the file `SplunkRum-iOS.xcarchive`:

    xcodebuild -create-xcframework -archive archives/SplunkRum-iOS.xcarchive -framework SplunkOtel.framework -archive archives/SplunkRum-iOS_Simulator.xcarchive -framework SplunkOtel.framework -output xcframeworks/SplunkOtel.xcframework

This will create a new xcframeworks directory with the SplunkOtel.xcframework file inside of it.

## 4. Importing the XCFramework into your project

Open your project in XCode and drag and drop the SplunkOtel.xcframework into the project navigator. This should automatically import the framework. 
