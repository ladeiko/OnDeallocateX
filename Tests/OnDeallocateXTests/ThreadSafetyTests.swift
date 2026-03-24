import XCTest
@testable import OnDeallocateX

/// Comprehensive thread safety tests for OnDeallocateX
final class ThreadSafetyTests: XCTestCase {
    
    class TestObject: NSObject {}
    
    // MARK: - Concurrent Observer Addition
    
    func testConcurrentAdditionFromMultipleThreads() {
        let object = TestObject()
        let expectation = XCTestExpectation(description: "All observers added")
        expectation.expectedFulfillmentCount = 1000
        
        // Add observers from multiple threads simultaneously
        for _ in 0..<10 {
            DispatchQueue.global().async {
                for _ in 0..<100 {
                    object.onWillDeallocate {
                        // Empty callback
                    }
                }
            }
        }
        
        // Wait a bit for all additions to complete
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            autoreleasepool {
                _ = object.description
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testConcurrentAdditionAndDeallocation() {
        let expectation = XCTestExpectation(description: "No crashes during concurrent operations")
        expectation.expectedFulfillmentCount = 100
        
        for _ in 0..<100 {
            DispatchQueue.global().async {
                autoreleasepool {
                    let object = TestObject()
                    
                    // Add observers from multiple threads
                    DispatchQueue.concurrentPerform(iterations: 10) { _ in
                        object.onWillDeallocate {
                            // Empty callback
                        }
                    }
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Concurrent Observer Removal
    
    func testConcurrentRemoval() {
        let object = TestObject()
        var keys: [String] = []
        let keysLock = NSLock()
        
        // Add many observers
        for _ in 0..<100 {
            let key = object.onWillDeallocate { }
            keysLock.lock()
            keys.append(key)
            keysLock.unlock()
        }
        
        // Remove them concurrently
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            keysLock.lock()
            let key = keys[index]
            keysLock.unlock()
            
            object.removeOnDeallocate(forKey: key)
        }
        
        // Test passes if no crash
        XCTAssert(true)
    }
    
    func testConcurrentAdditionAndRemoval() {
        let object = TestObject()
        let iterations = 1000
        
        DispatchQueue.concurrentPerform(iterations: iterations) { index in
            if index % 2 == 0 {
                // Add observer
                let key = object.onWillDeallocate { }
                
                // Immediately try to remove it
                DispatchQueue.global().async {
                    object.removeOnDeallocate(forKey: key)
                }
            } else {
                // Try to remove random key
                object.removeOnDeallocate(forKey: UUID().uuidString)
            }
        }
        
        // Test passes if no crash
        XCTAssert(true)
    }
    
    // MARK: - Race Conditions
    
    func testRaceConditionBetweenAddAndDeallocate() {
        let expectation = XCTestExpectation(description: "No race condition")
        expectation.expectedFulfillmentCount = 100
        
        for _ in 0..<100 {
            DispatchQueue.global().async {
                autoreleasepool {
                    let object = TestObject()
                    
                    // Thread 1: Add observer
                    DispatchQueue.global().async {
                        object.onWillDeallocate {
                            // May or may not execute depending on timing
                        }
                    }
                    
                    // Thread 2: Access object
                    DispatchQueue.global().async {
                        _ = object.description
                    }
                    
                    // Object deallocates when autoreleasepool exits
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testRaceConditionBetweenRemoveAndDeallocate() {
        let expectation = XCTestExpectation(description: "No race condition")
        expectation.expectedFulfillmentCount = 100
        
        for _ in 0..<100 {
            autoreleasepool {
                let object = TestObject()
                let key = object.onWillDeallocate { }
                
                // Try to remove observer while object is deallocating
                DispatchQueue.global().async {
                    object.removeOnDeallocate(forKey: key)
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Multiple Objects
    
    func testConcurrentOperationsOnMultipleObjects() {
        let objects = (0..<100).map { _ in TestObject() }
        let expectation = XCTestExpectation(description: "All operations complete")
        expectation.expectedFulfillmentCount = 100
        
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            let object = objects[index]
            
            // Perform various operations concurrently
            DispatchQueue.global().async {
                object.onWillDeallocate { }
            }
            
            DispatchQueue.global().async {
                _ = object.description
            }
            
            DispatchQueue.global().async {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testStressTestManyObjectsConcurrently() {
        let expectation = XCTestExpectation(description: "Stress test complete")
        expectation.expectedFulfillmentCount = 1000
        
        for _ in 0..<1000 {
            DispatchQueue.global().async {
                autoreleasepool {
                    let object = TestObject()
                    
                    // Add multiple observers from different threads
                    for _ in 0..<5 {
                        DispatchQueue.global().async {
                            object.onWillDeallocate {
                                // Empty callback
                            }
                        }
                    }
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Queue Safety
    
    func testSafetyWithDifferentQueueTypes() {
        let mainQueue = DispatchQueue.main
        let globalQueue = DispatchQueue.global()
        let customSerial = DispatchQueue(label: "custom.serial")
        let customConcurrent = DispatchQueue(label: "custom.concurrent", attributes: .concurrent)
        
        let expectation = XCTestExpectation(description: "All queues safe")
        expectation.expectedFulfillmentCount = 4
        
        autoreleasepool {
            let object = TestObject()
            
            object.onWillDeallocate({
                expectation.fulfill()
            }, in: mainQueue)
            
            object.onWillDeallocate({
                expectation.fulfill()
            }, in: globalQueue)
            
            object.onWillDeallocate({
                expectation.fulfill()
            }, in: customSerial)
            
            object.onWillDeallocate({
                expectation.fulfill()
            }, in: customConcurrent)
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Data Race Detection
    
    func testNoDataRaceInAssociatedObjects() {
        let object = TestObject()
        
        // Simultaneously add and access associated objects
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            if index % 2 == 0 {
                object.onWillDeallocate { }
            } else {
                _ = object.description
            }
        }
        
        // Test passes if no crash or data corruption
        XCTAssert(true)
    }
    
    func testNoDataRaceInSwizzling() {
        // Create many objects of the same class simultaneously
        // This tests that swizzling (which happens once per class) is thread-safe
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            let object = TestObject()
            object.onWillDeallocate { }
        }
        
        // Test passes if no crash
        XCTAssert(true)
    }
    
    // MARK: - Async Callback Thread Safety
    
    func testAsyncCallbackThreadSafety() {
        let expectation = XCTestExpectation(description: "Async callbacks thread-safe")
        expectation.expectedFulfillmentCount = 100
        
        for _ in 0..<100 {
            autoreleasepool {
                let object = TestObject()
                
                object.onWillDeallocateAsync { completion in
                    // Simulate async work on different thread
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
                        completion()
                        expectation.fulfill()
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testConcurrentAsyncCallbacks() {
        let expectation = XCTestExpectation(description: "Concurrent async callbacks")
        expectation.expectedFulfillmentCount = 10
        
        autoreleasepool {
            let object = TestObject()
            
            for _ in 0..<10 {
                object.onWillDeallocateAsync { completion in
                    DispatchQueue.global().async {
                        Thread.sleep(forTimeInterval: 0.01)
                        completion()
                        expectation.fulfill()
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
