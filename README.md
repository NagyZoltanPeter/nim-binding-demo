# nim-binding-demo
Demonstrate protobuf contract based nim library and language bindings

## Project Structure

- `demolib/` - Nim library with C API
- `examples/` - Example applications in different languages
- `proto/` - Protocol buffer definitions

## Prerequisites

- Nim 2.2.4 or higher
- CMake 3.10 or higher
- A C++17 compatible compiler (clang++ or g++)
- Protobuf library installed

## Building the Nim Library

```bash
cd demolib
nimble buildlib
```

This will create both static and dynamic libraries in the `demolib/build` directory.

## Building and Running Examples

### C++ Demo

```bash
cd examples/cpp_demo
mkdir -p build
cd build
cmake ..
make
./cpp_demo
```

## VSCode Configuration

This project includes VSCode configuration files for building and debugging:

- Debug configurations for the C++ demo application
- Build tasks for both the Nim library and C++ demo
- IntelliSense configuration for C++ development

To use the VSCode configuration:

1. Open the root folder in VSCode
2. Install the C/C++ extension if not already installed
3. Use `Ctrl+Shift+B` to build the project
4. Use `F5` to debug the C++ demo application
