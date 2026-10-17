local _, ns = ...
local P = {}
ns.ItemPresentation = P
local function plain(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, v)
    return ok and secret == false
end
local function call(fn, ...)
    if type(fn) ~= "function" then return end
    return pcall(fn, ...)
end
-- Cosmetic cache data never replaces catalog stats or the comparison snapshot.
function P.Metadata(itemID)
    local api = rawget(_G, "C_Item")
    local info = { icon = "Interface\\Icons\\INV_Misc_QuestionMark", color = { 0.82, 0.86, 0.90 } }
    if type(api) ~= "table" or not itemID then return info end
    local ok, icon = call(api.GetItemIconByID, itemID)
    if ok and plain(icon) and (type(icon) == "number" or type(icon) == "string") then info.icon = icon end
    local got, name, link, quality = call(api.GetItemInfo, itemID)
    if got then
        if plain(name) and type(name) == "string" then info.name = name end
        if plain(link) and type(link) == "string" then info.link = link end
        if plain(quality) and ns.GuideModel.Finite(quality) then
            local colored, r, g, b = call(api.GetItemQualityColor, quality)
            if colored and plain(r) and plain(g) and plain(b) and ns.GuideModel.Finite(r)
                and ns.GuideModel.Finite(g) and ns.GuideModel.Finite(b) then info.color = { r, g, b } end
        end
    end
    return info
end
local function hideComparison()
    for _, name in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2" }) do
        local tooltip = rawget(_G, name)
        if tooltip and type(tooltip.Hide) == "function" then tooltip:Hide() end
    end
end
function P.HideTooltip()
    P.owner, P.itemID = nil, nil
    hideComparison()
    local tooltip = rawget(_G, "GameTooltip")
    if tooltip then tooltip:Hide() end
    local hide = rawget(_G, "GameTooltip_HideShoppingTooltips")
    if type(hide) == "function" then hide(tooltip) end
end
function P.Tooltip(owner, itemID)
    local tooltip = rawget(_G, "GameTooltip")
    if not tooltip or not itemID then return end
    P.owner, P.itemID = owner, itemID
    tooltip:SetOwner(owner, "ANCHOR_RIGHT")
    -- SetHyperlink is exercised by the existing in-game item probe.
    tooltip:SetHyperlink("item:" .. itemID)
    tooltip:Show()
    local compare = rawget(_G, "GameTooltip_ShowCompareItem")
    local ok, shifted = call(rawget(_G, "IsShiftKeyDown"))
    local cvar = rawget(_G, "C_CVar")
    local read, always = call(type(cvar) == "table" and cvar.GetCVarBool, "alwaysCompareItems")
    if type(compare) == "function" and ((ok and plain(shifted) and shifted == true)
        or (read and plain(always) and always == true)) then compare(tooltip) else hideComparison() end
end
function P.Link(itemID)
    local ok, shifted = call(rawget(_G, "IsShiftKeyDown"))
    if not ok or not plain(shifted) or shifted ~= true then return false end
    local insert = rawget(_G, "ChatEdit_InsertLink")
    local info = P.Metadata(itemID)
    if type(insert) == "function" and info.link then insert(info.link) end
    -- A modified click never changes selection or the baseline, including a cache miss.
    return true
end
function P.ModifiersChanged()
    if P.owner and P.owner:IsShown() then P.Tooltip(P.owner, P.itemID) end
end
function P.ValidateOwner()
    if P.owner and (not P.owner:IsShown() or P.owner.itemID ~= P.itemID) then P.HideTooltip() end
end