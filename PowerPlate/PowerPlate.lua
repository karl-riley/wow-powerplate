local VERSION = "0.11"
local DEFAULT_PARTY_COLOR = { r = 1, g = 105 / 255, b = 180 / 255 }
local DEFAULT_OTHER_COLOR = { r = 99 / 255, g = 99 / 255, b = 99 / 255 }
local DEFAULT_HIDE_OTHERS = true
local dbReady = false

local function DefaultColor(key)
	if key == "party" then
		return DEFAULT_PARTY_COLOR
	end
	return DEFAULT_OTHER_COLOR
end

local function ColorByte(value)
	return math.floor((tonumber(value) or 0) * 255 + 0.5)
end

local function SameColor(a, b)
	return type(a) == "table" and type(b) == "table"
		and ColorByte(a.r) == ColorByte(b.r)
		and ColorByte(a.g) == ColorByte(b.g)
		and ColorByte(a.b) == ColorByte(b.b)
end

local function PruneDB()
	if type(PowerPlateDB) ~= "table" then
		return
	end
	if type(PowerPlateDB.party) == "table" and PowerPlateDB.party.color == nil and next(PowerPlateDB.party) == nil then
		PowerPlateDB.party = nil
	end
	if type(PowerPlateDB.other) == "table" and PowerPlateDB.other.color == nil and PowerPlateDB.other.hide == nil and next(PowerPlateDB.other) == nil then
		PowerPlateDB.other = nil
	end
	if next(PowerPlateDB) == nil then
		PowerPlateDB = nil
	end
end

local function EnsureDB()
	dbReady = true
end

local function CategoryColor(key)
	local fallback = DefaultColor(key)
	if dbReady and type(PowerPlateDB) == "table" then
		local entry = PowerPlateDB[key]
		local color = entry and entry.color
		if type(color) == "table" and tonumber(color.r) and tonumber(color.g) and tonumber(color.b) then
			return color.r, color.g, color.b
		end
	end
	return fallback.r, fallback.g, fallback.b
end

local function StoreColor(key, r, g, b)
	local color = { r = r, g = g, b = b }
	if SameColor(color, DefaultColor(key)) then
		if type(PowerPlateDB) == "table" and type(PowerPlateDB[key]) == "table" then
			PowerPlateDB[key].color = nil
			PruneDB()
		end
		return
	end
	if type(PowerPlateDB) ~= "table" then
		PowerPlateDB = {}
	end
	if type(PowerPlateDB[key]) ~= "table" then
		PowerPlateDB[key] = {}
	end
	local saved = PowerPlateDB[key].color
	if type(saved) ~= "table" then
		saved = {}
		PowerPlateDB[key].color = saved
	end
	saved.r, saved.g, saved.b = r, g, b
end

local function HideOthers()
	if dbReady and type(PowerPlateDB) == "table" and type(PowerPlateDB.other) == "table" and type(PowerPlateDB.other.hide) == "boolean" then
		return PowerPlateDB.other.hide
	end
	return DEFAULT_HIDE_OTHERS
end

local function StoreHide(hide)
	if hide == DEFAULT_HIDE_OTHERS then
		if type(PowerPlateDB) == "table" and type(PowerPlateDB.other) == "table" then
			PowerPlateDB.other.hide = nil
			PruneDB()
		end
		return
	end
	if type(PowerPlateDB) ~= "table" then
		PowerPlateDB = {}
	end
	if type(PowerPlateDB.other) ~= "table" then
		PowerPlateDB.other = {}
	end
	PowerPlateDB.other.hide = hide
end

local function ColorForKind(kind)
	if kind == "party" then
		return CategoryColor("party")
	end
	if kind == "other" and not HideOthers() then
		return CategoryColor("other")
	end
end

local function IsSecret(value)
	return type(issecretvalue) == "function" and issecretvalue(value)
end

local function SafeString(value)
	if value == nil then
		return "nil"
	end
	if IsSecret(value) then
		return "<secret>"
	end
	local ok, text = pcall(tostring, value)
	if ok then
		return text
	end
	return "<unprintable>"
end

local function Log(msg)
	print("|cffFF69B4Power Plate:|r " .. SafeString(msg))
end

