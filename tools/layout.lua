-- Resolves the mock client's anchors into screen rectangles (UIParent units, y up) and
-- lists every visible texture and font string under a frame in draw order, for the
-- HTML preview.

local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local LAYER = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }

local function frameOf(r)
	if r.__kind == "Texture" or r.__kind == "FontString" then
		return r.__parent
	end
	return r
end

local function scaleOf(r)
	local f, s = frameOf(r), 1
	while f do
		s = s * (f.__scale or 1)
		f = f.__parent
	end
	return s
end

local function strataOf(f)
	while f do
		if f.__strataSet then
			return f.__strata
		end
		f = f.__parent
	end
	return "MEDIUM"
end

local function levelOf(f)
	return f and f:GetFrameLevel() or 0
end

local function alphaOf(r)
	local a, o = 1, r
	while o do
		a = a * (o.__alpha or 1)
		o = o.__parent
	end
	return a
end

local function plain(s)
	s = string.gsub(s or "", "|c%x%x%x%x%x%x%x%x", "")
	s = string.gsub(s, "|r", "")
	return s
end

local rects

local function pointXY(rect, p)
	local x, y
	if string.find(p, "LEFT") then
		x = rect.l
	elseif string.find(p, "RIGHT") then
		x = rect.r
	else
		x = (rect.l + rect.r) / 2
	end
	if string.find(p, "TOP") then
		y = rect.t
	elseif string.find(p, "BOTTOM") then
		y = rect.b
	else
		y = (rect.t + rect.b) / 2
	end
	return x, y
end

local function rectOf(r)
	if rects[r] ~= nil then
		return rects[r] or nil
	end
	if r == UIParent or r == WorldFrame then
		return { l = 0, r = 1365, b = 0, t = 768 }
	end
	if r.__all then
		local t = rectOf(r.__all)
		rects[r] = t or false
		return t
	end
	if #r.__points == 0 then
		rects[r] = false
		return nil
	end
	local es = scaleOf(r)
	local w, h = r.__w or 0, r.__h or 0
	if r.__kind == "FontString" then
		local fs = r.__font and r.__font[2] or 12
		if w == 0 then
			local wide = r.__font and string.find(r.__font[1], "FRIZ") and 0.64 or 0.53
			w = string.len(plain(r.__text)) * fs * wide
		end
		if h == 0 then
			h = fs * 1.15
		end
	end
	w, h = w * es, h * es
	local L, R, T, B, CX, CY
	for _, pt in ipairs(r.__points) do
		local point, rel, relPoint, x, y = pt[1], pt[2], pt[3], pt[4] or 0, pt[5] or 0
		if type(rel) == "string" then
			rel = _G[rel]
		end
		rel = rel or r.__parent or UIParent
		local tr = rectOf(rel)
		if tr then
			local px, py = pointXY(tr, relPoint or point)
			px, py = px + x * es, py + y * es
			if string.find(point, "LEFT") then
				L = px
			elseif string.find(point, "RIGHT") then
				R = px
			else
				CX = px
			end
			if string.find(point, "TOP") then
				T = py
			elseif string.find(point, "BOTTOM") then
				B = py
			else
				CY = py
			end
		end
	end
	if not L then
		if R then
			L = R - w
		elseif CX then
			L = CX - w / 2
		else
			L = 0
		end
	end
	if not R then
		R = L + w
	end
	if not T then
		if B then
			T = B + h
		elseif CY then
			T = CY + h / 2
		else
			T = 768
		end
	end
	if not B then
		B = T - h
	end
	local rect = { l = L, r = R, t = T, b = B }
	rects[r] = rect
	return rect
end

function MOCK.Layout(root)
	rects = {}
	local items = {}
	local function walk(o)
		for _, c in ipairs(o.__children or {}) do
			if c:IsVisible() then
				if c.__kind == "Minimap" then
					local rect = rectOf(c)
					if rect then
						table.insert(items, {
							kind = "MinimapFace", l = rect.l, r = rect.r, t = rect.t, b = rect.b,
							strata = STRATA[strataOf(c)] or 3, level = levelOf(c), layer = 1, seq = c.__seq, alpha = 1,
							text = "", size = 12, font = "", flags = "", point = "CENTER", scale = 1,
						})
					end
				end
				if c.__kind == "StatusBar" and c.__sbtex then
					-- the bar's fill, as wide as its value
					local rect = rectOf(c)
					local a = alphaOf(c)
					if rect and a > 0.01 then
						local lo, hi = c:GetMinMaxValues()
						local frac = hi > lo and (c:GetValue() - lo) / (hi - lo) or 1
						local col = c.__sbcolor or { 1, 1, 1 }
						table.insert(items, {
							kind = "Texture", l = rect.l, r = rect.l + (rect.r - rect.l) * frac, t = rect.t, b = rect.b,
							strata = STRATA[strataOf(c)] or 3, level = levelOf(c), layer = 3, seq = c.__seq, alpha = a,
							tex = c.__sbtex, color = { col[1], col[2], col[3], 1 }, text = "", size = 12, font = "",
							flags = "", point = "CENTER", scale = 1,
						})
					end
				end
				if c.__kind == "Texture" or c.__kind == "FontString" then
					if c.__layer ~= "HIGHLIGHT" then
						local rect = rectOf(c)
						local a = alphaOf(c)
						if rect and a > 0.01 and (c.__kind == "Texture" or (c.__text and c.__text ~= "")) then
							local f = frameOf(c)
							table.insert(items, {
								kind = c.__kind, l = rect.l, r = rect.r, t = rect.t, b = rect.b,
								strata = STRATA[strataOf(f)] or 3, level = levelOf(f), layer = LAYER[c.__layer or "ARTWORK"] or 3,
								seq = c.__seq, alpha = a, tex = c.__tex, color = c.__color, grad = c.__grad,
								blend = c.__blend, coord = c.__coord, text = c.__text,
								size = c.__font and c.__font[2] or 12, font = c.__font and c.__font[1] or "",
								flags = c.__font and c.__font[3] or "", tcolor = c.__tcolor,
								point = c.__points[1] and c.__points[1][1] or "CENTER", scale = scaleOf(c),
							})
						end
					end
				else
					walk(c)
				end
			end
		end
	end
	walk(root)
	table.sort(items, function(a, b)
		if a.strata ~= b.strata then
			return a.strata < b.strata
		elseif a.level ~= b.level then
			return a.level < b.level
		elseif a.layer ~= b.layer then
			return a.layer < b.layer
		end
		return a.seq < b.seq
	end)
	return items
end
