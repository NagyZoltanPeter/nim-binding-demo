import std/[options, atomics, locks, os]
import chronicles
import lockfreequeues
import protobuf_serialization
import message, api

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

# Queue for incoming requests (multi-producer, single-consumer)
type RequestItem = object
  req: string
  argBuffer: pointer
  argLen: int

type ThreadContext = object
  incomingQueue: Mupsic[1024, 16, RequestItem]
  outgoingQueue: Sipsic[1024, WakuMessage]

var threadContextP: ptr ThreadContext

# Thread synchronization
var dispatcherThread: Thread[ptr ThreadContext]
var threadRunning: Atomic[bool]

proc createContext(): ptr ThreadContext =
  result = ThreadContext.createShared()
  # result.incomingQueue = initMupsic[1024, 16, RequestItem]
  # result.outgoingQueue = initSipsic[1024, WakuMessage]

proc initializeLibrary() = # {.exported.} =
  if not libInitialized.testAndSet():
    ## Every Nim library needs to call `<yourprefix>NimMain` once exactly, to initialize the Nim runtime.
    ## Being `<yourprefix>` the value given in the optional compilation flag --nimMainPrefix:yourprefix
    libdemoNimMain()

    when declared(setupForeignThreadGc):
      setupForeignThreadGc()

proc dispatchRequest(req: RequestItem) =
  debugEcho "dispatchRequest to ", req.req
  if req.req == "Send":
    let bytePtr = cast[ptr UncheckedArray[byte]](req.argBuffer)
    let arg = Protobuf.decode(toOpenArray(bytePtr, 0, req.argLen - 1), WakuMessage)
    debugEcho "dispatchingArg wakuMessage = ", $arg
    send(arg)

# Thread procedure for dispatching calls
proc dispatcherThreadProc(ctx: ptr ThreadContext) {.thread.} =
  info "Dispatcher thread started"

  initializeLibrary()

  # Main dispatch loop
  while threadRunning.load:
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
    sleep(10)

  info "Dispatcher thread stopping"

proc createRunEnv() =
  # do it once
  if not runEnvInitialized.testAndSet():
    info "Initializing run environment"

    # Initialize thread running flag
    threadRunning.store(true)

    threadContextP = createContext()
    # Start the dispatcher thread
    try:
      createThread(dispatcherThread, dispatcherThreadProc, threadContextP)
    except ValueError, ResourceExhaustedError:
      freeShared(threadContextP)

    info "Dispatcher thread created"

proc exec*(req: cstring, argBuffer: pointer, argLen: cint) {.dynlib, exportc, cdecl.} =
  initializeLibrary()
  createRunEnv()

  # Convert cstring to string for easier handling
  let reqStr = $req
  info "Adding lib call", req = reqStr, argLen = argLen

  # Create request item
  let item = RequestItem(req: reqStr, argBuffer: argBuffer, argLen: int(argLen))

  info "request item created and about to be pushed"

  # Add request to queue
  if not threadContextP[].incomingQueue.push(item):
    error "Failed to enqueue request, queue might be full", req = reqStr
  else:
    info "Request enqueued successfully", req = reqStr

  info "request pushed", $threadContextP[].incomingQueue.storage.len
