import std/[options, atomics, locks, os]
import chronicles
import lockfreequeues
import protobuf_serialization

import request_dispatcher
import event_dispatcher
import api

when not declared(c_malloc):
  proc c_malloc(size: csize_t): pointer {.
    importc: "malloc", header: "<stdlib.h>".}
  proc c_free(p: pointer) {.
    importc: "free", header: "<stdlib.h>".}

# thread and context management
# instantiate mpsc_queue to feed toward nim context thread
#  and spmc_queue for reading on binded side
# exports connector interface

### Library setup

# Every Nim library must have this function called - the name is derived from
# the `--nimMainPrefix` command line option
proc libdemoNimMain() {.importc.}

# To control when the library has been initialized
var libInitialized: AtomicFlag
var runEnvInitialized: AtomicFlag

proc initializeLibrary() = # {.exported.} =
  if not libInitialized.testAndSet():
    ## Every Nim library needs to call `<yourprefix>NimMain` once exactly, to initialize the Nim runtime.
    ## Being `<yourprefix>` the value given in the optional compilation flag --nimMainPrefix:yourprefix
    libdemoNimMain()

    when declared(setupForeignThreadGc):
      setupForeignThreadGc()

#### Library interface

proc initDemoLib*() {.dynlib, exportc, cdecl.} =
  initializeLibrary()
  createRequestDispatcherEnv()
  createEventDispatcherEnv()

proc requestApiCall*(req: cstring, argBuffer: pointer, argLen: cint) {.dynlib, exportc, cdecl.} =
  # This initialization can be managed automatically with CPP global instance
  # initializeLibrary()
  # createRunEnv()

  # Convert cstring to string for easier handling
  let reqStr = $req
  info "Adding lib call", req = reqStr, argLen = argLen

  # Create request item
  let item = RequestItem(req: reqStr, argBuffer: argBuffer, argLen: int(argLen))

  info "request item created and about to be pushed"

  let producer =   requestContextP[].incomingQueue.getProducer()
  # Add request to queue
  if not producer.push(item):
    info "Failed to enqueue request, queue might be full", request = reqStr
  else:
    info "Request enqueued successfully", request = reqStr

  info "request pushed", incomingQueueLen = $requestContextP[].incomingQueue.storage.len

proc stopDemoLib*() {.dynlib, exportc, cdecl.} =
  shutdownRequestDispatcher()
  shutdownEventDispatcher()

# Public API functions following Google Protobuf pattern
proc demolib_initialize*() {.dynlib, exportc, cdecl.} =
  ## Initialize the demolib library. Must be called before using any other demolib functions.
  ## This is equivalent to initDemoLib() but follows the explicit initialization pattern.
  initializeLibrary()
  createRequestDispatcherEnv()
  createEventDispatcherEnv()

proc demolib_teardown*() {.dynlib, exportc, cdecl.} =
  ## Cleanup the demolib library. Should be called when done using the library.
  ## This is equivalent to stopDemoLib() but follows the explicit teardown pattern.
  shutdownRequestDispatcher()
  shutdownEventDispatcher()
