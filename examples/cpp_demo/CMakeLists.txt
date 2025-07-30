cmake_minimum_required(VERSION 3.10)
project(nim_binding_cpp_demo VERSION 0.1.0 LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Find Protobuf package
find_package(Protobuf REQUIRED)

# Include directories
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/../../demolib/src
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

# Set the path to the demolib.a static library
set(DEMOLIB_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../../demolib/build/demolib.a)

# Link libraries
target_link_libraries(cpp_demo
    ${DEMOLIB_PATH}
    ${Protobuf_LIBRARIES}
)

# Install
install(TARGETS cpp_demo
    RUNTIME DESTINATION bin
)