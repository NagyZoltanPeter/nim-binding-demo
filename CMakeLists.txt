cmake_minimum_required(VERSION 3.10)
project(nim_binding_demo VERSION 0.1.0 LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Build options
option(BUILD_DEMOLIB "Build the Nim demolib library" ON)
option(BUILD_CPP_GENERATOR "Build the protoc C++ generator plugin" ON)
option(BUILD_CPP_DEMO "Build the C++ demo application" ON)
option(BUILD_ALL "Build all components" OFF)

# Set default build type if not specified
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Global variables
set(PROJECT_ROOT_DIR ${CMAKE_CURRENT_SOURCE_DIR})
set(DEMOLIB_DIR ${PROJECT_ROOT_DIR}/demolib)
set(DEMOLIB_BUILD_DIR ${DEMOLIB_DIR}/build)
set(DEMOLIB_STATIC_LIB ${DEMOLIB_BUILD_DIR}/demolib.a)

# Find required packages
find_package(Protobuf REQUIRED)
find_package(absl REQUIRED)

# Check for Nim compiler
find_program(NIM_COMPILER nim)
if(NOT NIM_COMPILER)
    message(WARNING "Nim compiler not found. Demolib will not be built automatically.")
    set(BUILD_DEMOLIB OFF)
endif()

# Check for Nimble
find_program(NIMBLE_TOOL nimble)
if(NOT NIMBLE_TOOL)
    message(WARNING "Nimble not found. Using direct nim compilation for demolib.")
endif()

# Custom target for building demolib using nimble
if(BUILD_DEMOLIB OR BUILD_ALL)
    add_custom_target(demolib_nim
        COMMENT "Building Nim demolib library"
        WORKING_DIRECTORY ${DEMOLIB_DIR}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${DEMOLIB_BUILD_DIR}
        COMMAND ${NIMBLE_TOOL} buildlib
        BYPRODUCTS ${DEMOLIB_STATIC_LIB}
    )
    
    # Create an imported library target for the Nim library
    add_library(demolib_static STATIC IMPORTED)
    set_target_properties(demolib_static PROPERTIES
        IMPORTED_LOCATION ${DEMOLIB_STATIC_LIB}
    )
    add_dependencies(demolib_static demolib_nim)
endif()

# Add subdirectories for different components
if(BUILD_CPP_GENERATOR OR BUILD_ALL)
    add_subdirectory(cpp_generator)
endif()

if(BUILD_CPP_DEMO OR BUILD_ALL)
    add_subdirectory(examples/cpp_raw_demo)
endif()

# Custom targets for partial builds
add_custom_target(build_protoc_plugin
    COMMENT "Building only the protoc plugin"
    DEPENDS protoc-gen-dispatcher
)

add_custom_target(build_nim_lib
    COMMENT "Building only the Nim library"
    DEPENDS demolib_nim
)

add_custom_target(build_cpp_demo_only
    COMMENT "Building only the C++ demo"
    DEPENDS cpp_demo
)

# Main build target that builds everything
add_custom_target(build_all
    COMMENT "Building all components"
    DEPENDS demolib_nim protoc-gen-dispatcher cpp_demo
)

# Clean target for Nim build artifacts
add_custom_target(clean_nim
    COMMENT "Cleaning Nim build artifacts"
    WORKING_DIRECTORY ${DEMOLIB_DIR}
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${DEMOLIB_BUILD_DIR}
)

# Install targets
install(DIRECTORY ${DEMOLIB_BUILD_DIR}/
    DESTINATION lib
    FILES_MATCHING PATTERN "*.a" PATTERN "*.so" PATTERN "*.h"
)

# Print build configuration
message(STATUS "=== Nim Binding Demo Build Configuration ===")
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "Build demolib: ${BUILD_DEMOLIB}")
message(STATUS "Build C++ generator: ${BUILD_CPP_GENERATOR}")
message(STATUS "Build C++ demo: ${BUILD_CPP_DEMO}")
message(STATUS "Nim compiler: ${NIM_COMPILER}")
message(STATUS "Nimble tool: ${NIMBLE_TOOL}")
message(STATUS "============================================")