#!/bin/bash

usage() {
	[ "$1" ] && echo "invalid option: $1"
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
}

[[ $# == 0 ]] && usage

while [[ $# > 0 ]]; do
	k="$1"; shift
	case $k in
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
		;;
		-lc | --list-clib)
		;;
		-ll | --list-lua)
		;;
		-z  | --upx)
		;;
		-c  | --clib)
		;;
		-i  | --icon)
		;;
		-w  | --no-console)
		;;
		*)
			usage "$k"
		;;
	esac
done
