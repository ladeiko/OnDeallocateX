import XCTest
@testable import OnDeallocateX

/// Performance-focused tests for OnDeallocateX
final class PerformanceTests: XCTestCase {
    
    class TestObject: NSObject {}
    
    // MARK: - Memory Performance
    
    func testMemoryOverheadSingleObserver() {
        measure(metrics: [XCTMemoryMetric()]) {
            let objects = (0..<1000).map { _ in
                let obj = TestObject()
                obj.onWillDeallocate { }
                return obj
            }
            
            // Keep objects alive during measurement
            _ = objects.count
        }
    }
    
    func testMemoryOverheadMultipleObservers() {
        measure(metrics: [XCTMemoryMetric()]) {
            let objects = (0..<1000).map { _ in
                let obj = TestObject()
                obj.onWillDeallocate { }
                obj.onWillDeallocate { }
                obj.onWillDeallocate { }
                return obj
            }
            
            _ = objects.count
        }
    }
    
    // MARK: - CPU Performance
    
    func testPerformanceAddingObservers() {
        let objects = (0..<1000).map { _ in TestObject() }
        
        measure {
            for object in objects {
                object.onWillDeallocate { }
            }
        }
    }
    
    func testPerformanceAddingMultipleObservers() {
        let objects = (0..<100).map { _ in TestObject() }
        
        measure {
            for object in objects {
                for _ in 0..<10 {
                    object.onWillDeallocate { }
                }
            }
        }
    }
    
    func testPerformanceRemovingObservers() {
        let objects = (0..<1000).map { _ in TestObject() }
        let keys = objects.map { $0.onWillDeallocate { } }
        
        measure {
            for (object, key) in zip(objects, keys) {
                object.removeOnDeallocate(forKey: key)
            }
        }
    }
    
    func testPerformanceObjectDeallocation() {
        measure {
            autoreleasepool {
                for _ in 0..<1000 {
                    let object = TestObject()
                    object.onWillDeallocate { }
                }
            }
        }
    }
    
    // MARK: - Scalability Tests
    
    func testScalabilityManyObserversPerObject() {
        let object = TestObject()
        
        measure {
            for _ in 0..<100 {
                object.onWillDeallocate { }
            }
        }
    }
    
    func testScalabilityManyObjects() {
        measure {
            autoreleasepool {
                for _ in 0..<10000 {
                    let object = TestObject()
                    object.onWillDeallocate { }
                }
            }
        }
    }
    
    func testScalabilityConcurrentAccess() {
        let objects = (0..<100).map { _ in TestObject() }
        
        measure {
            DispatchQueue.concurrentPerform(iterations: 100) { index in
                objects[index % objects.count].onWillDeallocate { }
            }
        }
    }
    
    // MARK: - Real-World Scenarios
    
    func testPerformanceTypicalAppScenario() {
        // Simulate typical app: 10 view controllers, each with 5 observers
        measure {
            autoreleasepool {
                for _ in 0..<10 {
                    let vc = TestObject()
                    for _ in 0..<5 {
                        vc.onWillDeallocate { }
                    }
                }
            }
        }
    }
    
    func testPerformanceAsyncCallbacks() {
        let expectation = XCTestExpectation(description: "Async callbacks complete")
        expectation.expectedFulfillmentCount = 100
        
        measure {
            autoreleasepool {
                for _ in 0..<100 {
                    let object = TestObject()
                    object.onWillDeallocateAsync { completion in
                        completion()
                        expectation.fulfill()
                    }
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Comparison Baseline
    
    func testBaselineObjectCreation() {
        // Baseline: Creating objects without OnDeallocateX
        measure {
            autoreleasepool {
                for _ in 0..<1000 {
                    _ = TestObject()
                }
            }
        }
    }
    
    func testBaselineObjectWithDeinit() {
        class ObjectWithDeinit: NSObject {
            var callback: (() -> Void)?
            deinit {
                callback?()
            }
        }
        
        // Baseline: Traditional deinit approach
        measure {
            autoreleasepool {
                for _ in 0..<1000 {
                    let object = ObjectWithDeinit()
                    object.callback = { }
                }
            }
        }
    }
}
