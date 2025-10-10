cmake_minimum_required(VERSION 3.10)
project(cpp_binding VERSION 0.1.0 LANGUAGES CXX)

# C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Dependencies
find_package(Protobuf REQUIRED)
find_package(absl REQUIRED)

include(FetchContent)

FetchContent_Declare(
    tl_expected
    GIT_REPOSITORY https://github.com/TartanLlama/expected.git
    GIT_TAG        v1.3.1
)

FetchContent_MakeAvailable(tl_expected)


# Generate protobuf sources for the binding API messages
if(NOT DEFINED PROJECT_ROOT_DIR)
    # Fallback when built standalone
    get_filename_component(PROJECT_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../.." ABSOLUTE)
endif()

# Define protobuf source directory
set(PROTO_DIR "${PROJECT_ROOT_DIR}/proto")

# Collect all .proto files from the proto directory
file(GLOB_RECURSE PROTO_FILES
    "${PROTO_DIR}/*.proto"
)

# Validate that proto files exist
if(NOT PROTO_FILES)
    message(FATAL_ERROR "No .proto files found in ${PROTO_DIR}. Ensure protobuf files are present.")
endif()

# Validate protobuf package is available
if(NOT Protobuf_FOUND)
    message(FATAL_ERROR "Protobuf package not found. Please install protobuf development libraries.")
endif()

# Generate C++ sources and headers from protobuf files
protobuf_generate_cpp(PROTO_SRCS PROTO_HDRS ${PROTO_FILES})

# Add custom target for protobuf generation to enable proper dependency tracking
add_custom_target(generate_proto_files
    DEPENDS ${PROTO_SRCS} ${PROTO_HDRS}
    COMMENT "Generating C++ files from protobuf definitions"
)


# Library target
add_library(cpp_binding STATIC
src/event_bridge.cpp
${PROTO_SRCS}
)

# Ensure protobuf files are generated before building the library
add_dependencies(cpp_binding generate_proto_files)

# Ensure position independent code for wider compatibility when linking into shared libs
set_target_properties(cpp_binding PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_include_directories(cpp_binding
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
    $<BUILD_INTERFACE:${PROJECT_ROOT_DIR}/libnimdemo/src>
    $<BUILD_INTERFACE:${PROJECT_ROOT_DIR}/libnimdemo/build>
    $<BUILD_INTERFACE:${tl_expected_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

# Link against demolib.a via the imported target created by the root build,
# and protobuf libs needed by generated sources.
if(NOT TARGET demolib_static)
    message(FATAL_ERROR "Target 'demolib_static' not found. Enable BUILD_DEMOLIB in the root CMake or build from the project root.")
endif()

target_link_libraries(cpp_binding
    PUBLIC
        ${Protobuf_LIBRARIES}
        absl::log_internal_message
        absl::log_internal_check_op
)
add_dependencies(cpp_binding demolib_static)

# Merge libnimdemo.a into cpp_binding to produce a single archive on all platforms
get_target_property(DEMOLIB_PATH demolib_static IMPORTED_LOCATION)
if(NOT DEMOLIB_PATH)
    message(FATAL_ERROR "Could not determine path of demolib_static (IMPORTED_LOCATION)")
endif()

if(APPLE)
    # macOS uses Apple's libtool to merge static libraries
    add_custom_command(TARGET cpp_binding POST_BUILD
        COMMAND /usr/bin/libtool -static -o $<TARGET_FILE_DIR:cpp_binding>/libcpp_binding_merged.a
                $<TARGET_FILE:cpp_binding> ${DEMOLIB_PATH}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE_DIR:cpp_binding>/libcpp_binding_merged.a $<TARGET_FILE:cpp_binding>
        COMMENT "Merging libnimdemo.a into libcpp_binding.a (Apple libtool)"
        VERBATIM)
elseif(MSVC)
    # MSVC toolchain: use lib.exe to combine libraries
    add_custom_command(TARGET cpp_binding POST_BUILD
        COMMAND lib /nologo /OUT:$<TARGET_FILE_DIR:cpp_binding>\\cpp_binding_merged.lib
                $<TARGET_FILE:cpp_binding> ${DEMOLIB_PATH}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE_DIR:cpp_binding>/cpp_binding_merged.lib $<TARGET_FILE:cpp_binding>
        COMMENT "Merging libnimdemo.lib into cpp_binding.lib (MSVC lib.exe)"
        VERBATIM)
else()
    # Generic Unix/MinGW: use ar in MRI script mode to add libraries
    add_custom_command(TARGET cpp_binding POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "create $<TARGET_FILE_DIR:cpp_binding>/libcpp_binding_merged.a" > $<TARGET_FILE_DIR:cpp_binding>/merge.mri
        COMMAND ${CMAKE_COMMAND} -E echo "addlib $<TARGET_FILE:cpp_binding>" >> $<TARGET_FILE_DIR:cpp_binding>/merge.mri
        COMMAND ${CMAKE_COMMAND} -E echo "addlib ${DEMOLIB_PATH}" >> $<TARGET_FILE_DIR:cpp_binding>/merge.mri
        COMMAND ${CMAKE_COMMAND} -E echo "save" >> $<TARGET_FILE_DIR:cpp_binding>/merge.mri
        COMMAND ${CMAKE_COMMAND} -E echo "end" >> $<TARGET_FILE_DIR:cpp_binding>/merge.mri
        COMMAND "${CMAKE_AR}" -M < $<TARGET_FILE_DIR:cpp_binding>/merge.mri
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE_DIR:cpp_binding>/libcpp_binding_merged.a $<TARGET_FILE:cpp_binding>
        COMMENT "Merging libnimdemo.a into libcpp_binding.a (ar MRI)"
        VERBATIM)
endif()

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