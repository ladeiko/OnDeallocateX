// MIT License
//
// Copyright (c) 2018-present Siarhei Ladzeika
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#if SWIFT_PACKAGE
#import "OnDeallocateX.h"
#else
#import <OnDeallocateX/OnDeallocateX.h>
#endif

#import <objc/runtime.h>
#import <objc/message.h>

__attribute__((visibility("hidden"))) static SEL retainCountSelector;
__attribute__((visibility("hidden"))) static const char setupKey;
__attribute__((visibility("hidden"))) static const char blocksKey;
__attribute__((visibility("hidden"))) static const char selfReferenceKey;

typedef void (^__OnDeallocate__)(void);

@implementation NSObject(OnDeallocateX)

+ (void)load
{
    char selName[] = {'r' + 1,'e' + 1,'t' + 1,'a' + 1,'i' + 1,'n' + 1,'C' + 1,'o' + 1,'u' + 1,'n' + 1,'t' + 1, 0 + 1};
    for (NSUInteger i = 0; i < sizeof(selName); ++i) { selName[i] -= 1; }
    retainCountSelector = NSSelectorFromString([NSString stringWithUTF8String:selName]);
}

- (void)setupOnDeallocateCodeForClass
{
    char selName[] = {'r' + 1,'e' + 1,'l' + 1,'e' + 1,'a' + 1,'s' + 1,'e' + 1, 0 + 1};
    for (NSUInteger i = 0; i < sizeof(selName); ++i) { selName[i] -= 1; }

    Class class = [self class];
    
    const SEL originalSelector = NSSelectorFromString([NSString stringWithUTF8String:selName]);
    const SEL swizzledSelector = @selector(releaseOnDeallocateX);
    
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    
    const BOOL didAddMethod = class_addMethod(class, originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(class,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

- (void)releaseOnDeallocateX
{
    NSUInteger (*rc)(id,SEL) = (NSUInteger (*)(id,SEL))objc_msgSend;
    const NSUInteger r = rc(self, retainCountSelector);
    if (r == 2 /* will become 1, because 1 is take with self reference in selfReferenceKey */) {

        // Here it is safe to access vars without sync
        NSDictionary* const blocks = objc_getAssociatedObject(self, &blocksKey);
        objc_setAssociatedObject(self, &blocksKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        if (blocks) {
            for (NSDictionary* k in blocks.allValues) {
                const __OnDeallocate__ onDeallocate = [k objectForKey:@"block"];
                const dispatch_queue_t queue = [k objectForKey:@"queue"];
                dispatch_async(queue, ^{
                    onDeallocate();
                    [self description]; // life prolongation
                    //  Here, typically, real deallocation will occur, but only
                    //  if code in onDeallocate does not add new references to object
                });
            }
            objc_setAssociatedObject(self, &selfReferenceKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    [self releaseOnDeallocateX];
}

- (NSString* _Nonnull)onWillDeallocate:(OnWillDeallocateBlock _Nonnull)block inQueue:(dispatch_queue_t _Nonnull)queue
{
    @synchronized(self)
    {
        if (!objc_getAssociatedObject([self class], &setupKey))
        {
            objc_setAssociatedObject([self class], &setupKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [self setupOnDeallocateCodeForClass];
        }

        NSMutableDictionary * blocks = objc_getAssociatedObject(self, &blocksKey);
        if (!blocks) {
            blocks = [NSMutableDictionary new];
            objc_setAssociatedObject(self, &blocksKey, blocks, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, &selfReferenceKey, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }

        NSString* key = [[NSUUID UUID] UUIDString];
        NSDictionary* const info = @{@"block": [block copy], @"queue": queue};
        [blocks setObject:info forKey:key];
        return key;
    }
}

- (NSString* _Nonnull)onWillDeallocate:(OnWillDeallocateBlock _Nonnull)block
{
    return [self onWillDeallocate:block inQueue:dispatch_get_main_queue()];
}

- (void)removeOnDeallocateForKey:(NSString* _Nonnull)key {
    @synchronized (self) {
        NSMutableDictionary * blocks = objc_getAssociatedObject(self, &blocksKey);
        if (blocks) {
            [blocks removeObjectForKey:key];
            if ([blocks count]) {
                objc_setAssociatedObject(self, &blocksKey, nil, OBJC_ASSOCIATION_RETAIN);
                objc_setAssociatedObject(self, &selfReferenceKey, nil, OBJC_ASSOCIATION_RETAIN);
            }
        }
    }
}

@end
