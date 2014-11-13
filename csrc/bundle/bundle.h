extern int bundle_loader_c(lua_State *L);
extern int bundle_loader_lua(lua_State *L);
extern void bundle_add_loaders(lua_State* L);
extern int bundle_main(lua_State *L, int argc, char** argv);
