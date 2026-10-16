local addonName, ns = ...
ns.name = addonName

function ns.ShowStatus(message)
    local command, itemID, variant = (message or ""):match("^%s*(%S*)%s*(%S*)%s*(%S*)%s*$")
    if command == "auto" then ns.Equipped:Automatic()
    elseif command == "baseline" or command == "historical" then
        if not ns.Equipped:Manual(tonumber(itemID), variant ~= "" and variant or "base", command == "historical") then
            print("Wanderful: catalog baseline not found. Use baseline <itemID> [variant], or auto.")
            return
        end
    elseif command ~= "" and command ~= "status" then
        print("Wanderful: /wanderful [status | auto | baseline <itemID> [variant] | historical <itemID> [variant]]")
        return
    end
    if ns.Equipped.state.mode == "automatic" then ns.Equipped:Refresh() end
    local state = ns.Equipped.state
    local value = state.snapshot and ns.Comparison.DPS(state.snapshot).value
    print("Wanderful: " .. state.mode .. " baseline; " .. state.status .. "; " .. state.provenance
        .. (state.itemID and "; item " .. state.itemID or "")
        .. (state.variant and "; variant " .. state.variant or "")
        .. (value and string.format("; %.2f base wand DPS", value) or "; DPS unknown")
        .. (state.reason and "; " .. state.reason or "") .. ".")
    if state.mode == "manual" then
        print("Wanderful: manual selection is active for this session. /wanderful auto returns to equipped detection.")
    end
end

SLASH_WANDERFUL1 = "/wanderful"
SlashCmdList.WANDERFUL = ns.ShowStatus
