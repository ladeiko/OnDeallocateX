import XCTest
@testable import OnDeallocateX

/// Edge case and corner case tests for OnDeallocateX
final class EdgeCaseTests: XCTestCase {
    
    class TestObject: NSObject {}
    
    class TestObjectWithProperties: NSObject {
        var stringValue: String = ""
        var intValue: Int = 0
        var closure: (() -> Void)?
    }
    
    // MARK: - Retain Cycle Edge Cases
    
    func testNoRetainCycleWithUnownedCapture() {
        let expectation = XCTestExpectation(description: "Object deallocates with unowned")
        
        autoreleasepool {
            let object = TestObject()
            let helper = TestObject()
            
            object.onWillDeallocate { [weak helper] in
                _ = helper?.description ?? ""
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testWeakCaptureBecomesNil() {
        let expectation = XCTestExpectation(description: "Weak reference becomes nil")
        var weakObject: TestObject?
        
        autoreleasepool {
            let object = TestObject()
            weakObject = object
            
            object.onWillDeallocate { [weak object] in
                // At this point, weak reference might be nil
                // depending on exact timing
                expectation.fulfill()
            }
        }
        
        XCTAssertNil(weakObject, "Weak reference should be nil after deallocation")
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Immediate Deallocation
    
    func testObserverOnImmediatelyDeallocatedObject() {
        let expectation = XCTestExpectation(description: "Immediate deallocation callback")
        
        TestObject().onWillDeallocate {
            expectation.fulfill()
        }
        // Object deallocates immediately
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMultipleObserversOnImmediatelyDeallocatedObject() {
        let expectation1 = XCTestExpectation(description: "Callback 1")
        let expectation2 = XCTestExpectation(description: "Callback 2")
        let expectation3 = XCTestExpectation(description: "Callback 3")
        
        let object = TestObject()
        object.onWillDeallocate { expectation1.fulfill() }
        object.onWillDeallocate { expectation2.fulfill() }
        object.onWillDeallocate { expectation3.fulfill() }
        // Object deallocates at end of scope
        
        wait(for: [expectation1, expectation2, expectation3], timeout: 1.0)
    }
    
    // MARK: - Nested Autoreleasepool
    
    func testNestedAutoreleasepool() {
        let expectation = XCTestExpectation(description: "Nested autoreleasepool")
        
        autoreleasepool {
            autoreleasepool {
                let object = TestObject()
                object.onWillDeallocate {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testObjectPassedBetweenAutoreleasepool() {
        let expectation = XCTestExpectation(description: "Object passed between pools")
        var strongRef: TestObject?
        
        autoreleasepool {
            let object = TestObject()
            strongRef = object
            object.onWillDeallocate {
                expectation.fulfill()
            }
        }
        
        // Object still alive due to strong reference
        XCTAssertNotNil(strongRef)
        
        // Now deallocate
        strongRef = nil
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Callback Complexity
    
    func testCallbackThatCreatesNewObserver() {
        let expectation1 = XCTestExpectation(description: "First callback")
        let expectation2 = XCTestExpectation(description: "Second object callback")
        
        autoreleasepool {
            let object1 = TestObject()
            
            object1.onWillDeallocate {
                expectation1.fulfill()
                
                // Create new object with observer inside callback
                autoreleasepool {
                    let object2 = TestObject()
                    object2.onWillDeallocate {
                        expectation2.fulfill()
                    }
                }
            }
        }
        
        wait(for: [expectation1, expectation2], timeout: 2.0)
    }
    
    func testCallbackThatAccessesMultipleObjects() {
        let expectation = XCTestExpectation(description: "Multiple object access")
        
        let helper1 = TestObject()
        let helper2 = TestObject()
        let helper3 = TestObject()
        
        autoreleasepool {
            let object = TestObject()
            
            object.onWillDeallocate { [weak helper1, weak helper2, weak helper3] in
                _ = helper1?.description
                _ = helper2?.description
                _ = helper3?.description
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Observer Removal Edge Cases
    
    func testRemoveObserverImmediatelyAfterAdding() {
        let expectation = XCTestExpectation(description: "Observer not called")
        expectation.isInverted = true
        
        autoreleasepool {
            let object = TestObject()
            
            let key = object.onWillDeallocate {
                expectation.fulfill()
            }
            
            // Immediately remove it
            object.removeOnDeallocate(forKey: key)
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testRemoveSameKeyMultipleTimes() {
        let object = TestObject()
        let key = object.onWillDeallocate { }
        
        // Remove multiple times - should not crash
        object.removeOnDeallocate(forKey: key)
        object.removeOnDeallocate(forKey: key)
        object.removeOnDeallocate(forKey: key)
        
        XCTAssert(true, "Multiple removals should be safe")
    }
    
    func testRemoveObserverFromInsideCallback() {
        let expectation1 = XCTestExpectation(description: "Callback 1")
        let expectation2 = XCTestExpectation(description: "Callback 2 - should still execute")
        
        autoreleasepool {
            let object = TestObject()
            
            let key2 = object.onWillDeallocate {
                expectation2.fulfill()
            }
            
            object.onWillDeallocate {
                expectation1.fulfill()
                // Try to remove other observer from inside callback
                object.removeOnDeallocate(forKey: key2)
            }
        }
        
        // Note: This behavior depends on implementation details
        wait(for: [expectation1, expectation2], timeout: 1.0)
    }
    
    // MARK: - Class Hierarchy Edge Cases
    
    func testSubclassObserver() {
        class SubObject: TestObject {}
        
        let expectation = XCTestExpectation(description: "Subclass observer")
        
        autoreleasepool {
            let object = SubObject()
            object.onWillDeallocate {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMultipleLevelsOfSubclassing() {
        class Level1: TestObject {}
        class Level2: Level1 {}
        class Level3: Level2 {}
        
        let expectation = XCTestExpectation(description: "Deep subclass observer")
        
        autoreleasepool {
            let object = Level3()
            object.onWillDeallocate {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testDifferentSubclassesSeparately() {
        class SubA: TestObject {}
        class SubB: TestObject {}
        
        let expectationA = XCTestExpectation(description: "SubA observer")
        let expectationB = XCTestExpectation(description: "SubB observer")
        
        do {
            let objA = SubA()
            let objB = SubB()
            
            objA.onWillDeallocate {
                expectationA.fulfill()
            }
            
            objB.onWillDeallocate {
                expectationB.fulfill()
            }
        }
        
        wait(for: [expectationA, expectationB], timeout: 1.0)
    }
    
    // MARK: - Async Edge Cases
    
    func testAsyncCallbackNeverCallsCompletion() {
        // This test verifies that object doesn't deallocate if completion not called
        let expectation = XCTestExpectation(description: "Timeout - object should not deallocate")
        expectation.isInverted = true
        
        var strongRef: TestObject?
        
        autoreleasepool {
            let object = TestObject()
            strongRef = object // Keep it alive artificially
            
            object.onWillDeallocateAsync { completion in
                // Never call completion()
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Clean up
        strongRef = nil
    }
    
    func testAsyncCallbackCallsCompletionMultipleTimes() {
        let expectation = XCTestExpectation(description: "Async callback complete")
        
        autoreleasepool {
            let object = TestObject()
            
            object.onWillDeallocateAsync { completion in
                completion()
                completion() // Call multiple times - should be safe
                completion()
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMixedSyncAndAsyncCallbacks() {
        let expectation1 = XCTestExpectation(description: "Sync callback")
        let expectation2 = XCTestExpectation(description: "Async callback")
        let expectation3 = XCTestExpectation(description: "Sync callback 2")
        
        autoreleasepool {
            let object = TestObject()
            
            object.onWillDeallocate {
                expectation1.fulfill()
            }
            
            object.onWillDeallocateAsync { completion in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    expectation2.fulfill()
                    completion()
                }
            }
            
            object.onWillDeallocate {
                expectation3.fulfill()
            }
        }
        
        wait(for: [expectation1, expectation2, expectation3], timeout: 2.0)
    }
    
    // MARK: - Object Properties Edge Cases
    
    func testObjectWithComplexProperties() {
        let expectation = XCTestExpectation(description: "Complex object deallocates")
        
        autoreleasepool {
            let object = TestObjectWithProperties()
            object.stringValue = String(repeating: "a", count: 10000)
            object.intValue = 42
            object.closure = {
                print("Closure executed")
            }
            
            object.onWillDeallocate {
                XCTAssertEqual(object.stringValue.count, 10000)
                XCTAssertEqual(object.intValue, 42)
                XCTAssertNotNil(object.closure)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Empty or Nil Cases
    
    func testMultipleEmptyCallbacks() {
        let expectation = XCTestExpectation(description: "Empty callbacks")
        expectation.expectedFulfillmentCount = 5
        
        autoreleasepool {
            let object = TestObject()
            
            for _ in 0..<5 {
                object.onWillDeallocate {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Stress Edge Cases
    
    func testRapidAddRemoveCycle() {
        let object = TestObject()
        
        for _ in 0..<1000 {
            let key = object.onWillDeallocate { }
            object.removeOnDeallocate(forKey: key)
        }
        
        // Test passes if no crash
        XCTAssert(true)
    }
    
    func testAlternatingAddRemove() {
        let object = TestObject()
        var keys: [String] = []
        
        for i in 0..<100 {
            if i % 2 == 0 {
                let key = object.onWillDeallocate { }
                keys.append(key)
            } else if !keys.isEmpty {
                object.removeOnDeallocate(forKey: keys.removeLast())
            }
        }
        
        // Test passes if no crash
        XCTAssert(true)
    }
}
