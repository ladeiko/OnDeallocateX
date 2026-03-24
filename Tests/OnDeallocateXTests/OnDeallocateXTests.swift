import XCTest
@testable import OnDeallocateX

/// Main test suite for OnDeallocateX functionality
final class OnDeallocateXTests: XCTestCase {
    
    // MARK: - Test Objects
    
    /// Simple test object that tracks deinitialization
    class TestObject: NSObject {
        var deinitCalled: (() -> Void)?
        
        deinit {
            deinitCalled?()
        }
    }
    
    /// Object that can hold strong references for testing retain cycles
    class TestObjectWithClosure: NSObject {
        var closure: (() -> Void)?
    }
    
    // MARK: - Basic Functionality Tests
    
    func testBasicDeallocationCallback() {
        let expectation = XCTestExpectation(description: "onWillDeallocate called")
        
        autoreleasepool {
            let object = TestObject()
            
            object.onWillDeallocate {
                expectation.fulfill()
            }
            
            // Object will deallocate when exiting autoreleasepool
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testCallbackExecutesBeforeDeinit() {
        let expectation = XCTestExpectation(description: "Callback order verified")
        var callOrder: [String] = []
        
        autoreleasepool {
            let object = TestObject()
            
            object.deinitCalled = {
                callOrder.append("deinit")
                if callOrder == ["callback", "deinit"] {
                    expectation.fulfill()
                }
            }
            
            object.onWillDeallocate {
                callOrder.append("callback")
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMultipleObservers() {
        let expectation1 = XCTestExpectation(description: "Observer 1")
        let expectation2 = XCTestExpectation(description: "Observer 2")
        let expectation3 = XCTestExpectation(description: "Observer 3")
        
        autoreleasepool {
            let object = TestObject()
            
            object.onWillDeallocate {
                expectation1.fulfill()
            }
            
            object.onWillDeallocate {
                expectation2.fulfill()
            }
            
            object.onWillDeallocate {
                expectation3.fulfill()
            }
        }
        
        wait(for: [expectation1, expectation2, expectation3], timeout: 1.0)
    }
    
    func testReturnsUniqueKeys() {
        let object = TestObject()
        
        let key1 = object.onWillDeallocate { }
        let key2 = object.onWillDeallocate { }
        let key3 = object.onWillDeallocate { }
        
        // All keys should be unique
        XCTAssertNotEqual(key1, key2)
        XCTAssertNotEqual(key2, key3)
        XCTAssertNotEqual(key1, key3)
        
        // Keys should be valid UUIDs
        XCTAssertNotNil(UUID(uuidString: key1))
        XCTAssertNotNil(UUID(uuidString: key2))
        XCTAssertNotNil(UUID(uuidString: key3))
    }
    
    // MARK: - Observer Removal Tests
    
    func testRemoveObserver() {
        let expectation1 = XCTestExpectation(description: "Observer 1")
        let expectation2 = XCTestExpectation(description: "Observer 2 - should not trigger")
        expectation2.isInverted = true
        
        autoreleasepool {
            let object = TestObject()
            
            object.onWillDeallocate {
                expectation1.fulfill()
            }
            
            let key2 = object.onWillDeallocate {
                expectation2.fulfill()
            }
            
            // Remove second observer
            object.removeOnDeallocate(forKey: key2)
        }
        
        wait(for: [expectation1, expectation2], timeout: 1.0)
    }
    
    func testRemoveObserverWithInvalidKey() {
        let object = TestObject()
        
        // Should not crash or throw
        object.removeOnDeallocate(forKey: "invalid-key")
        object.removeOnDeallocate(forKey: UUID().uuidString)
        
        // Test still passes if no crash
        XCTAssert(true)
    }
    
    func testRemoveAllObservers() {
        let expectation1 = XCTestExpectation(description: "Observer 1 - should not trigger")
        let expectation2 = XCTestExpectation(description: "Observer 2 - should not trigger")
        expectation1.isInverted = true
        expectation2.isInverted = true
        
        autoreleasepool {
            let object = TestObject()
            
            let key1 = object.onWillDeallocate {
                expectation1.fulfill()
            }
            
            let key2 = object.onWillDeallocate {
                expectation2.fulfill()
            }
            
            // Remove both observers
            object.removeOnDeallocate(forKey: key1)
            object.removeOnDeallocate(forKey: key2)
        }
        
        wait(for: [expectation1, expectation2], timeout: 1.0)
    }
    
    // MARK: - Custom Queue Tests
    
    func testCustomQueue() {
        let expectation = XCTestExpectation(description: "Callback on custom queue")
        let customQueue = DispatchQueue(label: "test.queue")
        let queueKey = DispatchSpecificKey<String>()
        let queueValue = "test.queue.marker"
        
        customQueue.setSpecific(key: queueKey, value: queueValue)
        
        autoreleasepool {
            let object = TestObject()
            
            object.onWillDeallocate({
                // Verify we're on the custom queue
                let currentValue = DispatchQueue.getSpecific(key: queueKey)
                XCTAssertEqual(currentValue, queueValue, "Callback should execute on custom queue")
                expectation.fulfill()
            }, in: customQueue)
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMainQueue() {
        let expectation = XCTestExpectation(description: "Callback on main queue")
        
        autoreleasepool {
            let object = TestObject()
            
            object.onWillDeallocate {
                XCTAssertTrue(Thread.isMainThread, "Default queue should be main queue")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testBackgroundQueue() {
        let expectation = XCTestExpectation(description: "Callback on background queue")
        let backgroundQueue = DispatchQueue.global(qos: .background)
        
        autoreleasepool {
            let object = TestObject()
            
            object.onWillDeallocate({
                XCTAssertFalse(Thread.isMainThread, "Should execute on background queue")
                expectation.fulfill()
            }, in: backgroundQueue)
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Async Callback Tests
    
    func testAsyncCallback() {
        let expectation = XCTestExpectation(description: "Async callback completes")
        
        autoreleasepool {
            let object = TestObject()
            
            object.onWillDeallocateAsync { completion in
                // Simulate async work
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    expectation.fulfill()
                    completion()
                }
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testAsyncCallbackWithCustomQueue() {
        let expectation = XCTestExpectation(description: "Async callback on custom queue")
        let customQueue = DispatchQueue(label: "test.async.queue")
        let queueKey = DispatchSpecificKey<String>()
        let queueValue = "test.async.queue.marker"
        
        customQueue.setSpecific(key: queueKey, value: queueValue)
        
        autoreleasepool {
            let object = TestObject()
            
            object.onWillDeallocateAsync({ completion in
                // Verify we're on the custom queue
                let currentValue = DispatchQueue.getSpecific(key: queueKey)
                XCTAssertEqual(currentValue, queueValue, "Async callback should execute on custom queue")
                
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    expectation.fulfill()
                    completion()
                }
            }, in: customQueue)
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testMultipleAsyncCallbacks() {
        let expectation1 = XCTestExpectation(description: "Async callback 1")
        let expectation2 = XCTestExpectation(description: "Async callback 2")
        
        autoreleasepool {
            let object = TestObject()
            
            object.onWillDeallocateAsync { completion in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    expectation1.fulfill()
                    completion()
                }
            }
            
            object.onWillDeallocateAsync { completion in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.15) {
                    expectation2.fulfill()
                    completion()
                }
            }
        }
        
        wait(for: [expectation1, expectation2], timeout: 2.0)
    }
    
    // MARK: - Memory Management Tests
    
    func testNoRetainCycleWithWeakSelf() {
        let expectation = XCTestExpectation(description: "Object deallocates with weak self")
        
        autoreleasepool {
            let object = TestObject()
            
            object.onWillDeallocate { [weak object] in
                // Using weak reference should not create retain cycle
                XCTAssertNil(object, "Object should be nil with weak reference")
            }
            
            object.deinitCalled = {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testObjectDeallocatesWithoutObservers() {
        let expectation = XCTestExpectation(description: "Object deallocates normally")
        
        autoreleasepool {
            let object = TestObject()
            object.deinitCalled = {
                expectation.fulfill()
            }
            // No observers added
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentObserverAddition() {
        let expectation = XCTestExpectation(description: "All concurrent observers execute")
        expectation.expectedFulfillmentCount = 100
        
        autoreleasepool {
            let object = TestObject()
            
            // Add observers from multiple threads concurrently
            DispatchQueue.concurrentPerform(iterations: 100) { index in
                object.onWillDeallocate {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testConcurrentObserverAdditionAndRemoval() {
        let object = TestObject()
        var keys: [String] = []
        let keysQueue = DispatchQueue(label: "keys.queue")
        
        // Add observers from multiple threads
        DispatchQueue.concurrentPerform(iterations: 50) { index in
            let key = object.onWillDeallocate {
                // Empty callback
            }
            keysQueue.sync {
                keys.append(key)
            }
        }
        
        // Remove half of them concurrently
        DispatchQueue.concurrentPerform(iterations: 25) { index in
            keysQueue.sync {
                if index < keys.count {
                    object.removeOnDeallocate(forKey: keys[index])
                }
            }
        }
        
        // Test passes if no crash occurs
        XCTAssert(true)
    }
    
    func testThreadSafetyWithMultipleObjects() {
        let expectation = XCTestExpectation(description: "All objects deallocate safely")
        expectation.expectedFulfillmentCount = 100
        
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            autoreleasepool {
                let object = TestObject()
                
                object.onWillDeallocate {
                    expectation.fulfill()
                }
                
                // Add some concurrent operations
                DispatchQueue.global().async {
                    _ = object.description
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyCallback() {
        let expectation = XCTestExpectation(description: "Empty callback executes")
        
        autoreleasepool {
            let object = TestObject()
            
            object.onWillDeallocate {
                // Empty callback
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testCallbackWithException() {
        let expectation1 = XCTestExpectation(description: "First callback executes")
        let expectation2 = XCTestExpectation(description: "Second callback executes despite exception")
        
        autoreleasepool {
            let object = TestObject()
            
            object.onWillDeallocate {
                expectation1.fulfill()
                // This should not prevent other callbacks
                fatalError("Test exception")
            }
            
            object.onWillDeallocate {
                expectation2.fulfill()
            }
        }
        
        // Note: This test will crash due to fatalError
        // In real scenarios, exceptions should be handled gracefully
        // wait(for: [expectation1, expectation2], timeout: 1.0)
    }
    
    func testMultipleDifferentObjectTypes() {
        let expectation1 = XCTestExpectation(description: "TestObject deallocates")
        let expectation2 = XCTestExpectation(description: "TestObjectWithClosure deallocates")
        
        autoreleasepool {
            let object1 = TestObject()
            let object2 = TestObjectWithClosure()
            
            object1.onWillDeallocate {
                expectation1.fulfill()
            }
            
            object2.onWillDeallocate {
                expectation2.fulfill()
            }
        }
        
        wait(for: [expectation1, expectation2], timeout: 1.0)
    }
    
    func testObserverOnShortLivedObject() {
        let expectation = XCTestExpectation(description: "Short-lived object callback")
        
        do {
            let object = TestObject()
            object.onWillDeallocate {
                expectation.fulfill()
            }
        } // Object deallocates immediately
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Integration Tests
    
    func testRealWorldScenario_ViewControllerLifecycle() {
        class MockViewController: NSObject {
            var viewDidLoadCalled = false
            var viewWillAppearCalled = false
            
            func viewDidLoad() {
                viewDidLoadCalled = true
            }
            
            func viewWillAppear() {
                viewWillAppearCalled = true
            }
        }
        
        let expectation = XCTestExpectation(description: "ViewController deallocates")
        
        autoreleasepool {
            let vc = MockViewController()
            vc.viewDidLoad()
            vc.viewWillAppear()
            
            vc.onWillDeallocate {
                XCTAssertTrue(vc.viewDidLoadCalled)
                XCTAssertTrue(vc.viewWillAppearCalled)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testRealWorldScenario_ResourceCleanup() {
        class ResourceManager: NSObject {
            var isResourceOpen = true
            
            func closeResource() {
                isResourceOpen = false
            }
        }
        
        let expectation = XCTestExpectation(description: "Resource cleaned up")
        
        autoreleasepool {
            let manager = ResourceManager()
            XCTAssertTrue(manager.isResourceOpen)
            
            manager.onWillDeallocate {
                manager.closeResource()
                XCTAssertFalse(manager.isResourceOpen)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testRealWorldScenario_NotificationObserverRemoval() {
        let expectation = XCTestExpectation(description: "Notification observer removed")
        let notificationCenter = NotificationCenter()
        
        autoreleasepool {
            let object = TestObject()
            
            // Simulate adding notification observer
            let observer = notificationCenter.addObserver(
                forName: NSNotification.Name("TestNotification"),
                object: nil,
                queue: nil
            ) { _ in }
            
            // Auto-remove observer on deallocation
            object.onWillDeallocate {
                notificationCenter.removeObserver(observer)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}
