import std/[options, atomics, locks]
import api
import chronicles
import lockfreequeues/mpsc_queue
import lockfreequeues/spmc_queue
import demolib/[context, message]

# thread and context management
# instantiate mpsc_queue to feed toward nim context thread
#  and spmc_queue for reading on binded side
# exports connector interface

### Library setup

# Every Nim library must have this function called - the name is derived from
# the `--nimMainPrefix` command line option
proc libwakuNimMain() {.importc.}

# To control when the library has been initialized
var libInitialized: AtomicFlag
var runEnvInitialized: AtomicFlag

# Queue for incoming requests (multi-producer, single-consumer)
type RequestItem = object
  req: string
  argBuffer: pointer
  argLen: int

var incomingQueue = mpsc_queue.newMpscQueue[RequestItem](1024)
var outgoingQueue = spmc_queue.newSpmcQueue[WakuMessage](1024)

# Thread synchronization
var dispatcherThread: Thread[void]
var threadRunning: Atomic[bool]

type RunContext = ref object of RootObj
  ctx: Context

proc initializeLibrary() {.exported.} =
  if not libInitialized.testAndSet():
    ## Every Nim library needs to call `<yourprefix>NimMain` once exactly, to initialize the Nim runtime.
    ## Being `<yourprefix>` the value given in the optional compilation flag --nimMainPrefix:yourprefix
    libwakuNimMain()
  when declared(setupForeignThreadGc):
    setupForeignThreadGc()

# Thread procedure for dispatching calls
proc dispatcherThreadProc() {.thread.} =
  info "Dispatcher thread started"
  
  # Setup thread-local GC
  when declared(setupForeignThreadGc):
    setupForeignThreadGc()
  
  # Create context for this thread
  let ctx = initSubmodule()
  
  # Main dispatch loop
  while threadRunning.load:
    # Process incoming requests
    var item: RequestItem
    if incomingQueue.tryDequeue(item):
      info "Processing request", req = item.req
      
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
    
    # Start the dispatcher thread
    createThread(dispatcherThread, dispatcherThreadProc)
    
    info "Dispatcher thread created"

proc addLibCall(
    req: cstring, argBuffer: pointer, argLen: cint
) {.dynlib, exportc, cdecl.} =
  initializeLibrary()
  createRunEnv()
  
  # Convert cstring to string for easier handling
  let reqStr = $req
  info "Adding lib call", req = reqStr, argLen = argLen
  
  # Create request item
  let item = RequestItem(
    req: reqStr,
    argBuffer: argBuffer,
    argLen: int(argLen)
  )
  
  # Add request to queue
  if not incomingQueue.tryEnqueue(item):
    error "Failed to enqueue request, queue might be full", req = reqStr
  else:
    info "Request enqueued successfully", req = reqStr
