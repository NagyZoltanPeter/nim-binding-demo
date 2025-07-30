# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest
import os
import stew/byteutils
# import protobuf_serialization
# import message

import protobuf_serialization
import protobuf_serialization/files/type_generator
# This generates the same definition as above using a compile-time macro / parser
import_proto3 "../../proto/message.proto"

# Declare the C functions from the header
proc exec(
  req: cstring, argBuffer: pointer, argLen: cint
) {.header: "../src/demolib.h", importc.}

test "dispatch calls":
  var msg =
    WakuMessage(payload: "Test message".toBytes(), content_topic: "/zoltan/1/demo/0")
  let encoded = Protobuf.encode(msg)

  # Get pointer and length from the encoded sequence
  let encodedPtr = cast[pointer](unsafeAddr encoded[0])
  let encodedLen = cint(encoded.len)

  # Call the exec procedure with "Send" command and the encoded message
  exec("Send", encodedPtr, encodedLen)

  # Sleep briefly to allow the message to be processed
  sleep(100)
