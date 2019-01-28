# vis-spellcheck

A spellchecking lua plugin for the [vis editor](https://github.com/martanne/vis).

## installation

1. Download `spellcheck.lua` or clone this repository
2. Load the plugin in your `visrc.lua` with `require(path/to/plugin/spellcheck)`

## usage

+ To enable highlighting of misspelled words press `<Ctrl-w>e` in normal mode.
+ To disable highlighting press `<Ctrl-w>d` in normal mode.
+ To correct the word under the cursor press `<Ctrl+w>w` in normal mode.
+ To ignore the word under the cursor press `<Ctrl+w>i` in normal mode.

## configuration

The module table returned from `require(...)` has three configuration options:

* `cmd`: cmd that is passed to popen() and must return word corrections in Ispell format.
	* default: `enchant -d %s` 
* `list_cmd`: cmd that is passed to popen() and must output a list of misspelled words.
	* default: `enchant -l -d %s` 
* `lang`: The name of the used dictionary. `lang` is inserted in the cmd-strings at `%s`.
	* default: `$LANG` or `en_US`

A possible configuration could look like this:

	spellcheck = require(...)
	spellcheck.cmd = "aspell -l %s -a"
	spellcheck.list_cmd = "aspell list -l %s -a"
	spellcheck.lang = "de_DE"

Changing language during runtime:

	:set spelllang en_US

