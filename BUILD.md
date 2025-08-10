# Build System Documentation

This project uses a unified CMake build system that combines all components into a single, manageable build process.

## Prerequisites

- CMake 3.10 or higher
- C++17 compatible compiler
- Nim compiler (2.2.4 or higher)
- Nimble package manager
- Protocol Buffers compiler and libraries
- Abseil C++ libraries

## Project Structure

```
nim-binding-demo/
├── CMakeLists.txt              # Root CMake configuration
├── libnimdemo/
│   ├── CMakeLists.txt          # Nim library build configuration
│   └── libnimdemo.nimble       # Nim package configuration
├── cpp_generator/
│   └── CMakeLists.txt          # Protoc plugin build configuration
├── examples/cpp_demo_app/
│   └── CMakeLists.txt          # C++ demo build configuration
└── proto/
   └── message.proto           # Protocol buffer definitions
```

## Build Options

The build system provides several configuration options:

- `BUILD_DEMOLIB`: Build the Nim libnimdemo library (default: ON)
- `BUILD_CPP_GENERATOR`: Build the protoc C++ generator plugin (default: ON)
- `BUILD_CPP_DEMO`: Build the C++ demo application (default: ON)
- `BUILD_ALL`: Build all components (default: OFF)

## Quick Start

### Full Build

To build all components:

```bash
mkdir build
cd build
cmake ..
make build_all
```

### Partial Builds

Build individual components:

```bash
# Build only the Nim library
make build_nim_lib

# Build only the protoc plugin
make build_protoc_plugin

# Build only the C++ demo
make build_cpp_demo_only
```

### Configuration Options

Configure build with specific options:

```bash
# Build only specific components
cmake -DBUILD_DEMOLIB=ON -DBUILD_CPP_GENERATOR=OFF -DBUILD_CPP_DEMO=ON ..

# Debug build
cmake -DCMAKE_BUILD_TYPE=Debug ..

# Release build (default)
cmake -DCMAKE_BUILD_TYPE=Release ..
```

## Build Targets

### Primary Targets

- `build_all`: Builds all components (libnimdemo, protoc plugin, C++ demo)
- `build_nim_lib`: Builds only the Nim libnimdemo library
- `build_protoc_plugin`: Builds only the protoc generator plugin
- `build_cpp_demo_only`: Builds only the C++ demo application

### Component Targets

- `demolib_nim`: Nim library build target (libnimdemo)
- `protoc-gen-dispatcher`: Protoc plugin executable
- `cpp_demo_app`: C++ demo executable

### Utility Targets

- `clean_nim`: Clean Nim build artifacts
- `test_demolib`: Run Nim library tests (requires nimble)

## Build Artifacts

After a successful build, you'll find:

```
build/
├── libnimdemo/build/
│   ├── libnimdemo.a            # Static Nim library
│   └── libnimdemo.h            # C header
├── examples/cpp_demo_app/
│   └── cpp_demo_app           # C++ demo executable
└── proto/
   └── protoc-gen-dispatcher   # Protoc plugin executable
```

Additionally, a convenience symlink is created in the root directory:

```
cpp_demo_app -> build/examples/cpp_demo_app/cpp_demo_app  # Symlink to demo executable
```

This allows you to run the demo directly from the root folder:

```bash
./cpp_demo_app
```

## Nim Library Integration

The build system automatically:

1. Uses `nimble buildlib` to build the Nim library if nimble is available
2. Falls back to direct `nim` compilation if nimble is not found
3. Creates an imported CMake target for easy linking
4. Handles dependencies between C++ components and the Nim library

## Standalone Builds

Each component can also be built independently:

### Nim Library Only

```bash
cd libnimdemo
nimble buildlib
```

### C++ Generator Only

```bash
cd cpp_generator
mkdir build && cd build
cmake ..
make
```

### C++ Demo Only

```bash
cd examples/cpp_demo_app
mkdir build && cd build
cmake ..
make
```

## Troubleshooting

### Common Issues

1. **Nim compiler not found**
   - Ensure Nim is installed and in your PATH
   - Set `BUILD_DEMOLIB=OFF` if you don't need the Nim library

2. **Nimble not found**
   - The build will fall back to direct nim compilation
   - Install nimble for full functionality

3. **Protobuf not found**
   - Install protobuf development packages
   - On macOS: `brew install protobuf abseil`
   - On Ubuntu: `apt-get install libprotobuf-dev protobuf-compiler libabsl-dev`

4. **Build dependencies**
   - The C++ demo depends on the Nim library
   - Build order is automatically handled by CMake dependencies

### Clean Build

To perform a clean build:

```bash
rm -rf build
mkdir build
cd build
cmake ..
make build_all
```

### Verbose Build

For debugging build issues:

```bash
make VERBOSE=1
```

## Integration with IDEs

### VS Code

The project includes VS Code configuration files in `.vscode/` directories for each component.

### CLion

CLion should automatically detect the CMake configuration and provide full IDE support.

### Other IDEs

Most modern IDEs with CMake support should work out of the box.

## Advanced Usage

### Custom Nim Flags

You can pass custom flags to the Nim compiler by modifying the nimble file or using environment variables:

```bash
export NIMFLAGS="-d:release --opt:speed"
cmake ..
make
```

### Cross-compilation

The build system supports cross-compilation by setting appropriate CMake toolchain files and Nim target options.

### Testing

Run tests for the Nim library:

```bash
make test_demolib
```

## Contributing

When adding new components:

1. Create a `CMakeLists.txt` in the component directory
2. Add the component to the root `CMakeLists.txt` using `add_subdirectory()`
3. Create appropriate build targets
4. Update this documentation

## License

This build system is part of the nim-binding-demo project and follows the same license terms.