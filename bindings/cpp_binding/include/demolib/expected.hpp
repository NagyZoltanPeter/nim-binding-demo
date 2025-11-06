#pragma once

#if __cplusplus >= 202302L
    #include <expected>
    template <typename T, typename E>
    using expected = std::expected<T, E>;
    template <typename E>
    using unexpected = std::unexpected<E>;
#else
    #include <tl/expected.hpp>
    // using namespace tl;
    template <typename T, typename E>
    using expected = tl::expected<T, E>;
    template <typename E>
    using unexpected = tl::unexpected<E>;
#endif
