local module = {}
module.lang = os.getenv("LANG"):sub(0,5) or "en_US"
-- TODO use more spellcheckers (aspell/hunspell)
module.cmd = "enchant -d %s -a"

function spellcheck()
	local win = vis.win
	local file = win.file

	local cmd = module.cmd:format(module.lang)
	local ret, so, se = vis:pipe(file, { start = 0, finish = file.size }, cmd)

	if ret ~= 0 then
		return ret, se
	end

	local word_corrections = so:gmatch("(.-)\n")
	-- skip header line
	word_corrections()

	for i=1,#file.lines do
		local line = file.lines[i]
		local new_line = ""
		local words = line:gmatch("%w+")
		for w in words do
			local correction = word_corrections()
			if correction ~= "*" then
				local orig, pos, sug = correction:match("& (%w+) %d+ (%d+): (.*)")
				if orig ~= w then
					return 1, "Bad things happend!! Correction is not for" .. w
				end
				local cmd = 'printf "' .. sug:gsub(", ", "\\n") .. '\\n" | vis-menu'
				local f = io.popen(cmd)
				correction = f:read("*all")
				-- trim correction
				correction = correction:match("%a+")
				f:close()
				if correction then
					w = correction
				end
			end
			new_line = new_line .. " " .. w
		end
		file.lines[i] = new_line:match("^%s*(.-)%s*$")
		-- skip "end of line" new line
		word_corrections()
	end
end

vis:map(vis.modes.NORMAL, "<C-s>", function(keys)
	ret, err = spellcheck()
	if ret then
		vis:info(err)
	end
	return 0
end, "Spellcheck the whole file")

return module
