# vis-spellcheck

A spellchecking lua plugin for the [vis editor](https://github.com/martanne/vis).

## Installation

1. Download `spellcheck.lua` or clone this repository into your plugin directory
2. Load the plugin in your `visrc.lua` with `require(plugins/vis-spellcheck)`

## Usage

+ To enable highlighting of misspelled words press `<Ctrl-w>e` in normal mode.
+ To disable highlighting press `<Ctrl-w>d` in normal mode.
+ To toggle highlighting press `<F7>` in normal mode.
+ To correct the word under the cursor press `<Ctrl+w>w` in normal mode.
+ To ignore the word under the cursor press `<Ctrl+w>i` in normal mode.

## Configuration

The module table returned from `require(...)` has some configuration options:

* `cmd`: cmd that is passed to popen() and must return word corrections in Ispell format.
	* default: `enchant -d %s` 
* `list_cmd`: cmd that is passed to popen() and must output a list of misspelled words.
	* default: `enchant -l -d %s` 
* `lang`: The name of the used dictionary. `lang` is inserted in the cmd-strings at `%s`.
	* default: `$LANG` or `en_US`
* `typo_style`: The style string with which misspellings should be highlighted when using the _full viewport_ method
	* default: `fore:red`
* `check_tokens`: A table mapping all token names we consider for spellchecking to true
	* default: `{[vis.lexers.STRING]=true, [vis.lexers.COMMENT]=true, [vis.lexers.DEFAULT]=true}`
* `disable_syntax_awareness`: Disable the syntax aware spellchecking and use always _full viewport_
	* default: `false`

A possible configuration could look like this:

	spellcheck = require(...)
	spellcheck.cmd = "aspell -l %s -a"
	spellcheck.list_cmd = "aspell list -l %s -a"
	spellcheck.lang = "de_DE"

Changing language during runtime:

	:set spelllang en_US

