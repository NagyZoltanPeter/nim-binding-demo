cmake_minimum_required(VERSION 3.10)
project(cpp_binding VERSION 0.1.0 LANGUAGES CXX)

# C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Dependencies
find_package(Protobuf REQUIRED)
find_package(absl REQUIRED)

# Generate protobuf sources for the binding API messages
if(NOT DEFINED PROJECT_ROOT_DIR)
    # Fallback when built standalone
    get_filename_component(PROJECT_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../.." ABSOLUTE)
endif()

set(PROTO_FILES ${PROJECT_ROOT_DIR}/proto/message.proto)
protobuf_generate_cpp(PROTO_SRCS PROTO_HDRS ${PROTO_FILES})

# Library target
add_library(cpp_binding STATIC
    src/event_bridge.cpp
    ${PROTO_SRCS}
)

# Ensure position independent code for wider compatibility when linking into shared libs
set_target_properties(cpp_binding PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_include_directories(cpp_binding
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
        $<BUILD_INTERFACE:${PROJECT_ROOT_DIR}/demolib/src>
        $<BUILD_INTERFACE:${PROJECT_ROOT_DIR}/demolib/build>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

# Link against demolib.a via the imported target created by the root build,
# and protobuf libs needed by generated sources.
if(NOT TARGET demolib_static)
    message(FATAL_ERROR "Target 'demolib_static' not found. Enable BUILD_DEMOLIB in the root CMake or build from the project root.")
endif()

target_link_libraries(cpp_binding
    PUBLIC
        demolib_static
        ${Protobuf_LIBRARIES}
        absl::log_internal_message
        absl::log_internal_check_op
)
add_dependencies(cpp_binding demolib_static)

# Optional: on macOS, produce a single static library by merging demolib.a into cpp_binding
if(APPLE)
    add_custom_command(TARGET cpp_binding POST_BUILD
        COMMAND /usr/bin/libtool -static -o $<TARGET_FILE_DIR:cpp_binding>/libcpp_binding_merged.a $<TARGET_FILE:cpp_binding> ${PROJECT_ROOT_DIR}/demolib/build/demolib.a
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE_DIR:cpp_binding>/libcpp_binding_merged.a $<TARGET_FILE:cpp_binding>
        COMMENT "Merging demolib.a into libcpp_binding.a (macOS)"
        VERBATIM)
endif()
add_dependencies(cpp_binding demolib_static)

# Optional install (can be customized later)
include(GNUInstallDirs)

install(TARGETS cpp_binding
    EXPORT cpp_bindingTargets
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

# Headers to export for consumers
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/message.pb.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

# Generate and install CMake package config
include(CMakePackageConfigHelpers)
write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/cpp_bindingConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/cpp_bindingConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/cpp_bindingConfig.cmake
    @ONLY
)

install(EXPORT cpp_bindingTargets
    FILE cpp_bindingTargets.cmake
    NAMESPACE cpp_binding::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/cpp_binding
)

install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/cpp_bindingConfig.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/cpp_bindingConfigVersion.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/cpp_binding
)