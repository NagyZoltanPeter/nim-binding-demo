cmake_minimum_required(VERSION 3.20)
project(rust_demo_app C)

find_program(CARGO cargo REQUIRED)

# Share the same Rust profile convention as rust_binding
set(RUST_PROFILE "release" CACHE STRING "Rust profile (debug|release)")
if(RUST_PROFILE STREQUAL "debug")
  set(RUST_FLAG "")
  set(RUST_DIR "debug")
else()
  set(RUST_FLAG "--release")
  set(RUST_DIR "release")
endif()

set(RUST_APP_OUT ${CMAKE_CURRENT_SOURCE_DIR}/target/${RUST_DIR}/rust_demo_app)

add_custom_command(
  OUTPUT ${RUST_APP_OUT}
  COMMAND ${CARGO} build ${RUST_FLAG}
          --manifest-path ${CMAKE_CURRENT_SOURCE_DIR}/Cargo.toml
  # Touch/copy to ensure OUTPUT is considered updated
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
          ${RUST_APP_OUT} ${RUST_APP_OUT}
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  COMMENT "Building rust_demo_app (${RUST_DIR})"
  VERBATIM
)

add_custom_target(rust_demo_app
  DEPENDS ${RUST_APP_OUT}
)
