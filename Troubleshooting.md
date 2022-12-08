
# Troubleshooting 

## Swift Static Libraries

Up until Xcode 9, support for building Swift into static libraries was non-existent and use of dynamic frameworks was required.With CocoaPods 1.5.0, developers are no longer restricted into specifying use_frameworks! in their Podfile in order to install pods that use Swift. Interop with Objective-C should just work. However, if your Swift pod depends on an Objective-C, pod you will need to enable "modular headers" for that Objective-C pod.

## Modular Headers

if Swift pod depends on an Objective-C framework, a pod file needs to enable "modular headers" for that Objective-C pod
There are multiple ways we can use modular headers based on project requirements.

1.Comment use_frameworks! and add use_modular_headers!  in pod file

2.In most cases for a small project it will be enough to add use_modular_headers! instead of the removed use_frameworks! Alternatively, you can try adding:modular_headers => true after each pod declaration of a "missing" module But the bigger project might contain modules that just don't want to be static, with or without modular headers.
Ex:- pod 'ABCD', '~> 1.0.7.5', :modular_headers => true

3.use_frameworks! :linkage => :static which will generate full frameworks with statically linked libraries and module map files.


