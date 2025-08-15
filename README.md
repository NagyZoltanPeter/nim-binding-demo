# nim-binding-demo
Demonstrates a protobuf contract-based Nim library and multi-language bindings (C++ and Rust).

## Project Structure

- `libnimdemo/` — Nim core library exposing a C API (`libnimdemo.h`) and a static lib (`build/libnimdemo.a`).
- `bindings/cpp_binding/` — C++ binding static library that wraps the C API and provides a simple facade. The build merges the Nim static lib into a single archive for easy consumption.
- `bindings/rust_binding/` — Rust binding (Cargo crate) exporting a C ABI event entrypoint and a small Rust API (see `src/api.rs`). Built via Cargo from CMake and merged with the Nim static lib.
- `cpp_generator/` — Protoc plugin example (optional).
- `examples/cpp_demo_app/` — C++ demo app using the C++ binding. Provides a `run_cpp` target.
- `examples/rust_demo_app/` — Rust demo app using the Rust binding. Built with Cargo; root adds a `run_rust` target.
- `proto/` — Protobuf definitions (e.g., `message.proto`).

## Prerequisites

- Nim 2.2.4+ and Nimble
- CMake 3.20+ (recommended; subprojects use newer features)
- A C++17 compiler (clang++/g++)
- Protobuf C++ and Abseil (required by the C++ binding)
- Rust toolchain with Cargo (for Rust binding and demo)

## Build: top-level (recommended)

```bash
mkdir -p build
cd build
cmake ..
cmake --build . -j
```

Key CMake options (ON by default unless otherwise noted):
- `BUILD_DEMOLIB` — Build the Nim library
- `BUILD_CPP_GENERATOR` — Build the protoc plugin (optional)
- `BUILD_CPP_BINDING` — Build the C++ binding
- `BUILD_CPP_DEMO` — Build the C++ demo app
- `BUILD_RUST_DEMO` — Build the Rust demo app
- `BUILD_ALL=ON` — Build everything

Common targets:
- `libnimdemo` — Build only the Nim library
- `cpp_binding` — Build the C++ binding
- `cpp_demo_app` — Build the C++ demo
- `rust_binding` — Build the Rust binding (via Cargo)
- `rust_demo_app` — Build the Rust demo (via Cargo)
- `build_all` — Build all components
- `clean_nim` — Clean Nim build artifacts
- `build_protoc_plugin` — Build only the protoc plugin

Run the demos from the root build directory:
- C++: `cmake --build . --target run_cpp`
- Rust: `cmake --build . --target run_rust`

Notes:
- The binding libraries merge `libnimdemo.a` into their output to ship a single archive. You may see benign "duplicate member name" warnings from the archiver on macOS/Linux.
- If Protobuf/Abseil are not found, install them with your system package manager.

## Build: per-example (alternative)

### C++ demo only

```bash
cd examples/cpp_demo_app
mkdir -p build
cd build
cmake ..
cmake --build . -j
cmake --build . --target run_cpp
```

### Rust demo only

```bash
cd examples/rust_demo_app
cargo run
```

## VS Code

Includes tasks and launch configs for building and debugging:
- Build tasks for the Nim library and C++ demo
- Debug configuration for the C++ demo
- Cargo workflow can be used for Rust demo

To use:
1. Open the repo in VS Code
2. Install the C/C++ extension
3. Use the provided tasks (Ctrl/Cmd+Shift+B) or run CMake/Cargo commands
