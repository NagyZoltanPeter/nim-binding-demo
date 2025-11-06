#pragma once

#include <string>
#include <vector>
#include <type_traits>
#include <stdexcept>
#include <cstdint>

#include "api_types.pb.h"
// For allocateArgBuffer / deallocateArgBuffer
#include "ffi_interface.h"
// Expected alias (std::expected or tl::expected)
#include "demolib/expected.hpp"


template<typename FromProto, typename ToNative>
expected<ToNative, std::string> deserializeApiType(void* buffer, size_t size) {
    FromProto protoMsg;
    ToNative nativeMsg{};

    if (buffer == nullptr || size == 0) {
        // buffer maybe empty is a valid no value case
        return nativeMsg;
    }

    auto parseResult = protoMsg.ParseFromArray(buffer, static_cast<int>(size));
    deallocateArgBuffer(buffer);
    if (!parseResult) {
        return unexpected(std::string("Failed to parse protobuf message"));
    }


    // ApiString -> std::string
    if constexpr (std::is_same_v<FromProto, ApiString> && std::is_same_v<ToNative, std::string>) {
        nativeMsg = protoMsg.value();
    }
    // ApiBytes -> std::vector<uint8_t>
    else if constexpr (std::is_same_v<FromProto, ApiBytes> && std::is_same_v<ToNative, std::vector<uint8_t>>) {
        const auto& bytes = protoMsg.value();
        nativeMsg.assign(reinterpret_cast<const uint8_t*>(bytes.data()),
                         reinterpret_cast<const uint8_t*>(bytes.data()) + bytes.size());
    }
    // ApiStrings -> std::vector<std::string>
    else if constexpr (std::is_same_v<FromProto, ApiStrings> && std::is_same_v<ToNative, std::vector<std::string>>) {
        nativeMsg.reserve(protoMsg.value_size());
        for (const auto& s : protoMsg.value()) nativeMsg.push_back(s);
    }
    // ApiBool -> bool
    else if constexpr (std::is_same_v<FromProto, ApiBool> && std::is_same_v<ToNative, bool>) {
        nativeMsg = protoMsg.value();
    }
    // ApiInt -> int (int32)
    else if constexpr (std::is_same_v<FromProto, ApiInt> && 
        (std::is_same_v<ToNative, int>) || (std::is_same_v<ToNative, int32_t>) ) {
        nativeMsg = static_cast<ToNative>(protoMsg.value());
    }
    // ApiUInt -> unsigned int (uint32)
    else if constexpr (std::is_same_v<FromProto, ApiUInt> && 
        (std::is_same_v<ToNative, unsigned int>) || (std::is_same_v<ToNative, uint32_t>) ) {
        nativeMsg = static_cast<ToNative>(protoMsg.value());
    }
    // ApiInt64 -> int64_t
    else if constexpr (std::is_same_v<FromProto, ApiInt64> && 
        (std::is_same_v<ToNative, long long>) || (std::is_same_v<ToNative, int64_t>()) ) {
        nativeMsg = static_cast<ToNative>(protoMsg.value());
    }
    // ApiUInt64 -> uint64_t
    else if constexpr (std::is_same_v<FromProto, ApiUInt64> && 
        (std::is_same_v<ToNative, unsigned long long>) || (std::is_same_v<ToNative, uint64_t>()) ) {
        nativeMsg = static_cast<ToNative>(protoMsg.value());
    }
    // ApiFloat -> float
    else if constexpr (std::is_same_v<FromProto, ApiFloat> && std::is_same_v<ToNative, float>) {
        nativeMsg = protoMsg.value();
    }
    // ApiDouble -> double
    else if constexpr (std::is_same_v<FromProto, ApiDouble> && std::is_same_v<ToNative, double>) {
        nativeMsg = protoMsg.value();
    }
    else {
        static_assert(sizeof(FromProto) == 0, "Unsupported type mapping in deserializeApiType");
    }

    return nativeMsg;
}

