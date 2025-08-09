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
  let bytePtr = cast[ptr UncheckedArray[byte]](buffer)
  try:
    ok(Protobuf.decode(toOpenArray(bytePtr, 0, len - 1), T))
  except CatchableError as e:
    err(e.msg)
  except Exception:
    err(getCurrentExceptionMsg())

macro ffi*(procDef: untyped): untyped =
  if procDef.kind != nnkProcDef:
    error "'.ffi' can only be applied to a proc definition"
  let nameStr = $procDef.name
  let nameLit = newLit(nameStr)
  let params = procDef.params
  # params[0] is return type, expect exactly one explicit param => total len == 2
  if params.len != 2:
    error "FFI proc '" & nameStr & "' must have exactly one parameter"
  let identDefs = params[1]
  if identDefs.kind != nnkIdentDefs or identDefs.len < 3:
    error "Unexpected parameter AST form in proc " & nameStr
  # identDefs layout: <ident> <type> <default or empty>
  let paramTypeNode = identDefs[1]
  let paramTypeNameLit = newLit($paramTypeNode)
  let procSym = procDef.name
  # Registration statement appended after original proc
  let registerStmt = quote do:
    ffiTable[`nameLit`] = FfiEntry(
      paramTypeName: `paramTypeNameLit`,
      invoke: proc (buffer: pointer, len: int) {.gcsafe, raises: [].} =
        let res = demarshal[`paramTypeNode`](buffer, len)
        # Always free producer-owned shared memory after copying
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
  hint "Registered FFI proc: name = " & nameStr & " paramType = " & $paramTypeNode
  result = newStmtList(procDef, registerStmt)

# Example FFI procs (you can place these in other modules too; they auto-register)
# proc Send*(msg: WakuMessage) {.ffi.} =
#   info "Send called", msg = $msg

# proc Subscribe*(sub: Subscription) {.ffi.} =
#   info "Subscribe called", sub = $sub