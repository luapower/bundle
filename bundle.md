---
project: bundle
tagline: LuaJIT single-executable app deployment
---

## WORK IN PROGRESS

## What Is

Bundle is a small framework for bundling together LuaJIT, Lua modules,
Lua/C modules, Dynasm/Lua modules, C libraries, and other static assets
into a single fat executable. In its default configuration, it assumes luapower's [toolchain] and [directory layout] and it works on Windows,
Linux and OSX, x86 and x64.

## How it works

At the core there's a slightly modifed LuaJIT frontend which adds two
additional loaders at the end of the `package.loaders` table, enabling
`require()` to load modules embedded in the executable when they are
not found externally. `ffi.load()` is also modified to return `ffi.C` if
the requested library is not found, allowing embedded C symbols to be used
instead. Assets can be loaded with `bundle.load(filename)` subject to the
same policy: load the embedded asset if the corresponding file is not present.

This allows mixed deployments where some modules and assets are bundled
inside the exe and some are left outside, with no changes to the code needed.
External modules always take precedence over embedded ones, allowing
partial upgrades to the original executable without the need for a rebuild.
To close the circle, one of the modules (embedded or not) can be specified
to run instead of the usual command line, effectively enabling
single-executable app deployment for pure Lua apps with no glue C code needed.

## Usage


	sh bundle.sh [options...]

	-o  --output <file>                 Output executable [a.exe]

	-m  --modules "file1 ..."|--all     Modules to bundle
	-a  --alibs "lib1 ..."|--all        Static libs to bundle
	-d  --dlibs "lib1 ..."              Dynamic libs to link against
	-f  --frameworks "frm1 ..."         Frameworks to link against (OSX)

	-M  --main <module>                 Module to run on start-up

	-m32                                Force 32bit platform (OSX)
	-z  --compress                      Compress the executable
	-i  --icon <file>                   Set icon (Windows)
	-w  --no-console                    Hide the terminal / console (Windows)

	-ll --list-lua-modules              List Lua modules
	-la --list-alibs                    List static libs (.a files)

	-C  --clean                         Ignore the object cache

	-v  --verbose                       Be verbose
	-h  --help                          Show this screen


## Examples

	# full bundle: all Lua, dasm and statically built C modules
	sh bundle.sh -v -a --all -m --all -M main -o fat.exe

	# minimal bundle, two Lua modules, one C module, one blob
	sh bundle.sh -v -a sha2 -m 'sha2 main media/bmp/bg.bmp' -M main -o lean.exe

	# luajit frontend with built-in luasocket support, no main module
	sh bundle.sh -v -a 'socket_core mime_core' -m 'socket mime ltn12 socket/*.lua' -o luajit.exe

## About compression

Compressed executables cannot be mmapped, so they have to stay in RAM
fully and always. If the bundled assets are large and compressible,
better results can be acheived by compressing them individually instead of
compressing the entire exe.


[toolchain]:         building.html
[directory layout]:  get-involved.html

