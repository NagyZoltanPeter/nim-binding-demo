import std/[macros, tables, typetraits]
import results
import protobuf_serialization
import message, request_item

type
  FfiEntry* = object
    paramTypeName*: string
    invoke*: proc (buffer: pointer, len: int) {.gcsafe.}

type
  FFILookupTable* = TableRef[string, FfiEntry]
var ffiTable*: FFILookupTable  = newTable[string, FfiEntry]()

# Generic safe demarshal from a raw buffer allocated with allocShared0 / allocShared
proc demarshal*[T](buffer: pointer, len: int): Result[T, string] {.raises: [].} =
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

macro ffi*(procDef: untyped): untyped =
  if procDef.kind != nnkProcDef:
    error "'.ffi' can only be applied to a proc definition"
  let nameStr = $procDef.name
  let nameLit = newLit(nameStr)
  let params = procDef.params
  let procSym = procDef.name

  var registerStmt: NimNode
  if params.len == 1:
    # Zero-argument proc
    let paramTypeNameLit = newLit("")
    registerStmt = quote do:
      ffiTable[`nameLit`] = FfiEntry(
        paramTypeName: `paramTypeNameLit`,
        invoke: proc (buffer: pointer, len: int) {.gcsafe, raises: [].} =
          if not buffer.isNil:
            deallocShared(buffer)
          try:
            `procSym`()
          except CatchableError as e:
            echo "FFI target proc raised: ", e.msg
          except Exception:
            echo "FFI target proc raised (unknown): ", getCurrentExceptionMsg()
      )
  elif params.len == 2:
    # Single-argument proc
    let identDefs = params[1]
    if identDefs.kind != nnkIdentDefs or identDefs.len < 3:
      error "Unexpected parameter AST form in proc " & nameStr
    let paramTypeNode = identDefs[1]
    let paramTypeNameLit = newLit($paramTypeNode)
    registerStmt = quote do:
      ffiTable[`nameLit`] = FfiEntry(
        paramTypeName: `paramTypeNameLit`,
        invoke: proc (buffer: pointer, len: int) {.gcsafe, raises: [].} =
          let res = demarshal[`paramTypeNode`](buffer, len)
          if not buffer.isNil:
            deallocShared(buffer)
          if res.isErr():
            echo "FFI demarshal failed for ", `nameLit`, ": ", res.error()
            return
          try:
            `procSym`(res.get())
          except CatchableError as e:
            echo "FFI target proc raised: ", e.msg
          except Exception:
            echo "FFI target proc raised (unknown): ", getCurrentExceptionMsg()
      )
  else:
    error "FFI proc '" & nameStr & "' must have zero or one parameter"

  result = newStmtList(procDef, registerStmt)
