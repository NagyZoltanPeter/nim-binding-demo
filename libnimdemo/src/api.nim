# This is just an example to get you started. A typical library package
# exports the main API in this file. Note that you cannot rename this file
# but you can remove it if you wish.

import stew/byteutils, chronos
import chronicles
import protobuf_serialization
import event_dispatcher
import message
import ffi, serde

var managedMsgs {.threadvar.}: seq[WakuMessage]

proc emitOnReceivedEvent(msg: WakuMessage) {.async.} =
  let event = onReceivedEvent(msg : msg)
  let serialized = serialize(event).valueOr:
    error "Cannot emit OnReceivedEvent due to serialization error", error = error
    return

  info "emitting onReceivedEvent", msg = $msg
  let (argBuffer, bufferSize) = serialized
  await emitEvent("onReceivedEvent", argBuffer, bufferSize)

# Async procedure that processes messages and calls callbacks
proc processMessages() {.async.} =
  while true:
    await sleepAsync(chronos.milliseconds(200))
    # If we have messages and callbacks
    if managedMsgs.len > 0:
      for msg in managedMsgs:
        await emitOnReceivedEvent(msg)

    managedMsgs = @[]

proc init*(): Result[void, string]{.ffi.} =
  managedMsgs.add(
    WakuMessage(payload: cast[seq[byte]]("Test message #1"), content_topic: "/zoltan/1/demo/0")
  )

  # Start the async message processing
  asyncSpawn processMessages()

  info "API initialized, processing started"
  return ok()


proc send*(msg: WakuMessage): Result[int32, string] {.ffi.} =
  let payload = string.fromBytes(msg.payload)
  info "send API called", msg = $msg, payload = payload
  managedMsgs.add(msg)
  info "message stored at", index = (managedMsgs.len - 1)
  return ok(int32(managedMsgs.len - 1))
