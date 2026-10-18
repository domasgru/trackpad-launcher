// A bare MultitouchSupport client: a no-op frame callback on every device, nothing else. Baseline for per-frame cost.
#include <dlfcn.h>
#include <unistd.h>
#include <CoreFoundation/CoreFoundation.h>
static int onFrame(void *d, void *t, int c, double ts, int f) { return 0; }
int main(void) {
    void *h = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW);
    CFArrayRef (*createList)(void) = dlsym(h, "MTDeviceCreateList");
    void (*reg)(void *, void *) = dlsym(h, "MTRegisterContactFrameCallback");
    int (*start)(void *, int) = dlsym(h, "MTDeviceStart");
    CFArrayRef list = createList();
    for (CFIndex i = 0; i < CFArrayGetCount(list); i++) { void *d = (void *)CFArrayGetValueAtIndex(list, i); reg(d, onFrame); start(d, 0); }
    for (;;) pause();
}
