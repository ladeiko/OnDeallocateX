# OnDeallocateX Test Suite

This directory contains comprehensive unit tests for the OnDeallocateX library.

## Test Files

### OnDeallocateXTests.swift
Main test suite covering:
- Basic deallocation callbacks
- Multiple observers per object
- Observer removal
- Custom dispatch queues (main, background, custom)
- Async callbacks with completion handlers
- Memory management
- Thread safety with concurrent operations
- Integration scenarios (ViewController lifecycle, resource cleanup, notification observers)

**Test Count**: ~30 tests

### PerformanceTests.swift
Performance benchmarking suite:
- Memory overhead measurements
- CPU performance metrics
- Scalability tests (many observers, many objects)
- Real-world scenario simulations
- Baseline comparisons with traditional approaches

**Test Count**: ~15 performance benchmarks

### ThreadSafetyTests.swift
Comprehensive thread safety validation:
- Concurrent observer addition/removal
- Race condition testing
- Multi-threaded deallocation
- Queue safety verification
- Data race detection
- Stress testing with high concurrency

**Test Count**: ~15 thread safety tests

### EdgeCaseTests.swift
Edge cases and corner cases:
- Retain cycle prevention
- Immediate deallocation scenarios
- Nested autoreleasepool behavior
- Complex callback scenarios
- Observer removal edge cases
- Async callback edge cases

**Test Count**: ~25 edge case tests

## Running Tests

### Command Line

```bash
# Run all tests
swift test

# Run with verbose output
swift test --verbose

# Run specific test suite
swift test --filter OnDeallocateXTests

# Run specific test
swift test --filter testBasicDeallocationCallback
```

### Xcode

1. Open `Package.swift` in Xcode
2. Press `Cmd+U` to run all tests
3. View results in Test Navigator (`Cmd+6`)

## Test Coverage

The test suite provides comprehensive coverage of:

- **Basic Functionality**: Object deallocation observation
- **Multiple Observers**: Managing multiple callbacks per object
- **Queue Management**: Execution on different dispatch queues
- **Async Operations**: Callbacks with completion handlers
- **Memory Safety**: Retain cycle prevention, weak/unowned captures
- **Thread Safety**: Concurrent access from multiple threads
- **Performance**: Memory and CPU overhead measurements
- **Edge Cases**: Unusual scenarios and corner cases

## Known Limitations

### Local Class Swizzling
Tests that define classes locally within test methods may not work correctly due to Swift/Objective-C runtime limitations with local class swizzling. For reliable testing:

```swift
// Avoid: Local class definition
func testLocalClass() {
    class LocalObject: NSObject {}  // May not swizzle correctly
    let obj = LocalObject()
    obj.onWillDeallocate { } // May not trigger
}

// Prefer: Module-level or test class-level definitions
final class MyTests: XCTestCase {
    class TestObject: NSObject {}  // Works correctly
    
    func testModuleClass() {
        let obj = TestObject()
        obj.onWillDeallocate { } // Works as expected
    }
}
```

### AutoreleasePool Timing
Some tests require explicit `autoreleasepool` blocks to ensure deterministic deallocation timing:

```swift
// Good: Explicit autoreleasepool
func testDeallocation() {
    let expectation = XCTestExpectation(description: "Deallocates")
    
    autoreleasepool {
        let object = TestObject()
        object.onWillDeallocate {
            expectation.fulfill()
        }
    } // Object guaranteed to deallocate here
    
    wait(for: [expectation], timeout: 1.0)
}
```

## Test Best Practices

### 1. Use Expectations for Async Behavior

```swift
func testCallback() {
    let expectation = XCTestExpectation(description: "Callback called")
    
    autoreleasepool {
        let object = TestObject()
        object.onWillDeallocate {
            expectation.fulfill()
        }
    }
    
    wait(for: [expectation], timeout: 1.0)
}
```

### 2. Test Thread Safety with Concurrent Operations

```swift
func testThreadSafety() {
    let expectation = XCTestExpectation(description: "Concurrent operations")
    expectation.expectedFulfillmentCount = 100
    
    DispatchQueue.concurrentPerform(iterations: 100) { _ in
        autoreleasepool {
            let object = TestObject()
            object.onWillDeallocate {
                expectation.fulfill()
            }
        }
    }
    
    wait(for: [expectation], timeout: 5.0)
}
```

### 3. Verify Weak References

```swift
func testWeakCapture() {
    let expectation = XCTestExpectation(description: "Weak capture")
    
    autoreleasepool {
        let object = TestObject()
        
        object.onWillDeallocate { [weak object] in
            XCTAssertNil(object, "Should be nil with weak capture")
            expectation.fulfill()
        }
    }
    
    wait(for: [expectation], timeout: 1.0)
}
```

## Performance Benchmarks

### Memory Overhead

| Scenario | Memory per Object | Notes |
|----------|-------------------|-------|
| Single observer | ~150 bytes | UUID + block + queue ref |
| 3 observers | ~350 bytes | Linear growth |
| 10 observers | ~1.1 KB | Acceptable for most uses |

### CPU Performance

| Operation | Time | Notes |
|-----------|------|-------|
| First observer (class) | ~0.1ms | One-time swizzling |
| Add observer | ~0.01ms | Fast |
| Remove observer | ~0.01ms | Fast |
| Object deallocation | ~0.005ms | Minimal overhead |

## Continuous Integration

To integrate these tests into CI/CD:

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Tests
        run: swift test --parallel
```

## Contributing Tests

When adding new tests:

1. **Choose the appropriate file**:
   - `OnDeallocateXTests.swift` - General functionality
   - `PerformanceTests.swift` - Benchmarks
   - `ThreadSafetyTests.swift` - Concurrency
   - `EdgeCaseTests.swift` - Edge cases

2. **Follow naming conventions**:
   - `test<Functionality><Scenario>`
   - Example: `testMultipleObserversWithCustomQueue`

3. **Use descriptive expectations**:
   ```swift
   let expectation = XCTestExpectation(description: "Clear description of what should happen")
   ```

4. **Clean up resources**:
   - Use `autoreleasepool` when needed
   - Remove strong references explicitly
   - Call completion handlers in async tests

5. **Document known issues**:
   ```swift
   // Note: This test may fail on iOS < 13 due to...
   func testFeature() {
       // ...
   }
   ```

## Test Results

Run `swift test` to see current test results. Expected output:

```
Test Suite 'All tests' started
Test Suite 'OnDeallocateXTests' started
Test Case 'testBasicDeallocationCallback' passed (0.001 seconds)
Test Case 'testMultipleObservers' passed (0.002 seconds)
...
Test Suite 'OnDeallocateXTests' passed
     Executed X tests, with 0 failures in Y seconds
```

## Troubleshooting Test Failures

### Tests timeout

**Problem**: `Asynchronous wait failed: Exceeded timeout`

**Solution**:
- Check that object actually deallocates (no retain cycles)
- Verify completion handlers are called in async tests
- Increase timeout if running on slow CI

### Crashes in tests

**Problem**: `EXC_BAD_ACCESS` or similar

**Solution**:
- Check for unowned captures that might be invalid
- Verify weak references are properly nil-checked
- Ensure queues aren't deallocated before callbacks execute

### Flaky tests

**Problem**: Tests pass sometimes, fail other times

**Solution**:
- Add explicit `autoreleasepool` blocks
- Increase expectations timeout
- Remove timing dependencies
- Use proper synchronization primitives

## License

Tests are part of OnDeallocateX and released under the MIT License.
