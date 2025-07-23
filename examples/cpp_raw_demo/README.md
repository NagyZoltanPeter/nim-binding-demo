# C++ Demo for Nim Binding

This is a C++ demo application that uses the Nim library binding.

## Prerequisites

- CMake 3.10 or higher
- A C++17 compatible compiler (clang++ or g++)
- Protobuf library installed

## Building the Project

### Using VSCode Tasks

1. Open this folder in VSCode
2. Press `Ctrl+Shift+P` and select "Tasks: Run Build Task" or press `Ctrl+Shift+B`
3. The build will automatically create the `build` directory, run CMake, and compile the project

### Using Terminal

```bash
mkdir -p build
cd build
cmake ..
make
```

## Running the Application

After building, you can run the application:

```bash
./build/cpp_demo
```

Or use the VSCode debug configuration:
1. Press `F5` to start debugging
2. Or go to the Run and Debug view and select "Debug cpp_demo" or "Run cpp_demo"

## Debugging

The project includes two debug configurations:
- "Debug cpp_demo" - Builds and runs the application with debugging capabilities
- "Run cpp_demo" - Builds and runs the application without stopping at entry point

## Cleaning the Build

To clean the build directory:
- Use the "clean build" task in VSCode
- Or run `rm -rf build` in the terminal