//
/*
Copyright 2026 Splunk Inc.

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

#import <XCTest/XCTest.h>

@import SplunkAgentObjC;


// MARK: - Test processor that renames screens

@interface PrefixingProcessor : NSObject <SPLKNavigationEventProcessor>

@property (nonatomic, copy) NSString *prefix;

@end


@implementation PrefixingProcessor

- (instancetype)initWithPrefix:(NSString *)prefix {
    self = [super init];
    if (self) {
        _prefix = [prefix copy];
    }
    return self;
}

- (SPLKNavigationEvent * _Nullable)onViewControllerWithTypeName:(NSString *)typeName
                                             controllerIdentity:(NSString *)controllerIdentity {
    NSString *name = [NSString stringWithFormat:@"%@/%@", self.prefix, typeName];
    return [[SPLKNavigationEvent alloc] initWithName:name
                                  controllerIdentity:controllerIdentity
                                          attributes:nil];
}

@end


// MARK: - Test processor that suppresses all events

@interface SuppressingProcessor : NSObject <SPLKNavigationEventProcessor>

@end


@implementation SuppressingProcessor

- (SPLKNavigationEvent * _Nullable)onViewControllerWithTypeName:(NSString *)typeName
                                             controllerIdentity:(NSString *)controllerIdentity {
    return nil;
}

@end


// MARK: - Tests

@interface NavigationAPI10EventProcessorObjCTests : XCTestCase

@end


@implementation NavigationAPI10EventProcessorObjCTests

// MARK: - NavigationEvent Tests

- (void)testNavigationEventInitialization {
    SPLKNavigationEvent *event = [[SPLKNavigationEvent alloc] initWithName:@"HomeScreen"
                                                        controllerIdentity:@"0x12345"
                                                                attributes:nil];

    XCTAssertNotNil(event);
    XCTAssertEqualObjects(event.name, @"HomeScreen");
    XCTAssertEqualObjects(event.controllerIdentity, @"0x12345");
    XCTAssertNil(event.attributes);
}

- (void)testNavigationEventWithAttributes {
    NSDictionary *attributes = @{@"app.section": @"settings", @"app.level": @42};

    SPLKNavigationEvent *event = [[SPLKNavigationEvent alloc] initWithName:@"SettingsScreen"
                                                        controllerIdentity:@"0xABCDE"
                                                                attributes:attributes];

    XCTAssertNotNil(event);
    XCTAssertEqualObjects(event.name, @"SettingsScreen");
    XCTAssertEqualObjects(event.controllerIdentity, @"0xABCDE");
    XCTAssertNotNil(event.attributes);
    XCTAssertEqualObjects(event.attributes[@"app.section"], @"settings");
    XCTAssertEqualObjects(event.attributes[@"app.level"], @42);
}


// MARK: - DefaultNavigationEventProcessor Tests

- (void)testDefaultProcessorInitialization {
    SPLKDefaultNavigationEventProcessor *processor = [[SPLKDefaultNavigationEventProcessor alloc] init];
    XCTAssertNotNil(processor);
}

- (void)testDefaultProcessorPassesThrough {
    SPLKDefaultNavigationEventProcessor *processor = [[SPLKDefaultNavigationEventProcessor alloc] init];

    SPLKNavigationEvent *event = [processor onViewControllerWithTypeName:@"DetailViewController"
                                                     controllerIdentity:@"0x99999"];

    XCTAssertNotNil(event);
    XCTAssertEqualObjects(event.name, @"DetailViewController");
    XCTAssertEqualObjects(event.controllerIdentity, @"0x99999");
    XCTAssertNil(event.attributes);
}


// MARK: - Custom Processor Tests

- (void)testCustomProcessorRenames {
    PrefixingProcessor *processor = [[PrefixingProcessor alloc] initWithPrefix:@"MyApp"];

    SPLKNavigationEvent *event = [processor onViewControllerWithTypeName:@"HomeVC"
                                                     controllerIdentity:@"0x11111"];

    XCTAssertNotNil(event);
    XCTAssertEqualObjects(event.name, @"MyApp/HomeVC");
    XCTAssertEqualObjects(event.controllerIdentity, @"0x11111");
}

- (void)testCustomProcessorSuppresses {
    SuppressingProcessor *processor = [[SuppressingProcessor alloc] init];

    SPLKNavigationEvent *event = [processor onViewControllerWithTypeName:@"InternalVC"
                                                     controllerIdentity:@"0x22222"];

    XCTAssertNil(event);
}


// MARK: - Configuration Integration Tests

- (void)testConfigurationWithCustomProcessor {
    PrefixingProcessor *processor = [[PrefixingProcessor alloc] initWithPrefix:@"App"];

    SPLKNavigationConfiguration *config = [[SPLKNavigationConfiguration alloc] initWithEnabled:YES
                                                                            automatedTracking:YES
                                                                     navigationEventProcessor:processor];

    XCTAssertNotNil(config);
    XCTAssertTrue(config.isEnabled);
    XCTAssertTrue(config.enableAutomatedTracking);
    XCTAssertNotNil(config.navigationEventProcessor);
}

- (void)testConfigurationWithNilProcessor {
    SPLKNavigationConfiguration *config = [[SPLKNavigationConfiguration alloc] initWithEnabled:YES
                                                                            automatedTracking:YES
                                                                     navigationEventProcessor:nil];

    XCTAssertNotNil(config);
    XCTAssertNil(config.navigationEventProcessor);
}

@end
