local held = {}   -- [src] = { slot, name }
local biting = {} -- [src] = cas zacatku kousnuti

---------------------------------------------------------------------
-- Aplikace efektu (hunger/thirst/health) podle frameworku
---------------------------------------------------------------------
local function ApplyEffects(src, cfg)
    -- jidlo/piti z obchodu doplni jen cast (Config.StoreMultiplier)
    local mult = cfg.store and (Config.StoreMultiplier or 0.5) or 1.0
    local hunger = cfg.hunger and cfg.hunger * mult
    local thirst = cfg.thirst and cfg.thirst * mult
    local health = cfg.health and math.floor(cfg.health * mult)

    if Config.Framework == 'esx' then
        -- esx_status pracuje se skalou 0 - 1 000 000
        if hunger then TriggerClientEvent('esx_status:add', src, 'hunger', math.floor(hunger * 10000)) end
        if thirst then TriggerClientEvent('esx_status:add', src, 'thirst', math.floor(thirst * 10000)) end
        if health then TriggerClientEvent('genv_food:heal', src, health) end

    elseif Config.Framework == 'qb' or Config.Framework == 'qbox' then
        local Player = Config.Framework == 'qbox'
            and exports.qbx_core:GetPlayer(src)
            or exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
        if not Player then return end
        local meta = Player.PlayerData.metadata
        if hunger then
            Player.Functions.SetMetaData('hunger', math.max(0, math.min(100, meta.hunger + hunger)))
        end
        if thirst then
            Player.Functions.SetMetaData('thirst', math.max(0, math.min(100, meta.thirst + thirst)))
        end
        if health then TriggerClientEvent('genv_food:heal', src, health) end

    else
        -- CUSTOM: sem dopln vlastni system hladu/zizne
        print(('[genv_food] custom framework: hunger=%s thirst=%s'):format(hunger, thirst))
    end
end

---------------------------------------------------------------------
-- Callbacky
---------------------------------------------------------------------

-- Hrac vezme item do ruky
lib.callback.register('genv_food:hold', function(src, slotId)
    if held[src] then return false end

    local slot = exports.ox_inventory:GetSlot(src, slotId)
    if not slot then return false end

    local cfg = Config.Items[slot.name]
    if not cfg then return false end

    held[src] = { slot = slotId, name = slot.name }
    return true, (slot.metadata and slot.metadata.uses) or cfg.uses
end)

-- Hrac item odlozil / prestal drzet
lib.callback.register('genv_food:release', function(src)
    held[src] = nil
    biting[src] = nil
    return true
end)

lib.callback.register('genv_food:biteStart', function(src)
    if not held[src] or biting[src] then return false end
    biting[src] = GetGameTimer()
    return true
end)

lib.callback.register('genv_food:biteCancel', function(src)
    biting[src] = nil
    return true
end)

-- Dokonceni kousnuti -> spotrebuje jedno pouziti
lib.callback.register('genv_food:biteFinish', function(src)
    local job, started = held[src], biting[src]
    biting[src] = nil
    if not job or not started then return false, 0 end

    local cfg = Config.Items[job.name]
    if not cfg then held[src] = nil return false, 0 end

    -- anti-cheat: uplynula dostatecna doba?
    if (GetGameTimer() - started) < (cfg.biteTime * Config.MinTimeRatio) then
        return false, 0
    end

    -- item musi porad byt v inventari (hrac s nim mohl v inventari pohnout do jineho slotu)
    local slot = exports.ox_inventory:GetSlot(src, job.slot)
    if not slot or slot.name ~= job.name then
        slot = exports.ox_inventory:GetSlotWithItem(src, job.name)
        if not slot then held[src] = nil return false, 0 end
        job.slot = slot.slot
    end

    local metadata = slot.metadata or {}
    local left = (metadata.uses or cfg.uses) - 1

    if left <= 0 then
        if not exports.ox_inventory:RemoveItem(src, job.name, 1, nil, job.slot) then
            held[src] = nil
            return false, 0
        end
        if cfg.emptyItem then
            exports.ox_inventory:AddItem(src, cfg.emptyItem, 1)
        end
        held[src] = nil
    else
        metadata.uses = left
        metadata.description = Config.Locale.remaining:format(left, cfg.uses)
        exports.ox_inventory:SetMetadata(src, job.slot, metadata)
    end

    ApplyEffects(src, cfg)
    return true, math.max(left, 0)
end)

AddEventHandler('playerDropped', function()
    held[source] = nil
    biting[source] = nil
end)

---------------------------------------------------------------------
-- Kontrola verze (vypis do server konzole pri startu)
---------------------------------------------------------------------
local function parseVersion(v)
    local parts = {}
    for n in tostring(v):gmatch('%d+') do parts[#parts + 1] = tonumber(n) end
    return parts
end

-- vraci 1 kdyz a > b, -1 kdyz a < b, 0 kdyz stejne
local function compareVersions(a, b)
    local pa, pb = parseVersion(a), parseVersion(b)
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x > y and 1 or -1 end
    end
    return 0
end

CreateThread(function()
    local vc = Config.VersionCheck
    if not vc or not vc.enabled then return end

    Wait(2000)

    local resource = GetCurrentResourceName()
    local current = GetResourceMetadata(resource, 'version', 0) or '0.0.0'
    local tag = '^3[Version Check]^7'

    if not vc.url or vc.url == '' then
        return print(('%s ^3Nastav Config.VersionCheck.url, jinak nejde zjistit nejnovejsi verzi. Bezi verze %s.^7'):format(tag, current))
    end

    PerformHttpRequest(vc.url, function(status, body)
        if status ~= 200 or not body then
            return print(('%s ^1Nepodarilo se zkontrolovat verzi (HTTP %s).^7'):format(tag, tostring(status)))
        end

        local latest
        local ok, data = pcall(json.decode, body)
        if ok and type(data) == 'table' and data.version then
            latest = data.version
        else
            latest = body:match('%d+%.%d+[%.%d]*')
        end

        if not latest then
            return print(('%s ^1Neplatna odpoved serveru s verzi.^7'):format(tag))
        end

        if compareVersions(current, latest) >= 0 then
            print(('%s ✅ ^2You are running the latest version!^7'):format(tag))
        else
            print(('%s ⚠️ ^1New version available: %s (you are running %s)^7'):format(tag, latest, current))
        end
    end, 'GET')
end)
