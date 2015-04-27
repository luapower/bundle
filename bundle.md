---
project: bundle
tagline: LuaJIT single-executable app deployment
---

## What is

Bundle is a small framework for bundling together LuaJIT, Lua modules,
Lua/C modules, DynASM/Lua modules, C libraries, and other static assets
into a single fat executable. In its default configuration, it assumes
luapower's [toolchain][building] and [directory layout][get-involved]
and it works on Windows, Linux and OSX, x86 and x64.

## Usage

	mgit bundle options...

	  -o  --output FILE                  Output executable (required)

	  -m  --modules "FILE1 ..."|--all|-- Lua (or other) modules to bundle [1]
	  -a  --alibs "LIB1 ..."|--all|--    Static libs to bundle            [2]
	  -d  --dlibs "LIB1 ..."|--          Dynamic libs to link against     [3]

	  -M  --main MODULE                  Module to run on start-up

	  -m32                               Force 32bit platform
	  -z  --compress                     Compress the executable (needs UPX)

	  -ll --list-lua-modules             List Lua modules
	  -la --list-alibs                   List static libs (.a files)

	  -C  --clean                        Ignore the object cache

	  -v  --verbose                      Be verbose
	  -h  --help                         Show this screen

	 Passing -- clears the list of args for that option, including implicit args.

	 [1] .lua, .c and .dasl are compiled, other files are added as blobs.

	 [2] implicit static libs:           luajit
	 [3] implicit dynamic libs:


### Examples

	# full bundle: all Lua modules plus all static libraries
	mgit bundle -a --all -m --all -M main -o fat.exe

	# minimal bundle: two Lua modules, one static lib, one blob
	mgit bundle -a sha2 -m 'sha2 main media/bmp/bg.bmp' -M main -o lean.exe

	# luajit frontend with built-in luasocket support, no main module
	mgit bundle -a 'socket_core mime_core' -m 'socket mime ltn12 socket/*.lua' -o luajit.exe

	# run the unit tests
	mgit bundle-test


## How it works

The core of it is a slightly modifed LuaJIT frontend which adds two
additional loaders at the end of the `package.loaders` table, enabling
`require()` to load modules embedded in the executable when they are
not found externally. `ffi.load()` is also modified to return `ffi.C` if
the requested library is not found, allowing embedded C symbols to be used
instead. Assets can be loaded with `bundle.load(filename)` (see below),
subject to the same policy: load the embedded asset if the corresponding
file is not present in the filesystem.

This allows mixed deployments where some modules and assets are bundled
inside the exe and some are left outside, with no changes to the code and no
rebundling needed. External modules always take precedence over embedded ones,
allowing partial upgrades to the original executable without the need for a
rebuild. Finally, one of the modules (embedded or not) can be specified
to run instead of the usual command line, effectively enabling
single-executable app deployment for pure Lua apps with no glue C code needed.

### Components

#### .mgit/bundle.sh

The bundler script (see below): compiles and links modules to create
a fat executable.

#### csrc/bundle/luajit.c

The standard LuaJIT frontend, slightly modified to run stuff from `bundle.c`.

#### csrc/bundle/bundle.c

The bundle loader (C part):

  * installs require() loaders on startup for loading embedded Lua
  and C modules
  * fills `_G.arg` with command-line args
  * sets `_G.arg[-1]` to the name of the main script (`-M` option)
  * calls `require'bundle_loader'`
    * (which means bundle_loader itself can be upgraded without a rebuild)

#### bundle_loader.lua

The bundle loader (Lua part):

  * sets `package.path` and `package.cpath` to load modules relative
  to the exe's dir
  * overrides `ffi.load` to return `ffi.C` when a library is not found
  * loads the main module, if any, per `arg[-1]`
  * falls back to LuaJIT REPL if there's no main module

#### bundle.lua

Optional module for loading embedded binary files: contains the function
`bundle.load(filename) -> string`.


## A note on compression

Compressed executables cannot be mmapped, so they have to stay in RAM
fully and always. If the bundled assets are large and compressible,
better results can be acheived by compressing them individually or not
compressing them at all, instead of compressing the entire exe.
Compression also adds up to the exe's loading time.

