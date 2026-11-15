local ns = select(2, ...)
local VERSION = ns.VERSION or "?"
local PARTY_COLOR = { r = 1, g = 105 / 255, b = 180 / 255 }
local RAID_COLOR = { r = 80 / 255, g = 140 / 255, b = 1 }
local GUILD_COLOR = { r = 80 / 255, g = 200 / 255, b = 120 / 255 }
local FRIEND_COLOR = { r = 1, g = 176 / 255, b = 64 / 255 }
local RECENT_COLOR = { r = 83 / 255, g = 201 / 255, b = 1 }
local OTHER_COLOR = { r = 99 / 255, g = 99 / 255, b = 99 / 255 }
local CATEGORIES = {
	{ key = "party", label = "Party", color = PARTY_COLOR, hide = false, colorTip = "Defines the nameplate color for players in your party.", hideTip = "Hides nameplates for players in your party." },
	{ key = "raid", label = "Raid", color = RAID_COLOR, hide = false, colorTip = "Defines the nameplate color for other players in your raid.", hideTip = "Hides nameplates for other players in your raid." },
	{ key = "guild", label = "Guild", color = GUILD_COLOR, hide = false, colorTip = "Defines the nameplate color for guild members.", hideTip = "Hides nameplates for guild members." },
	{ key = "friend", label = "Friends", color = FRIEND_COLOR, hide = false, colorTip = "Defines the nameplate color for friends.", hideTip = "Hides nameplates for friends." },
	{ key = "recent", label = "Recent Allies", color = RECENT_COLOR, hide = false, colorTip = "Defines the nameplate color for recent allies.", hideTip = "Hides nameplates for recent allies." },
	{ key = "other", label = "Other Players", color = OTHER_COLOR, hide = true, colorTip = "Defines the nameplate color for every other player.", hideTip = "Hides nameplates for every other player." },
}
local dbReady = false

local function CategoryByKey(key)
	for i = 1, #CATEGORIES do
		if CATEGORIES[i].key == key then
			return CATEGORIES[i]
		end
	end
end

local function DefaultColor(key)
	local category = CategoryByKey(key)
	if category then
		return category.color
	end
	return OTHER_COLOR
end

local function DefaultHide(key)
	local category = CategoryByKey(key)
	return category and category.hide or false
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
	for i = 1, #CATEGORIES do
		local key = CATEGORIES[i].key
		local entry = PowerPlateDB[key]
		if type(entry) == "table" and entry.color == nil and entry.hide == nil and next(entry) == nil then
			PowerPlateDB[key] = nil
		end
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

local function CategoryHidden(key)
	if not CategoryByKey(key) then
		return false
	end
	if dbReady and type(PowerPlateDB) == "table" and type(PowerPlateDB[key]) == "table" and type(PowerPlateDB[key].hide) == "boolean" then
		return PowerPlateDB[key].hide
	end
	return DefaultHide(key)
end

local function StoreHide(key, hide)
	if hide == DefaultHide(key) then
		if type(PowerPlateDB) == "table" and type(PowerPlateDB[key]) == "table" then
			PowerPlateDB[key].hide = nil
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
	PowerPlateDB[key].hide = hide
end

local function DebugEnabled()
	return type(PowerPlateDB) == "table" and PowerPlateDB.debug == true
end

local function StoreDebug(enabled)
	if not enabled then
		if type(PowerPlateDB) == "table" then
			PowerPlateDB.debug = nil
			PruneDB()
		end
		return
	end
	if type(PowerPlateDB) ~= "table" then
		PowerPlateDB = {}
	end
	PowerPlateDB.debug = true
end

local function ColorForKind(kind)
	if CategoryByKey(kind) and not CategoryHidden(kind) then
		return CategoryColor(kind)
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
	if not DebugEnabled() then
		return
	end
	print("|cffFF69B4Power Plate:|r " .. SafeString(msg))
end

