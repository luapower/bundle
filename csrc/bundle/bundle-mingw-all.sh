export C_LIBS="
luajit sha2 lpeg z freetype pixman png cairo chipmunk cjson clipper
dasm_x86 expat fribidi genx gif glut ucdn harfbuzz hunspell lanes_core
lfs b64 exif jpeg unibreak md5 minizip nanojpeg2 pmurhash
socket_core struct vararg
"
export SYS_LIBS="
stdc++ gdi32 msimg32 opengl32 winmm ws2_32
"
export LUA_MODULES="
sha2
zlib zlib_h
freetype freetype_h
libpng libpng_h
cairo cairo_h
chipmunk chipmunk_h
clipper
dasm dasm_x64 dynasm
expat expat_h
fribidi fribidi_h
genx genx_h
giflib giflib_h
glut
ucdn
harfbuzz harfbuzz_h
hunspell
lanes
libb64
libexif libexif_h
libjpeg libjpeg_h
libunibreak
md5
minizip minizip_h
nanojpeg
pmurhash
socket socket.ftp socket.headers socket.http socket.mbox socket.smtp
socket.tftp socket.tp socket.url ltn12 mime

glue
stdio
"
export ICON_FILE=C:/luapower/csrc/wluajit/luajit.ico

exec ./bundle-mingw.sh