local WATCHED_CVARS = {
	"nameplateShowFriendlyPlayers",
	"nameplateShowOnlyNames",
	"nameplateShowOnlyNameForFriendlyPlayerUnits",
	"nameplateSimplifiedTypes",
	"nameplateShowAll",
	"UnitNameFriendlyPlayerName",
	"nameplateMinAlpha",
	"nameplateMaxAlpha",
	"nameplateSelectedAlpha",
	"nameplateNotSelectedAlpha",
	"nameplateOccludedAlphaMult",
}

local function ReadCVar(name)
	local getter = C_CVar and C_CVar.GetCVar or GetCVar
	if not getter then
		return nil
	end
	local ok, value = pcall(getter, name)
	if ok then
		return value
	end
	return nil
end

local function WriteCVar(name, value)
	local setter = C_CVar and C_CVar.SetCVar or SetCVar
	local current = ReadCVar(name)
	if not setter then
		Log(name .. "=" .. SafeString(current) .. " (no SetCVar)")
		return
	end
	if current == value then
		Log(name .. "=" .. SafeString(current) .. " already")
		return
	end
	local ok, err = pcall(setter, name, value)
	if ok then
		Log(name .. " " .. SafeString(current) .. " -> " .. value)
	else
		Log(name .. " " .. SafeString(current) .. " -> " .. value .. " FAILED " .. SafeString(err))
	end
end

local function PlateCount(includeForbidden)
	if not C_NamePlate or not C_NamePlate.GetNamePlates then
		return 0
	end
	local ok, plates = pcall(C_NamePlate.GetNamePlates, includeForbidden)
	if not ok or type(plates) ~= "table" then
		return 0
	end
	local count = 0
	for _ in pairs(plates) do
		count = count + 1
	end
	return count
end

local RefreshPlates
local PartyPlateSummary

local function LogPlateAvailability(reason)
	local openCount = PlateCount(false)
	local protectedCount = PlateCount(true)
	Log(reason .. " plates open=" .. openCount .. " protected=" .. protectedCount)
	for i = 1, #WATCHED_CVARS do
		local name = WATCHED_CVARS[i]
		Log(name .. "=" .. SafeString(ReadCVar(name)))
	end
	local partyExists = UnitExists("party1")
	if not IsSecret(partyExists) and partyExists then
		Log(PartyPlateSummary("party1"))
	end
	return openCount, protectedCount
end

local function FlattenDistanceAlpha()
	Log("The game fades nameplates by distance. Pinning that curve to fully opaque so party plates stay bright.")
	WriteCVar("nameplateMinAlpha", "1")
	WriteCVar("nameplateMaxAlpha", "1")
	WriteCVar("nameplateSelectedAlpha", "1")
	WriteCVar("nameplateNotSelectedAlpha", "1")
	WriteCVar("nameplateOccludedAlphaMult", "1")
end

local function EnableFriendlyNameplates()
	Log("The name over a player is 3D world text until friendly nameplates are on. Addons can color only the nameplate.")
	WriteCVar("nameplateShowFriendlyPlayers", "1")
	WriteCVar("nameplateShowOnlyNameForFriendlyPlayerUnits", "0")
	WriteCVar("nameplateSimplifiedTypes", "0")
	if C_Timer and C_Timer.After then
		C_Timer.After(0.5, function()
			LogPlateAvailability("after enabling friendly nameplates")
			RefreshPlates("after enabling friendly nameplates")
		end)
	end
end

local function Truthy(value)
	if IsSecret(value) then
		return nil
	end
	return not not value
end

local function SameUnit(a, b)
	local ok, same = pcall(UnitIsUnit, a, b)
	if ok then
		local truth = Truthy(same)
		if truth ~= nil then
			return truth
		end
	end
	local okA, guidA = pcall(UnitGUID, a)
	local okB, guidB = pcall(UnitGUID, b)
	if okA and okB and not IsSecret(guidA) and not IsSecret(guidB) and type(guidA) == "string" and type(guidB) == "string" then
		return guidA == guidB
	end
	return nil
end

