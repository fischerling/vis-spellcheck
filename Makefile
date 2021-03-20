.PHONY: check format check-luacheck check-format

LUA_FILES = $(wildcard *.lua)

# bash's process substitution is used for check-format
SHELL := /bin/bash

check: check-luacheck check-format

check-luacheck:
	luacheck --globals=vis -- $(LUA_FILES)

check-format:
	for f in $(LUA_FILES); do diff $$f <(lua-format $$f) >/dev/null; done

format:
	lua-format -i $(LUA_FILES)
