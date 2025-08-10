#pragma once

#include <string>
#include <unordered_map>
#include <functional>
#include <memory>
#include <iostream>

#include "demolib.h"
#include "message.pb.h"
#include "demolib/event_tag.hpp"

class EventHandlerBase {
public:
    virtual ~EventHandlerBase() = default;
    virtual void call(void* data, size_t size) const = 0;
};

template <typename MessageT>
class HandlerImpl : public EventHandlerBase {
public:
    using Callback = std::function<void(const MessageT&)>;
    explicit HandlerImpl(Callback cb) : callback(std::move(cb)) {}

    void call(void* data, size_t size) const override {
        MessageT msg;
        const bool parseSucceeded = msg.ParseFromArray(data, static_cast<int>(size));
        deallocateArgBuffer(data);
        if (parseSucceeded) {
            callback(msg);
        } else {
            std::cerr << "CPP side> Failed to parse protobuf message for event: "
                      << typeid(MessageT).name() << '\n';
        }
    }

private:
    Callback callback;
};

class EventDispatcher {
public:
    template <typename MessageT>
    static void registerHandler(std::function<void(const MessageT&)> cb) {
        registerHandler<MessageT>(EventName<MessageT>::value, std::move(cb));
    }

    template <typename MessageT>
    static void registerHandler(const std::string& name, std::function<void(const MessageT&)> handler) {
        handlers()[name] = std::make_unique<HandlerImpl<MessageT>>(std::move(handler));
    }

    static void dispatch(const std::string& name, void* data, size_t size) {
        auto& map = handlers();
        auto it = map.find(name);
        if (it != map.end()) {
            it->second->call(data, size);
        } else {
            std::cerr << "CPP side> No handler registered for event: " << name << '\n';
            // If no handler, still free the buffer to avoid leaks
            deallocateArgBuffer(data);
        }
    }

private:
    static std::unordered_map<std::string, std::unique_ptr<EventHandlerBase>>& handlers() {
        static std::unordered_map<std::string, std::unique_ptr<EventHandlerBase>> s_handlers;
        return s_handlers;
    }
};
