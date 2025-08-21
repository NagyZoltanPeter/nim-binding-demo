# Ideas and task list for completion

## Problems

## Ideas for enhancments

## TODOs

- support multiple contexts
  - each context represents a separate NIM request thread with separate event dispatch thread.
  - context handle/id shall be part of each API call in host language side
- synchronous calls with return data
  - sync calls must block requester thread and return code and value must be handled. 
- support for simple single values passing - to ease the use of API definition.
As not always needed to define complex structures for each api calls and response.
  - ApiInt, ApiFloat, ApiString, ApiBytes, ApiStrings
- Error handling
  - ApiResult is status code and optional error message
    - status code 0 is success
-   API (.ffi.) procs must use
    -      Result[void, ApiResult] 
    -      Result[<ApiInt/ApiString/ApiBytes/ApiFloat>, ApiResult]
    -      Result[<Proto defined struct>, ApiResult]
- Protobuf definition schema
  - Data structures must be defined as any regular `message` type
  - Api Calls shall follow the prefixing convention
    - `ApiCall`+Methodname for Api requests
    - `OnEvent`+Eventname for events
  - Inside the message definition, fields must be prefixed as:
    - `Arg`+ArgumentName
      - Currently only one argument is supported, multiple arguments must be boundled into separate type definition
    - `Ret`+ReturnValueName
      - Only one return value is supported, multiple return values must be boundled into separate type definition
- Currently event dispatch needs an explicit export from host language binding library (that links/boundles nim library).
  - It seems a better option to pass the fn pointer with the correct signature in nim library init function and use it dynamically.
- 