-- Copyright (c) 2021 Florian Fischer. All rights reserved.
-- Use of this source code is governed by a MIT license found in the LICENSE file.
local source_str = debug.getinfo(1, "S").source:sub(2)
local script_path = source_str:match("(.*/)")

return dofile(script_path .. 'spellcheck.lua')