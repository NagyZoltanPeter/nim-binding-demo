import taskpools/channels_spsc_single
	
type ResponseBuffer* = tuple
    buffer*: pointer
    len*: int

type RequestItem* = object
  req*: string
  argBuffer*: pointer
  argLen*: int
  responseChannel*: ptr ChannelSPSCSingle[ResponseBuffer]