local function InMyParty(unit)
	if IsSecret(unit) then
		return false, "unit <secret>"
	end
	if not unit or type(unit) ~= "string" then
		return false, "unit " .. SafeString(unit)
	end
	local ok, inParty = pcall(UnitInParty, unit)
	local partyTruth
	if ok then
		partyTruth = Truthy(inParty)
	end
	if partyTruth then
		return true, "UnitInParty"
	end
	local secretCompare = false
	local compared = 0
	for i = 1, 4 do
		local partyUnit = "party" .. i
		if Truthy(UnitExists(partyUnit)) then
			compared = compared + 1
			local same = SameUnit(unit, partyUnit)
			if same == nil then
				secretCompare = true
			elseif same then
				return true, "UnitIsUnit " .. partyUnit
			end
		end
	end
	if partyTruth == false then
		return false, "not in party"
	end
	if compared > 0 and not secretCompare then
		return false, "not in party"
	end
	return false, "party check secret"
end

local function Classify(unit)
	if IsSecret(unit) or type(unit) ~= "string" then
		return "unknown", "unit " .. SafeString(unit)
	end
	local isSelf = SameUnit(unit, "player")
	if isSelf then
		return "self", "you"
	end
	if isSelf == nil then
		return "unknown", "you check secret"
	end
	local inParty, why = InMyParty(unit)
	if inParty then
		return "party", why
	end
	if why == "party check secret" then
		return "unknown", why
	end
	local isPlayer = UnitIsPlayer(unit)
	if Truthy(isPlayer) == nil then
		return "unknown", "UnitIsPlayer secret"
	end
	if Truthy(isPlayer) then
		return "other", why
	end
	return "npc", "not a player"
end

local function TokenOnPlate(plate)
	if not plate then
		return nil
	end
	local forbiddenOk, forbidden = pcall(function()
		return plate.IsForbidden and plate:IsForbidden()
	end)
	if forbiddenOk and forbidden then
		return nil, "forbidden"
	end
	local tokenOk, token = pcall(function()
		return plate.namePlateUnitToken
	end)
	if tokenOk and not IsSecret(token) and type(token) == "string" then
		return token
	end
	local frameOk, frame = pcall(function()
		return plate.UnitFrame
	end)
	if frameOk and frame then
		local unitOk, unit = pcall(function()
			return frame.unit
		end)
		if unitOk and not IsSecret(unit) and type(unit) == "string" then
			return unit
		end
		if unitOk and IsSecret(unit) then
			return nil, "secret"
		end
	end
	if tokenOk and IsSecret(token) then
		return nil, "secret"
	end
	return nil, "no unit"
end

function PartyPlateSummary(partyUnit)
	if not C_NamePlate or not C_NamePlate.GetNamePlates then
		return partyUnit .. " plate=none (no api)"
	end
	local function Scan(includeForbidden)
		local ok, plates = pcall(C_NamePlate.GetNamePlates, includeForbidden)
		if not ok or type(plates) ~= "table" then
			return nil, ok and "no list" or SafeString(plates)
		end
		local note
		for _, plate in pairs(plates) do
			local token, tokenNote = TokenOnPlate(plate)
			if token then
				local same = SameUnit(token, partyUnit)
				if same then
					return token
				end
				if same == nil then
					note = "secret"
				end
			elseif tokenNote == "secret" or tokenNote == "forbidden" then
				note = tokenNote
			end
		end
		return nil, note
	end
	local openToken, openNote = Scan(false)
	local anyToken, anyNote = Scan(true)
	if openToken then
		return partyUnit .. " is " .. openToken .. " (open)"
	end
	if anyToken then
		return partyUnit .. " is " .. anyToken .. " (protected)"
	end
	local note = openNote or anyNote
	if note then
		return partyUnit .. " plate=none (" .. note .. ")"
	end
	return partyUnit .. " plate=none"
end

local function PlateFor(frame, unit)
	if frame and frame.namePlateFrame and not (frame.namePlateFrame.IsForbidden and frame.namePlateFrame:IsForbidden()) then
		return frame.namePlateFrame
	end
	if unit and not IsSecret(unit) and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
		local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit, false)
		if ok then
			return plate
		end
	end
end

local function PlateUnit(plate)
	local unit = plate.namePlateUnitToken
	if IsSecret(unit) or unit == nil then
		local frame = plate.UnitFrame
		unit = frame and frame.unit
	end
	return unit
end

local function FindUnit(widget)
	local node = widget
	for _ = 1, 6 do
		if not node then
			return nil
		end
		local candidate = node.unit
		if not IsSecret(candidate) and type(candidate) == "string" then
			return candidate
		end
		if not node.GetParent then
			return nil
		end
		node = node:GetParent()
	end
	return nil
end

