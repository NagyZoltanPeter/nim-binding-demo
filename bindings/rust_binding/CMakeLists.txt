cmake_minimum_required(VERSION 3.20)
project(rust_binding C)

find_program(CARGO cargo REQUIRED)

# Build profile (Debug/Release)
set(RUST_PROFILE "release" CACHE STRING "Rust profile (debug|release)")
if(RUST_PROFILE STREQUAL "debug")
  set(RUST_FLAG "")
  set(RUST_DIR "debug")
else()
  set(RUST_FLAG "--release")
  set(RUST_DIR "release")
endif()

# Build rust static lib
add_custom_command(
  OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/target/${RUST_DIR}/librust_binding.a
  COMMAND ${CARGO} build ${RUST_FLAG}
    --manifest-path ${CMAKE_CURRENT_SOURCE_DIR}/Cargo.toml
  # Ensure the OUTPUT exists so Ninja/Make sees it even if Cargo printed in a different place
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    ${CMAKE_CURRENT_SOURCE_DIR}/target/${RUST_DIR}/librust_binding.a
    ${CMAKE_CURRENT_SOURCE_DIR}/target/${RUST_DIR}/librust_binding.a
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  COMMENT "Building rust_binding (${RUST_DIR})"
  VERBATIM
)

add_custom_target(rust_binding_build ALL
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/target/${RUST_DIR}/librust_binding.a
)

# Expose as imported target for consumers
add_library(rust_binding STATIC IMPORTED GLOBAL)
set_target_properties(rust_binding PROPERTIES
  IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/target/${RUST_DIR}/librust_binding.a
)
add_dependencies(rust_binding rust_binding_build)

# Merge libnimdemo.a into librust_binding.a to ship a single archive when possible
# Resolve Nim library path from imported target
if(TARGET demolib_static)
  get_target_property(NIM_PATH demolib_static IMPORTED_LOCATION)
endif()

if(NIM_PATH)
  if(APPLE)
    add_custom_command(TARGET rust_binding_build POST_BUILD
      COMMAND /usr/bin/libtool -static -o ${CMAKE_CURRENT_BINARY_DIR}/librust_binding_merged.a
              ${CMAKE_CURRENT_SOURCE_DIR}/target/${RUST_DIR}/librust_binding.a
              ${NIM_PATH}
      COMMAND ${CMAKE_COMMAND} -E copy
              ${CMAKE_CURRENT_BINARY_DIR}/librust_binding_merged.a
              ${CMAKE_CURRENT_SOURCE_DIR}/target/${RUST_DIR}/librust_binding.a
      COMMENT "Merging libnimdemo into librust_binding (Apple libtool)"
      VERBATIM)
  elseif(MSVC)
    add_custom_command(TARGET rust_binding_build POST_BUILD
      COMMAND lib.exe /OUT:${CMAKE_CURRENT_BINARY_DIR}/rust_binding_merged.lib
              ${CMAKE_CURRENT_SOURCE_DIR}/target/${RUST_DIR}/rust_binding.lib
              ${NIM_PATH}
      COMMAND ${CMAKE_COMMAND} -E copy
              ${CMAKE_CURRENT_BINARY_DIR}/rust_binding_merged.lib
              ${CMAKE_CURRENT_SOURCE_DIR}/target/${RUST_DIR}/rust_binding.lib
      COMMENT "Merging libnimdemo into rust_binding (MSVC lib.exe)"
      VERBATIM)
  else()
    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/merge.mri
"create librust_binding_merged.a
addlib ${CMAKE_CURRENT_SOURCE_DIR}/target/${RUST_DIR}/librust_binding.a
addlib ${NIM_PATH}
save
end
")
    add_custom_command(TARGET rust_binding_build POST_BUILD
      COMMAND ${CMAKE_AR} -M < ${CMAKE_CURRENT_BINARY_DIR}/merge.mri
      COMMAND ${CMAKE_COMMAND} -E copy
              ${CMAKE_CURRENT_BINARY_DIR}/librust_binding_merged.a
              ${CMAKE_CURRENT_SOURCE_DIR}/target/${RUST_DIR}/librust_binding.a
      COMMENT "Merging libnimdemo into librust_binding (ar MRI)"
      VERBATIM)
  endif()
endif()

# Install artifacts (SDK-style)
install(FILES
  ${CMAKE_CURRENT_SOURCE_DIR}/target/${RUST_DIR}/librust_binding.a
  DESTINATION lib
)
