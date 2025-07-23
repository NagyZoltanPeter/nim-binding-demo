cmake_minimum_required(VERSION 3.10)
project(protoc-gen-dispatcher VERSION 0.1.0 LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Find Protobuf package
find_package(Protobuf REQUIRED)
find_package(absl REQUIRED)

# Add executable for the protoc plugin
add_executable(protoc-gen-dispatcher
    src/nim_api_interface_generator.cpp
)

# Link libraries using the same approach as the working example
target_link_libraries(protoc-gen-dispatcher
    protobuf::libprotoc
    protobuf::libprotobuf
    absl::log_internal_message
    absl::log_internal_check_op
    absl::hash
    absl::raw_hash_set
)

# Set output directory to proto folder in the root
set_target_properties(protoc-gen-dispatcher PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../proto
)

# Install the plugin to the proto directory
install(TARGETS protoc-gen-dispatcher
    RUNTIME DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/../proto
)