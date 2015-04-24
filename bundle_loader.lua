
-- bundle loader module: runs when a bundled executable starts.
-- returns a "main" function which is called with the args from cmdline.
-- Written by Cosmin Apreutesei. Public domain.

local ffi = require'ffi'

--overload ffi.load to fallback to ffi.C when the lib is not found.
local ffi_load = ffi.load
function ffi.load(...)
	local ok, C = pcall(ffi_load, ...)
	if not ok then
		return ffi.C
	else
		return C
	end
end

--find a module in package.loaders, like require() does.
local function find_module(name)
	for _, loader in ipairs(package.loaders) do
		local chunk = loader(name)
		if type(chunk) == 'function' then
			return chunk
		end
	end
end

return function(...)
	--set package paths relative to the exe dir.
	--NOTE: this only works as long as the current dir doesn't change,
	--but unlike the '!' symbol in package paths, it's portable.
	local dir = arg[0]:gsub('[/\\]?[^/\\]+$', '') --arg[0] is the exe path
	local slash = package.config:sub(1,1)
	package.path = string.format('lua/%s/?.lua;lua/%s/?/init.lua', dir, dir):gsub('/', slash)
	package.cpath = string.format('%s/clib/?.dll', dir):gsub('/', slash)

	--find and run the main module, its name given in arg[-1].
	local m = arg[-1]
	if not m then
		return true --no module specified: fallback to luajit frontend
	end
	m = find_module(m)
	if not m then
		return true --module not found: fallback to luajit frontend
	end
	local ok, err = xpcall(m, debug.traceback, ...)
	if not ok then
		error(err, 2)
	end
end
