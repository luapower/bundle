
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
	ffi.cdef('const char* '..sym)
	return ffi.C[sym]
end

local function getblob(file)
	local sym = symname(file)
	local ok, p = pcall(getsym, sym)
	print(sym, ok, p)
	local ok, p2 = pcall(getsym, 'luaJIT_BCF_bundle')
	print('luaJIT_BCF_bundle', ok, p2)
	local ok, p3 = pcall(getsym, 'xluaJIT_BCF_bundle')
	print('xluaJIT_BCF_bundle', ok, p3)
	print(p2[0])

	--if not ok then return end
	--local sz = ffi.cast('const uint32_t*', p)[0]
	--print(p, sz)
	--return ffi.string(p+4, sz)
end

local function load(file)
	return getfile(file) or getblob(file)
end

return {
	load = load,
}
