# vis-spellcheck

A spellchecking lua plugin for the [vis editor](https://github.com/martanne/vis).

## installation

1. Download `spellcheck.lua` or clone this repository
2. Load the plugin in your `visrc.lua` with `require(path/to/plugin/spellcheck)`

## usage

+ To correct the whole file press Ctrl+s in normal mode.

## configuration

The module table returned from `require(...)` has two configuration fields
`lang` and `cmd`. `lang` is inserted in the `cmd` string at `%s`.
The defaults are `enchant -d %s` and `$LANG or "en_US".

	spell = require(...)
	spell.cmd = "aspell -l %s -a"
	spell.lang = "en_US"
