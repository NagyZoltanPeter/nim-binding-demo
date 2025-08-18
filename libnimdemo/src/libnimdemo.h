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

enum ApiCallResult {
	NIMAPI_FAIL = -1,
    NIMAPI_OK = 0,
	NIMAPI_ERR_NOT_INITIALIZED = 1,
	NIMAPI_ERR_INVALID_ARG = 2,
	NIMAPI_ERR_QUEUE_FULL = 3,
	NIMAPI_ERR_UNKNOWN_PROC = 4,
  	NIMAPI_ERR_NO_ANSWER = 5
};


// Main API function
int asyncApiCall(const char* req, void* argBuffer, int argLen);
int syncApiCall(const char* req, void* argBuffer, int argLen, void** respBuffer, int* respLen);

void* allocateArgBuffer(int size);
void  deallocateArgBuffer(void* argBuffer);

#ifdef __cplusplus
}
#endif

#endif /* __libnimdemo__ */
