.PHONY: check format check-luacheck check-format

LUA_FILES := $(wildcard *.lua)

check: check-luacheck check-format

check-luacheck:
	luacheck --globals=vis -- $(LUA_FILES)

check-format:
	for lf in $(LUA_FILES); do tools/check-format "$${lf}"; done

format:
	lua-format -i $(LUA_FILES)
