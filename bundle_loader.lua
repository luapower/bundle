
-- bundle loader module: runs when a luajit bundle starts.
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