local function HealthBar(frame)
	if frame.healthBar then
		return frame.healthBar
	end
	local container = frame.HealthBarsContainer
	if container and container.healthBar then
		return container.healthBar
	end
end

local function ApplyName(fs)
	if not fs or fs.PowerPlateApplying then
		return
	end
	local r, g, b = ColorForKind(Classify(FindUnit(fs)))
	if not r then
		return
	end
	fs.PowerPlateApplying = true
	fs:SetTextColor(r, g, b, 1)
	fs.PowerPlateApplying = false
end

local function ApplyBar(bar)
	if not bar or bar.PowerPlateApplying then
		return
	end
	local r, g, b = ColorForKind(Classify(FindUnit(bar)))
	if not r then
		return
	end
	bar.PowerPlateApplying = true
	bar:SetStatusBarColor(r, g, b)
	bar.PowerPlateApplying = false
end

local function LockName(fs)
	if not fs or fs.PowerPlateLocked then
		return false
	end
	fs.PowerPlateLocked = true
	hooksecurefunc(fs, "SetVertexColor", function(self)
		if self.PowerPlateApplying then
			return
		end
		local unit = FindUnit(self)
		local kind = Classify(unit)
		if not ColorForKind(kind) then
			return
		end
		ApplyName(self)
		if not self.PowerPlateRecolorLogged then
			self.PowerPlateRecolorLogged = true
			Log("held " .. SafeString(unit) .. " name on the " .. kind .. " color")
		end
	end)
	return true
end

local function LockBar(bar)
	if not bar or bar.PowerPlateLocked or not bar.SetStatusBarColor then
		return false
	end
	bar.PowerPlateLocked = true
	hooksecurefunc(bar, "SetStatusBarColor", function(self)
		if self.PowerPlateApplying then
			return
		end
		local unit = FindUnit(self)
		local kind = Classify(unit)
		if not ColorForKind(kind) then
			return
		end
		ApplyBar(self)
		if not self.PowerPlateRecolorLogged then
			self.PowerPlateRecolorLogged = true
			Log("held " .. SafeString(unit) .. " health bar on the " .. kind .. " color")
		end
	end)
	return true
end

local function FrameShown(frame)
	if not frame or not frame.IsShown then
		return nil
	end
	local ok, shown = pcall(frame.IsShown, frame)
	if ok then
		return shown
	end
	return nil
end

local function ApplyHidden(frame, hidden)
	if not frame or frame.PowerPlateApplying or not frame.Hide or not frame.Show then
		return false, "no frame"
	end
	frame.PowerPlateApplying = true
	local ok, err = true, nil
	if hidden then
		local shown = FrameShown(frame)
		local scaleOk, scale = true, nil
		if frame.GetScale then
			scaleOk, scale = pcall(frame.GetScale, frame)
		end
		local alreadyHidden = frame.PowerPlateHidden and Truthy(shown) == false and shown ~= nil
		local alreadyTiny = scaleOk and type(scale) == "number" and scale <= 0.01
		if alreadyHidden and alreadyTiny then
			frame.PowerPlateApplying = false
			return true
		end
		if not frame.PowerPlateScale and frame.SetScale then
			if scaleOk and type(scale) == "number" and scale > 0.01 then
				frame.PowerPlateScale = scale
			else
				frame.PowerPlateScale = 1
			end
		end
		local scaled = alreadyTiny
		if frame.SetScale and not alreadyTiny then
			scaled = pcall(frame.SetScale, frame, 0.001)
		end
		if not alreadyHidden then
			ok, err = pcall(frame.Hide, frame)
		end
		if alreadyHidden or ok or scaled then
			frame.PowerPlateHidden = true
			ok = true
		end
	elseif frame.PowerPlateHidden then
		if frame.SetScale and frame.PowerPlateScale then
			pcall(frame.SetScale, frame, frame.PowerPlateScale)
			frame.PowerPlateScale = nil
		end
		ok, err = pcall(frame.Show, frame)
		if ok then
			frame.PowerPlateHidden = nil
		end
	end
	frame.PowerPlateApplying = false
	return ok, err
end