local WATCHED_CVARS = {
	"nameplateShowFriendlyPlayers",
	"nameplateShowOnlyNames",
	"nameplateShowOnlyNameForFriendlyPlayerUnits",
	"nameplateSimplifiedTypes",
	"nameplateShowAll",
	"UnitNameFriendlyPlayerName",
	"UnitNameFriendlyPetName",
	"UnitNameEnemyPetName",
	"nameplateShowFriendlyPets",
	"nameplateShowEnemyPets",
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

local function EnablePetNameplates()
	Log("Pet names are world text until pet nameplates are on. A pet plate then follows its owner.")
	WriteCVar("nameplateShowFriendlyPets", "1")
	WriteCVar("nameplateShowEnemyPets", "1")
	WriteCVar("UnitNameFriendlyPetName", "0")
	WriteCVar("UnitNameEnemyPetName", "0")
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

local function CallTruthy(func, ...)
	if type(func) ~= "function" then
		return false
	end
	local ok, value = pcall(func, ...)
	if not ok then
		return false
	end
	return Truthy(value)
end

local function InRaidGroup()
	return CallTruthy(IsInRaid) == true
end

local function GroupCount()
	if type(GetNumGroupMembers) ~= "function" then
		return 0
	end
	local ok, count = pcall(GetNumGroupMembers)
	if ok and type(count) == "number" and count > 0 then
		return count
	end
	return 0
end

local function SelectionType(unit)
	if type(UnitSelectionType) ~= "function" then
		return false, nil
	end
	local ok, value = pcall(UnitSelectionType, unit, true)
	if not ok then
		return false, nil
	end
	if IsSecret(value) then
		return true, nil
	end
	return false, tonumber(value)
end

local function FriendByName(unit)
	if not (C_FriendList and type(C_FriendList.GetFriendInfo) == "function") then
		return false
	end
	local ok, name, server = pcall(UnitName, unit)
	if not ok or IsSecret(name) or type(name) ~= "string" or name == "" then
		return nil
	end
	if IsSecret(server) then
		server = nil
	end
	local function Lookup(query)
		local found, info = pcall(C_FriendList.GetFriendInfo, query)
		if not found or IsSecret(info) then
			return nil
		end
		if type(info) == "table" and (type(canaccesstable) ~= "function" or canaccesstable(info)) then
			return true
		end
		return false
	end
	local queries = { name }
	if type(server) == "string" and server ~= "" then
		queries[#queries + 1] = name .. "-" .. server
	end
	local sawSecret = false
	for i = 1, #queries do
		local matched = Lookup(queries[i])
		if matched == nil then
			sawSecret = true
		elseif matched then
			return true
		end
	end
	if sawSecret then
		return nil
	end
	return false
end

local function PetGuid(unit)
	if type(UnitGUID) ~= "function" then
		return false, nil
	end
	local ok, guid = pcall(UnitGUID, unit)
	if not ok then
		return false, nil
	end
	if IsSecret(guid) then
		return true, nil
	end
	if type(guid) == "string" and guid:find("^Pet%-") then
		return false, true
	end
	return false, false
end

-- A pet uses its owner's category. UnitInParty is true for raid members here, so a player
-- is Party only for party1-4, or for UnitInSubgroup while they are outside a raid.
local function PetOwner(unit)
	local yours = SameUnit(unit, "pet")
	if yours == true then
		return "player", "your pet"
	end
	local otherPet = CallTruthy(UnitIsOtherPlayersPet, unit)
	local guidSecret, guidPet = PetGuid(unit)
	local controlled = CallTruthy(UnitPlayerControlled, unit)
	local confirmed = otherPet == true or guidPet == true
	local possible = confirmed or controlled == true or yours == nil or otherPet == nil or guidSecret or controlled == nil
	if not possible then
		return false
	end
	local sawSecret = yours == nil or otherPet == nil or guidSecret or controlled == nil
	local function SameToken(token)
		if not Truthy(UnitExists(token)) then
			return false
		end
		local same = SameUnit(unit, token)
		if same == nil then
			sawSecret = true
			return false
		end
		return same
	end
	for i = 1, 4 do
		if SameToken("partypet" .. i) then
			return "party" .. i, "partypet" .. i
		end
	end
	if InRaidGroup() then
		local count = GroupCount()
		for i = 1, count do
			if SameToken("raidpet" .. i) then
				return "raid" .. i, "raidpet" .. i
			end
		end
	end
	if type(UnitOwnerGUID) == "function" and type(UnitTokenFromGUID) == "function" then
		local ok, guid = pcall(UnitOwnerGUID, unit)
		if ok and IsSecret(guid) then
			sawSecret = true
		elseif ok and type(guid) == "string" then
			local tokenOk, token = pcall(UnitTokenFromGUID, guid)
			if tokenOk and IsSecret(token) then
				sawSecret = true
			elseif tokenOk and type(token) == "string" and token ~= "" then
				return token, "UnitOwnerGUID"
			end
		end
	end
	local function Consider(candidate)
		if type(candidate) ~= "string" or candidate == unit or IsSecret(candidate) then
			return nil
		end
		local owns = CallTruthy(UnitIsOwnerOrControllerOfUnit, candidate, unit)
		if owns == nil then
			sawSecret = true
			return nil
		end
		if owns then
			return candidate
		end
	end
	local owner = Consider("player")
	if owner then
		return owner, "player owns"
	end
	for i = 1, 4 do
		owner = Consider("party" .. i)
		if owner then
			return owner, "party" .. i .. " owns"
		end
	end
	if InRaidGroup() then
		local count = GroupCount()
		for i = 1, count do
			owner = Consider("raid" .. i)
			if owner then
				return owner, "raid" .. i .. " owns"
			end
		end
	end
	if C_NamePlate and C_NamePlate.GetNamePlates then
		local ok, plates = pcall(C_NamePlate.GetNamePlates, false)
		if ok and type(plates) == "table" then
			for _, plate in pairs(plates) do
				local token = plate.namePlateUnitToken
				if IsSecret(token) or type(token) ~= "string" then
					local frame = plate.UnitFrame
					token = frame and frame.unit
				end
				if type(token) == "string" and not IsSecret(token) then
					local same = SameUnit(token, unit)
					if same == nil then
						sawSecret = true
					elseif not same then
						owner = Consider(token)
						if owner then
							return owner, "nameplate owns"
						end
					end
				end
			end
		end
	end
	local minion = CallTruthy(UnitIsMinion, unit)
	if not (confirmed or controlled == true or minion == true) then
		return false
	end
	return nil, "unowned pet"
end

local function Classify(unit, depth)
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
	local isPlayer = CallTruthy(UnitIsPlayer, unit)
	if isPlayer ~= true and (depth or 0) == 0 then
		local owner, ownerWhy = PetOwner(unit)
		if owner and SameUnit(owner, unit) ~= true then
			local kind, why = Classify(owner, 1)
			return kind, "pet of " .. owner .. " via " .. ownerWhy .. " (" .. why .. ")"
		end
		if owner == nil then
			if ownerWhy == "unowned pet" or ownerWhy == "pet owner secret" then
				return "other", ownerWhy
			end
			return "unknown", ownerWhy
		end
	end
	if isPlayer == nil then
		return "unknown", "UnitIsPlayer secret"
	end
	if not isPlayer then
		return "npc", "not a player"
	end
	local partySecret = false
	for i = 1, 4 do
		local partyUnit = "party" .. i
		if Truthy(UnitExists(partyUnit)) then
			local same = SameUnit(unit, partyUnit)
			if same == nil then
				partySecret = true
			elseif same then
				return "party", "UnitIsUnit " .. partyUnit
			end
		end
	end
	if partySecret then
		return "unknown", "party check secret"
	end
	local raid = CallTruthy(UnitPlayerOrPetInRaid, unit)
	if raid == nil then
		return "unknown", "raid check secret"
	end
	if not raid then
		local subgroup = CallTruthy(UnitInSubgroup, unit)
		if subgroup == nil then
			return "unknown", "subgroup check secret"
		end
		if subgroup then
			return "party", "UnitInSubgroup"
		end
	elseif raid then
		return "raid", "UnitPlayerOrPetInRaid"
	end
	local guild = CallTruthy(UnitIsInMyGuild, unit)
	if guild == nil then
		return "unknown", "guild check secret"
	end
	if guild then
		return "guild", "UnitIsInMyGuild"
	end
	local selectionSecret, selection = SelectionType(unit)
	if selectionSecret then
		return "unknown", "selection type secret"
	end
	local friendNamed = FriendByName(unit)
	if selection == 8 or friendNamed == true then
		return "friend", selection == 8 and "selection 8" or "GetFriendInfo"
	end
	if selection == 16 then
		return "recent", "selection 16"
	end
	return "other", "player"
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
			local kind = Classify(unit)
			if CategoryByKey(kind) and CategoryHidden(kind) then
				ApplyHidden(self, true)
			end
		end)
		if frame.SetScale then
			hooksecurefunc(frame, "SetScale", function(self)
				if self.PowerPlateApplying then
					return
				end
				local kind = self.PowerPlateKind
				if CategoryByKey(kind) and CategoryHidden(kind) then
					ApplyHidden(self, true)
				end
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
			local unit = PlateUnit(self)
			local kind = Classify(unit)
			local previous = child.PowerPlateKind
			self.PowerPlateKind = kind
			child.PowerPlateKind = kind
			if kind ~= previous then
				Paint(self, child, unit, "category change", true)
				return
			end
			if CategoryByKey(kind) and CategoryHidden(kind) then
				ApplyHidden(child, true)
			elseif child.PowerPlateHidden and (kind == "npc" or kind == "self" or CategoryByKey(kind)) then
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
	local hideThis = CategoryByKey(kind) ~= nil and CategoryHidden(kind)
	local colorThis = CategoryByKey(kind) ~= nil and not hideThis
	if frame.PowerPlateHidden and (kind == "npc" or kind == "self" or colorThis) then
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
	hideHooked = LockHidden(plate, frame)
	if hideThis then
		local ok, err = ApplyHidden(frame, true)
		if ok then
			hiddenNote = "hidden=yes"
		else
			Log(SafeString(unit) .. " hide error: " .. SafeString(err))
			hiddenNote = "hidden=error"
		end
	end
	if not quiet then
		local action = "skip"
		if colorThis then
			action = "COLOR"
		elseif hideThis then
			action = "HIDE"
		end
		local _, selection = SelectionType(unit)
		Log(string.format(
			"%s %s via %s | %s | select=%s | name=%s hooked=%s | bar=%s hooked=%s | hideHook=%s",
			SafeString(unit),
			action,
			why,
			hiddenNote,
			SafeString(selection),
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
	if not panel or not panel.rows then
		return
	end
	for i = 1, #CATEGORIES do
		local key = CATEGORIES[i].key
		local row = panel.rows[key]
		if row then
			local r, g, b = CategoryColor(key)
			row.swatch:SetColorRGB(r, g, b)
			row.hide:SetChecked(CategoryHidden(key))
		end
	end
	if panel.debug then
		panel.debug:SetChecked(DebugEnabled())
	end
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

local function ShowOptionsTooltip(owner, title, text)
	if not (SettingsTooltip and Settings and Settings.InitTooltip) then
		return
	end
	SettingsTooltip:SetOwner(owner, "ANCHOR_RIGHT", 0, 0)
	Settings.InitTooltip(title, text)
	SettingsTooltip:Show()
end

local function HideOptionsTooltip()
	if SettingsTooltip then
		SettingsTooltip:Hide()
	end
end

local function CellText(parent, text)
	local line = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	line:SetPoint("LEFT", 0, 0)
	line:SetJustifyH("LEFT")
	line:SetText(text)
	return line
end

local function BuildOptions()
	if optionsBuilt or not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
		if not optionsBuilt then
			Log("Settings API is missing, so there is no AddOns page")
		end
		return
	end
	EnsureDB()
	local panel = CreateFrame("Frame", nil, UIParent)
	panel:Hide()
	optionsPanel = panel
	local list = CreateFrame("Frame", nil, panel, "SettingsListTemplate")
	list:SetAllPoints(panel)
	list.Header.Title:SetText("Power Plate v" .. VERSION)
	list.Header.DefaultsButton:Hide()
	list.Header.TutorialButton:Hide()
	list.ScrollBox:Hide()
	list.ScrollBox:EnableMouse(false)
	list.ScrollBox:SetAlpha(0)
	list.ScrollBar:Hide()
	list.ScrollBar:EnableMouse(false)
	local rows = CreateFrame("Frame", nil, list, "StaticGridLayoutFrame")
	rows:SetPoint("TOPLEFT", list.Header, "BOTTOMLEFT", 7, -12)
	rows:SetFrameLevel(list.ScrollBox:GetFrameLevel() + 20)
	rows:SetSize(520, 320)
	rows.childXPadding = 36
	rows.childYPadding = 6
	rows:Show()
	local function Place(cell, column, row, width)
		cell.gridColumn = column
		cell.gridRow = row
		cell.includeAsLayoutChildWhenHidden = true
		cell:SetSize(width, 32)
		cell:Show()
	end
	panel.rows = {}
	for i = 1, #CATEGORIES do
		local category = CATEGORIES[i]
		local key = category.key
		local nameCell = CreateFrame("Frame", nil, rows)
		Place(nameCell, 1, i, 150)
		local nameText = CellText(nameCell, category.label)
		nameCell:EnableMouse(true)
		nameCell:SetScript("OnEnter", function(self)
			ShowOptionsTooltip(self, category.label, category.colorTip)
		end)
		nameCell:SetScript("OnLeave", HideOptionsTooltip)
		local colorCell = CreateFrame("Frame", nil, rows)
		Place(colorCell, 2, i, 110)
		local colorText = CellText(colorCell, "Color")
		local swatch = CreateFrame("Button", nil, colorCell, "SettingsColorSwatchTemplate")
		swatch:SetPoint("LEFT", colorText, "RIGHT", 8, 0)
		swatch:SetTooltipFunc(function()
			Settings.InitTooltip(category.label, category.colorTip)
		end)
		swatch:SetScript("OnClick", function()
			OpenColorPicker(key)
		end)
		colorCell:EnableMouse(true)
		colorCell:SetScript("OnEnter", function(self)
			ShowOptionsTooltip(self, category.label, category.colorTip)
		end)
		colorCell:SetScript("OnLeave", HideOptionsTooltip)
		local hideCell = CreateFrame("Frame", nil, rows)
		Place(hideCell, 3, i, 110)
		local hideText = CellText(hideCell, "Hide")
		local hide = CreateFrame("CheckButton", nil, hideCell, "UICheckButtonTemplate")
		hide:SetPoint("LEFT", hideText, "RIGHT", 2, 0)
		hide.Text:SetText("")
		hide:SetScript("OnEnter", function(self)
			ShowOptionsTooltip(self, "Hide", category.hideTip)
		end)
		hide:SetScript("OnLeave", HideOptionsTooltip)
		hide:SetScript("OnClick", function(self)
			StoreHide(key, self:GetChecked() and true or false)
			RefreshPlates("options")
		end)
		hideCell:EnableMouse(true)
		hideCell:SetScript("OnEnter", function(self)
			ShowOptionsTooltip(self, "Hide", category.hideTip)
		end)
		hideCell:SetScript("OnLeave", HideOptionsTooltip)
		hideCell:SetScript("OnMouseDown", function(_, button)
			if button == "LeftButton" then
				hide:Click()
			end
		end)
		panel.rows[key] = { swatch = swatch, hide = hide }
	end
	local debugRow = #CATEGORIES + 1
	local debugCell = CreateFrame("Frame", nil, rows)
	Place(debugCell, 1, debugRow, 150)
	local debugText = CellText(debugCell, "Debug")
	local debugCheck = CreateFrame("CheckButton", nil, debugCell, "UICheckButtonTemplate")
	debugCheck:SetPoint("LEFT", debugText, "RIGHT", 2, 0)
	debugCheck.Text:SetText("")
	debugCheck:SetChecked(DebugEnabled())
	debugCheck:SetScript("OnEnter", function(self)
		ShowOptionsTooltip(self, "Debug", "Prints Power Plate messages in chat.")
	end)
	debugCheck:SetScript("OnLeave", HideOptionsTooltip)
	debugCheck:SetScript("OnClick", function(self)
		StoreDebug(self:GetChecked() and true or false)
	end)
	debugCell:EnableMouse(true)
	debugCell:SetScript("OnEnter", function(self)
		ShowOptionsTooltip(self, "Debug", "Prints Power Plate messages in chat.")
	end)
	debugCell:SetScript("OnLeave", HideOptionsTooltip)
	debugCell:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then
			debugCheck:Click()
		end
	end)
	panel.debug = debugCheck
	rows:Layout()
	panel:SetScript("OnShow", function()
		list.ScrollBox:Hide()
		list.ScrollBar:Hide()
		rows:Show()
		rows:Layout()
		RefreshOptionsPanel()
	end)
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
	EnablePetNameplates()
	local openCount, protectedCount = LogPlateAvailability("dump")
	if openCount == 0 and protectedCount == 0 then
		EnableFriendlyNameplates()
	elseif openCount == 0 then
		Log("Friendly plates are protected here, so addons cannot recolor them.")
	end
	RefreshPlates("dump")
end

local events = CreateFrame("Frame")
local REFRESH_EVENTS = {
	GUILD_ROSTER_UPDATE = true,
	PLAYER_GUILD_UPDATE = true,
	FRIENDLIST_UPDATE = true,
	RECENT_ALLIES_CACHE_UPDATE = true,
	RECENT_ALLY_DATA_UPDATED = true,
	UNIT_PET = true,
}
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
for eventName in pairs(REFRESH_EVENTS) do
	events:RegisterEvent(eventName)
end
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
		EnablePetNameplates()
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
	elseif REFRESH_EVENTS[event] then
		RefreshPlates(event, true)
	end
end)

SLASH_POWERPLATE1 = "/powerplate"
SLASH_POWERPLATE2 = "/pp"
SlashCmdList.POWERPLATE = Dump

EnsureHooks()
