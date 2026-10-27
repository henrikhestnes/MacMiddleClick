#include "CMultitouch.h"
#include <dlfcn.h>

_Static_assert(sizeof(MTTouch) == 96, "MTTouch must match the framework's 96-byte contact record");

// Resolved at runtime so the build does not link against a private framework.
static CFMutableArrayRef (*createList)(void);
static void (*registerCallback)(MTDeviceRef, MTFrameCallback);
static void (*unregisterCallback)(MTDeviceRef, MTFrameCallback);
static void (*deviceStart)(MTDeviceRef, int);
static void (*deviceStop)(MTDeviceRef);

bool MTLoad(void) {
    if (createList) return true;
    void *handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_LAZY);
    if (!handle) return false;
    registerCallback = dlsym(handle, "MTRegisterContactFrameCallback");
    unregisterCallback = dlsym(handle, "MTUnregisterContactFrameCallback");
    deviceStart = dlsym(handle, "MTDeviceStart");
    deviceStop = dlsym(handle, "MTDeviceStop");
    if (!registerCallback || !unregisterCallback || !deviceStart || !deviceStop) return false;
    createList = dlsym(handle, "MTDeviceCreateList");
    return createList != NULL;
}

CFArrayRef MTCopyDevices(void) {
    return createList ? createList() : NULL;
}

void MTStart(MTDeviceRef device, MTFrameCallback callback) {
    registerCallback(device, callback);
    deviceStart(device, 0);
}

void MTStop(MTDeviceRef device, MTFrameCallback callback) {
    unregisterCallback(device, callback);
    deviceStop(device);
}
