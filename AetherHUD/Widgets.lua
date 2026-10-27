-- AetherHUD widgets: the glass panel, the animated bar, icon sockets and diamond pips
-- that every module is built from.

local A = AetherHUD
local C = A.C

local function Tex(parent, layer, path)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetTexture(path or A.FLAT)
	return t
end
A.Tex = Tex

local function Line(parent, layer, c, a)
	local t = Tex(parent, layer or "BORDER")
	t:SetVertexColor(c[1], c[2], c[3], a or 1)
	return t
end

-- 1px frame around `target` (or the parent), drawn on `parent`.
function A.Border(parent, c, a, layer, target, inset)
	target = target or parent
	inset = inset or 0
	local b = {}
	for i = 1, 4 do
		b[i] = Line(parent, layer, c, a)
	end
	b[1]:SetPoint("TOPLEFT", target, "TOPLEFT", inset, -inset)
	b[1]:SetPoint("TOPRIGHT", target, "TOPRIGHT", -inset, -inset)
	b[1]:SetHeight(1)
	b[2]:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", inset, inset)
	b[2]:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -inset, inset)
	b[2]:SetHeight(1)
	b[3]:SetPoint("TOPLEFT", target, "TOPLEFT", inset, -inset)
	b[3]:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", inset, inset)
	b[3]:SetWidth(1)
	b[4]:SetPoint("TOPRIGHT", target, "TOPRIGHT", -inset, -inset)
	b[4]:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -inset, inset)
	b[4]:SetWidth(1)
	return b
end

function A.BorderColor(b, c, a)
	for i = 1, 4 do
		A.SetColor(b[i], c[1], c[2], c[3], a or 1)
	end
end

------------------------------------------------------------------------
-- Panel: navy glass, a steel hairline, an aether glint along the top edge and gold
-- brackets in the corners.
------------------------------------------------------------------------

function A.Panel(name, parent, w, h, opts)
	opts = opts or {}
	local f = CreateFrame("Frame", name, parent or A.root)
	f:SetWidth(w)
	f:SetHeight(h)
	-- a panel sits in its parent's layer unless told otherwise
	local strata = opts.strata or (parent and parent.GetFrameStrata and parent:GetFrameStrata()) or "LOW"
	f:SetFrameStrata(strata)
	return A.Dress(f, opts)
end

-- The panel's look on any frame, our own or a stock one being re-skinned.
function A.Dress(f, opts)
	opts = opts or {}
	local bg = Tex(f, "BACKGROUND")
	bg:SetAllPoints(f)
	A.Gradient(bg, "VERTICAL", C.bg, C.bgTop, opts.alpha or 0.82, (opts.alpha or 0.82) * 0.9)
	f.bg = bg

	f.shadow = A.Border(f, { 0, 0, 0 }, 0.85, "BORDER", f, -1)
	f.edge = A.Border(f, C.edge, 0.9, "BORDER")

	if not opts.noGlint then
		local glint = Tex(f, "ARTWORK", A.MEDIA .. "line")
		glint:SetBlendMode("ADD")
		glint:SetPoint("TOPLEFT", f, "TOPLEFT", 6, 3)
		glint:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, 3)
		glint:SetHeight(6)
		glint:SetVertexColor(C.aether[1], C.aether[2], C.aether[3], 0.9)
		f.glint = glint
	end

	if not opts.noBrackets then
		f.brackets = {}
		local L = opts.bracket or 7
		local function Bracket(point, sx, sy)
			local hz = Line(f, "ARTWORK", C.gold, 0.95)
			hz:SetPoint(point, f, point, 0, 0)
			hz:SetWidth(L)
			hz:SetHeight(1)
			local vt = Line(f, "ARTWORK", C.gold, 0.95)
			vt:SetPoint(point, f, point, 0, 0)
			vt:SetWidth(1)
			vt:SetHeight(L)
			table.insert(f.brackets, hz)
			table.insert(f.brackets, vt)
		end
		Bracket("TOPLEFT")
		Bracket("TOPRIGHT")
		Bracket("BOTTOMLEFT")
		Bracket("BOTTOMRIGHT")
	end
	return f
end

-- Tint a panel's hairline (alerts: enraged, low health).
function A.PanelAlert(f, c, a)
	if c then
		A.BorderColor(f.edge, c, a or 1)
	else
		A.BorderColor(f.edge, C.edge, 0.9)
	end
end

------------------------------------------------------------------------
-- Bar: gradient fill that eases toward its value, a pale trail showing what was just
-- lost, an optional shield segment past the fill and a spark at the leading edge.
------------------------------------------------------------------------