local function LockHidden(plate, frame)
	local hooked = false
	if frame and not frame.PowerPlateHideLocked and frame.Show then
		frame.PowerPlateHideLocked = true
		hooked = true
		hooksecurefunc(frame, "Show", function(self)
			if self.PowerPlateApplying then
				return
			end
			local unit = self.unit
			if IsSecret(unit) or type(unit) ~= "string" then
				unit = FindUnit(self)
			end
			if Classify(unit) ~= "other" or not HideOthers() then
				return
			end
			ApplyHidden(self, true)
		end)
		if frame.SetScale then
			hooksecurefunc(frame, "SetScale", function(self)
				if self.PowerPlateApplying or self.PowerPlateKind ~= "other" or not HideOthers() then
					return
				end
				ApplyHidden(self, true)
			end)
		end
	end
	if plate and not plate.PowerPlateHideWatch and plate.HookScript then
		plate.PowerPlateHideWatch = true
		hooked = true
		plate:HookScript("OnUpdate", function(self)
			local child = self.UnitFrame
			if not child or (child.IsForbidden and child:IsForbidden()) then
				return
			end
			local kind = Classify(PlateUnit(self))
			self.PowerPlateKind = kind
			child.PowerPlateKind = kind
			local hideOther = kind == "other" and HideOthers()
			if hideOther then
				ApplyHidden(child, true)
			elseif child.PowerPlateHidden and (kind == "party" or kind == "npc" or kind == "self" or kind == "other") then
				ApplyHidden(child, false)
			end
		end)
	end
	return hooked
end

local function Paint(plate, frame, unit, reason, quiet)
	if not frame or (frame.IsForbidden and frame:IsForbidden()) then
		if not quiet then
			Log(SafeString(unit) .. " skipped (" .. reason .. "): frame forbidden or missing")
		end
		return
	end
	local liveUnit = frame.unit
	if not IsSecret(liveUnit) and type(liveUnit) == "string" then
		unit = liveUnit
	end
	local kind, why = Classify(unit)
	local name = frame.name
	local bar = HealthBar(frame)
	plate = plate or PlateFor(frame, unit)
	frame.PowerPlateKind = kind
	if plate then
		plate.PowerPlateKind = kind
	end
	if not quiet then
		if name then
			name.PowerPlateRecolorLogged = nil
		end
		if bar then
			bar.PowerPlateRecolorLogged = nil
		end
	end
	local nameHooked, barHooked, hideHooked = false, false, false
	local hiddenNote = "hidden=no"
	local hideOther = kind == "other" and HideOthers()
	local colorThis = kind == "party" or (kind == "other" and not HideOthers())
	if frame.PowerPlateHidden and (kind == "party" or kind == "npc" or kind == "self" or colorThis) then
		local ok, err = ApplyHidden(frame, false)
		if ok then
			hiddenNote = "hidden=restored"
		else
			Log(SafeString(unit) .. " show error: " .. SafeString(err))
			hiddenNote = "hidden=error"
		end
	end
	if colorThis then
		if name then
			nameHooked = LockName(name)
			local ok, err = pcall(ApplyName, name)
			if not ok then
				Log(SafeString(unit) .. " name color error: " .. SafeString(err))
			end
		end
		if bar then
			barHooked = LockBar(bar)
			local ok, err = pcall(ApplyBar, bar)
			if not ok then
				Log(SafeString(unit) .. " bar color error: " .. SafeString(err))
			end
		end
	end
	if kind == "other" then
		hideHooked = LockHidden(plate, frame)
		if hideOther then
			local ok, err = ApplyHidden(frame, true)
			if ok then
				hiddenNote = "hidden=yes"
			else
				Log(SafeString(unit) .. " hide error: " .. SafeString(err))
				hiddenNote = "hidden=error"
			end
		end
	end
	if not quiet then
		local action = "skip"
		if kind == "party" or (kind == "other" and not hideOther) then
			action = "COLOR"
		elseif kind == "other" then
			action = "HIDE"
		end
		Log(string.format(
			"%s %s via %s | %s | name=%s hooked=%s | bar=%s hooked=%s | hideHook=%s",
			SafeString(unit),
			action,
			why,
			hiddenNote,
			name and "yes" or "no",
			nameHooked and "new" or (name and name.PowerPlateLocked and "already" or "no"),
			bar and "yes" or "no",
			barHooked and "new" or (bar and bar.PowerPlateLocked and "already" or "no"),
			hideHooked and "new" or (frame.PowerPlateHideLocked and "already" or "no")
		))
	end
end

