local addonName, ns = ...

ns.name = addonName

function ns.ShowStatus()
    print("Wanderful: development skeleton loaded. The wand guide is not available yet.")
end

SLASH_WANDERFUL1 = "/wanderful"
SlashCmdList.WANDERFUL = ns.ShowStatus
