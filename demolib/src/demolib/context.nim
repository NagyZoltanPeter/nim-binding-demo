# This is just an example to get you started. Users of your library will
# import this file by writing ``import demolib/submodule``. Feel free to rename or
# remove this file altogether. You may create additional modules alongside
# this file as required.

import results
import ./message

type Context* = object
  name*: string

proc initSubmodule*(): Context =
  ## Initialises a new ``Submodule`` object.
  Context(name: "Anonymous")

proc send(c: Context, msg: WakuMessage): Result[uint32, string] =
  discard

proc poll(c: Context): Result[WakuMessage, string] =
  discard
