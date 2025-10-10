import std/[options, atomics]
import chronicles
import chronos, chronos/threadsync
import lockfreequeues
import protobuf_serialization

var eventDispatcherEnvInitialized: AtomicFlag

# Queue for incoming requests (multi-producer, single-consumer)
type EventItem* = object
  event*: string
  argBuffer*: pointer
  argLen*: int

type EventContext* = object
  outgoingQueue: Sipsic[1024, EventItem]
  eventSignal: ThreadSignalPtr 


var eventContextP*: ptr EventContext

# Thread synchronization
var dispatcherThread: Thread[ptr EventContext]
var isEventDispatcherRunning: Atomic[bool]

proc createEventContext*(): ptr EventContext =
  result = EventContext.createShared()
  result.eventSignal = ThreadSignalPtr.new().valueOr:
    error "Cannot create event signaling"
    quit(QuitFailure)

proc destroyEventContext(ctx: ptr EventContext) =
  if ctx != nil:
    discard ctx[].eventSignal.close()
    freeShared(ctx)


proc dispatchEvent(event: cstring, argBuffer: pointer, argLen: cint) {.importc: "dispatchEvent".}


# Thread procedure for dispatching calls
proc dispatcherThreadProc(ctx: ptr EventContext) {.thread.} =
  info "Event Dispatcher thread started"
  # Diagnostic: Try to force output to stdout

  # Main dispatch loop
  while isEventDispatcherRunning.load:
    var item = ctx[].outgoingQueue.pop()

    while item.isSome():
      info "Processing event", req = item.get().event
      # it is safe to cast event string to cstring here as we can expect from dispatchEvent implementation
      # to copy it right away and dispatchEvent call is sync.
      dispatchEvent(cstring(item.get().event), item.get().argBuffer, cast[cint](item.get().argLen))
      item = ctx[].outgoingQueue.pop()

    waitFor ctx[].eventSignal.wait()

  info "Event Dispatcher thread stopping"

proc createEventDispatcherEnv*() =
  # do it once
  if not eventDispatcherEnvInitialized.testAndSet():
    info "Initializing event dispatch environment"

    # Initialize thread running flag
    isEventDispatcherRunning.store(true)

    eventContextP = createEventContext()
    # Start the dispatcher thread
    try:
      info "About to create event dispatcher thread"
      createThread(dispatcherThread, dispatcherThreadProc, eventContextP)
      info "Event dispatcher thread created successfully"
    except ValueError, ResourceExhaustedError:
      error "Failed to create event dispatcher thread"
      destroyEventContext(eventContextP)

proc shutdownEventDispatcher*() =
  info "Stopping event dispatcher thread"
  isEventDispatcherRunning.store(false)
  discard eventContextP[].eventSignal.fireSync()
  joinThread(dispatcherThread)
  destroyEventContext(eventContextP)

proc emitEvent*(event: string, argBuffer: pointer, argBufferSize: int) {.async.} =
  let eventItem = EventItem(event: event, argBuffer: argBuffer, argLen: argBufferSize)
  
  if not eventContextP[].outgoingQueue.push(eventItem):
    info "Failed to enqueue event, queue might be full", event = event
    deallocShared(argBuffer)
  else:
    info "Event enqueued successfully", event = event
    await eventContextP[].eventSignal.fire()
