//
/*
Copyright 2025 Splunk Inc.

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

@interface API10AttributeValueObjCTests : XCTestCase

// MARK: - Constants

@property (nonatomic, readonly) BOOL sampleBool;
@property (nonatomic, readonly) double sampleDouble;
@property (nonatomic, readonly) NSInteger sampleInteger;
@property (nonatomic, readonly) NSString *sampleString;

@end


@implementation API10AttributeValueObjCTests

// MARK: - Constants

- (BOOL)sampleBool {
    return NO;
}

- (double)sampleDouble {
    return 1.0;
}

- (NSInteger)sampleInteger {
    return -1;
}

- (NSString *)sampleString {
    return @"Test";
}


// MARK: - API Tests

- (void)testInitialization {
    // Initialization with native types
    SPLKAttributeValue *boolAttribute = [[SPLKAttributeValue alloc] initWithBool:self.sampleBool];
    SPLKAttributeValue *doubleAttribute = [[SPLKAttributeValue alloc] initWithDouble:self.sampleDouble];
    SPLKAttributeValue *integerAttribute = [[SPLKAttributeValue alloc] initWithInteger:self.sampleInteger];
    SPLKAttributeValue *stringAttribute = [[SPLKAttributeValue alloc] initWithString:self.sampleString];

    // Initialization with encapsulation into NSNumber
    NSNumber *boolNumber = [NSNumber numberWithBool:self.sampleBool];
    SPLKAttributeValue *boolNumberAttribute = [[SPLKAttributeValue alloc] initWithBoolNumber:boolNumber];

    NSNumber *doubleNumber = [NSNumber numberWithDouble:self.sampleDouble];
    SPLKAttributeValue *doubleNumberAttribute = [[SPLKAttributeValue alloc] initWithDoubleNumber:doubleNumber];

    NSNumber *integerNumber = [NSNumber numberWithInteger:self.sampleInteger];
    SPLKAttributeValue *integerNumberAttribute = [[SPLKAttributeValue alloc] initWithIntegerNumber:integerNumber];


    XCTAssertNotNil(boolAttribute);
    XCTAssertNotNil(doubleAttribute);
    XCTAssertNotNil(integerAttribute);
    XCTAssertNotNil(stringAttribute);

    XCTAssertNotNil(boolNumberAttribute);
    XCTAssertNotNil(doubleNumberAttribute);
    XCTAssertNotNil(integerNumberAttribute);
}

- (void)testFactoryMethods {
    SPLKAttributeValue *boolAttribute = [SPLKAttributeValue attributeWithBool:self.sampleBool];
    SPLKAttributeValue *doubleAttribute = [SPLKAttributeValue attributeWithDouble:self.sampleDouble];
    SPLKAttributeValue *integerAttribute = [SPLKAttributeValue attributeWithInteger:self.sampleInteger];
    SPLKAttributeValue *stringAttribute = [SPLKAttributeValue attributeWithString:self.sampleString];

    BOOL storedBool = boolAttribute.asBoolNumber.boolValue;
    double storedDouble = doubleAttribute.asDoubleNumber.doubleValue;
    NSInteger storedInteger = integerAttribute.asIntegerNumber.integerValue;
    NSString *storedString = stringAttribute.asString;


    XCTAssertEqual(storedBool, self.sampleBool);
    XCTAssertEqual(boolAttribute.type, SPLKAttributeValueTypeBool);

    XCTAssertEqual(storedDouble, self.sampleDouble);
    XCTAssertEqual(doubleAttribute.type, SPLKAttributeValueTypeDouble);

    XCTAssertEqual(storedInteger, self.sampleInteger);
    XCTAssertEqual(integerAttribute.type, SPLKAttributeValueTypeInteger);

    XCTAssertTrue([storedString isEqualToString:self.sampleString]);
    XCTAssertEqual(stringAttribute.type, SPLKAttributeValueTypeString);
}

- (void)testBoolTypedGetters {
    SPLKAttributeValue *boolAttribute = [[SPLKAttributeValue alloc] initWithBool:self.sampleBool];

    // Access using getter for stored type
    NSNumber *storedBoolNumber = boolAttribute.asBoolNumber;
    BOOL storedBool = storedBoolNumber.boolValue;
    SPLKAttributeValueType storedType = boolAttribute.type;

    // Access using non-compatible getters should return `nil`
    NSNumber *storedDoubleNumber = boolAttribute.asDoubleNumber;
    NSNumber *storedIntegerNumber = boolAttribute.asIntegerNumber;
    NSString *storedString = boolAttribute.asString;


    XCTAssertNotNil(storedBoolNumber);
    XCTAssertEqual(storedBool, self.sampleBool);
    XCTAssertEqual(storedType, SPLKAttributeValueTypeBool);

    XCTAssertNil(storedDoubleNumber);
    XCTAssertNil(storedIntegerNumber);
    XCTAssertNil(storedString);
}

- (void)testDoubleTypedGetters {
    SPLKAttributeValue *doubleAttribute = [[SPLKAttributeValue alloc] initWithDouble:self.sampleDouble];

    // Access using getter for stored type
    NSNumber *storedDoubleNumber = doubleAttribute.asDoubleNumber;
    double storedDouble = storedDoubleNumber.doubleValue;
    SPLKAttributeValueType storedType = doubleAttribute.type;

    // Access using non-compatible getters should return `nil`
    NSNumber *storedBoolNumber = doubleAttribute.asBoolNumber;
    NSNumber *storedIntegerNumber = doubleAttribute.asIntegerNumber;
    NSString *storedString = doubleAttribute.asString;


    XCTAssertNotNil(storedDoubleNumber);
    XCTAssertEqual(storedDouble, self.sampleDouble);
    XCTAssertEqual(storedType, SPLKAttributeValueTypeDouble);

    XCTAssertNil(storedBoolNumber);
    XCTAssertNil(storedIntegerNumber);
    XCTAssertNil(storedString);
}

- (void)testIntegerTypedGetters {
    SPLKAttributeValue *integerAttribute = [[SPLKAttributeValue alloc] initWithInteger:self.sampleInteger];

    // Access using getter for stored type
    NSNumber *storedIntegerNumber = integerAttribute.asIntegerNumber;
    NSInteger storedInteger = storedIntegerNumber.integerValue;
    SPLKAttributeValueType storedType = integerAttribute.type;

    // Access using non-compatible getters should return `nil`
    NSNumber *storedBoolNumber = integerAttribute.asBoolNumber;
    NSNumber *storedDoubleNumber = integerAttribute.asDoubleNumber;
    NSString *storedString = integerAttribute.asString;


    XCTAssertNotNil(storedIntegerNumber);
    XCTAssertEqual(storedInteger, self.sampleInteger);
    XCTAssertEqual(storedType, SPLKAttributeValueTypeInteger);

    XCTAssertNil(storedBoolNumber);
    XCTAssertNil(storedDoubleNumber);
    XCTAssertNil(storedString);
}

- (void)testStringTypedGetters {
    SPLKAttributeValue *stringAttribute = [[SPLKAttributeValue alloc] initWithString:self.sampleString];

    // Access using getter for stored type
    NSString *storedString = stringAttribute.asString;
    SPLKAttributeValueType storedType = stringAttribute.type;

    // Access using non-compatible getters should return `nil`
    NSNumber *storedBoolNumber = stringAttribute.asBoolNumber;
    NSNumber *storedDoubleNumber = stringAttribute.asDoubleNumber;
    NSNumber *storedIntegerNumber = stringAttribute.asIntegerNumber;


    XCTAssertNotNil(storedString);
    XCTAssertTrue([storedString isEqualToString:self.sampleString]);
    XCTAssertEqual(storedType, SPLKAttributeValueTypeString);

    XCTAssertNil(storedBoolNumber);
    XCTAssertNil(storedDoubleNumber);
    XCTAssertNil(storedIntegerNumber);
}

- (void)testAttributeValueDescriptions {
    SPLKAttributeValue *boolAttribute = [[SPLKAttributeValue alloc] initWithBool:self.sampleBool];
    SPLKAttributeValue *doubleAttribute = [[SPLKAttributeValue alloc] initWithDouble:self.sampleDouble];
    SPLKAttributeValue *integerAttribute = [[SPLKAttributeValue alloc] initWithInteger:self.sampleInteger];
    SPLKAttributeValue *stringAttribute = [[SPLKAttributeValue alloc] initWithString:self.sampleString];

    XCTAssertNotNil(boolAttribute.description);
    XCTAssertNotNil(doubleAttribute.description);
    XCTAssertNotNil(integerAttribute.description);
    XCTAssertNotNil(stringAttribute.description);

    XCTAssertNotNil(boolAttribute.debugDescription);
    XCTAssertNotNil(doubleAttribute.debugDescription);
    XCTAssertNotNil(integerAttribute.debugDescription);
    XCTAssertNotNil(stringAttribute.debugDescription);

    XCTAssertTrue([boolAttribute.description isEqualToString:@"false"]);
    XCTAssertTrue([boolAttribute.debugDescription isEqualToString:@"SPLKAttributeValue<BOOL>: false"]);
}

@end
