#pragma once

#if __cplusplus >= 202302L
    #include <expected>
    template <typename T, typename E>
    using expected = std::expected<T, E>;
#else
    #include <tl/expected.hpp>
    template <typename T, typename E>
    using expected = tl::expected<T, E>;
#endif