local Bar = {}
Bar.__index = Bar

function A.Bar(parent, w, h, c1, c2)
	local b = setmetatable({}, Bar)
	local f = CreateFrame("Frame", nil, parent)
	f:SetWidth(w)
	f:SetHeight(h)
	b.frame, b.w, b.h = f, w, h

	b.bg = Tex(f, "BACKGROUND")
	b.bg:SetAllPoints(f)
	b.bg:SetVertexColor(0, 0, 0, 0.55)

	b.trail = Tex(f, "BORDER")
	b.trail:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	b.trail:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	b.trail:SetVertexColor(1, 0.92, 0.78, 0.55)

	b.fill = Tex(f, "ARTWORK", A.MEDIA .. "bar")
	b.fill:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	b.fill:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)

	b.extra = Tex(f, "ARTWORK", A.MEDIA .. "bar")
	b.extra:SetPoint("TOPLEFT", b.fill, "TOPRIGHT", 0, 0)
	b.extra:SetPoint("BOTTOMLEFT", b.fill, "BOTTOMRIGHT", 0, 0)
	b.extra:SetVertexColor(C.shield[1], C.shield[2], C.shield[3], 0.75)
	b.extra:Hide()

	b.spark = Tex(f, "OVERLAY", A.SPARK)
	b.spark:SetBlendMode("ADD")
	b.spark:SetWidth(10)
	b.spark:SetHeight(h * 2.4)
	b.spark:SetPoint("CENTER", b.fill, "RIGHT", 0, 0)
	b.spark:SetVertexColor(1, 1, 1, 0.7)

	b.edge = A.Border(f, { 0, 0, 0 }, 0.9, "OVERLAY", f, -1)

	b.cur, b.target, b.trailv, b.hold = 0, 0, 0, 0
	b.extraFrac = 0
	b:SetColors(c1 or C.hp1, c2 or C.hp2)
	b:Draw()
	return b
end

function Bar:SetColors(c1, c2)
	A.Gradient(self.fill, "HORIZONTAL", c1, c2, 1, 1)
end

-- frac 0..1; snap = jump there without easing (first fill, new unit).
function Bar:SetValue(frac, snap)
	frac = A.Clamp(frac or 0, 0, 1)
	if snap then
		self.cur, self.target, self.trailv, self.hold = frac, frac, frac, 0
		self:Draw()
		return
	end
	if frac < self.target and self.trailv < self.target then
		self.trailv = self.target
	end
	if frac < self.target then
		self.hold = 0.45
	end
	self.target = frac
end

-- Shield (absorb) as a fraction of the bar's maximum, drawn after the fill.
function Bar:SetExtra(frac)
	self.extraFrac = math.max(0, frac or 0)
end

function Bar:Tick(dt)
	local d = self.target - self.cur
	if math.abs(d) < 0.001 then
		self.cur = self.target
	else
		self.cur = self.cur + d * math.min(1, dt * 14)
	end
	if self.hold > 0 then
		self.hold = self.hold - dt
	elseif self.trailv > self.cur then
		self.trailv = math.max(self.cur, self.trailv - dt * 0.7)
	end
	if self.trailv < self.cur then
		self.trailv = self.cur
	end
	self:Draw()
end

function Bar:Draw()
	local w = self.frame:GetWidth()
	local fw = self.cur * w
	A.SetWidth(self.fill, fw)
	A.Show(self.fill, fw >= 0.5)
	local tw = self.trailv * w
	A.SetWidth(self.trail, tw)
	A.Show(self.trail, tw > fw + 0.5)
	A.Show(self.spark, self.cur > 0.01 and self.cur < 0.995)
	if self.extraFrac > 0.001 then
		local ew = math.min(self.extraFrac, 1 - self.cur) * w
		A.SetWidth(self.extra, ew)
		A.Show(self.extra, ew >= 0.5)
	else
		A.Show(self.extra, false)
	end
end

------------------------------------------------------------------------
-- Icon socket: cropped icon in a frame, a cooldown curtain that drains downward, a
-- countdown, a stack count and a glow that flares when it comes ready.
------------------------------------------------------------------------

local Socket = {}
Socket.__index = Socket

