export C_LIBS="
luajit boxblur sha2
"
export SYS_LIBS="
dl m
"
export LUA_MODULES="
sha2 glue
"
exec ./bundle-linux.sh
