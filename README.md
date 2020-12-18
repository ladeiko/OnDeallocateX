# OnDeallocateX

Helper code to track iOS objects deallocation

## Installation

### Cocoapods

Add to your Podfile:

```ruby
pod 'OnDeallocateX'
```

### Manually

Clone repository, then include "Sources" folder to your project.

## Usage

Class of object to be tracked should be inherited from NSObject.

```swift
class TestObject: NSObject {
	deinit {
		print("deinit")
	}
}

let t = TestObject()
let k = t.onWillDeallocate {
	// NOTE: Please do not keep strong references to object inside this callback!!!
	print("will deallocate")
}

// Here object is deallocated, because no more references to it and you will see in console:
// ...
// will deallocate
// deinit
// ...


// Also you can delete observation by:
t.removeOnDeallocate(forKey: k)
```

**NOTE**: ```onWillDeallocate``` will be called before deallocation, but real deallocation can be performed later (in case of additional strong references to object).

## License

MIT. See [LICENSE](LICENSE)

## Authors

- Siarhei Ladzeika <sergey.ladeiko@gmail.com>
