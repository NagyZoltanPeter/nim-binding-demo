#ifndef __libnimdemo__
#define __libnimdemo__

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Library initialization and cleanup functions (must be called explicitly)
void libnimdemo_initialize(void);
void libnimdemo_teardown(void);

// Main API function
void requestApiCall(const char* req, void* argBuffer, int argLen);

void* allocateArgBuffer(int size);
void  deallocateArgBuffer(void* argBuffer);

#ifdef __cplusplus
}
#endif

#endif /* __libnimdemo__ */
