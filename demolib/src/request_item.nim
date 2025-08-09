
# Queue for incoming requests (multi-producer, single-consumer)
type RequestItem* = object
  req*: string
  argBuffer*: pointer
  argLen*: int
