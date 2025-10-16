#include <string>
#include "demolib/event_dispatcher.hpp"

extern "C" void dispatchEvent(const char* event, void* argBuffer, int argLen) {
    std::cout << "CPP side>Dispatching event: " << (event ? event : "null") << " with argLen: " << argLen << std::endl;
    EventDispatcher::dispatch(event ? std::string(event) : std::string(), argBuffer, static_cast<size_t>(argLen));
}
