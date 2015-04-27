#!/bin/bash
# unit test for bundle

P="$1"
[ "$P" ] || P=`.mgit/platform.sh`
[ "$P" ] || exit 1
OS=${P%[0-9][0-9]}
[ $P = mingw32 -o $P = linux32 -o $P = osx32 ] && m32=-m32

D=.bundle-test/$P
EXE=test
[ $OS = mingw ] && EXE=test.exe

mkdir -p $D

# make a large file to test blob loading.
blobfile=$D/big.blob
blobsize=$((20*1024*1024))
[ -f $blobfile ] || \
	echo "Creating $blobfile..."
	(printf header
	cat /dev/zero | head -c $blobsize
	printf footer
	) > $blobfile

# bundle everything; the main script is bundle_test.
.mgit/bundle.sh $m32 -v -a --all -m --all -m bundle_test -m $blobfile -M bundle_test -o $D/$EXE

# we don't static link mysql (cuz it's GPL and we don't have a static lib for it anyway).
# so copy it to the dest. dir so we can test that too.
[ $OS = mingw ]  && cp -f bin/$P/libmysql.dll $D
[ $OS = linux ]  && cp -f bin/$P/libmysqlclient.so $D
[ $P = linux32 ] && cp -f bin/$P/libstdc++.so.6.0 $D
[ $P = linux64 ] && cp -f bin/$P/libstdc++.so.6 $D
[ $OS = osx ]    && cp -f bin/$P/libmysqlclient.dylib $D

# run the test
cd $D && ./$EXE
