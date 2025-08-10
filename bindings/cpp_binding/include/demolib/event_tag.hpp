#pragma once

// Forward declaration template mapping C++ message types to event names.
// Specialize this for each event type:
//   template <> struct EventName<MyEvent> { static constexpr const char* value = "myEvent"; };

template <typename T> struct EventName;