local function EachPlate(visitor)
	if not C_NamePlate or not C_NamePlate.GetNamePlates then
		Log("C_NamePlate.GetNamePlates is missing")
		return
	end
	local plates = C_NamePlate.GetNamePlates()
	local count = 0
	for _, plate in pairs(plates) do
		count = count + 1
		local frame = plate.UnitFrame
		local unit = plate.namePlateUnitToken
		if IsSecret(unit) or unit == nil then
			unit = frame and frame.unit
		end
		visitor(plate, frame, unit)
	end
	return count
end

function RefreshPlates(reason, quiet)
	local count = EachPlate(function(plate, frame, unit)
		if frame and not (frame.IsForbidden and frame:IsForbidden()) then
			Paint(plate, frame, unit, reason, quiet)
		elseif not quiet then
			Log(SafeString(unit) .. " skipped (" .. reason .. "): no modifiable unit frame")
		end
	end)
	if not quiet then
		Log(reason .. ", visible plates " .. SafeString(count))
	end
end

local hookedName, hookedClass

local function OnNameUpdate(frame)
	if not frame or (frame.IsForbidden and frame:IsForbidden()) then
		return
	end
	local unit = frame.unit
	if IsSecret(unit) or type(unit) ~= "string" or not unit:find("^nameplate%d+") then
		return
	end
	Paint(nil, frame, unit, "name update", true)
end

local function EnsureHooks()
	if not hookedName and type(CompactUnitFrame_UpdateName) == "function" then
		hooksecurefunc("CompactUnitFrame_UpdateName", OnNameUpdate)
		hookedName = true
		Log("hooked CompactUnitFrame_UpdateName")
	end
	if not hookedClass and type(NamePlateUnitFrameMixin) == "table" and type(NamePlateUnitFrameMixin.UpdateNameClassColor) == "function" then
		hooksecurefunc(NamePlateUnitFrameMixin, "UpdateNameClassColor", OnNameUpdate)
		hookedClass = true
		Log("hooked NamePlateUnitFrameMixin:UpdateNameClassColor")
	end
end

local optionsBuilt = false
local optionsPanel

local function RefreshOptionsPanel()
	local panel = optionsPanel
	if not panel then
		return
	end
	local partyR, partyG, partyB = CategoryColor("party")
	panel.partySwatch:SetColorTexture(partyR, partyG, partyB, 1)
	local otherR, otherG, otherB = CategoryColor("other")
	panel.otherSwatch:SetColorTexture(otherR, otherG, otherB, 1)
	panel.hideOthers:SetChecked(HideOthers())
end

local function OpenColorPicker(key)
	local r, g, b = CategoryColor(key)
	local previous = { r = r, g = g, b = b }
	local function Apply(nr, ng, nb)
		StoreColor(key, nr, ng, nb)
		RefreshOptionsPanel()
		RefreshPlates("options", true)
	end
	local info = {
		r = r,
		g = g,
		b = b,
		hasOpacity = false,
		swatchFunc = function()
			local nr, ng, nb = ColorPickerFrame:GetColorRGB()
			Apply(nr, ng, nb)
		end,
		cancelFunc = function(prev)
			local source = type(prev) == "table" and prev or previous
			Apply(source.r or previous.r, source.g or previous.g, source.b or previous.b)
		end,
	}
	if ColorPickerFrame.SetupColorPickerAndShow then
		ColorPickerFrame:SetupColorPickerAndShow(info)
		return
	end
	ColorPickerFrame.func = info.swatchFunc
	ColorPickerFrame.cancelFunc = info.cancelFunc
	ColorPickerFrame.hasOpacity = false
	ColorPickerFrame.previousValues = previous
	ColorPickerFrame:SetColorRGB(r, g, b)
	ColorPickerFrame:Show()
end

