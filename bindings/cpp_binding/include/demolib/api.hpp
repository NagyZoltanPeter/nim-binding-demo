#pragma once

// Single-include public facade for the C++ binding consumers.
// Provides:
//  - C API interop from libnimdemo.h
//  - EventDispatcher utilities
//  - EventName specializations for known events
//  - Convenience API wrappers (init, send)

#include "libnimdemo.h"         // C API from Nim
#include "message.pb.h"         // Protobuf messages
#include "api_types.pb.h"
#include "demolib/event_dispatcher.hpp"
#include "demolib/event_tag.hpp"

// ToDo: find proper place for this def
#include "demolib/expected.hpp"

struct ApiError {
    int code;
    std::string desc;
};

template <typename T> using ApiResult = tl::expected<T, ApiError>;

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
inline ApiCallResultCode init() {
    void* resultBuffer = nullptr;
    int resultLen = 0;
    char* errorDesc = nullptr;
    auto result = syncApiCall("init", nullptr, 0, &resultBuffer, &resultLen, &errorDesc);
    if (result != ApiCallResultCode::NIMAPI_OK) {
        std::string errorMsg(errorDesc ? errorDesc : "Unknown error");
        deallocateArgBuffer(errorDesc);
        std::cerr << "Api call error: " << static_cast<int>(result) << " # " << errorMsg << std::endl;
    }
    return static_cast<ApiCallResultCode>(result);
}

inline ApiCallResultCode send(const WakuMessage& waku_msg, std::function<void(const onReceivedEvent&)> onReceiveCb = nullptr) {
    if (onReceiveCb) { EventDispatcher::registerHandler<onReceivedEvent>(std::move(onReceiveCb)); }
    const int sizeRequired = static_cast<int>(waku_msg.ByteSizeLong());
    void* argBuffer = allocateArgBuffer(sizeRequired);
    if (!waku_msg.SerializeToArray(argBuffer, sizeRequired)) {
        std::cerr << "Failed to serialize WakuMessage" << std::endl;
        deallocateArgBuffer(argBuffer);
        return ApiCallResultCode::NIMAPI_FAIL;
    }
    return (ApiCallResultCode)asyncApiCall("send", argBuffer, sizeRequired);
    // Ownership of argBuffer is transferred to the Nim library.
}

inline ApiResult<std::vector<std::string>> getPeers() {
    void* returnBuffer = nullptr;
    int returnLen = 0;
    char* errorDesc = nullptr;
    auto result = syncApiCall("getPeers", nullptr, 0, &returnBuffer, &returnLen, &errorDesc);

    if (result != ApiCallResultCode::NIMAPI_OK) {
        std::cerr << "Failed to get peers: " << static_cast<int>(result) << std::endl;
        std::string errorMsg(errorDesc ? errorDesc : "Unknown error");
        deallocateArgBuffer(errorDesc);
        std::cerr << "Api call error: " << errorMsg << std::endl;
        return tl::unexpected(ApiError{result, errorMsg});
    }

    std::vector<std::string> peers;
    if (returnBuffer && returnLen > 0) {
        ApiStrings peerList;
        if (peerList.ParseFromArray(returnBuffer, returnLen)) {
            for (const auto& peer : peerList.value()) {
                peers.push_back(peer);
            }
        }
        deallocateArgBuffer(returnBuffer);
    }
    return peers;
}