import std/[options, atomics, locks, os]
import chronicles
import lockfreequeues
import protobuf_serialization
import message, api

when not declared(c_malloc):
  proc c_malloc(size: csize_t): pointer {.
    importc: "malloc", header: "<stdlib.h>".}
  proc c_free(p: pointer) {.
    importc: "free", header: "<stdlib.h>".}

var eventDispatcherEnvInitialized: AtomicFlag

# Queue for incoming requests (multi-producer, single-consumer)
type EventItem* = object
  event*: string
  argBuffer*: pointer
  argLen*: int

type EventContext* = object
  outgoingQueue: Sipsic[1024, EventItem]

var eventContextP*: ptr EventContext

# Thread synchronization
var dispatcherThread: Thread[ptr EventContext]
var isEventDispatcherRunning: Atomic[bool]

proc createEventContext*(): ptr EventContext =
  result = EventContext.createShared()

proc dispatchEvent(event: cstring, argBuffer: pointer, argLen: cint) {.importc: "dispatchEvent".}


# Thread procedure for dispatching calls
proc dispatcherThreadProc(ctx: ptr EventContext) {.thread.} =
  info "Event Dispatcher thread started"
  # Diagnostic: Try to force output to stdout

  # Main dispatch loop
  while isEventDispatcherRunning.load:
    # Process incoming requests
    let item = ctx[].outgoingQueue.pop()

    if item.isSome():
      info "Processing event", req = item.get().event
      dispatchEvent(item.get().event, item.get().argBuffer, cast[cint](item.get().argLen))

    # Avoid busy waiting
    sleep(10)

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
      freeShared(eventContextP)

proc shutdownEventDispatcher*() =
  info "Stopping event dispatcher thread"
  isEventDispatcherRunning.store(false)
  joinThread(dispatcherThread)

proc emitEvent*(event: string, argBuffer: pointer, argBufferSize: int) =
  let eventItem = EventItem(event: event, argBuffer: argBuffer, argLen: argBufferSize)
  
  if not eventContextP[].outgoingQueue.push(eventItem):
    info "Failed to enqueue event, queue might be full", event = event
    deallocShared(argBuffer)
  else:
    info "Event enqueued successfully", event = event

