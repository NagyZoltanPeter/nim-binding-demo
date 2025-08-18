#pragma once

// Single-include public facade for the C++ binding consumers.
// Provides:
//  - C API interop from libnimdemo.h
//  - EventDispatcher utilities
//  - EventName specializations for known events
//  - Convenience API wrappers (init, send)

#include "libnimdemo.h"         // C API from Nim
#include "message.pb.h"         // Protobuf messages
#include "demolib/event_dispatcher.hpp"
#include "demolib/event_tag.hpp"

void cpp_binding_initialize(void) {
    GOOGLE_PROTOBUF_VERIFY_VERSION;
    libnimdemo_initialize();
}

void cpp_binding_teardown(void) {
    libnimdemo_teardown();
    // Clean up protobuf
    google::protobuf::ShutdownProtobufLibrary();
}

// Known events mapping (extend as new events are added)
// Proto defines: message onReceivedEvent { WakuMessage msg = 1; }
struct onReceivedEvent; // forward from proto message

template <> struct EventName<onReceivedEvent> {
    static constexpr const char* value = "onReceivedEvent";
};

// Convenience C++ wrappers for C API
inline void init() {
    asyncApiCall("init", nullptr, 0);
}

inline void send(const WakuMessage& waku_msg) {
    const int sizeRequired = static_cast<int>(waku_msg.ByteSizeLong());
    void* argBuffer = allocateArgBuffer(sizeRequired);
    if (!waku_msg.SerializeToArray(argBuffer, sizeRequired)) {
        std::cerr << "Failed to serialize WakuMessage" << std::endl;
        deallocateArgBuffer(argBuffer);
        return;
    }
    asyncApiCall("send", argBuffer, sizeRequired);
    // Ownership of argBuffer is transferred to the Nim library.
}
