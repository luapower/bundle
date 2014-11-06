---
project: bundle
tagline: LuaJIT single-executable app deployment
---

## WORK IN PROGRESS

## What Is

Bundle is a small framework for bundling together LuaJIT, Lua modules,
Lua/C modules, C libraries, and other static assets into a single fat
executable. In its default configuration, it assumes luapower's [toolchain]
and [directory layout] and it works on Windows, Linux and OSX, x86 and x64.

## How it works

At the core there's a slightly modifed LuaJIT frontend which adds two
additional loaders at the end of the `package.loaders` table, enabling
`require()` to load modules embedded in the executable when they are
not found externally. `ffi.load()` is also modified to return `ffi.C`
if the requested library is not found, allowing embedded C symbols to be
used instead. Assets can be loaded with `bundle.load(filename)` on the same
policy: load the embedded asset if the corresponding file is not present.

This allows mixed deployments where some modules and assets are bundled
inside the exe and some are left outside, with no changes to the code needed.
External modules always take precedence over embedded ones, allowing
partial upgrades to the original executable without the need for a rebuild.
To close the circle, one of the modules (embedded or not) can be specified
to run instead of the usual command line, effectively enabling
single-executable app deployment for pure Lua apps (no glue C code needed).

## Usage


	./bundle.sh [options...]


## About compression

Compressing large executables is not always the best idea because compressed
executables cannot be mmapped, so they have to stay in RAM fully and always.
If the bundled assets are large and compressible, better results can be
acheived by compressing them individually instead of compressing the entire
exe. YMMV.


[toolchain]:         building.html
[directory layout]:  get-involved.html