-- opts: frame = "slot" (beveled skill socket) or nil (thin hairline), tint = colour table
function A.Socket(parent, size, opts)
	opts = opts or {}
	local s = setmetatable({}, Socket)
	local f = CreateFrame("Button", nil, parent)
	f:SetWidth(size)
	f:SetHeight(size)
	s.frame, s.size = f, size

	local inset = opts.frame == "slot" and math.floor(size * 0.1 + 0.5) or 1
	-- layers, back to front: recess, icon, cooldown curtain, its edge and the rim, glow
	local back = Tex(f, "BACKGROUND")
	back:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
	back:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
	A.Gradient(back, "VERTICAL", { 0.04, 0.07, 0.11 }, { 0.0, 0.01, 0.03 }, 0.9, 0.9)
	s.back = back
	s.icon = Tex(f, "BORDER")
	A.SetTexture(s.icon, "Interface\\Icons\\INV_Misc_QuestionMark")
	s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	s.icon:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
	s.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
	s.inner = size - 2 * inset

	s.curtain = Tex(f, "ARTWORK")
	s.curtain:SetVertexColor(0, 0.02, 0.05, 0.72)
	s.curtain:SetPoint("TOPLEFT", s.icon, "TOPLEFT", 0, 0)
	s.curtain:SetPoint("TOPRIGHT", s.icon, "TOPRIGHT", 0, 0)
	s.curtain:Hide()

	s.curtainEdge = Tex(f, "OVERLAY", A.MEDIA .. "line")
	s.curtainEdge:SetBlendMode("ADD")
	s.curtainEdge:SetVertexColor(C.aether[1], C.aether[2], C.aether[3], 0.9)
	s.curtainEdge:SetHeight(4)
	s.curtainEdge:SetPoint("LEFT", s.curtain, "BOTTOMLEFT", 0, 0)
	s.curtainEdge:SetPoint("RIGHT", s.curtain, "BOTTOMRIGHT", 0, 0)
	s.curtainEdge:Hide()

	if opts.frame == "slot" then
		s.rim = Tex(f, "OVERLAY", A.MEDIA .. "slot")
		s.rim:SetAllPoints(f)
		local t = opts.tint or C.steel
		s.rim:SetVertexColor(t[1], t[2], t[3], 1)
	else
		s.rim = A.Border(f, { 0, 0, 0 }, 1, "OVERLAY")
	end

	s.glow = Tex(f, "OVERLAY", A.MEDIA .. "glow")
	s.glow:SetBlendMode("ADD")
	s.glow:SetPoint("CENTER", f, "CENTER", 0, 0)
	s.glow:SetWidth(size * 2)
	s.glow:SetHeight(size * 2)
	s.glow:SetVertexColor(C.aether[1], C.aether[2], C.aether[3], 1)
	s.glow:SetAlpha(0)
	s.flash = 0

	-- text sits on its own frame level so it draws over the rim
	local top = CreateFrame("Frame", nil, f)
	top:SetAllPoints(f)
	top:SetFrameLevel(f:GetFrameLevel() + 2)
	s.timer = A.Text(top, opts.timerSize or math.max(9, math.floor(size * 0.36)))
	s.timer:SetPoint("CENTER", f, "CENTER", 0, 0)
	s.count = A.Text(top, opts.countSize or math.max(8, math.floor(size * 0.3)))
	s.count:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 2)
	s.count:SetJustifyH("RIGHT")
	s.top = top
	return s
end

function Socket:SetIcon(path)
	A.SetTexture(self.icon, path or "Interface\\Icons\\INV_Misc_QuestionMark")
end

-- left/total in seconds; left <= 0 clears it. Flares when it comes back from a wait.
function Socket:SetCooldown(left, total)
	if left and left > 0.05 and total and total > 0 then
		local frac = A.Clamp(left / total, 0, 1)
		A.SetHeight(self.curtain, math.max(0.5, self.inner * frac))
		A.Show(self.curtain, true)
		A.Show(self.curtainEdge, frac < 0.98)
		A.SetText(self.timer, A.Countdown(left))
		self.waiting = true
	else
		A.Show(self.curtain, false)
		A.Show(self.curtainEdge, false)
		A.SetText(self.timer, "")
		if self.waiting then
			self.waiting = nil
			self.flash = 0.45
		end
	end
end

function Socket:SetCount(n)
	if n and n > 1 then
		A.SetText(self.count, tostring(n))
	else
		A.SetText(self.count, "")
	end
end

function Socket:Tick(dt)
	if self.flash > 0 then
		self.flash = math.max(0, self.flash - dt)
		A.SetAlpha(self.glow, self.flash / 0.45)
	elseif self.glow.aA ~= 0 then
		A.SetAlpha(self.glow, 0)
	end
