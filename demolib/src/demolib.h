#ifndef __libdemo__
#define __libdemo__

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif


void exec(const char* req, void* argBuffer, int argLen);


#ifdef __cplusplus
}
#endif

#endif /* __libdemo__ */
