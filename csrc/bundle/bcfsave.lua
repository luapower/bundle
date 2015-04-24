
-- byte code saver, taken from bcsave.lua from luajit.
-- outputs Lua bytecode or other binary data as C code to stdout.
-- differences from luajit's bcsave:
-- * only outputs C code (other output formats were stripped).
-- * the symbol prefix is luaJIT_BCF_ instead of luaJIT_BC_.
-- * the first 4 bytes contain the bytecode size encoded as a uint32.
-- * module file name can be passed in env. var `m` when reading from stdin.
-- * `bin/*/lua/` prefix in filename is stripped when converting to symbol name.

local ffi = require'ffi'

local function readfile(file)
	if file == '-' then --stdin
		return io.stdin:read'*a'
	else
		local f = assert(io.open(file, 'r'))
		local s = f:read'*a'
		f:close()
		return s
	end
end

local function symname(s)
	if s=='-' then s = os.getenv'm' end
	local s1 = s:match'bin/[^/]+/lua/(.*)' --platform-specific Lua file
	s = s1 or s
	return s:gsub('%.lua$', ''):gsub('%.dasl$', ''):gsub('[\\%-/%.]', '_')
end

local function out(...)
	io.stdout:write(...)
end

local function bout(name, s)
	out(string.format([[
#ifdef _cplusplus
extern "C"
#endif
#ifdef _WIN32
__declspec(dllexport)
#endif
const char luaJIT_BCF_%s[] = {
]], name))

	local sz = ffi.new('uint32_t[1]', #s)
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

local function out(...)
	io.stdout:write(...)
end

local function bcout(file)
	local code = readfile(file)
	local chunk= assert(loadstring(code))
	local name = symname(file)
	local data = string.dump(chunk, file)
	bout(name, data)
end

local function bfout(file)
	local name = symname(file)
	local data = readfile(file)
	bout(name, data)
end

local use = bcout
for i=1,select('#', ...) do
	local arg = select(i, ...)
	if arg == '-b' then
		use = bfout
	elseif arg == '-l' then
		use = bcout
	else
		use(arg)
	end
end