template<typename TargetType>
expected<TargetType, std::string> deserializeApiType(void* buffer, size_t size) {
    if constexpr (std::is_base_of_v<google::protobuf::Message, TargetType>) {
        TargetType protoMsg;
        if (buffer == nullptr || size == 0) {
            // buffer maybe empty is a valid no value case
            return protoMsg;
        }

        auto parseResult = protoMsg.ParseFromArray(buffer, static_cast<int>(size));
        deallocateArgBuffer(buffer);
        if (!parseResult) {
            return unexpected(std::string("Failed to parse protobuf message"));
        }

        return protoMsg;
    }
    else if constexpr (std::is_same_v<TargetType, std::string>) {
        return deserializeApiType<ApiString, std::string>(buffer, size);
    }
    else if constexpr (std::is_same_v<TargetType, std::vector<uint8_t>>) {
        return deserializeApiType<ApiBytes, std::vector<uint8_t>>(buffer, size);
    }
    else if constexpr (std::is_same_v<TargetType, std::vector<std::string>>) {
        return deserializeApiType<ApiStrings, std::vector<std::string>>(buffer, size);
    }
    else if constexpr (std::is_same_v<TargetType, bool>) {
        return deserializeApiType<ApiBool, bool>(buffer, size);
    }
    else if constexpr (std::is_same_v<TargetType, int>) {
        return deserializeApiType<ApiInt, int>(buffer, size);
    }
    else if constexpr (std::is_same_v<TargetType, unsigned int>) {
        return deserializeApiType<ApiUInt, unsigned int>(buffer, size);
    }
    else if constexpr (std::is_same_v<TargetType, long long>) {
        return deserializeApiType<ApiInt64, long long>(buffer, size);
    }
    else if constexpr (std::is_same_v<TargetType, unsigned long long>) {
        return deserializeApiType<ApiUInt64, unsigned long long>(buffer, size);
    }
    else if constexpr (std::is_same_v<TargetType, float>) {
        return deserializeApiType<ApiFloat, float>(buffer, size);
    }
    else if constexpr (std::is_same_v<TargetType, double>) {
        return deserializeApiType<ApiDouble, double>(buffer, size);
    }
    // Fixed-width integer conveniences
    else if constexpr (std::is_same_v<TargetType, int32_t>) {
        return deserializeApiType<ApiInt, int32_t>(buffer, size);
    }
    else if constexpr (std::is_same_v<TargetType, uint32_t>) {
        return deserializeApiType<ApiUInt, uint32_t>(buffer, size);
    }
    else if constexpr (std::is_same_v<TargetType, int64_t>) {
        return deserializeApiType<ApiInt64, int64_t>(buffer, size);
    }
    else if constexpr (std::is_same_v<TargetType, uint64_t>) {
        return deserializeApiType<ApiUInt64, uint64_t>(buffer, size);
    }
    else {
        static_assert(sizeof(TargetType) == 0, "Unsupported type mapping in deserializeApiType");
    }
}

// Serialize native C++ values into protobuf wrapper messages defined in api_types.proto
// Allocates a buffer using allocateArgBuffer and writes the serialized bytes into it.
// Outputs: outBuffer (ownership transferred to caller/Nim as per API), outSize
template<typename FromNative, typename ToProto>
expected<void, std::string> serializeFromNativeType(const FromNative& nativeMsg, void*& outBuffer, size_t& outSize) {
    ToProto protoMsg;

    // std::string -> ApiString
    if constexpr (std::is_same_v<ToProto, ApiString> && std::is_same_v<FromNative, std::string>) {
        protoMsg.set_value(nativeMsg);
    }
    // std::vector<uint8_t> -> ApiBytes
    else if constexpr (std::is_same_v<ToProto, ApiBytes> && std::is_same_v<FromNative, std::vector<uint8_t>>) {
        const auto* dataPtr = reinterpret_cast<const char*>(nativeMsg.data());
        protoMsg.set_value(std::string(dataPtr, nativeMsg.size()));
    }
    // std::vector<std::string> -> ApiStrings
    else if constexpr (std::is_same_v<ToProto, ApiStrings> && std::is_same_v<FromNative, std::vector<std::string>>) {
        for (const auto& s : nativeMsg) protoMsg.add_value(s);
    }
    // bool -> ApiBool
    else if constexpr (std::is_same_v<ToProto, ApiBool> && std::is_same_v<FromNative, bool>) {
        protoMsg.set_value(nativeMsg);
    }
    // int (int32) -> ApiInt
    else if constexpr (std::is_same_v<ToProto, ApiInt> && 
        (std::is_same_v<FromNative, int>) || (std::is_same_v<FromNative, int32_t>)) {
        protoMsg.set_value(static_cast<int32_t>(nativeMsg));
    }
    // unsigned int (uint32) -> ApiUInt
    else if constexpr (std::is_same_v<ToProto, ApiUInt> && 
        (std::is_same_v<FromNative, unsigned int>) || (std::is_same_v<FromNative, uint32_t>)) {
        protoMsg.set_value(static_cast<uint32_t>(nativeMsg));
    }
    // long long (int64) -> ApiInt64
    else if constexpr (std::is_same_v<ToProto, ApiInt64> && 
        (std::is_same_v<FromNative, long long>) || (std::is_same_v<FromNative, int64_t>)) {
        protoMsg.set_value(static_cast<int64_t>(nativeMsg));
    }
    // unsigned long long (uint64) -> ApiUInt64
    else if constexpr (std::is_same_v<ToProto, ApiUInt64> && 
        (std::is_same_v<FromNative, unsigned long long>) || (std::is_same_v<FromNative, uint64_t>)) {
        protoMsg.set_value(static_cast<uint64_t>(nativeMsg));
    }
    // float -> ApiFloat
    else if constexpr (std::is_same_v<ToProto, ApiFloat> && std::is_same_v<FromNative, float>) {
        protoMsg.set_value(nativeMsg);
    }
    // double -> ApiDouble
    else if constexpr (std::is_same_v<ToProto, ApiDouble> && std::is_same_v<FromNative, double>) {
        protoMsg.set_value(nativeMsg);
    }
    else {
        static_assert(sizeof(ToProto) == 0, "Unsupported type mapping in serializeApiType");
    }

    const int sizeRequired = static_cast<int>(protoMsg.ByteSizeLong());
    void* buffer = allocateArgBuffer(sizeRequired);
    if (buffer == nullptr) {
        return unexpected(std::string("allocateArgBuffer failed"));
    }
    if (!protoMsg.SerializeToArray(buffer, sizeRequired)) {
        deallocateArgBuffer(buffer);
        return unexpected(std::string("Failed to serialize protobuf message"));
    }
    outBuffer = buffer;
    outSize = static_cast<size_t>(sizeRequired);
    return {};
}

