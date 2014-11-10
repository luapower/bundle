/*
** Package loaders for bundled Lua and Lua/C modules.
** By Cosmin Apreutesei, no (c) claimed.
**
** Major portions taken verbatim or adapted from LuaJIT's lib_package.c.
** Copyright (C) 2005-2014 Mike Pall. See Copyright Notice in luajit.h
**
** Major portions taken verbatim or adapted from the Lua interpreter.
** Copyright (C) 1994-2012 Lua.org, PUC-Rio. See Copyright Notice in lua.h
*/

#include <string.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include "luajit.h"
#include "lj_def.h"
#include "lj_arch.h"
#include "lj_lib.h"

/* ------------------------------------------------------------------------ */

/* Symbol name prefixes. */
#define SYMPREFIX_CF		"luaopen_%s"
/* we use a separate prefix for "fallback" embedded modules */
#define SYMPREFIX_BC		"luaJIT_BCF_%s"

#if LJ_TARGET_DLOPEN

	#include <dlfcn.h>

	static void *ll_sym(const char *sym)
	{
		void *lib;
		#if defined(RTLD_DEFAULT)
			lib = RTLD_DEFAULT;
		#elif LJ_TARGET_OSX || LJ_TARGET_BSD
			lib = (void *)(intptr_t)-2;
		#endif
		return dlsym(lib, sym);
	}

#elif LJ_TARGET_WINDOWS

	#define WIN32_LEAN_AND_MEAN
	#include <windows.h>

	#ifndef GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS
	#define GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS  4
	#define GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT  2
	BOOL WINAPI GetModuleHandleExA(DWORD, LPCSTR, HMODULE*);
	#endif

	static void *ll_sym(const char *sym)
	{
		HINSTANCE h = GetModuleHandleA(NULL);
		void *p = GetProcAddress(h, sym);
		if (p == NULL && GetModuleHandleExA(
					GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
					GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
				(const char *)ll_sym, &h))
			p = GetProcAddress(h, sym);
		return p;
	}

#else

	static void *ll_sym(const char *sym)
	{
		UNUSED(sym);
		return NULL;
	}

#endif

/* ------------------------------------------------------------------------ */

static void **ll_register(lua_State *L, const char *name)
{
	void **plib;
	lua_pushfstring(L, "LOADLIB: %s", name);
	lua_gettable(L, LUA_REGISTRYINDEX);  /* check library in registry? */
	if (!lua_isnil(L, -1)) {  /* is there an entry? */
		plib = (void **)lua_touserdata(L, -1);
	} else {  /* no entry yet; create one */
		lua_pop(L, 1);
		plib = (void **)lua_newuserdata(L, sizeof(void *));
		*plib = NULL;
		luaL_getmetatable(L, "_LOADLIB");
		lua_setmetatable(L, -2);
		lua_pushfstring(L, "LOADLIB: %s", name);
		lua_pushvalue(L, -2);
		lua_settable(L, LUA_REGISTRYINDEX);
	}
	return plib;
}

static const char *mksymname(lua_State *L, const char *modname,
	const char *prefix)
{
	const char *funcname;
	const char *mark = strchr(modname, *LUA_IGMARK);
	if (mark) modname = mark + 1;
	funcname = luaL_gsub(L, modname, ".", "_");
	funcname = lua_pushfstring(L, prefix, funcname);
	lua_remove(L, -2);  /* remove 'gsub' result */
	return funcname;
}

/* ------------------------------------------------------------------------ */

static void loaderror(lua_State *L)
{
  luaL_error(L, "error loading module " LUA_QS ":\n\t%s",
    lua_tostring(L, 1), lua_tostring(L, -1));
}

/* load a C module bundled in the running executable */
/* C modules are bundled as lua_CFunction as `luaopen_<name>` globals */
extern int bundle_loader_c(lua_State *L)
{
	const char *name = luaL_checkstring(L, 1);
	void **reg = ll_register(L, name);
	const char *sym = mksymname(L, name, SYMPREFIX_CF);
	lua_CFunction f = (lua_CFunction)ll_sym(sym);
	if (!f) {
		lua_pushfstring(L, "\n\tno symbol "LUA_QS, sym);
		return 1;
	}
	lua_pushcfunction(L, f);
	return 1;
}

/* load a Lua module bundled in the running executable */
/* Lua modules are bundled as bytecode as `luajit_BCF_<name>` globals */
extern int bundle_loader_lua(lua_State *L)
{
	const char *name = luaL_checkstring(L, 1);
	const char *bcname = mksymname(L, name, SYMPREFIX_BC);
	const char *bcdata = (const char *)ll_sym(bcname);
	if (bcdata == NULL) {
		lua_pushfstring(L, "\n\tno symbol "LUA_QS, bcname);
		return 1;
	}
	if (luaL_loadbuffer(L, bcdata, ~(size_t)0, name) != 0) {
		lua_pushfstring(L, "error loading chunk");
		loaderror(L);
	}
	return 1;
}

/* ------------------------------------------------------------------------ */

/* add our two bundle loaders at the end of package.loaders */
extern void bundle_add_loaders(lua_State* L)
{
	/* push package.loaders table into the stack */
	lua_getglobal(L, LUA_LOADLIBNAME);       /* get _G.package */
	lua_getfield(L, -1, "loaders");          /* get _G.package.loaders */

	lj_lib_pushcf(L, bundle_loader_lua, 1);  /* push as lua_CFunction */
	lua_rawseti(L, -2, lua_objlen(L, -2)+1); /* append to loaders table */

	lj_lib_pushcf(L, bundle_loader_c, 1);    /* push as lua_CFunction */
	lua_rawseti(L, -2, lua_objlen(L, -2)+1); /* append to loaders table */

	lua_pop(L, 2); /* remove loaders and package tables */
}
