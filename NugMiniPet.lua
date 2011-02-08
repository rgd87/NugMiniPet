NugMiniPet = CreateFrame("Frame","NugMiniPet")

NugMiniPet:SetScript("OnEvent", function(self, event, ...)
	self[event](self, event, ...)
end)
NugMiniPet:RegisterEvent("ADDON_LOADED")

local DB_VERSION = 3

BINDING_HEADER_NUGMINIPET = "NugMiniPet"

local id_now
local lastCall
local pet_indices = {}
local initalized = false
function NugMiniPet.ADDON_LOADED(self,event,arg1)
    if arg1 == "NugMiniPet" then
        NugMiniPetDB = NugMiniPetDB or {}
        NugMiniPetDB.pets = NugMiniPetDB.pets or {}
        NugMiniPetDB.timer = NugMiniPetDB.timer or 0
        NugMiniPetDB.enable = (NugMiniPetDB.enable == nil) and true or NugMiniPetDB.enable
        
        lastCall = GetTime()
        
        NugMiniPet:RegisterEvent("COMPANION_LEARNED")
        NugMiniPet.COMPANION_LEARNED = NugMiniPet.Initialize
        
        --PURGING OLD DB OF PETS
        if not NugMiniPetDB.DB_VERSION or NugMiniPetDB.DB_VERSION ~= DB_VERSION then
            NugMiniPetDB.pets = {}
            NugMiniPetDB.DB_VERSION = DB_VERSION
        end
        
        
        hooksecurefunc("MoveForwardStart",NugMiniPet.Summon)
        hooksecurefunc("ToggleAutoRun",NugMiniPet.Summon)
        
        hooksecurefunc("CallCompanion",function(compType, id)
            if compType == "CRITTER" then
                id_now = id
                lastCall = GetTime()
            end
        end)
        hooksecurefunc("SpellBookCompanionButton_OnModifiedClick",function(self,button)
            if SpellBookCompanionsFrame.mode ~= "CRITTER" or not IsControlKeyDown() then return end
            local cPage,maxPage = SpellBook_GetCurrentPage()
            local offset = (cPage -1) * NUM_COMPANIONS_PER_PAGE;
            local index = self:GetID() + offset
            local creatureID, creatureName, spellID, icon, active = GetCompanionInfo("CRITTER", index)
            if not NugMiniPetDB.pets[spellID] then
                NugMiniPetDB.pets[spellID] = true
                table.insert(pet_indices, index)
                self.nmpBorder:Show()
            else
                NugMiniPetDB.pets[spellID] = nil
                for i,ind in ipairs(pet_indices) do 
                    if ind == index then table.remove(pet_indices, i) break end
                end
                self.nmpBorder:Hide()
            end
        end)
        hooksecurefunc("SpellBook_UpdateCompanionsFrame",function(ctype)
            if ctype == "CRITTER" then NugMiniPet.UpdateBorders() end
        end)
        
        NugMiniPet.Auto_Button = self:CreateCheckBox()
        NugMiniPet.Timer_EditBox = self:CreateTimerEditBox()
        hooksecurefunc("SpellBookFrameTabButton_OnClick",function(self)
            if SpellBookFrame.currentTab.bookType == BOOKTYPE_COMPANION then
                NugMiniPet.Auto_Button:Show()
                NugMiniPet.Timer_EditBox:Show()
            else
                NugMiniPet.Auto_Button:Hide()
                NugMiniPet.Timer_EditBox:ClearFocus()
                NugMiniPet.Timer_EditBox:Hide()
            end
            NugMiniPet:UpdateBorders()
        end)
        
    end
end

function NugMiniPet.Summon()
    if not NugMiniPetDB.enable then return end
    local creatureID, creatureName, spellID, icon, active
    if id_now then creatureID, creatureName, spellID, icon, active = GetCompanionInfo("CRITTER", id_now) end
    if not active then id_now = nil end
    local timerExpired
    if NugMiniPetDB.timer ~= 0 then
        if lastCall + NugMiniPetDB.timer * 60 < GetTime() then timerExpired = true end
    end
    if not active or timerExpired then
        if not initalized then NugMiniPet:Initialize() end
        local id = NugMiniPet:Shuffle()
        if id
            and (lastCall+1.5 < GetTime()) and not UnitAffectingCombat("player")
            and not IsMounted() and not IsFlying() and not UnitHasVehicleUI("player")
            and not IsStealthed() and not UnitIsGhost("player")
            and not UnitAura("player",GetSpellInfo(51755),nil,"HELPFUL") -- Camouflage
            and not UnitAura("player",GetSpellInfo(32612),nil,"HELPFUL") -- Invisibility
        then
            lastCall = GetTime() -- isSummoned seems like not updated instantly so this is a cooldown for next summon
            CallCompanion("CRITTER",id)
        end
    end
end