template<typename SourceType>
expected<void, std::string> serializeApiType(const SourceType& msg, void*& outBuffer, size_t& outSize) {

    if constexpr (std::is_base_of_v<google::protobuf::Message, SourceType>) {
            
        const int sizeRequired = static_cast<int>(msg.ByteSizeLong());
        void* buffer = allocateArgBuffer(sizeRequired);
        if (buffer == nullptr) {
            return unexpected(std::string("allocateArgBuffer failed"));
        }
        if (!msg.SerializeToArray(buffer, sizeRequired)) {
            deallocateArgBuffer(buffer);
            return unexpected(std::string("Failed to serialize protobuf message"));
        }
        outBuffer = buffer;
        outSize = static_cast<size_t>(sizeRequired);
        return {};
    }
    else if constexpr (std::is_same_v<SourceType, std::string>) {
        return serializeFromNativeType<std::string, ApiString>(msg, outBuffer, outSize);
    }
    else if constexpr (std::is_same_v<SourceType, std::vector<uint8_t>>) {
        return serializeFromNativeType<std::vector<uint8_t>, ApiBytes>(msg, outBuffer, outSize);
    }
    else if constexpr (std::is_same_v<SourceType, std::vector<std::string>>) {
        return serializeFromNativeType<std::vector<std::string>, ApiStrings>(msg, outBuffer, outSize);
    }
    else if constexpr (std::is_same_v<SourceType, bool>) {
        return serializeFromNativeType<bool, ApiBool>(msg, outBuffer, outSize);
    }
    else if constexpr (std::is_same_v<SourceType, int>) {
        return serializeFromNativeType<int, ApiInt>(msg, outBuffer, outSize);
    }
    else if constexpr (std::is_same_v<SourceType, unsigned int>) {
        return serializeFromNativeType<unsigned int, ApiUInt>(msg, outBuffer, outSize);
    }
    else if constexpr (std::is_same_v<SourceType, long long>) {
        return serializeFromNativeType<long long, ApiInt64>(msg, outBuffer, outSize);
    }
    else if constexpr (std::is_same_v<SourceType, unsigned long long>) {
        return serializeFromNativeType<unsigned long long, ApiUInt64>(msg, outBuffer, outSize);
    }
    else if constexpr (std::is_same_v<SourceType, float>) {
        return serializeFromNativeType<float, ApiFloat>(msg, outBuffer, outSize);
    }
    else if constexpr (std::is_same_v<SourceType, double>) {
        return serializeFromNativeType<double, ApiDouble>(msg, outBuffer, outSize);
    }
    // Fixed-width integer conveniences
    else if constexpr (std::is_same_v<SourceType, int32_t>) {
        return serializeFromNativeType<int32_t, ApiInt>(msg, outBuffer, outSize);
    }
    else if constexpr (std::is_same_v<SourceType, uint32_t>) {
        return serializeFromNativeType<uint32_t, ApiUInt>(msg, outBuffer, outSize);
    }
    else if constexpr (std::is_same_v<SourceType, int64_t>) {
        return serializeFromNativeType<int64_t, ApiInt64>(msg, outBuffer, outSize);
    }
    else if constexpr (std::is_same_v<SourceType, uint64_t>) {
        return serializeFromNativeType<uint64_t, ApiUInt64>(msg, outBuffer, outSize);
    }
    else {
        static_assert(sizeof(SourceType) == 0, "Unsupported type mapping in serializeApiType");
    }
}