local function BuildOptions()
	if optionsBuilt or not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
		if not optionsBuilt then
			Log("Settings API is missing, so there is no AddOns page")
		end
		return
	end
	EnsureDB()
	local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
	local panel = CreateFrame("Frame", nil, UIParent)
	panel:Hide()
	optionsPanel = panel
	local function Label(parent, text, x, y, size, width)
		local line = parent:CreateFontString(nil, "OVERLAY")
		line:SetFont(font, size or 12, "")
		line:SetTextColor(0.94, 0.92, 0.85)
		line:SetJustifyH("LEFT")
		line:SetPoint("TOPLEFT", x, y)
		line:SetWidth(width or 460)
		line:SetText(text)
		return line
	end
	local function Rule(y)
		local line = panel:CreateTexture(nil, "ARTWORK")
		line:SetColorTexture(0.55, 0.5, 0.38, 0.9)
		line:SetPoint("TOPLEFT", 16, y)
		line:SetSize(480, 1)
	end
	local function ColorRow(key, swatchKey, y)
		local swatch = panel:CreateTexture(nil, "OVERLAY")
		swatch:SetPoint("TOPLEFT", 16, y)
		swatch:SetSize(22, 22)
		panel[swatchKey] = swatch
		local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		button:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
		button:SetSize(80, 22)
		button:SetText("Color")
		button:SetScript("OnClick", function()
			OpenColorPicker(key)
		end)
	end
	Label(panel, "Power Plate", 16, -16, 16, 530)
	Rule(-44)
	Label(panel, "Party", 16, -56, 14, 460)
	ColorRow("party", "partySwatch", -82)
	Rule(-118)
	Label(panel, "Other Players", 16, -130, 14, 460)
	ColorRow("other", "otherSwatch", -156)
	local hide = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	hide:SetPoint("TOPLEFT", 16, -192)
	hide:SetSize(26, 26)
	panel.hideOthers = hide
	local caption = Label(hide, "Hide", 0, 0, 12, 420)
	caption:ClearAllPoints()
	caption:SetPoint("LEFT", hide, "RIGHT", 4, 0)
	hide:SetScript("OnClick", function(self)
		StoreHide(self:GetChecked() == true)
		RefreshPlates("options")
	end)
	panel:SetScript("OnShow", RefreshOptionsPanel)
	RefreshOptionsPanel()
	local category = Settings.RegisterCanvasLayoutCategory(panel, "Power Plate")
	Settings.RegisterAddOnCategory(category)
	optionsBuilt = true
end

local function Dump()
	Log("dump v" .. VERSION)
	Log("CompactUnitFrame_UpdateName hook=" .. (hookedName and "yes" or "no")
		.. " UpdateNameClassColor hook=" .. (hookedClass and "yes" or "no"))
	local partyCount = 0
	for i = 1, 4 do
		local partyUnit = "party" .. i
		if Truthy(UnitExists(partyUnit)) then
			partyCount = partyCount + 1
			Log(partyUnit .. " exists")
		end
	end
	Log("party members besides you: " .. partyCount)
	FlattenDistanceAlpha()
	local openCount, protectedCount = LogPlateAvailability("dump")
	if openCount == 0 and protectedCount == 0 then
		EnableFriendlyNameplates()
	elseif openCount == 0 then
		Log("Friendly plates are protected here, so addons cannot recolor them.")
	end
	RefreshPlates("dump")
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == "PowerPlate" then
			EnsureDB()
			BuildOptions()
			Log("file loaded v" .. VERSION)
		end
		EnsureHooks()
	elseif event == "PLAYER_LOGIN" then
		EnsureDB()
		BuildOptions()
		EnsureHooks()
		Log("ready v" .. VERSION .. ". Options: Escape, Options, AddOns, Power Plate. /powerplate dumps.")
		FlattenDistanceAlpha()
		local openCount, protectedCount = LogPlateAvailability("login")
		if openCount == 0 and protectedCount == 0 then
			EnableFriendlyNameplates()
		elseif openCount == 0 then
			Log("Friendly plates are protected here, so addons cannot recolor them.")
		end
		RefreshPlates("login")
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		EnsureHooks()
		local plate = C_NamePlate.GetNamePlateForUnit(arg1)
		if not plate then
			Log(SafeString(arg1) .. " added, but GetNamePlateForUnit returned nothing (often a protected friendly plate)")
			return
		end
		Paint(plate, plate.UnitFrame, arg1, "added")
	elseif event == "GROUP_ROSTER_UPDATE" then
		local openCount = PlateCount(false)
		if openCount == 0 and PlateCount(true) == 0 then
			EnableFriendlyNameplates()
		end
		RefreshPlates("group update")
	end
end)

SLASH_POWERPLATE1 = "/powerplate"
SLASH_POWERPLATE2 = "/pp"
SlashCmdList.POWERPLATE = Dump

EnsureHooks()
