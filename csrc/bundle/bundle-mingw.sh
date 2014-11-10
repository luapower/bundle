# build a static luajit executable, bundling chosen C modules, Lua/C modules
# and Lua modules, all prepared for loading via ffi.load() and require().

# args
[ "$C_LIBS" ] || exit
[ "$LUA_MODULES" ] || exit
[ "$PLATFORM" ] || exit
[ "$EXE_FILE" ] || exit

MINGW_LIB_DIR="$(dirname "$(which gcc)")/../x86_64-w64-mingw32/lib"

# do everything from $BIN_DIR
cd ../../bin/$PLATFORM || exit

# remove .o files because we're using *.o later
rm -f *.o

# add Lua modules: *.lua -> *.c -> *.o
for m in $LUA_MODULES; do
	f="${m//\.//}"   # a.b -> a/b
	d="${f//\//_}"   # a/b -> a_b
	# we compile with gcc for compatibility with mingw, and also because
	# we want to replace the luaJIT_BC_ prefix with luaJIT_BCF_.
	# using luaJIT_BCF_ ensures that our loader, which runs last, is used.
	./luajit -b ../../$f.lua -n $d -t c - | \
		sed 's/luaJIT_BC_/luaJIT_BCF_/g' | \
			gcc -c -xc -o $d.o -
done

# add our custom luajit frontend and loaders.
gcc -c ../../csrc/luajit/bundle/*.c \
	-I../../csrc/luajit \
	-I../../csrc/luajit/src/src

# add the bundle init module.
./luajit -b ../../csrc/luajit/bundle/bundle_init.lua bundle_init.c
gcc -c bundle_init.c

# add the Lua main module
[ "$MAIN_MODULE" ] || \
	MAIN_MODULE=csrc/luajit/bundle/bundle_main
./luajit -b ../../$MAIN_MODULE.lua bundle_main.c
gcc -c bundle_main.c

# add C static libs
ALIBS=""
for f in $C_LIBS; do
	ALIBS="$ALIBS $f.a"
done

# add external, dynamic dependencies
DEPS=""
for f in $SYS_LIBS; do
	DEPS="$DEPS -l$f"
done

# add optional icon file: icon file + icon.rc -> _icon.o
[ "$ICON_FILE" ] && {
	echo -n "0  ICON  \"$ICON_FILE\"" > _icon.rc
	windres _icon.rc _icon.o
}

# add manifest file to enable the exe to use comctl 6.0
echo "\
#include \"winuser.h\"
1 RT_MANIFEST luajit.exe.manifest
" > _manifest.rc
windres _manifest.rc _manifest.o

# make a windows app or a console app
[ "$NOCONSOLE" ] && \
	OPT="$OPT -mwindows"

# link everything together to $EXE_FILE
gcc $OPT *.o \
	-static -static-libgcc -static-libstdc++ -o "$EXE_FILE" \
	-Wl,--enable-stdcall-fixup \
	-Wl,--export-all-symbols \
	-Wl,--whole-archive $ALIBS \
	-Wl,--no-whole-archive "$MINGW_LIB_DIR"/libmingw32.a \
	-Bdynamic $DEPS

# compress the exe file
#which upx >/dev/null && upx -qqq "$EXE_FILE"

# clean up
#rm -f *.c
rm -f *.o
rm _*.rc
