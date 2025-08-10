# Package

version = "0.1.0"
author = "NagyZoltanPeter"
description = "Demo nim library to demonstrate new language binding"
license = "MIT"
srcDir = "src"
installExt = @["nim"]
# Build configuration

# Dependencies

requires "nim >= 2.2.4",
  "stew",
  "faststreams",
  "serialization",
  "protobuf_serialization", # waiting for this to be in a release
  "unittest2",
  "chronicles",
  "confutils",
  "chronos",
  "metrics",
  "results",
  "lockfreequeues"

let nimc = getEnv("NIMC", "nim") # Which nim compiler to use
let lang = getEnv("NIMLANG", "c") # Which backend (c/cpp/js)
let flags = getEnv("NIMFLAGS", "") # Extra flags for the compiler
let verbose = getEnv("V", "") notin ["", "0"]

let styleCheckStyle = if (NimMajor, NimMinor) < (2, 2): "hint" else: "error"
let cfg =
  " --styleCheck:usages --styleCheck:" & styleCheckStyle &
  (if verbose: "" else: " --verbosity:0 --hints:off") &
  " --skipParentCfg --skipUserCfg --outdir:build --nimcache:build/nimcache -f"

proc build(args, path: string) =
  # Always use absolute path by joining with current directory
  echo "Building with absolute path: " & path
  exec nimc & " " & lang & " " & cfg & " " & flags & " " & args & " " & path

proc run(args, path: string) =
  echo "Running with args: " & args
  echo "Path: " & path
  echo "Full command will be: " & nimc & " " & lang & " " & cfg & " " & flags & " " &
    args & " -r " & path
  build args & " -r", path

proc buildBinary(name: string, srcDir = "./", params = "", lang = "c") =
  if not dirExists "build":
    mkDir "build"
  # allow something like "nim nimbus --verbosity:0 --hints:off nimbus.nims"
  var extra_params = params
  for i in 2 ..< paramCount():
    extra_params &= " " & paramStr(i)
  exec "nim " & lang & " --out:build/" & name & " --mm:orc " & extra_params & " " &
    srcDir & name & ".nim"

# proc buildLibrary(name: string, srcDir = "./", params = "", `type` = "static") =
#   if not dirExists "build":
#     mkDir "build"

#   # Debug output
#   echo "Building library: " & name
#   echo "Source directory: " & srcDir

#   # Use the params directly without trying to collect additional parameters
#   let extra_params = params

#   # Construct the source file path correctly
#   let sourceFile = srcDir & name & ".nim"
#   echo "Source file: " & sourceFile

#   # Check if the source file exists
#   if not fileExists(sourceFile):
#     echo "ERROR: Source file does not exist: " & sourceFile
#     return

#   if `type` == "static":
#     let cmd =
#       "nim c" & " --out:build/" & name &
#       ".a --threads:on --app:staticlib --opt:size --noMain --mm:orc --header --undef:metrics --nimMainPrefix:libdemo --skipParentCfg:on " &
#       extra_params & " " & sourceFile
#     echo "Executing command: " & cmd
#     exec cmd
#   else:
#     let cmd =
#       "nim c" & " --out:build/" & name &
#       ".so --threads:on --app:lib --opt:size --noMain --mm:orc --header --undef:metrics --nimMainPrefix:libdemo --skipParentCfg:on " &
#       extra_params & " " & sourceFile
#     echo "Executing command: " & cmd
#     exec cmd

proc buildLibrary(srcName: string, outName: string, srcDir = "./", params = "", `type` = "static") =
  if not dirExists "build":
    mkDir "build"

  # Debug output
  echo "Building library from source: " & srcName
  echo "Output library name: " & outName
  echo "Source directory: " & srcDir

  # Use the params directly without C++ object linking
  let extra_params = params

  # Construct the source file path correctly
  let sourceFile = srcDir & srcName & ".nim"
  echo "Source file: " & sourceFile

  # Check if the source file exists
  if not fileExists(sourceFile):
    echo "ERROR: Source file does not exist: " & sourceFile
    return

  if `type` == "static":
    let cmd =
      "nim c" & " --out:build/" & outName &
      ".a --threads:on --app:staticlib --opt:size --noMain --mm:orc --header --undef:metrics --nimMainPrefix:libnimdemo --skipParentCfg:on " &
      extra_params & " " & sourceFile
    echo "Executing command: " & cmd
    exec cmd
  else:
    let cmd =
      "nim c" & " --out:build/" & outName &
      ".so --threads:on --app:lib --opt:size --noMain --mm:orc --header --undef:metrics --nimMainPrefix:libnimdemo --skipParentCfg:on " &
      extra_params & " " & sourceFile
    echo "Executing command: " & cmd
    exec cmd
    
task buildlib, "Builds static and dynamic library artifacts":
  let srcName = "libnimdemo"
  let outName = "libnimdemo"
  buildLibrary(srcName, outName, "src/", " -d:chronicles_log_level='TRACE' ", "static")
  # buildLibrary(name, "src/", " -d:chronicles_log_level='TRACE' ", "dynamic")

task test, "Run all tests":
  echo "Current directory: " & getCurrentDir()
  let testFile = "test_all.nim"

  # Try multiple possible locations for the test file
  var testLocations = [
    getCurrentDir() & "/tests/" & testFile, # Current dir/tests
    getCurrentDir() & "/../tests/" & testFile, # Parent dir/tests
  getCurrentDir() & "/libnimdemo/tests/" & testFile, # Current dir/libnimdemo/tests
    "./tests/" & testFile, # Relative to script
    "../tests/" & testFile, # Parent relative to script
  ]

  var testPath = ""
  var found = false

  echo "Checking possible test file locations:"
  for path in testLocations:
    echo "Checking: " & path
    if fileExists(path):
      echo "FOUND: Test file exists at: " & path
      testPath = path
      found = true
      break

  if found:
    echo "Using test path: " & testPath
    exec nimc & " " & lang & " --out:build/ " & " --mm:orc --threads:on --tlsEmulation:off --passL:./build/libnimdemo.a " & " -r " & testPath
  else:
    echo "ERROR: Test file not found in any of the checked locations"
    echo "Listing current directory:"
    for file in listFiles(getCurrentDir()):
      echo "  - " & file

    if dirExists(getCurrentDir() & "/tests"):
      echo "Listing tests directory:"
      for file in listFiles(getCurrentDir() & "/tests"):
        echo "  - " & file

#   #Also iterate over every test in tests/fail, and verify they fail to compile.
#   echo "\r\n\x1B[0;94m[Suite]\x1B[0;37m Test Fail to Compile"
#   var tests: seq[string] = @[]
#   for path in listFiles(thisDir() % "tests" / "fail"):
#     if path.split(".")[^1] != "nim":
#       continue

#     if gorgeEx(nimc & " c " & path).exitCode != 0:
#       echo "  \x1B[0;92m[OK]\x1B[0;37m ", path.split(DirSep)[^1]
#     else:
#       echo "  \x1B[0;31m[FAILED]\x1B[0;37m ", path.split(DirSep)[^1]
#       exec "exit 1"