function NugMiniPet.SimpleSummon()
    if not initalized then NugMiniPet:Initialize() end
    local id = NugMiniPet:Shuffle()
    while id_now ~= nil and id == id_now and select(2,NugMiniPet:Shuffle()) > 1 do
        id = NugMiniPet:Shuffle()
    end
    lastCall = GetTime()
    CallCompanion("CRITTER",id)
end

function NugMiniPet.UpdateBorders(self)
    if SpellBookFrame.currentTab and SpellBookFrame.currentTab.bookType ~= BOOKTYPE_COMPANION then
        for i=1,NUM_COMPANIONS_PER_PAGE do
            local btn = _G["SpellBookCompanionButton"..i]
            if btn.nmpBorder then btn.nmpBorder:Hide() end
        end
        return
    end
    local cPage,maxPage = SpellBook_GetCurrentPage()
    local offset = (cPage -1) * NUM_COMPANIONS_PER_PAGE;
    for i=1,NUM_COMPANIONS_PER_PAGE do
        local btn = _G["SpellBookCompanionButton"..i]
        local index = i + offset
        if btn.creatureID then
            if not btn.nmpBorder then NugMiniPet:CreateBorder(btn) end
            local _,_, spellID = GetCompanionInfo("CRITTER",index)
            if NugMiniPetDB.pets[spellID] then
                btn.nmpBorder:Show()
            else
                btn.nmpBorder:Hide()
            end
        else
            if btn.nmpBorder then btn.nmpBorder:Hide() end
        end
    end
end

function NugMiniPet.Initialize(self)
    pet_indices = {}
	for i=1,GetNumCompanions("CRITTER") do
		local _,_, spellID, _, active = GetCompanionInfo("CRITTER", i)
		if not spellID then break end
		if NugMiniPetDB.pets[spellID] then 
            table.insert(pet_indices, i)
		end
        if active then id_now = i end
	end
	self:UpdateBorders()
end

function NugMiniPet.CreateBorder(self,button)
    local b = button:CreateTexture(nil,"OVERLAY")
    b:SetWidth(20)
    b:SetHeight(20)
    b:SetPoint("TOPRIGHT",button,"BOTTOMLEFT",7,18)
    b:SetTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Down")
    button.nmpBorder = b
end

function NugMiniPet.CreateCheckBox(self)
    local f = CreateFrame("CheckButton",nil,SpellBookCompanionModelFrame,"UICheckButtonTemplate")
    f:SetWidth(25)
    f:SetHeight(25)
    f:SetPoint("BOTTOMLEFT",SpellBookCompanionModelFrame,"BOTTOMRIGHT",7,27)
    f:SetChecked(NugMiniPetDB.enable)
    f:SetScript("OnClick",function(self,button)
        NugMiniPetDB.enable = not NugMiniPetDB.enable
    end)
    f:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText("NugMiniPet\nEnable/Disable Autosummon\n\nCtrlClick : Select pet", nil, nil, nil, nil, 1);
        GameTooltip:Show();
    end)
    f:SetScript("OnLeave",function(self)
        GameTooltip:Hide();
    end)
    
    local label  =  f:CreateFontString(nil, "OVERLAY")
    label:SetFontObject("QuestFontNormalSmall")
    label:SetPoint("LEFT",f,"RIGHT",0,0)
    label:SetText("Auto")
    
    return f
end

function NugMiniPet.CreateTimerEditBox()    
    local f = CreateFrame("EditBox",nil,SpellBookCompanionModelFrame,"InputBoxTemplate")
    f:SetWidth(30)
    f:SetHeight(15)
    f:SetAutoFocus(false)
    f:SetMaxLetters(3)
    f:SetText(NugMiniPetDB.timer)
    f:SetPoint("BOTTOMLEFT",SpellBookCompanionModelFrame,"BOTTOMRIGHT",15,5)
    f:SetScript("OnEnterPressed", function(self)
        if tonumber(self:GetText()) then
            NugMiniPetDB.timer = tonumber(self:GetText())
        end
        self:ClearFocus()
    end)
    f:SetScript("OnEscapePressed", function(self)
        self:SetText(NugMiniPetDB.timer)
        self:ClearFocus()
    end)
    
    f:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText("Summon new pet every X minutes\n0 = Disabled", nil, nil, nil, nil, 1);
        GameTooltip:Show();
    end)
    f:SetScript("OnLeave",function(self)
        GameTooltip:Hide();
    end)
    
    local label  =  f:CreateFontString(nil, "OVERLAY")
    label:SetFontObject("QuestFontNormalSmall")
    label:SetPoint("LEFT",f,"RIGHT",1,0)
    label:SetText("m")
    
    return f
end

function NugMiniPet.Shuffle(self)
    local maxn = table.maxn(pet_indices)
    local random
    if maxn == 1 then
        random = pet_indices[1]
        if id_now == random then random = nil end
    elseif maxn > 1 then
        repeat
            random = pet_indices[math.random(maxn)]
        until id_now ~= random
    end
    return random, maxn
end
