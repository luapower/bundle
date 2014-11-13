
-- part of bcsave.lua from luajit that outputs a module's bytecode as
-- C code to stdout, with two modifications:
-- 1) the symbol prefix is luaJIT_BCF_ instead of luaJIT_BC_, and
-- 2) the first 4 bytes represent the bytecode size encoded as a int32_t.

local ffi = require'ffi'

local function out(...)
	io.stdout:write(...)
end

local function symname(s)
	if s=='-' then s = os.getenv'm' end
	return s:gsub('[\\%-/%.]', '_'):gsub('%.lua$', '')
end

local function bcout(file)
	local code
	if file == '-' then --stdin
		code = loadstring(io.stdin:read'*a')
	else
		code = loadfile(file)
	end
	local s = string.dump(code)

	out(string.format([[
#ifdef _cplusplus
extern "C"
#endif
#ifdef _WIN32
__declspec(dllexport)
#endif
const char luaJIT_BCF_%s[] = {
]], symname(file)))

	local sz = ffi.new('int32_t[1]', #s)
	local psz = ffi.cast('uint8_t*', sz)
	for i=3,0,-1 do
		s = string.char(psz[i])..s
	end

	local t, n, m = {}, 0, 0
	for i=1,#s do
		local b = tostring(string.byte(s, i))
		m = m + #b + 1
		if m > 78 then
			out(table.concat(t, ",", 1, n), ",\n")
			n, m = 0, #b + 1
		end
		n = n + 1
		t[n] = b
	end

	out(table.concat(t, ",", 1, n).."\n};\n")
end

for i=1,select('#', ...) do
	bcout(select(i, ...))
end
