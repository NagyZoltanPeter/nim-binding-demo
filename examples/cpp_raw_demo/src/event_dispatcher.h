// This is the boilerplate eliminating template, this is part of the C++ glue library

#pragma once

#include <string>
#include <unordered_map>
#include <functional>
#include <memory>
#include <iostream>
#include <google/protobuf/message.h>

#include "demolib.h"
#include "message.pb.h"

template <typename T> struct EventName;

template <> struct EventName<onReceivedEvent> {
    static constexpr const char* value = "onReceivedEvent";
};


class EventHandlerBase {
public:
    virtual ~EventHandlerBase() = default;
    virtual void call(const void* data, size_t size) const = 0;
};

template <typename MessageT>
class HandlerImpl : public EventHandlerBase {
public:
    using Callback = std::function<void(const MessageT&)>;
    HandlerImpl(Callback cb) : callback(std::move(cb)) {}

    void call(const void* data, size_t size) const override {
        MessageT msg;
        if (!msg.ParsePartialFromArray(data, size)) {
            std::cerr << "CPP side>Failed to parse protobuf message for event.\n";
            return;
        }
        callback(msg);
    }

private:
    Callback callback;
};

class EventDispatcher {
public:
template <typename MessageT>
    static void registerHandler(std::function<void(const MessageT&)> cb) {
        registerHandler<MessageT>(EventName<MessageT>::value, cb);
    }

    template<typename MessageT>
    static void registerHandler(const std::string& name, std::function<void(const MessageT&)> handler) {
        handlers[name] = std::make_unique<HandlerImpl<MessageT>>(std::move(handler));
    }

    static void dispatch(const std::string& name, const void* data, size_t size) {
        auto it = handlers.find(name);
        if (it != handlers.end()) {
            it->second->call(data, size);
        } else {
            std::cerr << "CPP side>No handler registered for event: " << name << '\n';
        }
    }

private:
    inline static std::unordered_map<std::string, std::unique_ptr<EventHandlerBase>> handlers{};
};

#ifdef __cplusplus
extern "C" {
#endif


void dispatchEvent(const char* event, void* argBuffer, int argLen)
{
    EventDispatcher::dispatch(event, argBuffer, argLen);
}


#ifdef __cplusplus
}
#endif
