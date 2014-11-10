#!/bin/bash
#
#  Bundle script: compile and link together LuaJIT, Lua modules, Lua/C modules,
#  C libraries, and other static assets into a single fat executable.
#
#  Tested with mingw, gcc and clang on Windows, Linux and OSX respectively.
#  Written by Cosmin Apreutesei. Public Domain.
#

# find all Lua modules -------------------------------------------------------

lua_module() {
	local f=$1
	ext=${f##*.}
	[ "$ext" != lua ] && return
	[ "${f%_test.lua}" != $f ] && return
	[ "${f%_demo.lua}" != $f ] && return
	f=${f:2}     # ./a/b.lua -> a/b.lua
	f=${f%*.lua} # a/b.lua -> a/b
	echo $f
}

lua_modules() {
	for f in $1/*; do
		if [ -d $f ]; then
			[ "${f:2:1}" != "_" \
				-a "${f:2:1}" != "." \
				-a "${f:2:3}" != bin \
				-a "${f:2:4}" != csrc \
				-a "${f:2:5}" != media \
			] && \
				lua_modules $f
		else
			lua_module $f
		fi
	done
}

all_lua_modules() {
	lua_modules .
}

# find all C libs for a specific platform ------------------------------------

# usage: all_c_libs <platform>
all_c_libs() {
	(cd bin/$1 &&
		for f in *.a; do
			echo ${f%*.a} # lib.a -> lib
		done)
}

# compile Lua modules --------------------------------------------------------

# convert *.lua -> *.c -> *.o -> lua_modules.a
# usage: compile_lua_modules module1 [module2 ...]
compile_lua_modules() {
	echo "Compiling Lua modules..."
	local tmp=_luao
	mkdir -p $tmp || return
	for m in "$@"; do
		d="${m//\//_}"   # a/b -> a_b
		# we compile with gcc for compatibility with mingw, and also because
		# we want to replace the luaJIT_BC_ prefix with luaJIT_BCF_.
		# using luaJIT_BCF_ ensures that our loader, which runs last, is used.
		[ ! -f $tmp/$d.o -o $tmp/$d.o -ot $m.lua ] && {
			echo "  $m"
			./luajit -b $m.lua -n $d -t c - | \
				sed 's/luaJIT_BC_/luaJIT_BCF_/g' | \
					gcc -c -xc $CFLAGS -o $tmp/$d.o -
		}
	done
	ar rcs lua_modules.a $tmp/*.o
}

# link all -------------------------------------------------------------------

# add our custom luajit frontend and loaders.
compile_bundle() {
	gcc -c ../../csrc/luajit/bundle/*.c \
		-I../../csrc/luajit \
		-I../../csrc/luajit/src/src
}

# "lib1 lib2 ..." -> "lib1.a lib2.a ..."
a_libs() {
	ALIBS=""
	for f in $C_LIBS; do
		ALIBS="$ALIBS $f.a"
	done
}

# add external dependencies: "lib1 lib2 ..." -> "-llib1 -llib2 ..."
ext_libs() {
	DEPS=""
	for f in $SYS_LIBS; do
		DEPS="$DEPS -l$f"
	done
}

# add optional icon file: icon file + icon.rc -> _icon.o
compile_icon_file() {
	[ "$ICON_FILE" ] || return
	echo -n "0  ICON  \"$ICON_FILE\"" > _icon.rc
	windres _icon.rc _icon.o
}

# add manifest file to enable the exe to use comctl 6.0
compile_manifest_file() {
	echo "\
	#include \"winuser.h\"
	1 RT_MANIFEST luajit.exe.manifest
	" > _manifest.rc
	windres _manifest.rc _manifest.o
}

# make a windows app or a console app
[ "$NOCONSOLE" ] && \
	OPT="$OPT -mwindows"

# link everything together to $EXE_FILE
link_mingw() {
	gcc $OPT *.o \
		-static -static-libgcc -static-libstdc++ -o "$EXE_FILE" \
		-Wl,--enable-stdcall-fixup \
		-Wl,--export-all-symbols \
		-Wl,--whole-archive $ALIBS \
		-Wl,--no-whole-archive "$MINGW_LIB_DIR"/libmingw32.a \
		-Bdynamic $DEPS
}

alias link_mingw32=link_mingw
alias link_mingw64=link_mingw

# compress the exe file
compress_exe() {
	which upx >/dev/null && upx -qqq "$EXE_FILE"
}

# ui -------------------------------------------------------------------------

usage() {
	[ "$1" ] && echo "Invalid option: $1"
	echo "Usage: $0 [options...]"
	echo
	echo "  -o  --output <file>       output executable"
	echo
	echo "  -m  --main <module>       module to run on start-up"
	echo "  -l  --lua <module1,...>   Lua modules to bundle"
	echo "  -c  --clib <lib1, ...>    C libs to bundle (.a or .o)"
	echo
	echo "  -ll --list-lua            list all Lua modules"
	echo "  -lc --list-clib           list all C libs (.a and .o)"
	echo
	echo "  -p  --platform <platf>    specify the platform (autodetected)"
	echo
	echo "  -z  --compress            compress the executable"
	echo "  -i  --icon <file>         set icon (for Windows and OSX)"
	echo "  -w  --no-console          do not show the terminal / console"
	echo
	exit
}

list_lua_modules() {
	echo "Lua modules:"
	echo --------------
	all_lua_modules
	echo
	exit
}

list_c_libs() {
	echo "C Libs:"
	echo --------------
	all_c_libs
	echo
	exit
}

bundle_all() {
	[ "$PLATFORM" ] || PLATFORM=mingw64
	[ "$LUA_MODULES" ] || LUA_MODULES=`all_lua_modules`
	[ "$C_LIBS" ] || C_LIBS=`all_c_libs`
	compile_lua_modules $LUA_MODULES
	compile_bundle
	compile_icon_file
	compile_manifest_file
	a_libs
	ext_libs
	link_$1
	compress_exe
}

while [[ $# > 0 ]]; do
	k="$1"; shift
	case "$k" in
		-o  | --output)
			EXE_FILE="$k"
			shift
		;;

		-m  | --main)
			MAIN_MODULE="$k"
			shift
		;;
		-l  | --lua)
			LUA_MODULES="$LUA_MODULES $k"
			while [[ $# > 1 ]]; do
				k="$1"; shift
				case $k in
					-*)
						break
					;;
					*)
						LUA_MODULES="$k"
						shift
					;;
				esac
			done
		;;
		-c  | --clib)
			LUA_MODULES="$k"
		;;

		-p  | --platform)
			PLATFORM=$k
		;;
		-lc | --list-clib)
			list_c_libs
		;;
		-ll | --list-lua)
			list_lua_modules
		;;
		-z  | --upx)
		;;
		-c  | --clib)
		;;
		-i  | --icon)
		;;
		-w  | --no-console)
		;;
		-h | --help | *)
			usage "$k"
		;;
	esac
done

