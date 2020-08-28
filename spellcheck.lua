-- Copyright (c) 2017-2019 Florian Fischer. All rights reserved.
-- Use of this source code is governed by a MIT license found in the LICENSE file.

local spellcheck = {}
spellcheck.lang = os.getenv("LANG"):sub(0,5) or "en_US"
local supress_stdout = " >/dev/null"
local supress_stderr = " 2>/dev/null"
local supress_output = supress_stdout .. supress_stderr
if os.execute("type enchant"..supress_output) then
	spellcheck.cmd = "enchant -d %s -a"
	spellcheck.list_cmd = "enchant -l -d %s -a"
elseif os.execute("type enchant-2"..supress_output) then
	spellcheck.cmd = "enchant-2 -d %s -a"
	spellcheck.list_cmd = "enchant-2 -l -d %s -a"
elseif os.execute("type aspell"..supress_output) then
	spellcheck.cmd = "aspell -l %s -a"
	spellcheck.list_cmd = "aspell list -l %s -a"
elseif os.execute("type hunspell"..supress_output) then
	spellcheck.cmd = "hunspell -d %s"
	spellcheck.list_cmd = "hunspell -l -d %s"
else
   return nil
end

spellcheck.typo_style = "fore:red"
spellcheck.check_full_viewport = {}
spellcheck.disable_syntax_awareness = false

spellcheck.check_tokens = {
	[vis.lexers.STRING] = true,
	[vis.lexers.COMMENT] = true,
	[vis.lexers.DEFAULT] = true,
}

-- Return nil or a string of misspelled word in a specific file range or text
-- by calling the spellchecker's list command.
-- If given a range we will use vis:pipe to get our typos from the spellchecker.
-- If a string was passed we call the spellchecker ourself and redirect its stdout
-- to a temporary file. See http://lua-users.org/lists/lua-l/2007-10/msg00189.html.
-- The returned string consists of each misspell followed by a newline.
local function get_typos(range_or_text)
	local cmd = spellcheck.list_cmd:format(spellcheck.lang)
	local typos = nil
	if type(range_or_text) == "string" then
		local text = range_or_text
		local tmp_name = os.tmpname()
		local full_cmd = cmd .. "> " .. tmp_name .. supress_stderr
		local proc = assert(io.popen(full_cmd, "w"))
		proc:write(text)
		-- this error detection may need lua5.2
		local success, reason, exit_code = proc:close()
		if not success then
			vis:info("calling " .. cmd .. " failed ("..exit_code..")")
			return nil
		end

		local tmp_file = assert(io.open(tmp_name, "r"))
		typos = tmp_file:read("*a")
		tmp_file:close()
		os.remove(tmp_name)
	else
		local range = range_or_text
		local ret, so, se = vis:pipe(vis.win.file, range, cmd)

		if ret ~= 0 then
			vis:info("calling " .. cmd .. " failed ("..ret..")")
			return nil
		end
		typos = so
	end

	return typos
end

-- plugin global list of ignored typos
local ignored = {}

-- Return an iterator over all not ignored typos and their positions in text.
-- The returned iterator is a self contained statefull iterator function closure.
-- Which will return the next typo and its start and finish in the text, starting by 1.
local function typo_iter(text, typos, ignored)
	local index = 1
	local unfiltered_iterator, iter_state = typos:gmatch("(.-)\n")
	return function(foo, bar)
		repeat
			typo = unfiltered_iterator(iter_state)
		until(not typo or (typo ~= "" and not ignored[typo]))

		if typo then
			-- to prevent typos from being found in correct words before them
			-- ("stuff stuf", "broken ok", ...)
			-- we match typos only when they are enclosed in non-letter characters.
			local start, finish = text:find("[%A]" .. typo .. "[%A]", index)
			-- typo was not found by our pattern this means it must be either
			-- the first or last word in the text
			if not start then
				-- check start of text
				start = 1
				finish = #typo
				-- typo is not the beginning must be the end of text
				if text:sub(start, finish) ~= typo then
					start = #text - #typo + 1
					finish = start + #typo - 1
				end

				if text:sub(start, finish) ~= typo then
					vis:info(string.format("can't find typo %s after %d. Please report this bug.",
										   typo, index))
				end
			-- our pettern [%A]typo[%A] found it
			else
				start = start + 1 -- ignore leading non letter char
				finish = finish - 1 -- ignore trailing non letter char
			end
			index = finish

			return typo, start, finish
		end
	end
end

local last_viewport, last_data, last_typos = nil, "", ""

vis.events.subscribe(vis.events.WIN_HIGHLIGHT, function(win)
	if not spellcheck.check_full_viewport[win] or not win:style_define(42, spellcheck.typo_style) then
		return false
	end
	local viewport = win.viewport
	local viewport_text = win.file:content(viewport)

	local typos = ""

	if last_viewport == viewport_text then
		typos = last_typos
	else
		typos = get_typos(viewport) or ""
		if not typos then
			return false
		end
	end

	for typo, start, finish in typo_iter(viewport_text, typos, ignored) do
		win:style(42, viewport.start + start - 1, viewport.start + finish)
	end

	last_viewport = viewport_text
	last_typos = typos
	return true
end)

