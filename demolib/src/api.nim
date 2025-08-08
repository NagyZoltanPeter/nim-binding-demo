# This is just an example to get you started. A typical library package
# exports the main API in this file. Note that you cannot rename this file
# but you can remove it if you wish.

import stew/byteutils, chronos, times
import chronicles
import protobuf_serialization
import event_dispatcher
import message

var managedMsgs {.threadvar.}: seq[WakuMessage]

proc emitOnReceivedEvent(msg: WakuMessage) =
  let event = onReceivedEvent(msg : msg)
  let bufferSize = Protobuf.computeSize(event) 
  var argBuffer = allocShared0(bufferSize)

  var stream = unsafeMemoryOutput(argBuffer, bufferSize)
  # Create the protobuf writer
  var writer = ProtobufWriter.init(stream)
  # Write the event directly to the buffer
  writeValue(writer, event)
  # Close the stream to ensure all data is written
  close(stream)  
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

proc init*() =
  managedMsgs.add(
    WakuMessage(payload: cast[seq[byte]]("Test message #1"), content_topic: "/zoltan/1/demo/0")
  )

  # Start the async message processing
  asyncSpawn processMessages()

  info "API initialized, processing started"

proc send*(msg: WakuMessage) =
  let payload = string.fromBytes(msg.payload)
  info "handling send request", msg = $msg, payload = payload
  managedMsgs.add(msg)
  info "message stored at", count = managedMsgs.len
