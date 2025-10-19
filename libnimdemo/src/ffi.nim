import std/[macros, tables, typetraits]
import results
import protobuf_serialization
import thread_data_exchange, serde

type
  FfiEntry* = object
    paramTypeName*: string
    invoke*: proc (buffer: pointer, len: int, result: var ApiResponse, call: InvokeType) {.gcsafe.}

type
  FFILookupTable* = TableRef[string, FfiEntry]
var ffiTable*: FFILookupTable  = newTable[string, FfiEntry]()

macro ffi*(procDef: untyped): untyped =
  if procDef.kind != nnkProcDef:
    error "'.ffi' can only be applied to a proc definition"
  let nameStr = $procDef.name
  let nameLit = newLit(nameStr)
  let params = procDef.params
  let procSym = procDef.name
  let returnType = procDef.params[0]

  let okReturnType =
    if (returnType.kind == nnkBracketExpr and eqIdent(returnType[0], "Result") and returnType.len == 3 and eqIdent(returnType[2], "string")):
      returnType[1]
    else:
      error(
        "Expected return type of 'Result[T, string]' got '" & repr(returnType) & "'", procDef)

  let isVoidResult = eqIdent(okReturnType, "void")
  var returnTypeHandlingStmt: NimNode
  let rSym = genSym(nskLet, "r")
  let responseSym = genSym(nskParam, "response")
  if isVoidResult:
    returnTypeHandlingStmt = quote do:
      if `rSym`.isErr():
        echo "FFI target proc returned error: ", `rSym`.error()
        `responseSym`.returnCode = NIMAPI_FAIL
        `responseSym`.errorDesc = `rSym`.error()
      else:
        `responseSym`.returnCode = NIMAPI_OK
  else:
    returnTypeHandlingStmt = quote do:
      if `rSym`.isErr():
        echo "FFI target proc returned error: ", `rSym`.error()
        `responseSym`.returnCode = NIMAPI_FAIL
        `responseSym`.errorDesc = `rSym`.error()
      else:
        `responseSym`.returnCode = NIMAPI_OK
        let serRes = serialize(`rSym`.get()).valueOr:
          echo "Failed to serialize response"
          `responseSym`.errorDesc = error
          `responseSym`.returnCode = NIMAPI_ERR_SERIALIZATION
          return
        `responseSym`.buffer = serRes.buffer
        `responseSym`.len = serRes.size

  var registerStmt: NimNode
  if params.len == 1:
    # Zero-argument proc
    let paramTypeNameLit = newLit("")
    registerStmt = quote do:
      ffiTable[`nameLit`] = FfiEntry(
        paramTypeName: `paramTypeNameLit`,
        invoke: proc (buffer: pointer, len: int, `responseSym`: var ApiResponse, call: InvokeType) {.gcsafe, raises: [].} =
          if not buffer.isNil:
            echo "FFI target proc does not accepts argument and shall not be provided"
            deallocShared(buffer)
          try:
            let `rSym` = `procSym`()
            `returnTypeHandlingStmt`

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
      # TODO: find out how to call chronicles log macro inside a macro... (macros.nim defines same name compile time loggings)
      ffiTable[`nameLit`] = FfiEntry(
        paramTypeName: `paramTypeNameLit`,
        invoke: proc (buffer: pointer, len: int, `responseSym`: var ApiResponse, call: InvokeType) {.gcsafe, raises: [].} =
          `responseSym`.buffer = nil
          `responseSym`.len = 0
          `responseSym`.return_code = NIMAPI_FAIL

          let res = deserialize[`paramTypeNode`](buffer, len)
          if not buffer.isNil:
            deallocShared(buffer)
          if res.isErr():
            echo "FFI deserialize failed for ", `nameLit`, ": ", res.error()
            return
          try:
            let `rSym` =`procSym`(res.get())
            `returnTypeHandlingStmt`

          except CatchableError as e:
            echo "FFI target proc raised: ", e.msg
          except Exception:
            echo "FFI target proc raised (unknown): ", getCurrentExceptionMsg()
      )
  else:
    error "FFI proc '" & nameStr & "' must have zero or one parameter"

  result = newStmtList(procDef, registerStmt)
  debugEcho "Generated FFI proc: ", repr(result)
