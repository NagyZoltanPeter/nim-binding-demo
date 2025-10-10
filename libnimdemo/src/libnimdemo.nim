import std/[atomics]
import chronicles
import chronos/threadsync
import lockfreequeues
import protobuf_serialization
import taskpools/channels_spsc_single

import request_dispatcher, thread_data_exchange
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
var libInitialized: Atomic[bool]

proc initializeLibrary() =
  # Atomically flip from false -> true; only the run init once
  var expectedInitialized: bool = false
  if libInitialized.compareExchange(expectedInitialized, true):
    ## Every Nim library needs to call `<yourprefix>NimMain` once exactly, to initialize the Nim runtime.
    ## Being `<yourprefix>` the value given in the optional compilation flag --nimMainPrefix:yourprefix
    libnimdemoNimMain()
    when declared(setupForeignThreadGc):
      setupForeignThreadGc()
    info "Library initialized"

proc isInitialized(): bool =
  return libInitialized.load()

#### Library interface
proc allocateArgBuffer*(argLen: cint): pointer {.dynlib, exportc, cdecl.} =
  return allocShared0(argLen)

proc deallocateArgBuffer*(argBuffer: pointer) {.dynlib, exportc, cdecl.} =  
  if argBuffer != nil: deallocShared(argBuffer)

proc asyncApiCall*(req: cstring, argBuffer: pointer, argLen: cint): cint {.dynlib, exportc, cdecl.} =
  let reqStr = $req
  info "Async API call", req = reqStr, argLen = argLen
  if not isInitialized() and not waitForRequestProcessingReady():
    error "Library not initialized, cannot process request", request = reqStr
    deallocateArgBuffer(argBuffer)
    return NIMAPI_ERR_NOT_INITIALIZED


  # Create request item
  let item = ApiCallRequest(req: reqStr, argBuffer: argBuffer, argLen: int(argLen), responseChannel: nil)

  let producer =   requestContextP[].incomingQueue.getProducer()
  if not producer.push(item):
    info "Failed to enqueue request, queue might be full", request = reqStr
    deallocateArgBuffer(argBuffer)
    return NIMAPI_ERR_QUEUE_FULL
  else:
    info "request pushed", request = reqStr, incomingQueueLen = $requestContextP[].incomingQueue.storage.len
    discard requestContextP[].requestSignal.fireSync()

  return NIMAPI_OK

var threadResponseChannel {.threadvar.} : ChannelSPSCSingle[ptr ApiResponse]
zeroMem(addr threadResponseChannel, sizeof(ChannelSPSCSingle[ptr ApiResponse]))

proc syncApiCall*(req: cstring, argBuffer: pointer, argLen: cint, 
                  respBuffer: var pointer, respLen: var cint, errorDesc: var cstring): cint {.dynlib, exportc, cdecl.} =
  let reqStr = $req
  info "Sync API call", req = reqStr, argLen = argLen
  if not isInitialized() and not waitForRequestProcessingReady():
    error "Library not initialized, cannot process request", request = reqStr
    deallocateArgBuffer(argBuffer)
    return NIMAPI_ERR_NOT_INITIALIZED

  # reset response ahead
  respBuffer = nil
  respLen = 0

  # Create request item
  let item = ApiCallRequest(req: reqStr, argBuffer: argBuffer, argLen: int(argLen), responseChannel: addr threadResponseChannel)

  let producer =   requestContextP[].incomingQueue.getProducer()
  if not producer.push(item):
    info "Failed to enqueue request, queue might be full", request = reqStr
    deallocateArgBuffer(argBuffer)
    return NIMAPI_ERR_QUEUE_FULL
  else:
    info "request pushed", request = reqStr, incomingQueueLen = $requestContextP[].incomingQueue.storage.len
    discard requestContextP[].requestSignal.fireSync()

  var callResult : ptr ApiResponse
  let recvOk = threadResponseChannel.tryRecv(callResult)
  if not recvOk:
    error "waku thread could not receive a request after calling ", request = reqStr 
    return NIMAPI_ERR_NO_ANSWER
  
  respBuffer = callResult[].buffer
  respLen = cint(callResult[].len)
  let returnCode = callResult[].returnCode
  if returnCode != NIMAPI_OK and callResult[].errorDesc.len > 0:
    errorDesc = cstring(callResult[].errorDesc) # need to allocate string and copy into
  else:
    errorDesc = nil

  deallocShared(callResult)
  return returnCode

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
