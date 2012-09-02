NugMiniPet = CreateFrame("Frame","NugMiniPet")

NugMiniPet:SetScript("OnEvent", function(self, event, ...)
	return self[event](self, event, ...)
end)
NugMiniPet:RegisterEvent("ADDON_LOADED")

local DB_VERSION = 4

BINDING_HEADER_NUGMINIPET = "NugMiniPet"

local lastCall
local favoritePetIDs = {}
local initalized = false
function NugMiniPet.ADDON_LOADED(self,event,arg1)
    if arg1 == "NugMiniPet" then
        NugMiniPetDB = NugMiniPetDB or {}
        --PURGING OLD DB OF PETS
        if not NugMiniPetDB.DB_VERSION or NugMiniPetDB.DB_VERSION ~= DB_VERSION then
            table.wipe(NugMiniPetDB)
            NugMiniPetDB.DB_VERSION = DB_VERSION
        end
        NugMiniPetDB.timer = NugMiniPetDB.timer or 0
        NugMiniPetDB.enable = (NugMiniPetDB.enable == nil) and true or NugMiniPetDB.enable
        
        lastCall = GetTime()

        self:RegisterEvent("PET_JOURNAL_LIST_UPDATE")
        self.PET_JOURNAL_LIST_UPDATE = self.Initialize
        
        hooksecurefunc("MoveForwardStart",NugMiniPet.Summon)
        hooksecurefunc("ToggleAutoRun",NugMiniPet.Summon)
        
    elseif arg1 == "Blizzard_PetJournal" then
        for i, btn in ipairs(PetJournal.listScroll.buttons) do
            btn:SetScript("OnClick",function(self, button)
                if IsControlKeyDown() then
                    local isFavorite = C_PetJournal.PetIsFavorite(self.petID)
                    C_PetJournal.SetFavorite(self.petID, isFavorite and 0 or 1)
                else
                    return PetJournalListItem_OnClick(self,button)
                end
            end)
        end

        NugMiniPet.Auto_Button = self:CreateCheckBox()
        NugMiniPet.Timer_EditBox = self:CreateTimerEditBox()
        hooksecurefunc("PetJournalParent_UpdateSelectedTab", function(self)
            local selected = PanelTemplates_GetSelectedTab(self);
            if selected == 2 then
                NugMiniPet.Auto_Button:Show()
                NugMiniPet.Timer_EditBox:Show()
            else
                NugMiniPet.Auto_Button:Hide()
                NugMiniPet.Timer_EditBox:ClearFocus()
                NugMiniPet.Timer_EditBox:Hide()
            end
        end)
    end
end

function NugMiniPet.Summon()
    if not NugMiniPetDB.enable then return end
    local active = C_PetJournal.GetSummonedPetID()
    local timerExpired
    if NugMiniPetDB.timer ~= 0 then
        if lastCall + NugMiniPetDB.timer * 60 < GetTime() then timerExpired = true end
    end
    if not active or timerExpired then
        if not initalized then NugMiniPet:Initialize() end
        local newPetID = NugMiniPet:Shuffle()
        if newPetID == active then return end
        if newPetID
            and (lastCall+1.5 < GetTime()) and not UnitAffectingCombat("player")
            and not IsMounted() and not IsFlying() and not UnitHasVehicleUI("player")
            and not IsStealthed() and not UnitIsGhost("player")
            and not UnitAura("player",GetSpellInfo(51755),nil,"HELPFUL") -- Camouflage
            and not UnitAura("player",GetSpellInfo(32612),nil,"HELPFUL") -- Invisibility
        then
            lastCall = GetTime()
            C_PetJournal.SummonPetByID(newPetID)
        end
    end
end

function NugMiniPet.SimpleSummon()
    if not initalized then NugMiniPet:Initialize() end
    local newPetID, maxfavs
    local active = C_PetJournal.GetSummonedPetID()
    repeat
        newPetID, maxfavs = NugMiniPet:Shuffle()
    until not active or newPetID ~= active or maxfavs < 2
    if active == newPetID then return end
    lastCall = GetTime()
    C_PetJournal.SummonPetByID(newPetID)
end

function NugMiniPet.Initialize(self)
    table.wipe(favoritePetIDs)
    local isWild = false
    local index = 1
    while true do
	    local petID, speciesID, isOwned, customName, level, favorite,
             isRevoked, name, icon, petType, creatureID, sourceText,
             description, isWildPet, canBattle = C_PetJournal.GetPetInfoByIndex(index, isWild);
        if not petID then break end
        if favorite then table.insert(favoritePetIDs, petID) end
        index = index + 1
    end
end

function NugMiniPet.CreateCheckBox(self)
    local f = CreateFrame("CheckButton",nil,PetJournal,"UICheckButtonTemplate")
    f:SetWidth(25)
    f:SetHeight(25)
    f:SetPoint("BOTTOMLEFT",PetJournal,"BOTTOMLEFT",170,2)
    f:SetChecked(NugMiniPetDB.enable)
    f:SetScript("OnClick",function(self,button)
        NugMiniPetDB.enable = not NugMiniPetDB.enable
    end)
    f:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText("NugMiniPet\nEnable/Disable Autosummon\n\nCtrlClick : Mark as favorite", nil, nil, nil, nil, 1);
        GameTooltip:Show();
    end)
    f:SetScript("OnLeave",function(self)
        GameTooltip:Hide();
    end)
    
    local label  =  f:CreateFontString(nil, "OVERLAY")
    label:SetFontObject("GameFontNormal")
    label:SetPoint("LEFT",f,"RIGHT",0,0)
    label:SetText("Auto")
    
    return f
end

function NugMiniPet.CreateTimerEditBox()    
    local f = CreateFrame("EditBox",nil, PetJournal,"InputBoxTemplate")
    f:SetWidth(30)
    f:SetHeight(15)
    f:SetAutoFocus(false)
    f:SetMaxLetters(3)
    f:SetText(NugMiniPetDB.timer)
    f:SetPoint("BOTTOMLEFT",PetJournal,"BOTTOMLEFT",250,6)
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
    label:SetFontObject("GameFontNormal")
    label:SetPoint("LEFT",f,"RIGHT",1,0)
    label:SetText("m")
    
    return f
end

function NugMiniPet.Shuffle(self)
    local maxn = #favoritePetIDs
    local random
    if maxn == 1 then
        random = favoritePetIDs[1]
    elseif maxn > 1 then
        repeat
            random = favoritePetIDs[math.random(maxn)]
        until C_PetJournal.GetSummonedPetID() ~= random
    end
    return random, maxn
end
