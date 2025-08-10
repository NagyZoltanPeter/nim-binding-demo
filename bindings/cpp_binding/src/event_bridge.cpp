#include <string>
#include "demolib/event_dispatcher.hpp"

extern "C" void dispatchEvent(const char* event, void* argBuffer, int argLen) {
    EventDispatcher::dispatch(event ? std::string(event) : std::string(), argBuffer, static_cast<size_t>(argLen));
}
