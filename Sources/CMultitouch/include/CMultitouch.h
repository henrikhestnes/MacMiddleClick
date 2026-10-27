#ifndef CMULTITOUCH_H
#define CMULTITOUCH_H

#include <CoreFoundation/CoreFoundation.h>
#include <stdbool.h>
#include <stdint.h>

// Reverse-engineered layout of the private MultitouchSupport.framework contact record (96 bytes).
typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint position, velocity; } MTVector;

typedef struct {
    int32_t frame;
    double timestamp;
    int32_t identifier;
    int32_t state;
    int32_t fingerID;
    int32_t handID;
    MTVector normalized;   // 0...1 in both axes, origin at the bottom left of the trackpad
    float size;
    int32_t zero1;
    float angle;
    float majorAxis;
    float minorAxis;
    MTVector absolute;     // millimetres
    int32_t zero2[2];
    float density;
} MTTouch;

typedef void *MTDeviceRef;
typedef int (*MTFrameCallback)(MTDeviceRef device, const MTTouch *touches, int32_t count, double timestamp, int32_t frame);

/// Loads the framework. Returns false if it or any required symbol is missing.
bool MTLoad(void);
/// Returns a retained array of MTDeviceRef, or NULL.
CFArrayRef MTCopyDevices(void) CF_RETURNS_RETAINED;
void MTStart(MTDeviceRef device, MTFrameCallback callback);
void MTStop(MTDeviceRef device, MTFrameCallback callback);

#endif
