# This is just an example to get you started. A typical library package
# exports the main API in this file. Note that you cannot rename this file
# but you can remove it if you wish.

import demolib/[context, message]
import stew/byteutils, chronos, times

var managedMsgs: seq[WakuMessage]

# Define the callback type
type MessageCallback* = proc(msg: WakuMessage) {.gcsafe.}

# Global registry for callbacks
var messageCallbacks: seq[MessageCallback]

# Async procedure that processes messages and calls callbacks
proc processMessages() {.async.} =
  while true:
    # Wait for 2 seconds
    await sleepAsync(2000)

    # If we have messages and callbacks
    if managedMsgs.len > 0 and messageCallbacks.len > 0:
      for msg in managedMsgs:
        for callback in messageCallbacks:
          discard catch(callback(msg))

proc init*() =
  managedMsgs.add(
    WakuMessage(payload: "Test message #1".toBytes(), content_topic: "/zoltan/1/demo/0")
  )

  # Start the async message processing
  asyncSpawn processMessages()

proc send*(msg: WakuMessage) =
  managedMsgs.add(msg)

proc subscribe*(callback: MessageCallback) =
  messageCallbacks.add(callback)

# proc poll*() =
#   discard
