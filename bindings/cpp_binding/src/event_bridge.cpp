#include <string>
#include "demolib/event_dispatcher.hpp"

extern "C" void dispatchEvent(const char* event, void* argBuffer, int argLen) {
    std::cout << "CPP side>Dispatching event: " << (event ? event : "null") << " with argLen: " << argLen << std::endl;
    EventDispatcher::dispatch(event ? std::string(event) : std::string(), argBuffer, static_cast<size_t>(argLen));
}

// TODO: dispatchEvent being the high level callback from nim side.
//       Given that it must also get the ID of the context that triggered the event and
//       it must be able to select the correct representing object's dispatcher
//       - object dispatchers must be autoregistered at creation time
//       - registration and selection must be thread safe
