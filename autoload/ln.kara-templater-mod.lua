--[[
 Copyright (c) 2007, Niels Martin Hansen, Rodrigo Braz Monteiro
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

   * Redistributions of source code must retain the above copyright notice,
	 this list of conditions and the following disclaimer.
   * Redistributions in binary form must reproduce the above copyright notice,
	 this list of conditions and the following disclaimer in the documentation
	 and/or other materials provided with the distribution.
   * Neither the name of the Aegisub Group nor the names of its contributors
	 may be used to endorse or promote products derived from this software
	 without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
]]

-- Aegisub Automation 4 Lua karaoke templater tool
-- Parse and apply a karaoke effect written in ASS karaoke template language
-- See help file and wiki for more information on this

local tr = aegisub.gettext

script_name = tr"Karaoke Templater mod"
script_description = tr"Macro and export filter to apply karaoke effects using the template language"
script_author = "Niels Martin Hansen, mods by logarithm"
script_version = "2.1.7c"


include("karaskel.lua")


-- Find and parse/prepare all karaoke template lines
function parse_templates(meta, styles, subs)
	local templates = { once = {}, line = {}, word = {}, syl = {}, char = {}, furi = {}, furichar = {}, styles = {} }
	local i = 1
	while i <= #subs do
		aegisub.progress.set((i-1) / #subs * 100)
		local l = subs[i]
		i = i + 1
		if l.class == "dialogue" and l.comment then
			local fx, mods = string.headtail(l.effect)
			fx = fx:lower()
			if fx == "code" then
				parse_code(meta, styles, l, templates, mods)
			elseif fx == "template" then
				parse_template(meta, styles, l, templates, mods)
			end
			templates.styles[l.style] = true
		elseif l.class == "dialogue" and l.effect == "fx" then
			-- this is a previously generated effect line, remove it
			i = i - 1
			subs.delete(i)
		end
	end
	aegisub.progress.set(100)
	return templates
end

function parse_code(meta, styles, line, templates, mods)
	local template = {
		code = line.text,
		loops = 1,
		style = line.style
	}
	local inserted = false

	local rest = mods
	while rest ~= "" do
		local m, t = string.headtail(rest)
		rest = t
		m = m:lower()
		if m == "once" then
			aegisub.debug.out(5, "Found run-once code line: %s\n", line.text)
			table.insert(templates.once, template)
			inserted = true
		elseif m == "line" then
			aegisub.debug.out(5, "Found per-line code line: %s\n", line.text)
			table.insert(templates.line, template)
			inserted = true
		elseif m == "word" then
			aegisub.debug.out(5, "Found per-word code line: %s\n", line.text)
			table.insert(templates.word, template)
			inserted = true
		elseif m == "syl" then
			aegisub.debug.out(5, "Found per-syl code line: %s\n", line.text)
			table.insert(templates.syl, template)
			inserted = true
		elseif m == "furi" then
			aegisub.debug.out(5, "Found per-furi code line: %s\n", line.text)
			table.insert(templates.furi, template)
			inserted = true
		elseif m == "char" then
			aegisub.debug.out(5, "Found per-char code line: %s\n", line.text)
			table.insert(templates.char, template)
			inserted = true
		elseif m == "furichar" then
			aegisub.debug.out(5, "Found per-furichar code line: %s\n", line.text)
			table.insert(templates.furichar, template)
			inserted = true
		elseif m == "multi" then
			template.multi = true
		elseif m == "all" then
			template.style = nil
		elseif m == "noblank" then
			template.noblank = true
		elseif m == "repeat" or m == "loop" then
			local times, t = string.headtail(rest)
			template.loops = tonumber(times)
			if not template.loops then
				aegisub.debug.out(3, "Failed reading this repeat-count to a number: %s\nIn template code line: %s\nEffect field: %s\n\n", times, line.text, line.effect)
				template.loops = 1
			else
				rest = t
			end
		else
			aegisub.debug.out(3, "Unknown modifier in code template: %s\nIn template code line: %s\nEffect field: %s\n\n", m, line.text, line.effect)
		end
	end

	if not inserted then
		aegisub.debug.out(5, "Found implicit run-once code line: %s\n", line.text)
		table.insert(templates.once, template)
	end
end

-- List of reserved words that can't be used as "line" template identifiers
template_modifiers = {
	"line", "lword", "lsyl", "lchar", "word", "syl", "furi", "char", "furichar", "all", "repeat", "loop",
	"notext", "keeptags", "noblank", "multi", "fx", "fxgroup", "style"
}

function parse_template(meta, styles, line, templates, mods)
	local template = {
		t = "",
		pre = "",
		style = line.style,
		loops = 1,
		layer = line.layer,
		addtext = true,
		keeptags = false,
		fxgroup = nil,
		stylegroup = nil,
		fx = nil,
		multi = false,
		isline = false,
		perword = false,
		persyl = false,
		perchar = false,
		noblank = false
	}
	local inserted = false

	local rest = mods
	while rest ~= "" do
		local m, t = string.headtail(rest)
		rest = t
		m = m:lower()
		if (m == "line" or m == "lword" or m == "lsyl" or m == "lchar") and not inserted then
			aegisub.debug.out(5, "Found line template '%s'\n", line.text)
			-- should really fail if already inserted
			local id, t = string.headtail(rest)
			id = id:lower()
			-- check that it really is an identifier and not a keyword
			for _, kw in pairs(template_modifiers) do
				if id == kw then
					id = nil
					break
				end
			end
			if id == "" then
				id = nil
			end
			if id then
				rest = t
			end
			-- get old template if there is one
			if id and templates.line[id] then
				template = templates.line[id]
			elseif id then
				template.id = id
				templates.line[id] = template
			else
				table.insert(templates.line, template)
			end
			inserted = true
			template.isline = true
			template.perword = m == "lword"
			template.persyl = m == "lsyl"
			template.perchar = m == "lchar"
			-- apply text to correct string
			if m ~= "line" then
				template.t = template.t .. line.text
			else -- must be pre-line
				template.pre = template.pre .. line.text
			end
		elseif m == "word" and not template.isline then
			table.insert(templates.word, template)
			inserted = true
		elseif m == "syl" and not template.isline then
			table.insert(templates.syl, template)
			inserted = true
		elseif m == "furi" and not template.isline then
			table.insert(templates.furi, template)
			inserted = true
		elseif m == "furichar" and not template.isline then
			table.insert(templates.furichar, template)
			inserted = true
		elseif m == "char" and not template.isline then
			table.insert(templates.char, template)
			inserted = true
		elseif (m == "line" or m == "lword" or m == "lsyl" or m == "lchar") and inserted then
			aegisub.debug.out(2, "Unable to combine %s class templates with other template classes\n\n", m)
		elseif (m == "word" or m == "syl" or m == "char" or m == "furi" or m == "furichar") and template.isline then
			aegisub.debug.out(2, "Unable to combine %s class template lines with line type classes\n\n", m)
		elseif m == "all" then
			template.style = nil
		elseif m == "repeat" or m == "loop" then
			local times, t = string.headtail(rest)
			template.loops = tonumber(times)
			if not template.loops then
				aegisub.debug.out(3, "Failed reading this repeat-count to a number: %s\nIn template line: %s\nEffect field: %s\n\n", times, line.text, line.effect)
				template.loops = 1
			else
				rest = t
			end
		elseif m == "notext" then
			template.addtext = false
		elseif m == "keeptags" then
			template.keeptags = true
		elseif m == "multi" then
			template.multi = true
		elseif m == "noblank" then
			template.noblank = true
		elseif m == "fx" then
			local fx, t = string.headtail(rest)
			if fx ~= "" then
				template.fx = fx
				rest = t
			else
				aegisub.debug.out(3, "No fx name following fx modifier\nIn template line: %s\nEffect field: %s\n\n", line.text, line.effect)
				template.fx = nil
			end
		elseif m == "fxgroup" then
			local fx, t = string.headtail(rest)
			if fx ~= "" then
				template.fxgroup = fx
				rest = t
			else
				aegisub.debug.out(3, "No fxgroup name following fxgroup modifier\nIn template line: %s\nEffect field: %s\n\n", line.text, line.effect)
				template.fxgroup = nil
			end
		elseif m == "style" then
			local style, t = string.headtail(rest)
			if style ~= "" then
				template.stylegroup = style
				rest = t
			else
				aegisub.debug.out(3, "No style matching string following style modifier\nIn template line: %s\nEffect field: %s\n\n", line.text, line.effect)
				template.stylegroup = nil
			end
		else
			aegisub.debug.out(3, "Unknown modifier in template: %s\nIn template line: %s\nEffect field: %s\n\n", m, line.text, line.effect)
		end
	end

	if not inserted then
		table.insert(templates.syl, template)
	end
	if not template.isline then
		template.t = line.text
	end
end

-- Iterator function, return all templates that apply to the given line
function matching_templates(templates, line, tenv)
	local lastkey = nil
	local function test_next()
		local k, t = next(templates, lastkey)
		lastkey = k
		if not t then
			return nil
		elseif (t.style == line.style or not t.style) and
				(not t.fxgroup or
				(t.fxgroup and tenv.fxgroup[t.fxgroup] ~= false)) and
				(not t.stylegroup or
				(line.style:match(t.stylegroup)))then
			return t
		else
			return test_next()
		end
	end
	return test_next
end

-- Iterator function, run a loop using tenv.j and tenv.maxj as loop controllers
function template_loop(tenv, initmaxj)
	local oldmaxj = initmaxj
	tenv.maxj = initmaxj
	tenv.j = 0
	local function itor()
		if tenv.j >= tenv.maxj or aegisub.progress.is_cancelled() then
			return nil
		else
			tenv.j = tenv.j + 1
			if oldmaxj ~= tenv.maxj then
				aegisub.debug.out(5, "Number of loop iterations changed from %d to %d\n", oldmaxj, tenv.maxj)
				oldmaxj = tenv.maxj
			end
			return tenv.j, tenv.maxj
		end
	end
	return itor
end

context_id = 0;
function allocate_context_id()
	context_id = context_id + 1;
	return context_id;
end
function text_template_interpreter(meta, ...)
	local args = table.pack(...);
	if args.n == 0 then
		return run_text_template(meta.text, meta.tenv, meta.tenv.varctx);
	else
		local new_varctx = {};
		if meta.params ~= nil then
			for i, k in ipairs(meta.params) do
				new_varctx[k] = args[i];
			end
		else
			local extra = args[1];
			if extra ~= nil then
				for k, v in pairs(extra) do
					new_varctx[k] = v;
				end
			end
		end
		setmetatable(new_varctx, { __index = meta.tenv.varctx });
		return run_text_template(meta.text, meta.tenv, new_varctx);
	end
end
function use_tag(source, id, index)
	for tags in string.gmatch(source.text, "{[^}]+}") do
		local match = string.match(tags, "\\" .. id .. "([^\\}]+)")
		if match ~= nil then
			if index ~= nil then
				local i = 1
				for w in string.gmatch(match, "[^,%(%)]+") do
					if i == index then
						return tonumber(w) or w;
					end
					i = i + 1
				end
			else
				return tonumber(match) or match;
			end
		end
	end
	return nil
end
function locate(line, syl, ox, oy, x, y, align, matrix)
	x = x or line.center;
	y = y or line.middle;
	align = align or line.styleref.align or 5;
	local xoffset, yoffset;
	if align == 1 or align == 4 or align == 7 then
		xoffset = 0;
	elseif align == 3 or align == 6 or align == 9 then
		xoffset = -line.width;
	else
		xoffset = -line.width / 2;
	end
	if align == 1 or align == 2 or align == 3 then
		yoffset = -line.height;
	elseif align == 7 or align == 8 or align == 9 then
		yoffset = 0;
	else
		yoffset = -line.height / 2;
	end
	if syl ~= nil then
		xoffset = xoffset + syl.left;
	end
	if ox ~= nil then
		xoffset = xoffset + ox - line.left;
		if syl ~= nil then
			xoffset = xoffset - syl.left;
		end
	else
		if syl ~= nil then
			xoffset = xoffset + syl.width / 2;
		else
			xoffset = xoffset + line.width / 2;
		end
	end
	if oy ~= nil then
		yoffset = yoffset + oy - line.top;
	else
		yoffset = yoffset + line.height / 2;
	end
	if matrix ~= nil then
		if type(matrix.get_data) == "function" then
			matrix = matrix.get_data();
		end
		local z, w = 0, 1;
		xoffset, yoffset = xoffset * matrix[1] + yoffset * matrix[5] + z * matrix[9] + w * matrix[13],
						   xoffset * matrix[2] + yoffset * matrix[6] + z * matrix[10] + w * matrix[14];
	end
	x = x + xoffset;
	y = y + yoffset;
	return x, y;
end
function transform(t1, t2, step, tag, easing)
	local ret, f, g = {}, nil, nil;
	local delta_t = t2 - t1;
	if delta_t <= 0 or step <= 0 then
		aegisub.debug.out(3, "Invalid arguments from transformation: t1 = %s, t2 = %s, step = %s\n", t1, t2, step);
		return "";
	end
	if easing ~= nil then
		g = function(t)
			return easing((t - t1) / delta_t, t, t1, t2);
		end
	else
		g = function(t)
			return (t - t1) / delta_t;
		end;
	end
	f = function(t)
		return tag(g(t), t, t1, t2);
	end
	local t, t_old, ratio, accel, g_delta, g_old = t1, t1, 0.5, 1.0, 0.0, 1.0;
	if t1 == 0 then
		table.insert(ret, f(t1));
	else
		table.insert(ret, string.format("\\t(%d,%d,%s,%s)", t1, t1, 1, f(t1)));
	end
	while t < t2 do
		t_old = t;
		t = math.min(t + step, t2);
		g_old = g(t_old);
		g_delta = g(t) - g_old;
		if g_delta ~= 0 then
			ratio = (g((t + t_old) / 2) - g_old) / g_delta;
			if ratio > 0.99999 then ratio = 0.99999 end
			if ratio < 0.00001 then ratio = 0.00001 end
			accel = math.log(ratio) / math.log(0.5);
			accel = math.floor(accel * 1000) / 1000;
			table.insert(ret, string.format("\\t(%d,%d,%s,%s)", t_old, t, accel, f(t)));
		end
	end
	return table.concat(ret);
end
function get_loop_ctx(tenv)
	local template = tenv.template;
	local loop_ctx;
	local loop_target = template.isline and tenv.orgline or tenv.basesyl;
	local loop_target_id = loop_target._loop_target_id;
	if loop_target_id == nil then
		loop_target_id = allocate_context_id();
		loop_target._loop_target_id = loop_target_id;
	end
	local loop_ctx_key = string.format("_loop_ctx_%x", loop_target_id);
	if type(template[loop_ctx_key]) == "table" then
		loop_ctx = template[loop_ctx_key];
	else
		loop_ctx = {
			maxj = tenv.maxj,
			vars = {}
		};
		template[loop_ctx_key] = loop_ctx;
	end
	return loop_ctx;
end
function makeloop(tenv, namespace, receiver, args)
	local argn = #args;
	local loop_ctx = get_loop_ctx(tenv);
	local loop_state, loop_vars;
	if type(receiver) == "string" then
		loop_state = tenv[receiver];
		if loop_state ~= nil then
			if type(loop_state) ~= "table" then
				loop_state = {};
				tenv[receiver] = loop_state;
				aegisub.debug.out(2, "Trying to use a non-table as loop state receiver.\n");
			end
		else
			loop_state = {};
			tenv[receiver] = loop_state;
		end
	else
		loop_state = {};
	end
	loop_vars = loop_ctx.vars[namespace];
	if loop_vars == nil then
	    loop_vars = {};
	    loop_ctx.vars[namespace] = loop_vars;
	end
	if loop_ctx.maxj ~= tenv.maxj then
		aegisub.debug.out(2, "Do not use both makeloop(...) and loopctl/maxloop. maxj should be %s instead of %s.\n", loop_ctx.maxj, tenv.maxj);
		tenv.maxj = loop_ctx.maxj;
	end
	for i = 2, argn, 2 do
		local name, range = args[i - 1], args[i];
		local data = loop_vars[name];
		-- { j_divider, j_modder, factor, offset }
		if data ~= nil then
			loop_state[name] = math.floor((tenv.j - 1) / data[1]) % data[2] * data[3] + data[4];
		else
			if tenv.j == 1 then
				if type(range) == "number" then
					data = { tenv.maxj, range, 1, 1 };
				elseif type(range) == "table" then
					local rn = #range;
					if rn == 1 then
						data = { tenv.maxj, range[1], 1, 1 };
					elseif rn == 2 then
						data = { tenv.maxj, range[2] - range[1] + 1, 1, range[1] };
					elseif rn == 3 then
						data = { tenv.maxj, math.floor((range[2] - range[1]) / range[3]) + 1, range[3], range[1] };
					end
				end
				if data ~= nil then
					loop_vars[name] = data;
					loop_state[name] = data[4];
					tenv.maxj = tenv.maxj * data[2];
					loop_ctx.maxj = tenv.maxj;
				else
					aegisub.debug.out(2, "Illegal loop variable range: %s\n", range);
				end
			else
				aegisub.debug.out(2, "Undefined loop variable: %s\n", name);
			end
		end
	end
	if type(receiver) == "function" then
		return receiver(loop_state);
	end
	return "";
end
function loopget(tenv, namespace, varname, query)
	local loop_ctx = get_loop_ctx(tenv);
	local loop_vars = loop_ctx.vars[namespace];
	-- { j_divider, j_modder, factor, offset }
	if loop_vars ~= nil and loop_vars[varname] ~= nil then
	    local data = loop_vars[varname];
		if query == "step_count" then
			return data[2];
		end
		if query == "step" then
			return data[3];
		end
		if query == "initial" then
			return data[4];
		end
		if query == "range" then
			return data[3] * (data[2] - 1);
		end
		if query == "final" then
			return data[4] + data[3] * (data[2] - 1);
		end
		if query == "index" then
			return math.floor((tenv.j - 1) / data[1]) % data[2] + 1;
		end
		if query == "progress" then
			return math.floor((tenv.j - 1) / data[1]) / data[2] % 1;
		end
		return math.floor((tenv.j - 1) / data[1]) % data[2] * data[3] + data[4];
	end
	return nil;
end
function loopset(tenv, namespace, args)
	local argn = #args;
	local loop_ctx = get_loop_ctx(tenv);
	local loop_vars = loop_ctx.vars[namespace];
	if loop_vars ~= nil then
		for i = 2, argn, 2 do
			local name, value = args[i - 1], args[i];
			local data = loop_vars[name];
			-- { j_divider, j_modder, factor, offset }
			if data ~= nil then
				local oldindex = math.floor((tenv.j - 1) / data[1]) % data[2];
				local newindex = math.floor((value - data[4]) / data[3]);
				if newindex < 0 then
					newindex = 0;
				elseif newindex >= data[2] then
					newindex = data[2] - 1;
				end
				tenv.j = tenv.j + data[1] * (newindex - oldindex);
			else
				aegisub.debug.out(2, "Undefined loop variable: %s\n", name);
			end
		end
	else
		aegisub.debug.out(2, "Cannot modify an uninitialized loop.\n");
	end
end

-- Apply the templates
function apply_templates(meta, styles, subs, templates)
	-- the environment the templates will run in
	local tenv = {
		meta = meta,
		-- put in some standard libs, and the subs object for much fun :3
		string = string,
		math = math,
		table = table,
		subs = subs,
		_G = _G,
		ipairs = ipairs,
		pairs = pairs,
		tonumber = tonumber,
		tostring = tostring,
		type = type
	}
	tenv.tenv = tenv

	-- Define helper functions in tenv

	tenv.retime = function(mode, addstart, addend)
		local line, syl = tenv.line, tenv.syl
		local newstart, newend = line.start_time, line.end_time
		addstart = addstart or 0
		addend = addend or 0
		if mode == "syl" then
			newstart = line.start_time + syl.start_time + addstart
			newend = line.start_time + syl.end_time + addend
		elseif mode == "presyl" then
			newstart = line.start_time + syl.start_time + addstart
			newend = line.start_time + syl.start_time + addend
		elseif mode == "postsyl" then
			newstart = line.start_time + syl.end_time + addstart
			newend = line.start_time + syl.end_time + addend
		elseif mode == "line" then
			newstart = line.start_time + addstart
			newend = line.end_time + addend
		elseif mode == "preline" then
			newstart = line.start_time + addstart
			newend = line.start_time + addend
		elseif mode == "postline" then
			newstart = line.end_time + addstart
			newend = line.end_time + addend
		elseif mode == "start2syl" then
			newstart = line.start_time + addstart
			newend = line.start_time + syl.start_time + addend
		elseif mode == "syl2end" then
			newstart = line.start_time + syl.end_time + addstart
			newend = line.end_time + addend
		elseif mode == "set" or mode == "abs" then
			newstart = addstart
			newend = addend
		elseif mode == "sylpct" then
			newstart = line.start_time + syl.start_time + addstart*syl.duration/100
			newend = line.start_time + syl.start_time + addend*syl.duration/100
		-- wishlist: something for fade-over effects,
		-- "time between previous line and this" and
		-- "time between this line and next"
		end
		line.start_time = newstart
		line.end_time = newend
		line.duration = newend - newstart
		return ""
	end

	---@deprecated
	tenv.k_retime = function(mode, addstart, addend)
		aegisub.debug.out(3, "k_retime is deprecated, please do not use\n");
		local line, syl = tenv.line, tenv.syl
		local newstart, newend = line.start_time, line.end_time
		addstart = addstart or 0
		addend = addend or 0
		if mode == "syl" then
			newstart = line.start_time + syl.start_time + addstart
			newend = line.start_time + syl.end_time + addend
		elseif mode == "presyl" then
			newstart = line.start_time + syl.start_time + addstart
			newend = line.start_time + syl.start_time + addend
		elseif mode == "postsyl" then
			newstart = line.start_time + syl.end_time + addstart
			newend = line.start_time + syl.end_time + addend
		elseif mode == "line" then
			newstart = line.start_time + addstart
			newend = line.end_time + addend
		elseif mode == "preline" then
			newstart = line.start_time + addstart
			newend = line.start_time + addend
		elseif mode == "postline" then
			newstart = line.end_time + addstart
			newend = line.end_time + addend
		elseif mode == "start2syl" then
			newstart = line.start_time + addstart
			newend = line.start_time + syl.start_time + addend
		elseif mode == "syl2end" then
			newstart = line.start_time + syl.end_time + addstart
			newend = line.end_time + addend
		elseif mode == "set" or mode == "abs" then
			newstart = addstart
			newend = addend
		elseif mode == "sylpct" then
			newstart = line.start_time + syl.start_time + addstart*syl.duration/100
			newend = line.start_time + syl.start_time + addend*syl.duration/100
		-- wishlist: something for fade-over effects,
		-- "time between previous line and this" and
		-- "time between this line and next"
		end
		syl.start_time = syl.start_time + (line.start_time-newstart)
		syl.end_time = syl.end_time + (line.start_time-newstart)
		line.start_time = newstart
		line.end_time = newend
		line.duration = newend - newstart
		return ""
	end

	tenv.fxgroup = {}

	tenv.relayer = function(layer)
		tenv.line.layer = layer
		return ""
	end

	tenv.restyle = function(style)
		tenv.line.style = style
		tenv.line.styleref = styles[style]
		return ""
	end

	tenv.maxloop = function(newmaxj)
		tenv.maxj = newmaxj
		return ""
	end
	tenv.maxloops = tenv.maxloop
	tenv.loopctl = function(newj, newmaxj)
		tenv.j = newj
		tenv.maxj = newmaxj
		return ""
	end

	tenv.recall = {}
	setmetatable(tenv.recall, {
		decorators = {},
		__call = function(tab, name, default)
			local decorator = getmetatable(tab).decorators[name]
			if decorator then
				name = decorator(tostring(name))
			end
			aegisub.debug.out(5, "Recalling '%s'\n", name)
			return tab[name] or default
		end,
		decorator_line = function(name)
			return string.format("_%s_%s", tostring(tenv.orgline), name)
		end,
		decorator_syl = function(name)
			return string.format("_%s_%s", tostring(tenv.syl), name)
		end,
		decorator_basesyl = function(name)
			return string.format("_%s_%s", tostring(tenv.basesyl), name)
		end
	})
	tenv.remember = function(name, value, decorator)
		getmetatable(tenv.recall).decorators[name] = decorator
		if decorator then
			name = decorator(tostring(name))
		end
		aegisub.debug.out(5, "Remembering '%s' as '%s'\n", name, tostring(value))
		tenv.recall[name] = value
		return value
	end
	tenv.remember_line = function(name, value)
		return tenv.remember(name, value, getmetatable(tenv.recall).decorator_line)
	end
	tenv.remember_syl = function(name, value)
		return tenv.remember(name, value, getmetatable(tenv.recall).decorator_syl)
	end
	tenv.remember_basesyl = function(name, value)
		return tenv.remember(name, value, getmetatable(tenv.recall).decorator_basesyl)
	end
	tenv.remember_if = function(name, value, condition, decorator)
		if condition then
			return tenv.remember(name, value, decorator)
		end
		return value
	end
	-- condition and true_value or false_value
	tenv.value_if = function(condition, true_value, false_value)
		if condition then
			return true_value
		end
		return false_value
	end
	-- load fx line as function
	tenv.load_fx = function(effect, ...)
		local text = "";
		for i, line in ipairs(subs) do
			if line.class == "dialogue" and line.comment and line.effect:match("fx " .. effect) then
				text = line.text;
				break;
			end
		end
		local ret = {
			text = text,
			tenv = tenv
		};
		if select("#", ...) > 0 then
			ret.params = table.pack(...);
		end
		setmetatable(ret, { __call = text_template_interpreter });
		return ret;
	end
	-- apply fx line
	tenv.use_fx_cache = {};
	tenv.use_fx = function(effect, extra)
		local eff = tenv.use_fx_cache[effect];
		if eff == nil then
			eff = tenv.load_fx(effect);
			tenv.use_fx_cache[effect] = eff;
		end
		return eff(extra);
	end
	-- text template
	tenv.create_template = function(text, ...)
		local ret = {
			text = text,
			tenv = tenv
		};
		if select("#", ...) > 0 then
			ret.params = table.pack(...);
		end
		setmetatable(ret, { __call = text_template_interpreter });
		return ret;
	end
	tenv.t = function(text, ...)
		return tenv.create_template(text:gsub("@", "$"):gsub("`", "!"), ...);
	end
	-- extract tag data from source (line or syl) supported custom tags
	tenv.use_tag = use_tag;
	tenv.u = setmetatable({}, {
		__index = function(tab, id)
			local f = function(index)
				return tenv.use_tag(tenv.line, id, index);
			end
			tab[id] = f;
			return f;
		end,
		__call = function(tab, id, index)
			return tenv.use_tag(tenv.line, id, index);
		end
	});
	tenv.usyl = setmetatable({}, {
		__index = function(tab, id)
			local f = function(index)
				return tenv.use_tag(tenv.syll, id, index);
			end
			tab[id] = f;
			return f;
		end,
		__call = function(tab, id, index)
			return tenv.use_tag(tenv.syll, id, index);
		end
	});
	-- transform (ox, oy) to coordinate defined by (x, y, align, matrix)
	tenv.locate_c = function(ox, oy, x, y, align, matrix)
		local line, syl = tenv.line, tenv.syl;
		return locate(
			line, syl,
			ox, oy,
			x or tenv.use_tag(line, "pos", 1), y or tenv.use_tag(line, "pos", 2),
			align or tenv.use_tag(line, "an"),
			matrix
		);
	end
	tenv.locate_x = function(ox, x, align, matrix)
		local rx, _ = tenv.locate_c(ox, nil, x, nil, align, matrix);
		return rx;
	end
	tenv.locate_y = function(oy, y, align, matrix)
		local _, ry = tenv.locate_c(nil, oy, nil, y, align, matrix);
		return ry;
	end
	tenv.locate = function(ox, oy, x, y, align, matrix)
		local rx, ry = tenv.locate_c(ox, oy, x, y, align, matrix);
		return string.format("%g,%g", rx, ry);
	end
	tenv.locate_s = function(ox, oy, x, y, align, matrix)
		local rx, ry = tenv.locate_c(ox, oy, x, y, align, matrix);
		return string.format("%g %g", rx, ry);
	end
	-- variable define
	tenv.varctx = nil;
	tenv.varctx_base = {};
	tenv.define = function(name, value, var_type, ...)
		if var_type == "template" then
			local template = tenv.create_template(value, ...);
			tenv.varctx_base[name] = function()
				return template();
			end
		elseif var_type == "computed" and type(value) == "function" then
			tenv.varctx_base[name] = value;
		else
			tenv.varctx_base[name] = tostring(value);
		end
	end
	-- interpolation
	tenv.transform = function(t1, t2, step, tag, easing)
		local line = tenv.line;
		local f_tag = tag;
		t1 = t1 or 0;
		t2 = t2 or line.duration;
		step = step or (aegisub.ms_from_frame(101) - aegisub.ms_from_frame(1)) / 200;
		if type(tag) == "string" then
			f_tag = tenv.t(tag, "p", "t", "tstart", "tend");
		elseif type(tag) == "table" then
			if tag.params == nil then
				tag.params = { "p", "t", "tstart", "tend" };
			end
		end
		return transform(t1, t2, step, f_tag, easing);
	end;
	-- random
	math.randomseed(0);
	tenv.random = math.random;
	-- debug out
	tenv.log = function(...)
		if select("#", ...) <= 1 then
			aegisub.log("%s", select(1, ...));
		else
			aegisub.log(...);
		end
		return "";
	end;
	-- import
	tenv.import = function(name, alias)
		if alias == nil then
			alias = name;
		end
		tenv[alias] = require(name);
	end
	tenv.import_local = function(path, name)
		local file = assert(io.open(aegisub.decode_path(path), "r"));
		local code = file:read("*a");
		file:close();
		f, err = loadstring(code);
		if err ~= nil then
			aegisub.debug.out(2, "Error import local: %s\n\n", err);
		else
			setfenv(f, tenv);
			local res, val = pcall(f)
			if res then
				if name ~= nil then
					tenv[name] = val;
				end
			else
				aegisub.debug.out(2, "Runtime error in local import: %s\n\n", val);
			end
		end
	end
	-- style helper
	tenv.styles = function(name)
		local style = styles[name];
		if style ~= nil then
			return table.copy(style);
		end
		return nil;
	end
	-- loop helper
	tenv.makeloop = function(receiver, ...)
		if select("#", ...) % 2 == 0 then
			return makeloop(tenv, "", receiver, table.pack(...));
		end
		return makeloop(tenv, "", nil, table.pack(receiver, ...));
	end
	tenv.loopget = function(varname, query)
		return loopget(tenv, "", varname, query);
	end
	tenv.loopset = function(...)
		loopset(tenv, "", table.pack(...));
		return "";
	end
	tenv.perframe = function(receiver)
		local line = tenv.line;
		local start_time, end_time = line.start_time, line.end_time;
		local start_frame, end_frame = aegisub.frame_from_ms(start_time), aegisub.frame_from_ms(end_time);
		if start_frame ~= nil or end_frame ~= nil then
			makeloop(tenv, "perframe", nil, { "absframe", { start_frame, end_frame - 1 } });
			local absframe = loopget(tenv, "perframe", "absframe");
			line.start_time = aegisub.ms_from_frame(absframe);
			line.end_time = aegisub.ms_from_frame(absframe + 1);
			line.duration = line.end_time - line.start_time;
			if type(receiver) == "string" then
				local rev = tenv[receiver];
				rev.frame = absframe - start_frame;
				rev.total = end_frame - start_frame;
				rev.progress = (absframe - start_frame) / (end_frame - start_frame);
			end
		else
			aegisub.debug.out(2, "FPS is unknown, please load at least one video.\n", val);
		end
		return "";
	end

	-- run all run-once code snippets
	for k, t in pairs(templates.once) do
		assert(t.code, "WTF, a 'once' template without code?")
		tenv.template = t
		run_code_template(t, tenv)
	end

	-- start processing lines
	local i, n = 0, #subs
	while i < n do
		aegisub.progress.set(i/n*100)
		i = i + 1
		local l = subs[i]
		if l.class == "dialogue" and ((l.effect == "" and not l.comment) or l.effect:match("[Kk]araoke")) then
			l.i = i
			l.comment = false
			karaskel.preproc_line(subs, meta, styles, l)
			additional_proc_line(l)
			if apply_line(meta, styles, subs, l, templates, tenv) then
				-- Some templates were applied to this line, make a karaoke timing line of it
				l.comment = true
				l.effect = "karaoke"
				subs[i] = l
			end
		end
	end
end

function set_ctx_syl(varctx, line, syl)
	varctx.sstart = syl.start_time
	varctx.send = syl.end_time
	varctx.sdur = syl.duration
	varctx.skdur = syl.duration / 10
	varctx.smid = syl.start_time + syl.duration / 2
	varctx["start"] = varctx.sstart
	varctx["end"] = varctx.send
	varctx.dur = varctx.sdur
	varctx.kdur = varctx.skdur
	varctx.mid = varctx.smid
	varctx.si = syl.i
	varctx.i = varctx.si
	varctx.ci = syl.ci
	varctx.sleft = math.floor((line.left + syl.left)*10+0.5)/10
	varctx.scenter = math.floor((line.left + syl.center)*10+0.5)/10
	varctx.sright = math.floor((line.left + syl.right)*10+0.5)/10
	varctx.swidth = math.floor(syl.width*10 + 0.5)/10
	if syl.isfuri then
		varctx.sbottom = varctx.ltop
		varctx.stop = math.floor((varctx.ltop - syl.height)*10 + 0.5)/10
		varctx.smiddle = math.floor((varctx.ltop - syl.height/2)*10 + 0.5)/10
	else
		varctx.stop = varctx.ltop
		varctx.smiddle = varctx.lmiddle
		varctx.sbottom = varctx.lbottom
	end
	varctx.sheight = syl.height
	if line.halign == "left" then
		varctx.sx = math.floor((line.left + syl.left)*10+0.5)/10
	elseif line.halign == "center" then
		varctx.sx = math.floor((line.left + syl.center)*10+0.5)/10
	elseif line.halign == "right" then
		varctx.sx = math.floor((line.left + syl.right)*10+0.5)/10
	end
	if line.valign == "top" then
		varctx.sy = varctx.stop
	elseif line.valign == "middle" then
		varctx.sy = varctx.smiddle
	elseif line.valign == "bottom" then
		varctx.sy = varctx.sbottom
	end
	varctx.slen = syl.length

	varctx.left = varctx.sleft
	varctx.center = varctx.scenter
	varctx.right = varctx.sright
	varctx.width = varctx.swidth
	varctx.top = varctx.stop
	varctx.middle = varctx.smiddle
	varctx.bottom = varctx.sbottom
	varctx.height = varctx.sheight
	varctx.x = varctx.sx
	varctx.y = varctx.sy
	varctx.len = varctx.slen
end

-- splitting into word and char tables
function additional_proc_line(line)
	local words = {n = 0}
	local chars = {n = 0}
	local fchars = {n = 0}

	local tags = {n=0}
	local ded = 0
	for ci,tag in line.text:gmatch("()(%b{})") do
		tags.n = tags.n+1
		tags[tags.n] = {text = tag, ci = ci - ded}
		ded = ded + unicode.len(tag)
	end

	local ci = 1
	for i=1,#line.kara do
		line.kara[i].ci = ci
		ci = ci + unicode.len(line.kara[i].text_stripped)
		line.kara[i].chars = {n=0}
	end

	local word
	local lf = 0
	local lastci = 0
	local lastpost = ""
	for ci, pre, wordtxt, post in line.text_stripped:gmatch("()(%s*)(%S+)(%s*)") do
		--w = aegisub.text_extents(line.styleref, pre .. wordtxt .. post)
		w = aegisub.text_extents(line.styleref, wordtxt)
		local tagstr = ""
		for i,tag in ipairs(tags) do
			if tag.ci > lastci and tag.ci <= ci then
				tagstr = tagstr .. tag.text:gsub("\\[Kk][of]?%d+",""):gsub("{}","")
			end
		end
		word = {
			i = words.n + 1,
			ci = ci,
			start_time = line.start_time,
			end_time = line.end_time,
			duration = line.duration,
			tags = tagstr,
			text = tagstr .. pre .. wordtxt .. post,
			text_stripped = pre .. wordtxt .. post,
			text_spacestripped = wordtxt,
			prespace = pre,
			postspace = post,
			width = w,
			left = lf,
			center = lf + w/2,
			right = lf + w,
			prespacewidth = aegisub.text_extents(line.styleref, pre),
			postspacewidth = aegisub.text_extents(line.styleref, post),
			chars = {n=0},
			kara = {n=0},
			style = line.styleref,
			length = unicode.len(pre .. wordtxt .. post)
		}

		for i=1,#line.kara do
			if line.kara[i].ci >= ci-unicode.len(pre)-unicode.len(lastpost) and line.kara[i].ci < ci+unicode.len(wordtxt) then
				line.kara[i].word = word
				line.kara[i].wi = words.n + 1
				word.kara.n = word.kara.n + 1
				word.kara[word.kara.n] = line.kara[i]
			end
		end

		if word.kara.n > 0 then
			word.highlights = {n=0}
			local hltime = 0
			for i=1,word.kara.n do
				for h=1,#word.kara[i].highlights do
					word.highlights.n = word.highlights.n + 1
					local highlight = {}
					highlight.duration = word.kara[i].highlights[h].duration
					highlight.start_time = word.kara[i].highlights[h].start_time + hltime
					highlight.end_time = word.kara[i].highlights[h].end_time + hltime
					word.highlights[word.highlights.n] = highlight
				end
				hltime = hltime + word.kara[i].duration
			end
			word.start_time = word.kara[1].start_time
			word.end_time = word.kara[word.kara.n].end_time
			word.duration = word.end_time-word.start_time
			word.si = word.kara[1].i
			word.inline_fx = word.kara[1].inline_fx
		end

		lf = lf + word.prespacewidth + word.width + word.postspacewidth
		lastci = ci
		lastpost = post

		words.n = words.n+1
		words[words.n] = word
	end

	line.words = words



	local char
	local lf = 0
	local ci = 0
	for c in unicode.chars(line.text_stripped) do
		ci = ci + 1
		w = aegisub.text_extents(line.styleref, c)
		local tagstr = ""
		for i,tag in ipairs(tags) do
			if tag.ci == ci then
				tagstr = tagstr .. tag.text:gsub("\\[Kk][of]?%d+",""):gsub("{}","")
			end
		end
		char = {
			i = ci,
			ci = ci,
			start_time = line.start_time,
			end_time = line.end_time,
			duration = line.duration,
			tags = tagstr,
			text = tagstr .. c,
			text_stripped = c,
			text_spacestripped = c,
			prespace = "",
			postspace = "",
			width = w,
			left = lf,
			center = lf + w/2,
			right = lf + w,
			prespacewidth = 0,
			postspacewidth = 0,
			style = line.styleref,
			length = unicode.len(c)
		}
		for i=1,words.n do
			if words[i].ci > ci then
				char.word = words[i-1]
				char.wi = i-1
				words[i-1].chars.n = words[i-1].chars.n + 1
				words[i-1].chars[words[i-1].chars.n] = char
				break
			end
		end
		if char.word == nil then
			char.word = words[words.n]
			char.wi = words.n
			words[words.n].chars.n = words[words.n].chars.n + 1
			words[words.n].chars[words[words.n].chars.n] = char
		end
		for i=1,#line.kara do
			if line.kara[i].ci > ci then
				char.syll = line.kara[i-1]
				char.si = i-1
				line.kara[i-1].chars.n = line.kara[i-1].chars.n + 1
				line.kara[i-1].chars[line.kara[i-1].chars.n] = char
				char.start_time = line.kara[i-1].start_time
				char.end_time = line.kara[i-1].end_time
				char.duration = line.kara[i-1].duration
				char.highlights = line.kara[i-1].highlights
				--char.style = line.kara[i-1].style
				break
			end
		end
		if char.syll == nil then
			char.syll = line.kara[#line.kara]
			char.si = #line.kara
			line.kara[#line.kara].chars.n = line.kara[#line.kara].chars.n + 1
			line.kara[#line.kara].chars[line.kara[#line.kara].chars.n] = char
			char.start_time = line.kara[#line.kara].start_time
			char.end_time = line.kara[#line.kara].end_time
			char.duration = line.kara[#line.kara].duration
			char.highlights = line.kara[#line.kara].highlights
			--char.style = line.kara[i-1].style
		end
		char.inline_fx = char.syll.inline_fx
		if char == char.syll.chars[1] and lf ~= char.syll.left then
			lf = char.syll.left
			char.left = lf
			char.center = lf + w/2
			char.right = lf + w
		end
		lf = lf + w

		chars.n = chars.n+1
		chars[chars.n] = char
	end

	line.chars = chars

	local fchar
	local lf = 0
	for fi,f in ipairs(line.furi) do
		local ci = 0
		for c in unicode.chars(f.text_stripped) do
			ci = ci + 1
			w = aegisub.text_extents(line.furistyle, c)
			local tagstr = ""
			for i,tag in ipairs(tags) do
				if tag.ci == ci then
					tagstr = tagstr .. tag.text:gsub("\\[Kk][of]?%d+",""):gsub("{}","")
				end
			end
			fchar = {
				start_time = line.start_time,
				end_time = line.end_time,
				duration = line.duration,
				tags = tagstr,
				text = tagstr .. c,
				text_stripped = c,
				text_spacestripped = c,
				prespace = "",
				postspace = "",
				width = w,
				left = lf,
				center = lf + w/2,
				right = lf + w,
				prespacewidth = 0,
				postspacewidth = 0,
				style = line.furistyle,
				length = unicode.len(c)
			}
			--[[for i=1,words.n do
				if words[i].ci > ci then
					char.word = words[i-1]
					char.wi = i-1
					words[i-1].chars.n = words[i-1].chars.n + 1
					words[i-1].chars[words[i-1].chars.n] = char
					break
				end
			end
			if char.word == nil then
				char.word = words[words.n]
				char.wi = words.n
				words[words.n].chars.n = words[words.n].chars.n + 1
				words[words.n].chars[words[words.n].chars.n] = char
			end]]--
			fchar.syll = f
			fchar.si = fi
			fchar.start_time = f.start_time
			fchar.end_time = f.end_time
			fchar.duration = f.duration
			fchar.highlights = f.highlights

			fchar.inline_fx = f.inline_fx
			if ci == 1 then
				lf = f.left
				fchar.left = lf
				fchar.center = lf + w/2
				fchar.right = lf + w
			end
			lf = lf + w

			fchars.n = fchars.n+1
			fchars[fchars.n] = fchar
		end
	end
	line.fchars = fchars
end

function apply_line(meta, styles, subs, line, templates, tenv)
	-- Tell whether any templates were applied to this line, needed to know whether the original line should be removed from input
	local applied_templates = false

	line.length = unicode.len(line.text_stripped)

	-- General variable replacement context
	local varctx = {
		layer = line.layer,
		lstart = line.start_time,
		lend = line.end_time,
		ldur = line.duration,
		lmid = line.start_time + line.duration/2,
		style = line.style,
		actor = line.actor,
		margin_l = ((line.margin_l > 0) and line.margin_l) or line.styleref.margin_l,
		margin_r = ((line.margin_r > 0) and line.margin_r) or line.styleref.margin_r,
		margin_t = ((line.margin_t > 0) and line.margin_t) or line.styleref.margin_t,
		margin_b = ((line.margin_b > 0) and line.margin_b) or line.styleref.margin_b,
		margin_v = ((line.margin_t > 0) and line.margin_t) or line.styleref.margin_t,
		syln = line.kara.n,
		li = line.i,
		lleft = math.floor(line.left*10+0.5)/10,
		lcenter = math.floor(line.left*10 + line.width*5 + 0.5)/10,
		lright = math.floor(line.left*10 + line.width*10 + 0.5)/10,
		lwidth = math.floor(line.width*10 + 0.5)/10,
		ltop = math.floor(line.top*10 + 0.5)/10,
		lmiddle = math.floor(line.middle*10 + 0.5)/10,
		lbottom = math.floor(line.bottom*10 + 0.5)/10,
		lheight = math.floor(line.height*10 + 0.5)/10,
		lx = math.floor(line.x*10+0.5)/10,
		ly = math.floor(line.y*10+0.5)/10,
		llen = line.length
	}

	tenv.orgline = line
	tenv.line = nil
	tenv.word = nil
	tenv.baseword = nil
	tenv.syll = nil
	tenv.basesyll = nil
	tenv.char = nil
	tenv.basechar = nil
	tenv.syl = nil
	tenv.basesyl = nil
	tenv.varctx = varctx;
	setmetatable(varctx, {
		__index = tenv.varctx_base
	})

	-- Apply all line templates
	aegisub.debug.out(5, "Running line templates\n")
	for t in matching_templates(templates.line, line, tenv) do
		if aegisub.progress.is_cancelled() then break end

		tenv.template = t

		-- Set varctx for per-line variables
		varctx["start"] = varctx.lstart
		varctx["end"] = varctx.lend
		varctx.dur = varctx.ldur
		varctx.kdur = math.floor(varctx.dur / 10)
		varctx.mid = varctx.lmid
		varctx.i = varctx.li
		varctx.left = varctx.lleft
		varctx.center = varctx.lcenter
		varctx.right = varctx.lright
		varctx.width = varctx.lwidth
		varctx.top = varctx.ltop
		varctx.middle = varctx.lmiddle
		varctx.bottom = varctx.lbottom
		varctx.height = varctx.lheight
		varctx.x = varctx.lx
		varctx.y = varctx.ly
		varctx.len = varctx.llen

		
		if t.code then
			aegisub.debug.out(5, "Code template, %s\n", t.code)
			tenv.line = line
			run_code_template(t, tenv)
		else
			aegisub.debug.out(5, "Line template, pre = '%s', t = '%s'\n", t.pre, t.t)
			for j, maxj in template_loop(tenv, t.loops) do
				applied_templates = true
				local newline = table.copy(line)
				tenv.line = newline
				newline.layer = t.layer
				textbuffer = {}
				if t.pre ~= "" then
					table.insert(textbuffer, run_text_template(t.pre, tenv, varctx))
				end
				if t.t ~= "" then
					if t.perword then
						for i = 1, line.words.n do
							local word = line.words[i]
							tenv.word = word
							tenv.baseword = word
							tenv.syl = word
							tenv.basesyl = word
							set_ctx_syl(varctx, line, word)
							table.insert(textbuffer, run_text_template(t.t, tenv, varctx))
							if t.addtext then
								if t.keeptags then
									table.insert(textbuffer, word.text)
								else
									table.insert(textbuffer, word.text_stripped)
								end
							end
						end
					elseif t.persyl then
						for i = 1, line.kara.n do
							local syl = line.kara[i]
							tenv.word = syl.word
							tenv.baseword = syl.word
							tenv.syll = syl
							tenv.basesyll = syl
							tenv.syl = syl
							tenv.basesyl = syl
							set_ctx_syl(varctx, line, syl)
							table.insert(textbuffer, run_text_template(t.t, tenv, varctx))
							if t.addtext then
								if t.keeptags then
									table.insert(textbuffer, syl.text)
								else
									table.insert(textbuffer, syl.text_stripped)
								end
							end
						end
					elseif t.perchar then
						for i = 1, line.chars.n do
							local char = line.chars[i]
							tenv.word = char.word
							tenv.baseword = char.word
							tenv.syll = char.syll
							tenv.basesyll = char.syll
							tenv.char = char
							tenv.basechar = char
							tenv.syl = char
							tenv.basesyl = char
							set_ctx_syl(varctx, line, char)
							table.insert(textbuffer, run_text_template(t.t, tenv, varctx))
							if t.addtext then
								if t.keeptags then
									table.insert(textbuffer, char.text)
								else
									table.insert(textbuffer, char.text_stripped)
								end
							end
						end
					end
				else
					-- hmm, no main template for the line... put original text in
					if t.addtext then
						if t.keeptags then
							table.insert(textbuffer, line.text)
						else
							table.insert(textbuffer, line.text_stripped)
						end
					end
				end
				newline.text = table.concat(textbuffer)
				newline.effect = "fx"
				if j <= tenv.maxj then subs.append(newline) end
			end
		end
	end
	aegisub.debug.out(5, "Done running line templates\n\n")

	-- Loop over furigana
	for i = 1, line.furi.n do
		if aegisub.progress.is_cancelled() then break end
		local furi = line.furi[i]

		aegisub.debug.out(5, "Applying templates to furigana: %s\n", furi.text)
		if apply_syllable_templates(furi, line, templates.furi, tenv, varctx, subs) then
			applied_templates = true
		end
	end

	-- Loop over furigana by chars
	for i = 1, line.fchars.n do
		if aegisub.progress.is_cancelled() then break end
		local furi = line.fchars[i]

		aegisub.debug.out(5, "Applying templates to furigana char: %s\n", furi.text)
		if apply_syllable_templates(furi, line, templates.furichar, tenv, varctx, subs) then
			applied_templates = true
		end
	end

	-- Loop over words
	for i = 1, line.words.n do
		if aegisub.progress.is_cancelled() then break end
		local word = line.words[i]
		tenv.word = word
		tenv.baseword = word
		aegisub.debug.out(5, "Applying templates to word: %s\n", word.text)
		if apply_syllable_templates(word, line, templates.word, tenv, varctx, subs) then
			applied_templates = true
		end
	end

	-- Loop over syllables
	for i = 1, line.kara.n do
		if aegisub.progress.is_cancelled() then break end
		local syl = line.kara[i]
		tenv.word = syl.word
		tenv.baseword = syl.word
		tenv.syll = syl
		tenv.basesyll = syl

		aegisub.debug.out(5, "Applying templates to syllable: %s\n", syl.text)
		if apply_syllable_templates(syl, line, templates.syl, tenv, varctx, subs) then
			applied_templates = true
		end
	end

	-- Loop over characters
	for i = 1, line.chars.n do
		if aegisub.progress.is_cancelled() then break end
		local char = line.chars[i]
		tenv.word = char.word
		tenv.baseword = char.word
		tenv.syll = char.syll
		tenv.basesyll = char.syll
		tenv.char = char
		tenv.basechar = char

		aegisub.debug.out(5, "Applying templates to char: %s\n", char.text)
		if apply_syllable_templates(char, line, templates.char, tenv, varctx, subs) then
			applied_templates = true
		end
	end

	return applied_templates
end

function run_code_template(template, tenv)
	local f, err = loadstring(template.code, "template code")
	if not f then
		aegisub.debug.out(2, "Failed to parse Lua code: %s\nCode that failed to parse: %s\n\n", err, template.code)
	else
		local pcall = pcall
		setfenv(f, tenv)
		for j, maxj in template_loop(tenv, template.loops) do
			local res, err = pcall(f)
			if not res then
				aegisub.debug.out(2, "Runtime error in template code: %s\nCode producing error: %s\n\n", err, template.code)
			end
		end
	end
end

function is_primitive(type)
	return type == "boolean" or type == "number" or type == "string"
end

function run_text_template(template, tenv, varctx)
	local res = template
	aegisub.debug.out(5, "Running text template '%s'\n", res)

	-- Replace the variables in the string (this is probably faster than using a custom function, but doesn't provide error reporting)
	if varctx then
		aegisub.debug.out(5, "Has varctx, replacing variables\n")
		local function var_replacer(varname)
			varname = string.lower(varname)
			aegisub.debug.out(5, "Found variable named '%s', ", varname)
			local varvalue = varctx[varname]
			if type(varvalue) == "function" then
				local success, computed = pcall(varvalue)
				if success then
					varvalue = computed
				else
					aegisub.debug.out(2, "but failed to compute it: %s", computed)
					return "$" .. varname
				end
			end
			if varvalue ~= nil then
				aegisub.debug.out(5, "it exists, value is '%s'\n", varvalue)
				if not is_primitive(type(varvalue)) then
					aegisub.debug.out(2, "Found non-primitive '%s' in template: %s\n", varvalue, template)
				end
				return tostring(varvalue)
			else
				aegisub.debug.out(5, "doesn't exist\n")
				aegisub.debug.out(2, "Unknown variable name: %s\nIn karaoke template: %s\n\n", varname, template)
				return "$" .. varname
			end
		end
		res = string.gsub(res, "$([%a_]+)", var_replacer)
		aegisub.debug.out(5, "Done replacing variables, new template string is '%s'\n", res)
	end

	-- Function for evaluating expressions
	local function expression_evaluator(expression)
		f, err = loadstring(string.format("return (%s)", expression))
		if (err) ~= nil then
			aegisub.debug.out(2, "Error parsing expression: %s\nExpression producing error: %s\nTemplate with expression: %s\n\n", err, expression, template)
			return "!" .. expression .. "!"
		else
			setfenv(f, tenv)
			local res, val = pcall(f)
			if res then
				if not is_primitive(type(val)) then
					aegisub.debug.out(2, "Found non-primitive '%s' in template: %s\n", val, template)
				end
				return tostring(val)
			else
				aegisub.debug.out(2, "Runtime error in template expression: %s\nExpression producing error: %s\nTemplate with expression: %s\n\n", val, expression, template)
				return "!" .. expression .. "!"
			end
		end
	end
	-- Find and evaluate expressions
	aegisub.debug.out(5, "Now evaluating expressions\n")
	res = string.gsub(res , "!(.-)!", expression_evaluator)
	aegisub.debug.out(5, "After evaluation: %s\nDone handling template\n\n", res)

	return res
end

function apply_syllable_templates(syl, line, templates, tenv, varctx, subs)
	local applied = 0

	-- Loop over all templates matching the line style
	for t in matching_templates(templates, line, tenv) do
		if aegisub.progress.is_cancelled() then break end

		tenv.template = t
		tenv.syl = syl
		tenv.basesyl = syl
		set_ctx_syl(varctx, line, syl)

		applied = applied + apply_one_syllable_template(syl, line, t, tenv, varctx, subs, false)
	end

	return applied > 0
end

function is_syl_blank(syl)

	-- try to remove common spacing characters
	local t = syl.text_stripped
	if t:len() <= 0 then return true end
	t = t:gsub("[ \t\n\r]", "") -- regular ASCII space characters
	t = t:gsub("　", "") -- fullwidth space
	return t:len() <= 0
end

function apply_one_syllable_template(syl, line, template, tenv, varctx, subs, skip_multi)
	if aegisub.progress.is_cancelled() then return 0 end
	local t = template
	local applied = 0

	aegisub.debug.out(5, "Applying template to one syllable with text: %s\n", syl.text)

	-- Check for right inline_fx
	if t.fx and t.fx ~= syl.inline_fx then
		aegisub.debug.out(5, "Syllable has wrong inline-fx (wanted '%s', got '%s'), skipping.\n", t.fx, syl.inline_fx)
		return 0
	end

	if t.noblank and is_syl_blank(syl) and not t.perchar then
		aegisub.debug.out(5, "Syllable is blank, skipping.\n")
		return 0
	end

	-- Recurse to per-char if required - so never due to changed flow

	-- Recurse to multi-hl if required
	if not skip_multi and t.multi then
		aegisub.debug.out(5, "Doing multi-highlight effects...\n")
		local hlsyl = table.copy(syl)
		tenv.syl = hlsyl

		for hl = 1, syl.highlights.n do
			local hldata = syl.highlights[hl]
			hlsyl.start_time = hldata.start_time
			hlsyl.end_time = hldata.end_time
			hlsyl.duration = hldata.duration
			set_ctx_syl(varctx, line, hlsyl)

			applied = applied + apply_one_syllable_template(hlsyl, line, t, tenv, varctx, subs, true)
		end

		return applied
	end

	-- Regular processing
	if t.code then
		aegisub.debug.out(5, "Running code line\n")
		tenv.line = line
		run_code_template(t, tenv)
	else
		aegisub.debug.out(5, "Running %d effect loops\n", t.loops)
		for j, maxj in template_loop(tenv, t.loops) do
			local newline = table.copy(line)
			newline.styleref = syl.style
			newline.style = syl.style.name
			newline.layer = t.layer
			tenv.line = newline
			newline.text = run_text_template(t.t, tenv, varctx)
			if t.keeptags then
				newline.text = newline.text .. syl.text
			elseif t.addtext then
				newline.text = newline.text .. syl.text_stripped
			end
			newline.effect = "fx"
			aegisub.debug.out(5, "Generated line with text: %s\n", newline.text)
			if j <= tenv.maxj then
				subs.append(newline)
				applied = applied + 1
			end
		end
	end

	return applied
end


-- Main function to do the templating
function filter_apply_templates(subs, config)
	aegisub.progress.task("Collecting header data...")
	local meta, styles = karaskel.collect_head(subs, true)

	aegisub.progress.task("Parsing templates...")
	local templates = parse_templates(meta, styles, subs)

	aegisub.progress.task("Applying templates...")
	apply_templates(meta, styles, subs, templates)
end

function filter_apply_templates_furioff(subs, config)
	aegisub.progress.task("Collecting header data...")
	local meta, styles = karaskel.collect_head(subs, false)

	aegisub.progress.task("Parsing templates...")
	local templates = parse_templates(meta, styles, subs)

	aegisub.progress.task("Applying templates...")
	apply_templates(meta, styles, subs, templates)
end

function macro_apply_templates(subs, sel)
	filter_apply_templates(subs, {ismacro=true, sel=sel})
	aegisub.set_undo_point("apply karaoke template")
end

function macro_apply_templates_furioff(subs, sel)
	filter_apply_templates_furioff(subs, {ismacro=true, sel=sel})
	aegisub.set_undo_point("apply karaoke template")
end

function macro_can_template(subs)
	-- check if this file has templates in it, don't allow running the macro if it hasn't
	local num_dia = 0
	for i = 1, #subs do
		local l = subs[i]
		if l.class == "dialogue" then
			num_dia = num_dia + 1
			-- test if the line is a template
			if (string.headtail(l.effect)):lower() == "template" or (string.headtail(l.effect)):lower() == "code" then
				return true
			end
			-- don't try forever, this has to be fast
			if num_dia > 30 then
				return false
			end
		end
	end
	return false
end

aegisub.register_macro(tr"Apply karaoke template (modded)", tr"Applies karaoke effects from templates, does not generate furigana styles", macro_apply_templates_furioff, macro_can_template)
aegisub.register_macro(tr"Apply karaoke template (modded with furigana)", tr"Applies karaoke effects from templates, generates furigana styles", macro_apply_templates, macro_can_template)
aegisub.register_filter(tr"Karaoke template (modded)", tr"Apply karaoke effect templates to the subtitles.\n\nSee the help file for information on how to use this.", 2000, filter_apply_templates)
aegisub.register_filter(tr"Karaoke template (modded, furigana off)", tr"Apply karaoke effect templates to the subtitles.\n\nSee the help file for information on how to use this.", 2000, filter_apply_templates_furioff)
