inline ApiCallResultCode init() {
    void* resultBuffer = nullptr;
    int resultLen = 0;
    char* errorDesc = nullptr;
    auto result = syncApiCall(require_cpp_binding_context(), "init", nullptr, 0, &resultBuffer, &resultLen, &errorDesc);
    if (result != ApiCallResultCode::NIMAPI_OK) {
        std::string errorMsg(errorDesc ? errorDesc : "Unknown error");
        if (errorDesc) { deallocateArgBuffer(errorDesc); }
        std::cerr << "Api call error: " << static_cast<int>(result) << " # " << errorMsg << std::endl;
    }
    if (resultBuffer) { deallocateArgBuffer(resultBuffer); }
    return static_cast<ApiCallResultCode>(result);
}


inline ApiCallResultCode send(const WakuMessage& msg) {
    const int sizeRequired = static_cast<int>(msg.ByteSizeLong());
    void* argBuffer = allocateArgBuffer(sizeRequired);
    if (!msg.SerializeToArray(argBuffer, sizeRequired)) {
        std::cerr << "Failed to serialize argument for send" << std::endl;
        deallocateArgBuffer(argBuffer);
        return ApiCallResultCode::NIMAPI_FAIL;
    }
    return (ApiCallResultCode)asyncApiCall(require_cpp_binding_context(), "send", argBuffer, sizeRequired);
    // Ownership of argBuffer is transferred to the Nim library.

}


inline ApiResult<std::vector<std::string>> getPeers() {
    void* returnBuffer = nullptr;
    int returnLen = 0;
    char* errorDesc = nullptr;
    auto result = syncApiCall(require_cpp_binding_context(), "getPeers", nullptr, 0, &returnBuffer, &returnLen, &errorDesc);
    if (result != ApiCallResultCode::NIMAPI_OK) {
        std::string errorMsg(errorDesc ? errorDesc : "Unknown error");
        if (errorDesc) { deallocateArgBuffer(errorDesc); }
        std::cerr << "Api call error: " << errorMsg << std::endl;
        return tl::unexpected(ApiError{result, errorMsg});
    }
    std::vector<std::string> out;
    if (returnBuffer && returnLen > 0) {
        ApiStrings decoded;
        if (decoded.ParseFromArray(returnBuffer, returnLen)) {
            for (const auto& s : decoded.value()) { out.push_back(s); }
        }
        deallocateArgBuffer(returnBuffer);
    }
    return out;
}
