# go@ sh bundle.sh -v -o c:/1/a.exe -a --all
#!/bin/sh
#
#  Compile and link together LuaJIT, Lua modules, Lua/C modules, C libraries,
#  and other static assets into a single fat executable.
#
#  Tested with mingw, gcc and clang on Windows, Linux and OSX respectively.
#  Written by Cosmin Apreutesei. Public Domain.
#

say() { [ "$VERBOSE" ] && echo "$@"; }
verbose() { say "$@"; "$@"; }

# defaults -------------------------------------------------------------------

EXE_mingw=a.exe
EXE_linux=a.out
EXE_osx=a.out

# note: only the mingw linker is smart to ommit dlibs that are not used.
DLIBS_mingw="gdi32 msimg32 opengl32 winmm ws2_32"
DLIBS_linux=""
DLIBS_osx=""
FRAMEWORKS="ApplicationServices" # for OSX

APREFIX_mingw=
APREFIX_linux=lib
APREFIX_osx=lib

ALIBS="luajit"
MODULES="bundle_loader"
ICON=csrc/bundle/luajit2.ico

# list modules and libs ------------------------------------------------------

# usage: $0 basedir/file.lua|.dasl -> file.lua|.dasl
# note: skips test and demo modules, and other platforms modules.
lua_module() {
	local f=$1
	local ext=${f##*.}
	[ "$ext" != lua -a "$ext" != dasl ] && return
	[ "${f%_test.lua}" != $f ] && return
	[ "${f%_demo.lua}" != $f ] && return
	[ "${f#bin/}" != $f -a "${f#bin/$P/}" == $f ] && return
	echo $f
}

# usage: $0 [dir] -> module1.lua|.dasl ...
# note: skips looking in special dirs.
lua_modules() {
	for f in $1*; do
		if [ -d $f ]; then
			[ "${f:0:1}" != "_" \
				-a "${f:0:1}" != "." \
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

# usage: f='file1.lua ...' o=file.o $0 CFLAGS... -> file.o
compile_lua_module() {
	./luajit csrc/bundle/bcfsave.lua $f | f=- compile_c_module "$@"
}

# usage: f=file.dasl o=file.o $0 CFLAGS... -> file.o
compile_dasl_module() {
	./luajit dynasm.lua $f | m=$f f=- compile_lua_module "$@"
}

# usage: osuffix=suffix $0 file[.lua]|.c|.dasl CFLAGS... -> file.o
compile_module() {
	local f=$1; shift
	local x=${f##*.}                       # a.lua -> lua
	[ "$x" = $f ] && { x=lua; f=$f.lua; }
	local o=$ODIR/$f$osuffix.o             # a -> $ODIR/a.o
	OFILES="$OFILES $o"
	[ -f $o -a $o -nt $f ] && return       # does it need (re)compiling?
	mkdir -p `dirname $o`
	f=$f o=$o compile_${x}_module "$@"
	say "  $f"
}

# usage: $0 file.c
compile_bundle_module() {
	local f=$1; shift
	compile_module csrc/bundle/$f -Icsrc/bundle -Icsrc/luajit/src/src
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
	ODIR=_o/$P
	OFILES=""
	mkdir -p $ODIR || { echo "Cannot mkdir $ODIR"; exit 1; }
	compile_icon # the icon has to be first, believe it!
	compile_manifest
	for m in $MODULES; do
		compile_module $m
	done
	compile_bundle_module luajit.c
	local osuffix; local copt
	[ "$MAIN" ] && {
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
	g++ $CFLAGS $OFILES -o "$EXE" \
		-static-libgcc -static-libstdc++ \
		-Wl,-E \
		-Lbin/$P \
		-Wl,--whole-archive `aopt "$ALIBS"` \
		-Wl,--no-whole-archive -ldl `lopt "$DLIBS"` \
		&&	chmod +x "$EXE"
}

# usage: P=platform ALIBS='lib1 ...' DLIBS='lib1 ...' EXE=exe_file
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
	echo "Usage: $0 [-m32] [other-options...]"
	echo
	echo "  -o  --output <file>             Output executable [$EXE]"
	echo
	echo "  -m  --modules \"file1 ...\"|--all Lua (or C) modules to bundle"
	echo "  -a  --alibs \"lib1 ...\"|--all    Static libs to bundle        [1]"
	echo "  -d  --dlibs \"lib1 ...\"          Dynamic libs to link against [2]"
	[ $OS = osx ] && \
	echo "  -f  --frameworks \"frm1 ...\"     Frameworks to link against   [3]"
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
	[ $OS = mingw ] && \
	echo "  -i  --icon <file>               Set icon"
	[ $OS = mingw ] && \
	echo "  -w  --no-console                Hide the terminal / console"
	echo
	echo "  [1] implicit static libs:       "$ALIBS
	echo "  [2] implicit dynamic libs:      "$DLIBS
	[ $OS = osx ] && \
	echo "  [3] implicit frameworks:        "$FRAMEWORKS
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
				MODULES="$MODULES $1"
				[ "$1" = --all ] && MODULES="$(lua_modules)"
				shift
				;;
			-M  | --main)
				MAIN="$1"; shift;;
			-a  | --alibs)
				ALIBS="$ALIBS $1"
				[ "$1" = --all ] && ALIBS="$(alibs)"
				shift
				;;
			-d  | --dlibs)
				DLIBS="$DLIBS $1"; shift;;
			-f  | --frameworks)
				FRAMEWORKS="$FRAMEWORKS $1"; shift;;
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
