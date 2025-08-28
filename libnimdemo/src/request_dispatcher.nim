import std/[options, atomics, locks, os, tables]
import chronicles
import chronos, chronos/threadsync
import taskpools/channels_spsc_single
import lockfreequeues
import protobuf_serialization
import message, api, thread_data_exchange, ffi

var requestDispatcherEnvInitialized: AtomicFlag

# Queue for incoming requests (multi-producer, single-consumer)
type RequestContext* = object
  incomingQueue*: Mupsic[1024, 16, ApiCallRequest]
  ffiLookupTable*: FFILookupTable
  requestSignal*: ThreadSignalPtr 

var requestContextP*: ptr RequestContext

# Thread synchronization
var dispatcherThread: Thread[ptr RequestContext]
var isRequestDispatcherRunning: Atomic[bool]

proc createRequestContext*(ffiLookupTable: FFILookupTable): ptr RequestContext =
  result = RequestContext.createShared()
  result.ffiLookupTable = ffiLookupTable
  result.requestSignal = ThreadSignalPtr.new().valueOr:
    error "Cannot create request signaling"
    quit(QuitFailure)

proc destroyRequestContext(ctx: ptr RequestContext) =
  if ctx != nil:
    discard ctx[].requestSignal.close()
    freeShared(ctx)

# Dispatcher: look up and invoke
proc dispatchFFIRequest*(ctx: ptr RequestContext, req: ApiCallRequest) {.raises: [], gcsafe.} =
  info "dispatchFFIRequest", target = req.req, bytes = req.argLen
  if not ctx[].ffiLookupTable.hasKey(req.req):
    error "Unknown FFI proc", name = req.req
    if not req.argBuffer.isNil: deallocShared(req.argBuffer)
    return
  let entry = ctx[].ffiLookupTable.getOrDefault(req.req)
  if entry.invoke.isNil:
    error "FFI entry has no invoke", name = req.req
    if not req.argBuffer.isNil: deallocShared(req.argBuffer)
    return
  try:
    # let response = createShared(ApiResponse, int(NIMAPI_FAIL))
    let response = ApiResponse.createShared(NIMAPI_FAIL)
    if req.responseChannel == nil: # async call
        entry.invoke(req.argBuffer, req.argLen, response[], AsyncCall)
    else: # sync call
      entry.invoke(req.argBuffer, req.argLen, response[], SyncCall)
      if not req.responseChannel[].trySend(response):
        error "Failed to send response", name = req.req
        if not response[].buffer.isNil: deallocShared(response[].buffer)
        deallocShared(response)
        
  except CatchableError as e:
    error "FFI invoke raised", name = req.req, err = e.msg
  except Exception as e:
    error "FFI invoke raised (unknown)", name = req.req, err = e.msg

proc processRequests(ctx: ptr RequestContext) {.async.} =
  # Main dispatch loop
  while isRequestDispatcherRunning.load:
    var item = ctx[].incomingQueue.pop()
    # process all request in the queue, do not wait for signal
    while item.isSome():
      info "Processing request", req = item.get().req
      dispatchFFIRequest(ctx, item.get())
      item = ctx[].incomingQueue.pop()

    await ctx[].requestSignal.wait()

# Thread procedure for dispatching calls
proc dispatcherThreadProc(ctx: ptr RequestContext) {.thread, gcsafe.} =
  info "Dispatcher thread started"
  waitFor processRequests(ctx)

  info "Dispatcher thread stopping"

proc createRequestDispatcherEnv*() =
  # do it once
  if not requestDispatcherEnvInitialized.testAndSet():
    info "Initializing run environment"

    # Initialize thread running flag
    isRequestDispatcherRunning.store(true)

    requestContextP = createRequestContext(ffiTable)
    # Start the dispatcher thread
    try:
      info "About to create dispatcher thread"
      createThread(dispatcherThread, dispatcherThreadProc, requestContextP)
      info "Dispatcher thread created successfully"
    except ValueError, ResourceExhaustedError:
      error "Failed to create dispatcher thread"
      destroyRequestContext(requestContextP)

proc shutdownRequestDispatcher*() =
  info "Stopping request dispatcher thread"
  isRequestDispatcherRunning.store(false)
  discard requestContextP[].requestSignal.fireSync()
  joinThread(dispatcherThread)
  destroyRequestContext(requestContextP)
