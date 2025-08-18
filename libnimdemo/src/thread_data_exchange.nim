import taskpools/channels_spsc_single

type ApiCallResult* = cint
const 
  NIMAPI_FAIL* : ApiCallResult = -1
  NIMAPI_OK* : ApiCallResult = 0
  NIMAPI_ERR_NOT_INITIALIZED* : ApiCallResult = 1
  NIMAPI_ERR_INVALID_ARG* : ApiCallResult = 2
  NIMAPI_ERR_QUEUE_FULL* : ApiCallResult = 3
  NIMAPI_ERR_UNKNOWN_PROC* : ApiCallResult = 4
  NIMAPI_ERR_NO_ANSWER* : ApiCallResult = 5

type ApiResponse* = tuple
    return_code: int
    buffer: pointer
    len: int

type ApiCallRequest* = object
  req*: string
  argBuffer*: pointer
  argLen*: int
  responseChannel*: ptr ChannelSPSCSingle[ApiResponse]
