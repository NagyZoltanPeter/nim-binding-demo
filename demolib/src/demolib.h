#ifndef __libdemo__
#define __libdemo__

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus

extern "C" {
#endif

// Library initialization and cleanup functions (must be called explicitly)
void demolib_initialize(void);
void demolib_teardown(void);

// Internal library functions (still available for backwards compatibility)
void initDemoLib(void);
void stopDemoLib(void);

// Main API function
void requestApiCall(const char* req, void* argBuffer, int argLen);

#ifdef __cplusplus
}

#endif

#endif /* __libdemo__ */
