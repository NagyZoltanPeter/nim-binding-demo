import std/[typetraits]
import results
import protobuf_serialization

# Generic safe deserialization from a raw buffer allocated with allocShared0 / allocShared
proc deserialize*[T](buffer: pointer, len: int): Result[T, string] {.raises: [].} =
  if buffer.isNil:
    return err("nil buffer")
  if len <= 0:
    return err("non-positive length")
  var stream = unsafeMemoryInput(toOpenArray(cast[ptr UncheckedArray[byte]](buffer), 0, len - 1))
  try:
    var reader = ProtobufReader.init(stream)
    let value = readValue(reader, T)
    ok(value)
  except CatchableError as e:
    err(e.msg)
  except Exception:
    err(getCurrentExceptionMsg())
  # Note: memory input stream does not require explicit close and declaring
  # raises:[] forbids listing close which may raise IOError; let GC clean it up.

template wrapForSerialize[T](obj: T): untyped =
  when T is int32:
    type I32Wrapper {.proto3.} = object
      v {.fieldNumber: 1, sint.}: int32
    I32Wrapper(v: obj)
  elif T is uint32:
    type U32Wrapper {.proto3.} = object
      v {.fieldNumber: 1, pint.}: uint32
    U32Wrapper(v: obj)
  elif T is int64:
    type I64Wrapper {.proto3.} = object
      v {.fieldNumber: 1, sint.}: int64
    I64Wrapper(v: obj)
  elif T is uint64:
    type U64Wrapper {.proto3.} = object
      v {.fieldNumber: 1, pint.}: uint64
    U64Wrapper(v: obj)
  elif T is (bool or float32 or float64 or string or seq[byte]):
    type ScalarWrapper {.proto3.} = object
      v {.fieldNumber: 1.}: T
    ScalarWrapper(v: obj)
  else:
    obj

proc computeSerializedSize*[T](obj: T): Result[int, string] =
  when T is (int32 or uint32 or int64 or uint64 or bool or float32 or float64 or string or seq[byte]):
    let wrapped = wrapForSerialize(obj)
    ok(Protobuf.computeSize(wrapped))
  else:
    ok(Protobuf.computeSize(obj))

proc writeSerialized*[T](obj: T, buffer: pointer, size: int): Result[void, string] =
  var stream = unsafeMemoryOutput(buffer, size)
  var writer = ProtobufWriter.init(stream)
  when T is (int32 or uint32 or int64 or uint64 or bool or float32 or float64 or string or seq[byte]):
    let wrapped = wrapForSerialize(obj)
    let writeResult = catch:
      writeValue(writer, wrapped)
    close(stream)
    if writeResult.isErr():
      return err("Failed to serialize: " & writeResult.error().msg)
    return ok()
  else:
    let writeResult = catch:
      writeValue(writer, obj)
    close(stream)
    if writeResult.isErr():
      return err("Failed to serialize: " & writeResult.error().msg)
    return ok()

proc serialize*[T](obj: T): Result[tuple[buffer: pointer, size: int], string] =
  let sizeRes = computeSerializedSize(obj)
  if sizeRes.isErr():
    return err(sizeRes.error())
  let bufferSize = sizeRes.get()
  var buffer = allocShared0(bufferSize)
  if buffer == nil:
    error "Cannot allocate memory for protobuf serialization."
    return err("Cannot allocate memory for protobuf serialization.")
  let wr = writeSerialized(obj, buffer, bufferSize)
  if wr.isErr():
    deallocShared(buffer)
    return err(wr.error())
  ok((buffer: buffer, size: bufferSize))
