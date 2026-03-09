#pragma once

#ifndef __libnimdemo__
#define __libnimdemo__

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Library initialization and cleanup functions (must be called explicitly)
void nimlib_initialize(void);
void nimlib_teardown(void);

enum ApiCallResultCode {
	NIMAPI_FAIL = -1,
    NIMAPI_OK = 0,
	NIMAPI_ERR_NOT_INITIALIZED = 1,
	NIMAPI_ERR_INVALID_ARG = 2,
	NIMAPI_ERR_QUEUE_FULL = 3,
	NIMAPI_ERR_UNKNOWN_PROC = 4,
  	NIMAPI_ERR_NO_ANSWER = 5
};


// Context management
uint64_t nimlib_context_create(void* userRef);
int nimlib_context_start(uint64_t ctxHandle);
int nimlib_context_stop(uint64_t ctxHandle);
int nimlib_context_destroy(uint64_t ctxHandle);
bool nimlib_context_wait_ready(uint64_t ctxHandle, int timeoutMs);

// Main API functions
int asyncApiCall(uint64_t ctxHandle, const char* req, void* argBuffer, int argLen);
int syncApiCall(uint64_t ctxHandle, const char* req, void* argBuffer, int argLen, void** respBuffer, int* respLen, char** errorDesc );

void* allocateArgBuffer(int size);
void  deallocateArgBuffer(void* argBuffer);

#ifdef __cplusplus
}
#endif

#endif /* __libnimdemo__ */