end

------------------------------------------------------------------------
-- Diamond pip with an optional number on it.
------------------------------------------------------------------------

function A.Diamond(parent, size, c, layer)
	local d = Tex(parent, layer or "ARTWORK", A.MEDIA .. "diamond")
	d:SetWidth(size)
	d:SetHeight(size)
	if c then
		d:SetVertexColor(c[1], c[2], c[3], 1)
	end
	return d
end

-- Debuff colours by dispel type, as the stock debuff frames use them.
A.DISPEL = {
	Magic = { 0.20, 0.60, 1.00 },
	Curse = { 0.60, 0.00, 1.00 },
	Disease = { 0.60, 0.40, 0.00 },
	Poison = { 0.00, 0.60, 0.00 },
}

-- A row of small debuff sockets: Row:Set(list) with { icon, stacks, remaining, duration, dispelType }.
local Row = {}
Row.__index = Row

function A.AuraRow(parent, size, max, gap)
	local r = setmetatable({ parent = parent, size = size, max = max, gap = gap or 2, sockets = {} }, Row)
	return r
end

function Row:Socket(i)
	local s = self.sockets[i]
	if not s then
		s = A.Socket(self.parent, self.size, { timerSize = math.max(8, math.floor(self.size * 0.42)) })
		s.timer:ClearAllPoints()
		s.timer:SetPoint("TOP", s.frame, "BOTTOM", 0, -1)
		A.Font(s.timer, math.max(8, math.floor(self.size * 0.42)))
		s.frame:EnableMouse(true)
		s.frame:SetScript("OnEnter", function()
			if this.tip then
				GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
				GameTooltip:SetText(this.tip, 1, 1, 1)
				if this.tipType then
					GameTooltip:AddLine(this.tipType, 0.7, 0.8, 1)
				end
				GameTooltip:Show()
			end
		end)
		s.frame:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		self.sockets[i] = s
	end
	return s
end

-- anchorFn(frame, i) places socket i
function Row:Set(list, anchorFn)
	local n = math.min(table.getn(list), self.max)
	for i = 1, n do
		local d = list[i]
		local s = self:Socket(i)
		if not s.placed then
			s.placed = true
			anchorFn(s.frame, i)
		end
		s:SetIcon(d.icon)
		s:SetCount(d.stacks)
		local left = d.remaining
		if left and left > 0 and not d.permanent then
			A.SetText(s.timer, A.Countdown(left))
		else
			A.SetText(s.timer, "")
		end
		local c = d.dispelType and A.DISPEL[d.dispelType]
		if c then
			A.BorderColor(s.rim, c, 1)
		else
			A.BorderColor(s.rim, { 0, 0, 0 }, 1)
		end
		s.frame.tip = d.name
		s.frame.tipType = d.dispelType
		A.Show(s.frame, true)
	end
	for i = n + 1, table.getn(self.sockets) do
		A.Show(self.sockets[i].frame, false)
	end
	return n
end

-- A small north-up compass: a ring, a gold north tick and a gem on the rim at a bearing
-- (radians clockwise from north). Moving the gem needs no rotated texture, only an anchor.
local Compass = {}
Compass.__index = Compass

function A.Compass(parent, size)
	local f = CreateFrame("Frame", nil, parent)
	f:SetWidth(size)
	f:SetHeight(size)
	local ring = Tex(f, "BORDER", A.MEDIA .. "ring")
	ring:SetAllPoints(f)
	ring:SetVertexColor(C.steel[1], C.steel[2], C.steel[3], 0.9)
	local north = A.Diamond(f, math.max(4, math.floor(size * 0.28)), C.gold, "ARTWORK")
	north:SetPoint("CENTER", f, "TOP", 0, 0)
	local dot = A.Diamond(f, math.max(5, math.floor(size * 0.45)), C.bad, "OVERLAY")
	return setmetatable({ frame = f, dot = dot, r = size / 2 - 1 }, Compass)
end

-- bearing nil: no gem (where they are is not known)
function Compass:Point(bearing)
	if not bearing then
		A.Show(self.dot, false)
		return
	end
	A.Show(self.dot, true)
	local x = math.floor(self.r * math.sin(bearing) + 0.5)
	local y = math.floor(self.r * math.cos(bearing) + 0.5)
	if self.x ~= x or self.y ~= y then
		self.x, self.y = x, y
		self.dot:ClearAllPoints()
		self.dot:SetPoint("CENTER", self.frame, "CENTER", x, y)
	end
end
