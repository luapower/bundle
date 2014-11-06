
-- bundle init module: loaded automaticaly when the luajit bundle starts.
-- Written by Cosmin Apreutesei. Public domain.

local ffi = require'ffi'

--overload ffi.load to fallback on ffi.C where our embedded symbols are.
local ffi_load = ffi.load
function ffi.load(lib, ...)
	local ok, clib = pcall(ffi_load, lib, ...)
	if not ok then
		return ffi.C
	else
		return clib
	end
end

require'bundle_main'
