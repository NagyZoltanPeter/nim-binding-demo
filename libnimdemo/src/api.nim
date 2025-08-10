# This is just an example to get you started. A typical library package
# exports the main API in this file. Note that you cannot rename this file
# but you can remove it if you wish.

import stew/byteutils, chronos, times
import chronicles
import protobuf_serialization
import event_dispatcher
import message
import ffi

var managedMsgs {.threadvar.}: seq[WakuMessage]

proc serializeToBuffer[T](obj: T): Result[tuple[buffer: pointer, size: int], void] =
  let bufferSize = Protobuf.computeSize(obj)
  var buffer = allocShared0(bufferSize)

  if buffer == nil:
    error "Cannot allocate memory for protobuf serialization."
    return err()
  var stream = unsafeMemoryOutput(buffer, bufferSize)
  var writer = ProtobufWriter.init(stream)
  let writeResult = catch: writeValue(writer, obj)
  close(stream)

  if writeResult.isErr():
    error "Failed to serialize", error = writeResult.error().msg, obj = $obj
    return err()  
  return ok((buffer: buffer, size: bufferSize))

proc emitOnReceivedEvent(msg: WakuMessage) =
  let event = onReceivedEvent(msg : msg)
  let serialized = serializeToBuffer(event).valueOr:
    error "Cannot emit OnReceivedEvent due to serialization error"
    return

  let (argBuffer, bufferSize) = serialized
  emitEvent("onReceivedEvent", argBuffer, bufferSize)


  # let encoded = Protobuf.encode(event)
  # emitEvent("onReceivedEvent", encoded)
  info "emitting onReceivedEvent", msg = $msg

# Async procedure that processes messages and calls callbacks
proc processMessages() {.async.} =
  while true:
    # Wait for 2 seconds
    await sleepAsync(20)
    # If we have messages and callbacks
    if managedMsgs.len > 0:
      for msg in managedMsgs:
        emitOnReceivedEvent(msg)

    managedMsgs = @[]

proc init*() {.ffi.} =
  managedMsgs.add(
    WakuMessage(payload: cast[seq[byte]]("Test message #1"), content_topic: "/zoltan/1/demo/0")
  )

  # Start the async message processing
  asyncSpawn processMessages()

  info "API initialized, processing started"

proc send*(msg: WakuMessage) {.ffi.} =
  let payload = string.fromBytes(msg.payload)
  info "send API called", msg = $msg, payload = payload
  managedMsgs.add(msg)
  info "message stored at", index = (managedMsgs.len - 1)
