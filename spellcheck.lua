-- Copyright (c) 2017-2019 Florian Fischer. All rights reserved.
-- Use of this source code is governed by a MIT license found in the LICENSE file.

local spellcheck = {}
spellcheck.lang = os.getenv("LANG"):sub(0,5) or "en_US"
local supress_output = ">/dev/null 2>/dev/null"
if os.execute("type enchant "..supress_output) then
	spellcheck.cmd = "enchant -d %s -a"
	spellcheck.list_cmd = "enchant -l -d %s -a"
elseif os.execute("type enchant-2 "..supress_output) then
	spellcheck.cmd = "enchant-2 -d %s -a"
	spellcheck.list_cmd = "enchant-2 -l -d %s -a"
elseif os.execute("type aspell "..supress_output) then
	spellcheck.cmd = "aspell -l %s -a"
	spellcheck.list_cmd = "aspell list -l %s -a"
elseif os.execute("type hunspell "..supress_output) then
	spellcheck.cmd = "hunspell -d %s"
	spellcheck.list_cmd = "hunspell -l -d %s"
else
   return nil
end

spellcheck.enabled = {}

local ignored = {}

local last_viewport, last_typos = nil, nil

vis.events.subscribe(vis.events.WIN_HIGHLIGHT, function(win)
	if not spellcheck.enabled[win] or not win:style_define(42, "fore:red") then
		return false
	end
	local viewport = win.viewport
	local viewport_text = win.file:content(viewport)

	local typos = ""

	if last_viewport == viewport_text then
		typos = last_typos
	else
		local cmd = spellcheck.list_cmd:format(spellcheck.lang)
		local ret, so, se = vis:pipe(win.file, viewport, cmd)
		if ret ~= 0 then
			vis:message("calling " .. cmd .. " failed ("..se..")")
			return false
		end
		typos = so
	end

	local corrections_iter = typos:gmatch("(.-)\n")
	-- skip header line
	corrections_iter()
	local index = 0
	for typo in corrections_iter do
		if not ignored[typo] then
			local start, finish = viewport_text:find(typo, index, true)
			win:style(42, viewport.start + start - 1, viewport.start + finish)
			index = finish
		end
	end

	last_viewport = viewport_text
	last_typos = typos
	return true
end)

vis:map(vis.modes.NORMAL, "<C-w>e", function(keys)
	spellcheck.enabled[vis.win] = true
	return 0
end, "Enable spellchecking in the current window")

vis:map(vis.modes.NORMAL, "<C-w>d", function(keys)
	spellcheck.enabled[vis.win] = nil
	-- force new highlight
	vis.win:draw()
	return 0
end, "Disable spellchecking in the current window")

vis:map(vis.modes.NORMAL, "<C-w>w", function(keys)
	local win = vis.win
	local file = win.file
	local pos = win.selection.pos
	if not pos then return end
	local range = file:text_object_word(pos);
	if not range then return end
	if range.start == range.finish then return end

	local cmd = spellcheck.cmd:format(spellcheck.lang)
	local ret, so, se = vis:pipe(win.file, range, cmd)
	if ret ~= 0 then
		vis:message("calling " .. cmd .. " failed ("..se..")")
		return false
	end

	local suggestions = nil
	local answer_line = so:match(".-\n(.-)\n.*")
	local first_char = answer_line:sub(0,1)
	if first_char == "*" then
		vis:info(file:content(range).." is correctly spelled")
		return true
	elseif first_char == "#" then
		vis:info("No corrections available for "..file:content(range))
		return false
	elseif first_char == "&" then
		suggestions = answer_line:match("& %S+ %d+ %d+: (.*)")
	else
		vis:info("Unknown answer: "..answer_line)
		return false
	end

	-- select a correction
	local cmd = 'printf "' .. suggestions:gsub(", ", "\\n") .. '\\n" | vis-menu'
	local f = io.popen(cmd)
	local correction = f:read("*all")
	f:close()
	-- trim correction
	correction = correction:match("%S+")
	if correction then
		win.file:delete(range)
		win.file:insert(range.start, correction)
	end

	win.selection.pos = pos

	win:draw()

	return 0
end, "Correct misspelled word")

vis:map(vis.modes.NORMAL, "<C-w>i", function(keys)
	local win = vis.win
	local file = win.file
	local pos = win.selection.pos
	if not pos then return end
	local range = file:text_object_word(pos);
	if not range then return end
	if range.start == range.finish then return end

	ignored[file:content(range)] = true

	win:draw()
	return 0
end, "Ignore misspelled word")

vis:option_register("spelllang", "string", function(value, toggle)
	spellcheck.lang = value
	vis:info("Spellchecking language is now "..value)
	-- force new highlight
	last_viewport = nil
	return true
end, "The language used for spellchecking")

return spellcheck
