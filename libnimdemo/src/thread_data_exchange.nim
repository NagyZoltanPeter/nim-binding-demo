import taskpools/channels_spsc_single
import results

type ApiCallResultCode* = cint
const 
  NIMAPI_FAIL* : ApiCallResultCode = -1
  NIMAPI_OK* : ApiCallResultCode = 0
  NIMAPI_ERR_NOT_INITIALIZED* : ApiCallResultCode = 1
  NIMAPI_ERR_INVALID_ARG* : ApiCallResultCode = 2
  NIMAPI_ERR_QUEUE_FULL* : ApiCallResultCode = 3
  NIMAPI_ERR_UNKNOWN_PROC* : ApiCallResultCode = 4
  NIMAPI_ERR_NO_ANSWER* : ApiCallResultCode = 5
  NIMAPI_ERR_SERIALIZATION* : ApiCallResultCode = 6

type ApiResponse* = object
    returnCode*: cint
    errorDesc*: string
    buffer*: pointer
    len*: int

type ApiCallRequest* = object
  req*: string
  argBuffer*: pointer
  argLen*: int
  responseChannel*: ptr ChannelSPSCSingle[ptr ApiResponse]

proc createShared*(
    T: type ApiResponse,
    returnCode: cint,
    errorDesc: string = "",
    buffer: pointer = nil,
    len: int = 0
): ptr type T =
  var ret = createShared(T)
  ret[].returnCode = returnCode
  ret[].errorDesc = errorDesc
  ret[].buffer = buffer
  ret[].len = len
  return ret