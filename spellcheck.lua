local module = {}
module.lang = os.getenv("LANG"):sub(0,5) or "en_US"
-- TODO use more spellcheckers (aspell/hunspell)
module.cmd = "enchant -d %s -a"

function spellcheck(file, range)
	local cmd = module.cmd:format(module.lang)
	local ret, so, se = vis:pipe(file, range, cmd)

	if ret ~= 0 then
		return ret, se
	end

	local word_corrections = so:gmatch("(.-)\n")
	-- skip header line
	word_corrections()


	local orig = file:content(range)
	local new = orig:gsub("%S+", function(w)
		local correction = word_corrections()
		-- empty correction means a new line in range
		if correction == "" then
			correction = word_corrections()
		end
		if correction ~= "*" then
			-- get corrections
			local orig, pos, sug = correction:match("& (%w+) %d+ (%d+): (.*)")
			if orig ~= w then
				return 1, "Bad things happend!! Correction is not for" .. w
			end
			-- select a correction
			local cmd = 'printf "' .. sug:gsub(", ", "\\n") .. '\\n" | vis-menu'
			local f = io.popen(cmd)
			correction = f:read("*all")
			-- trim correction
			correction = correction:match("%S+")
			f:close()
			if correction then
				return correction
			end
		end
	end)

	file:delete(range)
	file:insert(range.start, new)
end

vis:map(vis.modes.NORMAL, "<C-s>", function(keys)
	local file = vis.win.file
	ret, err = spellcheck(file, { start=1, finish=file.size })
	if ret then
		vis:info(err)
	end
	return 0
end, "Spellcheck the whole file")

return module