local wrapped_lex_funcs = {}

local wrap_lex_func = function(old_lex_func)
	local old_new_tokens = {}

	return function(lexer, data, index, redrawtime_max)
		local tokens, timedout = old_lex_func(lexer, data, index, redrawtime_max)

		-- quit early if the lexer already took to long
		-- TODO: investigate further if timedout is actually set by the lexer.
		--       As I understand lpeg.match used by lexer.lex timedout will always be nil
		if timeout then
			return tokens, timedout
		end

		local new_tokens = {}

		local typos = ""
		if last_data ~= data
		then
			typos = get_typos(data)
			if not typos then
				return tokens, timedout
			end
			last_data = data
		else
			return old_new_tokens
		end

		local i = 1
		for typo, typo_start, typo_end in typo_iter(data, typos, ignored) do
			repeat
				-- no tokens left
				if i > #tokens -1 then
					break
				end

				local token_type = tokens[i]
				local token_start = (tokens[i-1] or 1) - 1
				local token_end = tokens[i+1]

				-- the current token ends before our typo -> append to new stream
				-- or is not spellchecked
				if token_end < typo_start or not spellcheck.check_tokens[token_type] then
					table.insert(new_tokens, token_type)
					table.insert(new_tokens, token_end)

					-- done with this token -> advance token stream
					i = i + 2
				-- typo and checked token overlap
				else
					local pre_typo_end = typo_start - 1
					-- unchanged token part before typo
					if pre_typo_end > token_start then
						table.insert(new_tokens, token_type)
						table.insert(new_tokens, pre_typo_end + 1)
					end

					-- highlight typo
					table.insert(new_tokens, vis.lexers.ERROR)
					-- the typo spans multiple tokens
					if token_end < typo_end then
						table.insert(new_tokens, token_end + 1)
						i = i + 2
					else
						table.insert(new_tokens, typo_end + 1)
					end
				end
			until(not token_end or token_end >= typo_end)
		end

		-- add tokens left after we handled all typos
		for i = i, #tokens, 1 do
			table.insert(new_tokens, tokens[i])
		end

		old_new_tokens = new_tokens
		return new_tokens, timedout
	end
end

local enable_spellcheck = function()
	-- prevent wrapping the lex function multiple times
	if wrapped_lex_funcs[vis.win] then
		return
	end

	if not spellcheck.disable_syntax_awareness and vis.win.syntax and vis.lexers.load then
		local lexer = vis.lexers.load(vis.win.syntax, nil, true)
		if lexer and lexer.lex then
			local old_lex_func = lexer.lex
			wrapped_lex_funcs[vis.win] = old_lex_func
			lexer.lex = wrap_lex_func(old_lex_func)
			-- reset last data to enforce new highlighting
			last_data = ""
			return
		end
	end

	-- fallback check spellcheck the full viewport
	spellcheck.check_full_viewport[vis.win] = true
end

local is_spellcheck_enabled = function()
	return spellcheck.check_full_viewport[vis.win] or wrapped_lex_funcs[vis.win]
end

vis:map(vis.modes.NORMAL, "<C-w>e", function(keys)
	enable_spellcheck()
end, "Enable spellchecking in the current window")

local disable_spellcheck = function()
	local old_lex_func = wrapped_lex_funcs[vis.win]
	if old_lex_func then
		local lexer = vis.lexers.load(vis.win.syntax, nil, true)
		lexer.lex = old_lex_func
		wrapped_lex_funcs[vis.win] = nil
	else
		spellcheck.check_full_viewport[vis.win] = nil
	end
end

vis:map(vis.modes.NORMAL, "<C-w>d", function(keys)
	disable_spellcheck()
	-- force new highlight
	vis.win:draw()
end, "Disable spellchecking in the current window")

-- toggle spellchecking on <F7>
-- <F7> is used by some word processors (LibreOffice) for spellchecking
-- Thanks to @leorosa for the hint.
vis:map(vis.modes.NORMAL, "<F7>", function(keys)
	if not is_spellcheck_enabled() then
		enable_spellcheck()
	else
		disable_spellcheck()
		vis.win:draw()
	end
	return 0
end, "Toggle spellchecking in the current window")

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
	local f = assert(io.popen(cmd))
	local correction = f:read("*all")
	f:close()
	-- trim correction
	correction = correction:match("^%s*(.-)%s*$")
	if correction ~= "" then
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
	-- force new highlight for full viewport
	last_viewport = nil
	-- force new highlight for syntax aware
	last_data = nil
	return true
end, "The language used for spellchecking")

return spellcheck
