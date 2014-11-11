# go@ sh bundle.sh -v --alibs "luajit socket_core clipper" --modules "glue socket"
#!/bin/sh
#
#  Compile and link together LuaJIT, Lua modules, Lua/C modules, C libraries,
#  and other static assets into a single fat executable.
#
#  Tested with mingw, gcc and clang on Windows, Linux and OSX respectively.
#  Written by Cosmin Apreutesei. Public Domain.
#

say() { [ "$VERBOSE" ] && echo "$@"; }

# defaults -------------------------------------------------------------------

EXE_mingw=a.exe
EXE_linux=a.out
EXE_osx=a.out

# note: only the mingw linker is smart to ommit dlibs which no code uses.
DLIBS_mingw="gdi32 msimg32 opengl32 winmm ws2_32"
DLIBS_linux="dl pthread"
DLIBS_osx=""
FRAMEWORKS="ApplicationServices" # for OSX

APREFIX_mingw=
APREFIX_linux=lib
APREFIX_osx=lib

ALIBS="luajit"

# list modules and libs ------------------------------------------------------

# usage: $0 ./dir/file.lua -> file.lua
# note: skips test and demo modules.
lua_module() {
	local f=$1
	local ext=${f##*.}
	[ "$ext" != lua ] && return
	[ "${f%_test.lua}" != $f ] && return
	[ "${f%_demo.lua}" != $f ] && return
	f=${f:2}     # ./a/b.lua -> a/b.lua
	echo $f
}

# usage: $0 <dir> -> module1.lua ...
# note: skips looking in special dirs.
lua_modules_in() {
	for f in $1/*; do
		if [ -d $f ]; then
			[ "${f:2:1}" != "_" \
				-a "${f:2:1}" != "." \
				-a "${f:2:3}" != bin \
				-a "${f:2:4}" != csrc \
				-a "${f:2:5}" != media \
			] && \
				lua_modules_in $f
		else
			lua_module $f
		fi
	done
}

# usage: $0 -> a/b.lua ...
lua_modules() {
	lua_modules_in .
}

# usage: P=<platform> $0 -> lib1 ...
alibs() {
	(cd bin/$P &&
		for f in *.a; do
			local m=${f%*.*}   # libz.* -> libz
			echo ${m#$APREFIX} # libz -> z
		done)
}

# compiling ------------------------------------------------------------------

# usage: f=<file.lua> o=<file.o> m=<module> $0 CFLAGS... -> file.o
compile_lua_module() {
	# we compile with gcc for compatibility with mingw, and also because
	# we want to replace the luaJIT_BC_ prefix with luaJIT_BCF_.
	# using luaJIT_BCF_ ensures that our loader is used, which runs last.
	./luajit -b $f -n $m -t c - | \
		sed 's/luaJIT_BC_/luaJIT_BCF_/g' | \
			gcc -c -xc - -o $o "$@"
}

# usage: f=<file.c> o=<file.o> $0 CFLAGS... -> file.o
compile_c_module() {
	gcc -c $f -o $o "$@"
}

set_module_vars() {
	f=$1
	x=${f##*.}             # a/b.lua -> lua
	[ "$x" = $f ] && { x=lua; f=$f.lua; }
	m=${f%*.*}             # a/b.lua -> a/b
	m=`echo $m | tr / _`   # a/b -> a_b (posix compliant)
	o=$ODIR/${x}_$m.o      # a_b -> $ODIR/lua_a_b.o
}

# usage: $0 module1[.lua]|.c CFLAGS...
compile_module() {
	set_module_vars $1; shift
	OFILES="$OFILES $o"
	[ -f $o -a $o -nt $f ] && return # does it need (re)compiling?
	echo "  $f"
	f=$f o=$o m=$m compile_${x}_module $CFLAGS "$@"
}

# usage: $0 <file.c>
compile_bundle_module() {
	compile_module csrc/bundle/$1 -Icsrc/bundle -Icsrc/luajit/src/src
}

# add an icon file for the exe file and main window (Windows only)
# usage: ICON=<file> $0 -> _icon.o
compile_icon() {
	[ "$OS" = mingw ] || return
	rm -f $ODIR/_icon.o
	[ "$ICON" ] || return
	echo -n "0  ICON  \"$ICON\"" | windres -o $ODIR/_icon.o
}

# add a manifest file to enable the exe to use comctl 6.0
# usage: $0 -> _manifest.o
compile_manifest() {
	[ "$OS" = mingw ] || return
	echo "\
		#include \"winuser.h\"
		1 RT_MANIFEST bin/mingw32/luajit.exe.manifest
		" | windres -o $ODIR/_manifest.o
}

# usage: MODULES=<mod1...> $0 -> $ODIR/*.o
compile_all() {
	say "Compiling modules..."
	ODIR=_o/$P
	OFILES=""
	mkdir -p $ODIR || { echo "Cannot mkdir $ODIR"; exit 1; }
	for m in $MODULES; do
		compile_module $m
	done
	compile_bundle_module bundle_loaders.c
	compile_bundle_module luajit.c
	compile_manifest
	compile_icon
}

# linking --------------------------------------------------------------------

aopt() { for f in $1; do echo "bin/$P/$APREFIX$f.a"; done; }
lopt() { for f in $1; do echo "-l$f"; done; }
fopt() { for f in $1; do echo "-framework $f"; done; }

# usage: P=<platform> ALIBS=<lib1...> DLIBS=<lib1...>
#        EXE=<exe_file> NOCONSOLE=1 $0
link_mingw() {

	local mingw_lib_dir
	if [ $P = mingw32 ]; then
		mingw_lib_dir="$(dirname "$(which gcc)")/../lib"
	else
		mingw_lib_dir="$(dirname "$(which gcc)")/../x86_64-w64-mingw32/lib"
	fi

	# make a windows app or a console app
	local opt; [ "$NOCONSOLE" ] && opt=-mwindows

	g++ $opt $CFLAGS $OFILES -o "$EXE" \
		-static -static-libgcc -static-libstdc++ \
		-Wl,--enable-stdcall-fixup \
		-Wl,--export-all-symbols \
		-Lbin/$P \
		-Wl,--whole-archive `aopt "$ALIBS"` \
		-Wl,--no-whole-archive "$mingw_lib_dir"/libmingw32.a \
		`lopt "$DLIBS"`
}

# usage: P=<platform> ALIBS=<lib1...> DLIBS=<lib1...> EXE=<exe_file>
link_linux() {
	g++ $CFLAGS $OFILES -o "$EXE" \
		-static-libgcc -static-libstdc++ \
		-Wl,-E \
		-Lbin/$P \
		-Wl,--whole-archive `aopt "$ALIBS"` \
		-Wl,--no-whole-archive `lopt "$DLIBS"` \
	&&	chmod +x "$EXE"
}

# usage: P=<platform> ALIBS=<lib1...> DLIBS=<lib1...> EXE=<exe_file>
link_osx() {
	gcc $CFLAGS $OFILES -o "$EXE" \
		-stdlib=libstdc++ \
		-Lbin/$P \
		`lopt "$DLIBS"` \
		`fopt "$FRAMEWORKS"` \
		-Wl,-all_load `aopt "$ALIBS"` \
	&&	chmod +x "$EXE"
}

link_all() {
	say "Linking $EXE..."
	link_$OS
}

compress_exe() {
	[ "$COMPRESS_EXE" ] || return
	say "Compressing $EXE..."
	which upx >/dev/null && upx -qqq "$EXE"
}

# usage: P=<platform> MODULES=<mod1...> ALIBS=<lib1...> DLIBS=<lib1...>
#         MAIN=<module> EXE=<exe_file> NOCONSOLE=1 ICON=<icon> COMPRESS_EXE=1 $0
bundle() {
	say "Bundle parameters:"
	say "  Platform:       $OS ($P)"
	say "  Modules:        "$MODULES
	say "  Static libs:    "$ALIBS
	say "  Dynamic libs:   "$DLIBS
	say
	compile_all
	link_all
	compress_exe
	say "Done."
}

# cmdline --------------------------------------------------------------------

usage() {
	echo "Usage: $0 [-m32] [other-options...]"
	echo
	echo "  -o  --output <file>             Output executable [$EXE]"
	echo
	echo "  -m  --modules \"file1 ...\"|--all Lua (or C) modules to bundle"
	echo "  -a  --alibs \"lib1 ...\"|--all    Static libs to bundle ["$ALIBS"]"
	echo "  -d  --dlibs \"lib1 ...\"          Dynamic libs to link against [*]"
	echo
	echo "  -M  --main <module>             Module to run on start-up"
	#echo "  -pl --package.path <spec>       Set package.path"
	#echo "  -pc --package.cpath <spec>      Set package.cpath"
	echo
	echo "  -ll --list-lua-modules          List Lua modules"
	echo "  -la --list-alibs                List static libs (.a files)"
	echo
	echo "  -m32                            Force 32bit platform"
	echo "  -z  --compress                  Compress the executable"
	echo "  -i  --icon <file>               Set icon (for Windows and OSX)"
	echo "  -w  --no-console                Do not show the terminal / console"
	echo
	echo "  [*] default dlibs: "$DLIBS
	echo
}

# usage: $0 [force_32bit]
set_platform() {
	if [ "$OSTYPE" = msys ]; then
		[ "$1" -o ! -f "$SYSTEMROOT\SysWOW64\kernel32.dll" ] && \
			P=mingw32 || P=mingw64
	else
		local a
		[ "$1" -o "$(uname -m)" != x86_64 ] && a=32 || a=64
		[ "${OSTYPE#darwin}" != "$OSTYPE" ] && P=osx$a || P=linux$a
	fi
	OS=${P%[0-9][0-9]}
	eval EXE=\$EXE_$OS
	eval DLIBS=\$DLIBS_$OS
	eval APREFIX=\$APREFIX_$OS
	[ $P = osx32 ] && CFLAGS="-arch i386"
	[ $P = osx64 ] && CFLAGS="-arch x86_64"
}

parse_cmdline() {
	while [ "$1" ]; do
		local opt="$1"; shift
		case "$opt" in
			-o  | --output)
				EXE="$1"; shift;;
			-m  | --modules)
				MODULES="$1"; shift
				[ "$MODULES" = --all ] && MODULES="$(lua_modules)";;
			-M  | --main)
				MAIN="$1"; shift;;
			-a  | --alibs)
				ALIBS="$1"; shift
				[ "$ALIBS" = --all ] && ALIBS="$(alibs)";;
			-d  | --dlibs)
				DLIBS="$1"; shift;;
			-ll | --list-lua-modules)
				lua_modules; exit;;
			-la | --list-alibs)
				alibs; exit;;
			-m32)
				set_platform m32;;
			-z  | --compress)
				COMPRESS_EXE=1;;
			-i  | --icon)
				ICON="$1"; shift;;
			-w  | --no-console)
				NOCONSOLE=1;;
			-h  | --help)
				usage; exit;;
			-v | --verbose)
				VERBOSE=1;;
			*)
				echo "Invalid option: $opt"
				usage "$opt"
				exit 1
				;;
		esac
	done
}

set_platform
parse_cmdline "$@"
bundle
