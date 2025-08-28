import std/[options, atomics, locks, os]
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

proc asyncApiCall*(req: cstring, argBuffer: pointer, argLen: cint): cint {.dynlib, exportc, cdecl.} =
  let reqStr = $req
  info "Async API call", req = reqStr, argLen = argLen

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

proc syncApiCall*(req: cstring, argBuffer: pointer, argLen: cint, 
                  respBuffer: var pointer, respLen: var cint): cint {.dynlib, exportc, cdecl.} =
  let reqStr = $req
  info "Sync API call", req = reqStr, argLen = argLen

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
    error "waku thread could not receive a request"
    return NIMAPI_ERR_NO_ANSWER
  
  respBuffer = callResult[].buffer
  respLen = cint(callResult[].len)
  let returnCode = callResult[].returnCode
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
