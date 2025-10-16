import std/[options, atomics, tables]
import chronicles
import chronos, chronos/threadsync
import taskpools/channels_spsc_single
import lockfreequeues
import protobuf_serialization
import thread_data_exchange, ffi

var requestDispatcherEnvInitialized: AtomicFlag

# Queue for incoming requests (multi-producer, single-consumer)
type RequestContext* = object
  incomingQueue*: Mupsic[1024, 16, ApiCallRequest]
  ffiLookupTable*: FFILookupTable
  requestSignal*: ThreadSignalPtr 
  dispatcherThread: Thread[ptr RequestContext]
  requestDispatcherShallRun: Atomic[bool]
  readyToProcessRequests: Atomic[bool]
  readyToProcessRequestsSignal: ThreadSignalPtr
  syncCallWaiter*: ThreadSignalPtr
  syncCallResponse*: Atomic[ptr ApiResponse]



var requestContextP*: ptr RequestContext

proc createRequestContext*(ffiLookupTable: FFILookupTable): ptr RequestContext =
  result = RequestContext.createShared()
  result.ffiLookupTable = ffiLookupTable
  result.requestSignal = ThreadSignalPtr.new().valueOr:
    error "Cannot create request signaling"
    quit(QuitFailure)
  result.requestDispatcherShallRun.store(true)
  result.readyToProcessRequests.store(false)
  result.readyToProcessRequestsSignal = ThreadSignalPtr.new().valueOr:
    error "Cannot create readyToProcessRequests signaling"
    quit(QuitFailure)
  result.syncCallWaiter = ThreadSignalPtr.new().valueOr:
    error "Cannot create sync call signaling"
    quit(QuitFailure)
  result.syncCallResponse.store(nil)


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
    if req.invokeType == AsyncCall:
        info "Async dispatch", request = req.req
        entry.invoke(req.argBuffer, req.argLen, response[], AsyncCall)
    else: # sync call
      info "Synch dispatch", request = req.req
      entry.invoke(req.argBuffer, req.argLen, response[], SyncCall)
      ctx[].syncCallResponse.store(response)
      ctx[].syncCallWaiter.fireSync().isOkOr:
        error "Failed to send response", name = req.req
        if not response[].buffer.isNil: deallocShared(response[].buffer)
        deallocShared(response)
        
  except CatchableError as e:
    error "FFI invoke raised", name = req.req, err = e.msg
  except Exception as e:
    error "FFI invoke raised (unknown)", name = req.req, err = e.msg

proc processRequests(ctx: ptr RequestContext) {.async.} =
  # Main dispatch loop
  ctx[].readyToProcessRequests.store(true)
  discard ctx[].readyToProcessRequestsSignal.fireSync()
  while ctx[].requestDispatcherShallRun.load():
    var item = ctx[].incomingQueue.pop()
    # process all request in the queue, do not wait for signal
    while item.isSome():
      info "Processing request", req = item.get().req
      dispatchFFIRequest(ctx, item.get())
      item = ctx[].incomingQueue.pop()

    await ctx[].requestSignal.wait()

  ctx[].readyToProcessRequests.store(false)

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
    requestContextP = createRequestContext(ffiTable)
    # Start the dispatcher thread
    try:
      info "About to create dispatcher thread"
      createThread(requestContextP[].dispatcherThread, dispatcherThreadProc, requestContextP)
      info "Dispatcher thread created successfully"
    except ValueError, ResourceExhaustedError:
      error "Failed to create dispatcher thread"
      destroyRequestContext(requestContextP)

proc shutdownRequestDispatcher*() =
  info "Stopping request dispatcher thread"
  requestContextP[].requestDispatcherShallRun.store(false)
  discard requestContextP[].requestSignal.fireSync()
  joinThread(requestContextP[].dispatcherThread)
  destroyRequestContext(requestContextP)

proc waitForRequestProcessingReady*(): bool =
  if requestContextP == nil:
    error "Request context is not yet initialized"
    return false
  if requestContextP[].readyToProcessRequests.load():
      return true
  info "Waiting for request processing to be ready"
  let result = requestContextP[].readyToProcessRequestsSignal.waitSync(10.seconds).valueOr:
    error "Having issue waiting for request processing to be ready", error = error
    return false
  info "Request processing ready"
  return true