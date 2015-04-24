---
project: bundle
tagline: LuaJIT single-executable app deployment
---

<warn>WORK IN PROGRESS</warn>

## What is

Bundle is a small framework for bundling together LuaJIT, Lua modules,
Lua/C modules, Dynasm/Lua modules, C libraries, and other static assets
into a single fat executable. In its default configuration, it assumes
luapower's [toolchain][building] and [directory layout][get-involved]
and it works on Windows, Linux and OSX, x86 and x64.

## How it works

The core of it is a slightly modifed LuaJIT frontend which adds two
additional loaders at the end of the `package.loaders` table, enabling
`require()` to load modules embedded in the executable when they are
not found externally. `ffi.load()` is also modified to return `ffi.C` if
the requested library is not found, allowing embedded C symbols to be used
instead. Assets can be loaded with `bundle.load(filename)` subject to the
same policy: load the embedded asset if the corresponding file is not present.

This allows mixed deployments where some modules and assets are bundled
inside the exe and some are left outside, with no changes to the code and no
rebundling needed. External modules always take precedence over embedded ones,
allowing partial upgrades to the original executable without the need for a
rebuild. To close the circle, one of the modules (embedded or not) can be
specified to run instead of the usual command line, effectively enabling
single-executable app deployment for pure Lua apps with no glue C code needed.

## Usage

	sh bundle.sh options...

	  -o  --output FILE                  Output executable (required)

	  -m  --modules "FILE1 ..."|--all|-- Lua (or other) modules to bundle [1]
	  -a  --alibs "LIB1 ..."|--all|--    Static libs to bundle            [2]
	  -d  --dlibs "LIB1 ..."|--          Dynamic libs to link against     [3]
	  -f  --frameworks "FRM1 ..."        Frameworks to link against       [4]

	  -M  --main MODULE                  Module to run on start-up

	  -m32                               Force 32bit platform
	  -z  --compress                     Compress the executable (needs UPX)

	  -ll --list-lua-modules             List Lua modules
	  -la --list-alibs                   List static libs (.a files)

	  -C  --clean                        Ignore the object cache

	  -q  --quiet                        Be quiet
	  -h  --help                         Show this screen

	 Passing -- clears the list of args for that option, including implicit args.

	 [1] .c and .dasl files will be compiled, other files will be added as blobs.

	 [2] implicit static libs:           luajit
	 [3] implicit dynamic libs:
	 [4] implicit frameworks:            ApplicationServices


## Examples

	# full bundle: all Lua, dasm and statically built C modules
	sh bundle.sh -a --all -m --all -M main -o fat.exe

	# minimal bundle, two Lua modules, one C module, one blob
	sh bundle.sh -a sha2 -m 'sha2 main media/bmp/bg.bmp' -M main -o lean.exe

	# luajit frontend with built-in luasocket support, no main module
	sh bundle.sh -a 'socket_core mime_core' -m 'socket mime ltn12 socket/*.lua' -o luajit.exe

## A note on compression

Compressed executables cannot be mmapped, so they have to stay in RAM
fully and always. If the bundled assets are large and compressible,
better results can be acheived by compressing them individually or not
compressing them at all, instead of compressing the entire exe.
Compression also adds up to the exe's loading time.

