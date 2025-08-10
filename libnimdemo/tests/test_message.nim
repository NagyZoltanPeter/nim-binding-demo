# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest

import protobuf_serialization
import stew/byteutils
import message

test "encode message":
  var msg =
    WakuMessage(payload: "Test message".toBytes(), content_topic: "/zoltan/1/demo/0")

  let encoded = Protobuf.encode(msg)

  debugEcho "type of encoded is ", encoded.type.name, repr(encoded)

  let decoded = Protobuf.decode(encoded, WakuMessage)

  check decoded.content_topic == "/zoltan/1/demo/0"
  check string.fromBytes(decoded.payload) == "Test message"
