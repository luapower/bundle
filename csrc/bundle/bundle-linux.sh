# build a static luajit binary, bundling C modules, Lua/C modules and
# Lua modules, all exported for loading via ffi.load() and require().

# args
[ "$C_LIBS" ] || exit
[ "$LUA_MODULES" ] || exit
[ "$PLATFORM" ] || exit
[ "$EXE_FILE" ] || exit

# do everything from the bin dir
cd ../../bin/$PLATFORM || exit

# remove .o files because we're using *.o later
rm -f *.o

# add lua modules: *.lua -> *.c -> *.o
for f in $LUA_MODULES; do
	f="${f//\.//}"   # a.b -> a/b
	d="${f//\//_}"   # a/b -> a_b
	./luajit -b ../../$f.lua $d.o
done

# add C static libs
ALIBS=""
for f in $C_LIBS; do
	ALIBS="$ALIBS lib$f.a"
done

# add external, dynamic dependencies
DEPS=""
for f in $SYS_LIBS; do
	DEPS="$DEPS -l$f"
done

if [ "$ARG1" ]; then
	# compile luajit.c but with main() renamed to _main().
	# lmain.c defines main() and calls _main().
	gcc -c -Dmain=_main ../../csrc/luajit/src/src/luajit.c \
	    -I ../../csrc/luajit/src/src \
	    -I ../../csrc/lua
	# lmain.c defines main() which calls _main() with $ARG1 in argv[1].
	MAIN="-DARG1=\"$ARG1\" ../../csrc/wluajit/lmain.c"
else
	# use the main() from luajit.c directly.
	MAIN=../../csrc/luajit/src/src/luajit.c
fi

# link everything together to $EXE_FILE
gcc -fPIC -static-libgcc -static-libstdc++ \
	$MAIN *.o \
	-o "$EXE_FILE" \
	-Wl,-E \
	-Wl,--whole-archive $ALIBS \
	-Wl,--no-whole-archive \
	-Bdynamic $DEPS

# clean up
rm -f *.c
rm -f *.o
