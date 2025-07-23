cmake_minimum_required(VERSION 3.10)
project(demolib VERSION 0.1.0)

# Find Nim compiler and Nimble
find_program(NIM_COMPILER nim REQUIRED)
find_program(NIMBLE_TOOL nimble)

# Set build directory
set(DEMOLIB_BUILD_DIR ${CMAKE_CURRENT_SOURCE_DIR}/build)
set(DEMOLIB_STATIC_LIB ${DEMOLIB_BUILD_DIR}/demolib.a)
set(DEMOLIB_HEADER ${DEMOLIB_BUILD_DIR}/demolib.h)

# Create build directory
file(MAKE_DIRECTORY ${DEMOLIB_BUILD_DIR})

# Custom command to build the Nim library using nimble
if(NIMBLE_TOOL)
    add_custom_command(
        OUTPUT ${DEMOLIB_STATIC_LIB} ${DEMOLIB_HEADER}
        COMMAND ${NIMBLE_TOOL} buildlib
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/src/demolib.nim
                ${CMAKE_CURRENT_SOURCE_DIR}/src/api.nim
                ${CMAKE_CURRENT_SOURCE_DIR}/src/event_dispatcher.nim
                ${CMAKE_CURRENT_SOURCE_DIR}/src/message.nim
                ${CMAKE_CURRENT_SOURCE_DIR}/src/request_dispatcher.nim
                ${CMAKE_CURRENT_SOURCE_DIR}/src/demolib/context.nim
                ${CMAKE_CURRENT_SOURCE_DIR}/demolib.nimble
        COMMENT "Building Nim demolib library using nimble"
        VERBATIM
    )
else()
    # Fallback to direct nim compilation if nimble is not available
    add_custom_command(
        OUTPUT ${DEMOLIB_STATIC_LIB} ${DEMOLIB_HEADER}
        COMMAND ${NIM_COMPILER} c 
                --out:${DEMOLIB_STATIC_LIB}
                --threads:on 
                --app:staticlib 
                --opt:size 
                --noMain 
                --mm:orc 
                --header 
                --undef:metrics 
                --nimMainPrefix:libdemo 
                --skipParentCfg:on
                -d:chronicles_log_level='TRACE'
                ${CMAKE_CURRENT_SOURCE_DIR}/src/demolib.nim
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/src/demolib.nim
                ${CMAKE_CURRENT_SOURCE_DIR}/src/api.nim
                ${CMAKE_CURRENT_SOURCE_DIR}/src/event_dispatcher.nim
                ${CMAKE_CURRENT_SOURCE_DIR}/src/message.nim
                ${CMAKE_CURRENT_SOURCE_DIR}/src/request_dispatcher.nim
                ${CMAKE_CURRENT_SOURCE_DIR}/src/demolib/context.nim
        COMMENT "Building Nim demolib library using direct nim compilation"
        VERBATIM
    )
endif()

# Create a custom target for the Nim library
add_custom_target(demolib_nim_build ALL
    DEPENDS ${DEMOLIB_STATIC_LIB} ${DEMOLIB_HEADER}
)

# Create an imported library target
add_library(demolib_static STATIC IMPORTED GLOBAL)
set_target_properties(demolib_static PROPERTIES
    IMPORTED_LOCATION ${DEMOLIB_STATIC_LIB}
    INTERFACE_INCLUDE_DIRECTORIES ${DEMOLIB_BUILD_DIR}
)
add_dependencies(demolib_static demolib_nim_build)

# Test target using nimble
if(NIMBLE_TOOL)
    add_custom_target(test_demolib
        COMMAND ${NIMBLE_TOOL} test
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        DEPENDS demolib_nim_build
        COMMENT "Running Nim demolib tests"
    )
endif()

# Clean target for Nim artifacts
add_custom_target(clean_demolib
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${DEMOLIB_BUILD_DIR}
    COMMENT "Cleaning Nim demolib build artifacts"
)

# Install targets
install(FILES ${DEMOLIB_STATIC_LIB}
    DESTINATION lib
    OPTIONAL
)

install(FILES ${DEMOLIB_HEADER}
    DESTINATION include
    OPTIONAL
)

# Print configuration
message(STATUS "=== Demolib Nim Library Configuration ===")
message(STATUS "Nim compiler: ${NIM_COMPILER}")
message(STATUS "Nimble tool: ${NIMBLE_TOOL}")
message(STATUS "Build directory: ${DEMOLIB_BUILD_DIR}")
message(STATUS "Static library: ${DEMOLIB_STATIC_LIB}")
message(STATUS "Header file: ${DEMOLIB_HEADER}")
message(STATUS "=========================================")