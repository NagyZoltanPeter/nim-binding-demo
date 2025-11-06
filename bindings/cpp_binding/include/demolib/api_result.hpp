#pragma once

#include "demolib/expected.hpp"

struct ApiError {
    int code;
    std::string desc;
};

template <typename T> using ApiResult = expected<T, ApiError>;
using ApiUnexpected = unexpected<ApiError>;
