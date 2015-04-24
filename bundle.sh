#!/bin/bash
shopt -s nullglob
say() { [ "$VERBOSE" ] && echo "$@"; }
verbose() { say "$@"; "$@"; }

# defaults -------------------------------------------------------------------

BLOB_PREFIX=Blob_

# note: only the mingw linker is smart to ommit dlibs that are not used.
DLIBS_mingw="gdi32 msimg32 opengl32 winmm ws2_32"
DLIBS_linux=
DLIBS_osx=
FRAMEWORKS="ApplicationServices" # for OSX

APREFIX_mingw=
APREFIX_linux=lib
APREFIX_osx=lib

ALIBS="luajit"
MODULES="bundle_loader"
ICON=csrc/bundle/luajit2.ico

IGNORE_ODIR=
COMPRESS_EXE=
NOCONSOLE=
VERBOSE=

# list modules and libs ------------------------------------------------------

# usage: P=<platform> $0 basedir/file.lua|.dasl -> file.lua|.dasl
# note: skips test and demo modules, and other platforms modules.
lua_module() {
	local f=$1
	local ext=${f##*.}
	[ "$ext" != lua -a "$ext" != dasl ] && return
	[ "${f%_test.lua}" != $f ] && return
	[ "${f%_demo.lua}" != $f ] && return
	[ "${f#bin/}" != $f -a "${f#bin/$P/}" = $f ] && return
	echo $f
}

# usage: P=<platform> $0 [dir] -> module1.lua|.dasl ...
# note: skips looking in special dirs.
lua_modules() {
	for f in $1*; do
		if [ -d $f ]; then
			[ "${f:0:1}" != "." \
				-a "${f:0:4}" != csrc \
				-a "${f:0:5}" != media \
			] && \
				lua_modules $f/
		else
			lua_module $f
		fi
	done
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

# usage: f=file.c o=file.o $0 CFLAGS... -> file.o
compile_c_module() {
	gcc -c -xc $f -o $o $CFLAGS "$@"
}

# usage: f='file1.lua ...' o=file.o | f=- m=file.o $0 CFLAGS... -> file.o
compile_lua_module() {
	./luajit csrc/bundle/bcfsave.lua $f | f=- compile_c_module "$@"
}

# usage: f=file.dasl o=file.o $0 CFLAGS... -> file.o
compile_dasl_module() {
	./luajit dynasm.lua $f | m=$f f=- compile_lua_module "$@"
}

# usage: f=file.* o=file.o $0 CFLAGS... -> file.o
compile_bin_module()
{
	local m=`echo $f | tr '[/\.\-\\\\]' _`
	echo "\
	.global $BLOB_PREFIX$m
	.section .rodata
$BLOB_PREFIX$m:
	.int data2 - data1
data1:
	.incbin \"$f\"
data2:
	" | gcc -c -xassembler - -o $o $CFLAGS "$@"
}

# usage: osuffix=suffix $0 file[.lua]|.c|.dasl CFLAGS... -> file.o
compile_module() {
	local f=$1; shift
	local x=${f##*.}                         # a.lua -> lua
	[ "$x" = $f ] && { x=lua; f=$f.lua; }    # a -> a.lua
	[ $x != lua -a $x != dasl -a $x != c ] && x=bin
	local o=$ODIR/$f$osuffix.o               # a -> $ODIR/a.o
	OFILES="$OFILES $o"
	[ -z "$IGNORE_ODIR" -a -f $o -a $o -nt $f ] && return # use cache
	mkdir -p `dirname $o`
	f=$f o=$o compile_${x}_module "$@"
	say "  $f"
}

# usage: $0 file.c CFLAGS... -> file.o
compile_bundle_module() {
	local f=$1; shift
	compile_module csrc/bundle/$f -Icsrc/bundle -Icsrc/luajit/src/src "$@"
}

# usage: o=file.o $0
compile_resource() {
	OFILES="$OFILES $o"
	say "  $o"
	echo "$s" | windres -o $o
}

# add an icon file for the exe file and main window (Windows only)
# usage: ICON=file $0 -> _icon.o
compile_icon() {
	[ "$OS" = mingw ] || return
	[ "$ICON" ] || return
	o=$ODIR/_icon.o s="0  ICON  \"$ICON\"" compile_resource
}

# add a manifest file to enable the exe to use comctl 6.0
# usage: $0 -> _manifest.o
compile_manifest() {
	[ "$OS" = mingw ] || return
	s="\
		#include \"winuser.h\"
		1 RT_MANIFEST bin/mingw32/luajit.exe.manifest
		" o=$ODIR/_manifest.o compile_resource
}

# usage: MODULES='mod1 ...' $0 -> $ODIR/*.o
compile_all() {
	say "Compiling modules..."
	ODIR=.bundle-tmp/$P
	OFILES=
	mkdir -p $ODIR || { echo "Cannot mkdir $ODIR"; exit 1; }
	compile_icon # the icon has to be linked first, believe it!
	compile_manifest
	for m in $MODULES; do
		compile_module $m
	done
	compile_bundle_module luajit.c
	local osuffix
	local copt
	[ "$MAIN" ] && {
		# bundle.c is a template: it compiles differently for each BUNDLE_MAIN,
		# so we make a different .o file for each unique value of $MAIN.
		osuffix=_$MAIN
		copt=-DBUNDLE_MAIN=$MAIN
	}
	osuffix=$osuffix compile_bundle_module bundle.c $copt
}

# linking --------------------------------------------------------------------

aopt() { for f in $1; do echo "bin/$P/$APREFIX$f.a"; done; }
lopt() { for f in $1; do echo "-l$f"; done; }
fopt() { for f in $1; do echo "-framework $f"; done; }

# usage: P=platform ALIBS='lib1 ...' DLIBS='lib1 ...'
#        EXE=exe_file NOCONSOLE=1 $0
link_mingw() {

	local mingw_lib_dir
	if [ $P = mingw32 ]; then
		mingw_lib_dir="$(dirname "$(which gcc)")/../lib"
	else
		mingw_lib_dir="$(dirname "$(which gcc)")/../x86_64-w64-mingw32/lib"
	fi

	# make a windows app or a console app
	local opt; [ "$NOCONSOLE" ] && opt=-mwindows

	verbose g++ $opt $CFLAGS $OFILES -o "$EXE" \
		-static -static-libgcc -static-libstdc++ \
		-Wl,--export-all-symbols \
		-Wl,--whole-archive `aopt "$ALIBS"` \
		-Wl,--no-whole-archive \
		"$mingw_lib_dir"/libmingw32.a \
		`lopt "$DLIBS"`

}

# usage: P=platform ALIBS='lib1 ...' DLIBS='lib1 ...' EXE=exe_file
link_linux() {
	verbose g++ $CFLAGS $OFILES -o "$EXE" \
		-static-libgcc -static-libstdc++ \
		-Wl,-E \
		-Lbin/$P \
		-Wl,--whole-archive `aopt "$ALIBS"` \
		-Wl,--no-whole-archive -ldl `lopt "$DLIBS"` \
		&&	chmod +x "$EXE"
}

# usage: P=platform ALIBS='lib1 ...' DLIBS='lib1 ...' EXE=exe_file
link_osx() {
	# note: luajit needs these flags for OSX/x64, see http://luajit.org/install.html#embed
	local xopt
	[ $P = osx64 ] && xopt="-pagezero_size 10000 -image_base 100000000"
	# note: using -stdlib=libstdc++ because in 10.9+, libc++ is the default.
	verbose g++ $CFLAGS $OFILES -o "$EXE" \
		-mmacosx-version-min=10.6 \
		-stdlib=libstdc++ \
		-Lbin/$P \
		`lopt "$DLIBS"` \
		`fopt "$FRAMEWORKS"` \
		-Wl,-all_load `aopt "$ALIBS"` $xopt \
	&&	chmod +x "$EXE"
}

link_all() {
	say "Linking $EXE..."
	link_$OS
}

compress_exe() {
	[ "$COMPRESS_EXE" ] || return
	say "Compressing $EXE..."
	which upx >/dev/null || { say "UPX not found."; return; }
	upx -qqq "$EXE"
}

# usage: P=platform MODULES='mod1 ...' ALIBS='lib1 ...' DLIBS='lib1 ...'
#         MAIN=module EXE=exe_file NOCONSOLE=1 ICON=icon COMPRESS_EXE=1 $0
bundle() {
	say "Bundle parameters:"
	say "  Platform:      " "$OS ($P)"
	say "  Modules:       " $MODULES
	say "  Static libs:   " $ALIBS
	say "  Dynamic libs:  " $DLIBS
	say "  Main module:   " $MAIN
	say "  Icon:          " $ICON
	compile_all
	link_all
	compress_exe
	say "Done."
}

# cmdline --------------------------------------------------------------------

usage() {
	echo
	echo " Compile and link together LuaJIT, Lua modules, Lua/C modules, C libraries,"
	echo " and other static assets into a single fat executable."
	echo
	echo " Tested with mingw, gcc and clang on Windows, Linux and OSX respectively."
	echo " Written by Cosmin Apreutesei. Public Domain."
	echo
	echo " USAGE: $0 options..."
	echo
	echo "  -o  --output FILE                  Output executable (required)"
	echo
	echo "  -m  --modules \"FILE1 ...\"|--all|-- Lua (or other) modules to bundle [1]"
	echo "  -a  --alibs \"LIB1 ...\"|--all|--    Static libs to bundle            [2]"
	echo "  -d  --dlibs \"LIB1 ...\"|--          Dynamic libs to link against     [3]"
	[ $OS = osx ] && \
	echo "  -f  --frameworks \"FRM1 ...\"        Frameworks to link against       [4]"
	echo
	echo "  -M  --main MODULE                  Module to run on start-up"
	echo
	[ $OS = osx ] && \
	echo "  -m32                               Force 32bit platform"
	echo "  -z  --compress                     Compress the executable (needs UPX)"
	[ $OS = mingw ] && \
	echo "  -i  --icon FILE                    Set icon"
	[ $OS = mingw ] && \
	echo "  -w  --no-console                   Hide the terminal / console"
	echo
	echo "  -ll --list-lua-modules             List Lua modules"
	echo "  -la --list-alibs                   List static libs (.a files)"
	echo
	echo "  -C  --clean                        Ignore the object cache"
	echo
	echo "  -v  --verbose                      Be verbose"
	echo "  -h  --help                         Show this screen"
	echo
   echo " Passing -- clears the list of args for that option, including implicit args."
	echo
	echo " [1] .lua, .c and .dasl are compiled, other files are added as blobs."
	echo
	echo " [2] implicit static libs:           "$ALIBS
	echo " [3] implicit dynamic libs:          "$DLIBS
	[ $OS = osx ] && \
	echo " [4] implicit frameworks:            "$FRAMEWORKS
	echo
	exit
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
	[ $P = osx32 ] && CFLAGS="-arch i386"
	[ $P = osx64 ] && CFLAGS="-arch x86_64"
}

set_platform

OS=${P%[0-9][0-9]}
eval DLIBS=\$DLIBS_$OS
eval APREFIX=\$APREFIX_$OS

parse_opts() {
	while [ "$1" ]; do
		local opt="$1"; shift
		case "$opt" in
			-o  | --output)
				EXE="$1"; shift;;
			-m  | --modules)
				[ "$1" = -- ] && MODULES= || MODULES="$MODULES $1"
				[ "$1" = --all ] && MODULES="$(lua_modules)"
				shift
				;;
			-M  | --main)
				MAIN="$1"; shift;;
			-a  | --alibs)
				[ "$1" = -- ] && ALIBS= || ALIBS="$ALIBS $1"
				[ "$1" = --all ] && ALIBS="$(alibs)"
				shift
				;;
			-d  | --dlibs)
				[ "$1" = -- ] && DLIBS= || DLIBS="$DLIBS $1"
				shift
				;;
			-f  | --frameworks)
				[ "$1" = -- ] && FRAMEWORKS= || FRAMEWORKS="$FRAMEWORKS $1"
				shift
				;;
			-ll | --list-lua-modules)
				lua_modules; exit;;
			-la | --list-alibs)
				alibs; exit;;
			-C  | --clean)
				IGNORE_ODIR=1;;
			-m32)
				set_platform m32;;
			-z  | --compress)
				COMPRESS_EXE=1;;
			-i  | --icon)
				ICON="$1"; shift;;
			-w  | --no-console)
				NOCONSOLE=1;;
			-h  | --help)
				usage;;
			-v | --verbose)
				VERBOSE=1;;
			*)
				echo "Invalid option: $opt"
				usage "$opt"
				;;
		esac
	done
	[ "$EXE" ] || usage
}

parse_opts "$@"
bundle
