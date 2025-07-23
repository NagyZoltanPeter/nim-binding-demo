cmake_minimum_required(VERSION 3.10)
project(nim_binding_cpp_demo VERSION 0.1.0 LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Find Protobuf package
find_package(Protobuf REQUIRED)
find_package(absl REQUIRED)

# Include directories
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/../../demolib/src
    ${CMAKE_CURRENT_SOURCE_DIR}/../../demolib/build  # For generated header
    ${Protobuf_INCLUDE_DIRS}
    ${CMAKE_CURRENT_BINARY_DIR}  # Add build directory for generated protobuf files
)

# Generate protobuf C++ files
set(PROTO_FILES ${CMAKE_CURRENT_SOURCE_DIR}/../../proto/message.proto)
protobuf_generate_cpp(PROTO_SRCS PROTO_HDRS ${PROTO_FILES})

# Add executable
add_executable(cpp_demo
    src/main.cpp
    ${PROTO_SRCS}
    ${PROTO_HDRS}
)

# Check if we're building as part of the main project
if(TARGET demolib_static)
    # Use the imported target from the main build
    target_link_libraries(cpp_demo
        demolib_static
        ${Protobuf_LIBRARIES}
        absl::log_internal_message
        absl::log_internal_check_op
    )
    add_dependencies(cpp_demo demolib_static)
else()
    # Standalone build - use the static library path
    set(DEMOLIB_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../../demolib/build/demolib.a)
    
    # Check if demolib exists, if not try to build it
    if(NOT EXISTS ${DEMOLIB_PATH})
        message(STATUS "Demolib not found, attempting to build it...")
        execute_process(
            COMMAND nimble buildlib
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../../demolib
            RESULT_VARIABLE NIMBLE_RESULT
        )
        if(NOT NIMBLE_RESULT EQUAL 0)
            message(FATAL_ERROR "Failed to build demolib. Please run 'nimble buildlib' in the demolib directory first.")
        endif()
    endif()
    
    target_link_libraries(cpp_demo
        ${DEMOLIB_PATH}
        ${Protobuf_LIBRARIES}
        absl::log_internal_message
        absl::log_internal_check_op
    )
endif()

# Set install prefix to project root if not specified
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX ${CMAKE_SOURCE_DIR} CACHE PATH "Install prefix" FORCE)
endif()

# Install
install(TARGETS cpp_demo
    RUNTIME DESTINATION bin
)

# Add a run target to execute the built binary
add_custom_target(run
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/cpp_demo
    DEPENDS cpp_demo
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running cpp_demo"
    VERBATIM
)
