
-- Bundle Lua API, currently containing the blob loader.
-- Written by Cosmin Apreutesei. Public Domain.

local ffi = require'ffi'
local BLOB_PREFIX = 'Blob_'

local function getfile(file)
	local f, err = io.open(file, 'rb')
	if not f then return end
	local s = f:read'*a'
	f:close()
	return s
end

local function symname(file)
	return BLOB_PREFIX..file:gsub('[\\%-/%.]', '_')
end

local function getsym(sym)
	ffi.cdef('void '..sym..'()')
	return ffi.cast('const void*', ffi.C[sym])
end

local function getblob(file)
	local sym = symname(file)
	local ok, p = pcall(getsym, sym)
	if not ok then return end
	p = ffi.cast('const uint32_t*', p)
	return ffi.string(p+1, p[0])
end

local function load(file)
	return getfile(file) or getblob(file)
end

return {
	load = load,
}
