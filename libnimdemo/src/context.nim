import std/[options, atomics, tables, locks]
import chronicles
import chronos, chronos/threadsync
import lockfreequeues
import protobuf_serialization
import thread_data_exchange, ffi


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
  userRef*: pointer
  userFinalizer*: proc (p: pointer) {.gcsafe.}

var registryInitialized: AtomicFlag
var registryLock: Lock
var ctxByHandle*: Table[uint64, ptr RequestContext]
var nextHandle: uint64

proc ensureRegistryInit() =
  if not registryInitialized.testAndSet():
    initLock(registryLock)
    ctxByHandle = initTable[uint64, ptr RequestContext]()
    # Start handles at 1 so that 0 can represent "no handle"
    nextHandle = 1'u64

proc createRequestContext*(ffiLookupTable: FFILookupTable, userRef: pointer = nil, userFinalizer: proc(p: pointer) {.gcsafe.} = nil): ptr RequestContext =
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
  result.userRef = userRef
  result.userFinalizer = userFinalizer


proc destroyRequestContext(ctx: ptr RequestContext) =
  if ctx != nil:
    discard ctx[].requestSignal.close()
    if ctx[].userFinalizer != nil and ctx[].userRef != nil:
      try:
        ctx[].userFinalizer(ctx[].userRef)
      except CatchableError as e:
        error "userFinalizer raised", err = e.msg
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
        entry.invoke(ctx[].userRef, req.argBuffer, req.argLen, response[], AsyncCall)
    else: # sync call
      info "Synch dispatch", request = req.req
      entry.invoke(ctx[].userRef, req.argBuffer, req.argLen, response[], SyncCall)
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

# Registry management and context lifecycle (handle-based)

proc registerContext(ctx: ptr RequestContext): uint64 =
  ensureRegistryInit()
  withLock(registryLock):
    let handle = nextHandle
    inc nextHandle
    ctxByHandle[handle] = ctx
    return handle

proc unregisterContext(handle: uint64): ptr RequestContext =
  ensureRegistryInit()
  withLock(registryLock):
    if ctxByHandle.hasKey(handle):
      let ctx = ctxByHandle[handle]
      ctxByHandle.del(handle)
      return ctx
    return nil

proc getContext*(handle: uint64): ptr RequestContext =
  ensureRegistryInit()
  withLock(registryLock):
    return ctxByHandle.getOrDefault(handle, nil)

proc createContext*(userRef: pointer = nil, userFinalizer: proc(p: pointer) {.gcsafe.} = nil): uint64 =
  let ctx = createRequestContext(ffiTable, userRef, userFinalizer)
  return registerContext(ctx)

proc startContext*(handle: uint64): bool =
  let ctx = getContext(handle)
  if ctx.isNil: return false
  try:
    info "About to create dispatcher thread", handle = handle
    createThread(ctx[].dispatcherThread, dispatcherThreadProc, ctx)
    info "Dispatcher thread created successfully", handle = handle
    return true
  except ValueError, ResourceExhaustedError:
    error "Failed to create dispatcher thread", handle = handle
    return false

proc stopContext*(handle: uint64): bool =
  let ctx = getContext(handle)
  if ctx.isNil: return false
  info "Stopping request dispatcher thread", handle = handle
  ctx[].requestDispatcherShallRun.store(false)
  discard ctx[].requestSignal.fireSync()
  joinThread(ctx[].dispatcherThread)
  return true

proc destroyContext*(handle: uint64): bool =
  let ctx = unregisterContext(handle)
  if ctx.isNil: return false
  destroyRequestContext(ctx)
  return true

proc waitForRequestProcessingReady*(ctx: ptr RequestContext, timeout = 10.seconds): bool =
  if ctx.isNil:
    error "Request context is not yet initialized"
    return false
  if ctx[].readyToProcessRequests.load():
      return true
  info "Waiting for request processing to be ready"
  result = ctx[].readyToProcessRequestsSignal.waitSync(timeout).valueOr:
    error "Having issue waiting for request processing to be ready", error = error
    return false
  info "Request processing ready"
  return result