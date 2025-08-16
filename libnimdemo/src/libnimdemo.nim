import std/[options, atomics, locks, os]
import chronicles
import chronos/threadsync
import lockfreequeues
import protobuf_serialization

import request_dispatcher, request_item
import event_dispatcher
import api

# thread and context management
# instantiate mpsc_queue to feed toward nim context thread
#  and spmc_queue for reading on binded side
# exports connector interface

### Library setup

# Every Nim library must have this function called - the name is derived from
# the `--nimMainPrefix` command line option
proc libnimdemoNimMain() {.importc.}

# To control when the library has been initialized
var libInitialized: AtomicFlag
var runEnvInitialized: AtomicFlag

proc initializeLibrary() =
  if not libInitialized.testAndSet():
    ## Every Nim library needs to call `<yourprefix>NimMain` once exactly, to initialize the Nim runtime.
    ## Being `<yourprefix>` the value given in the optional compilation flag --nimMainPrefix:yourprefix
    libnimdemoNimMain()
    when declared(setupForeignThreadGc):
      setupForeignThreadGc()

#### Library interface
proc allocateArgBuffer*(argLen: cint): pointer {.dynlib, exportc, cdecl.} =
  return allocShared0(argLen)

proc deallocateArgBuffer*(argBuffer: pointer) {.dynlib, exportc, cdecl.} =  
  if argBuffer != nil: deallocShared(argBuffer)

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
    deallocateArgBuffer(argBuffer)
  else:
    info "request pushed", request = reqStr, incomingQueueLen = $requestContextP[].incomingQueue.storage.len
    discard requestContextP[].requestSignal.fireSync()



# Public API functions following Google Protobuf pattern
proc libnimdemo_initialize*() {.dynlib, exportc, cdecl.} =
  ## Initialize the libnimdemo library. Must be called before using any other libnimdemo functions.
  ## This is equivalent to initDemoLib() but follows the explicit initialization pattern.
  initializeLibrary()
  createRequestDispatcherEnv()
  createEventDispatcherEnv()

proc libnimdemo_teardown*() {.dynlib, exportc, cdecl.} =
  ## Cleanup the libnimdemo library. Should be called when done using the library.
  ## This is equivalent to stopDemoLib() but follows the explicit teardown pattern.
  shutdownRequestDispatcher()
  shutdownEventDispatcher()
