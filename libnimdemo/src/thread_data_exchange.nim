import taskpools/channels_spsc_single

type ApiCallResult* = enum 
  NIMAPI_FAIL = -1,
  NIMAPI_OK = 0,
  NIMAPI_ERR_NOT_INITIALIZED = 1,
  NIMAPI_ERR_INVALID_ARG = 2,
  NIMAPI_ERR_QUEUE_FULL = 3,
  NIMAPI_ERR_UNKNOWN_PROC = 4,
  NIMAPI_ERR_NO_ANSWER = 5,

type ApiResponse* = tuple
    return_code: int
    buffer: pointer
    len: int

type ApiCallRequest* = object
  req*: string
  argBuffer*: pointer
  argLen*: int
  responseChannel*: ptr ChannelSPSCSingle[ApiResponse]
