import std/[options, atomics, locks, os]
import chronicles
import chronos
import lockfreequeues
import protobuf_serialization
import message, api

var requestDispatcherEnvInitialized: AtomicFlag

# Queue for incoming requests (multi-producer, single-consumer)
type RequestItem* = object
  req*: string
  argBuffer*: pointer
  argLen*: int

type RequestContext* = object
  incomingQueue*: Mupsic[1024, 16, RequestItem]
  # outgoingQueue: Sipsic[1024, WakuMessage]

var requestContextP*: ptr RequestContext

# Thread synchronization
var dispatcherThread: Thread[ptr RequestContext]
var isRequestDispatcherRunning: Atomic[bool]

proc createRequestContext*(): ptr RequestContext =
  result = RequestContext.createShared()

proc dispatchRequest(req: RequestItem) =
  info "dispatchRequest to ", requestProcessor = req.req
  if req.req == "Send":

    # decode transfer buffer to create API argument
    let bytePtr = cast[ptr UncheckedArray[byte]](req.argBuffer)
    let arg = catch: Protobuf.decode(toOpenArray(bytePtr, 0, req.argLen - 1), WakuMessage)

    # it is important to release the buffer allocated in the host language side to avoid leaks.
    # To spare the most buffer copy host side should allocate buffer for protobuf and transfer ownership to nim lib.
    # hence nim lib must take care of free the buffer.
    deallocShared(req.argBuffer)
    
    if arg.isErr():
      error "Failed to deserialize request", error = arg.error()
      return

    info "dispatching to send with arg wakuMessage = ", wakuMessage = $arg.get()
    send(arg.get())

proc processRequests(ctx: ptr RequestContext) {.async.} =
  # Main dispatch loop
  while isRequestDispatcherRunning.load:
    # Process incoming requests
    let item = ctx[].incomingQueue.pop()

    if item.isSome():
      info "Processing request", req = item.get().req
      dispatchRequest(item.get())
      # Here we would process the request and potentially put responses
      # in the outgoing queue
      # This is a placeholder for actual processing logic

      # Example of how we might handle a message
      # let wakuMsg = WakuMessage(payload: @[])
      # discard outgoingQueue.tryEnqueue(wakuMsg)

    # Avoid busy waiting
    await sleepAsync(10)

# Thread procedure for dispatching calls
proc dispatcherThreadProc(ctx: ptr RequestContext) {.thread.} =
  info "Dispatcher thread started"
  # Diagnostic: Try to force output to stdout
  init()
  waitFor processRequests(ctx)

  info "Dispatcher thread stopping"

proc createRequestDispatcherEnv*() =
  # do it once
  if not requestDispatcherEnvInitialized.testAndSet():
    info "Initializing run environment"

    # Initialize thread running flag
    isRequestDispatcherRunning.store(true)

    requestContextP = createRequestContext()
    # Start the dispatcher thread
    try:
      info "About to create dispatcher thread"
      createThread(dispatcherThread, dispatcherThreadProc, requestContextP)
      info "Dispatcher thread created successfully"
    except ValueError, ResourceExhaustedError:
      error "Failed to create dispatcher thread"
      freeShared(requestContextP)

proc shutdownRequestDispatcher*() =
  info "Stopping request dispatcher thread"
  isRequestDispatcherRunning.store(false)
  joinThread(dispatcherThread)
