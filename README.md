# nim-binding-demo
Demonstrate protobuf contract based nim library and language bindings

## Project Structure

- `libnimdemo/` - Nim library with C API
- `examples/` - Example applications in different languages
- `proto/` - Protocol buffer definitions

## Prerequisites

- Nim 2.2.4 or higher
- CMake 3.10 or higher
- A C++17 compatible compiler (clang++ or g++)
- Protobuf library installed

## Building the Nim Library

```bash
cd libnimdemo
nimble buildlib
```

This will create the static library and header in `libnimdemo/build`.

## Building and Running Examples

### C++ Demo

```bash
cd examples/cpp_raw_demo
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
