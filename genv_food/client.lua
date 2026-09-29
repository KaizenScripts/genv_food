local held = nil      -- { name, cfg, left, prop }
local biting = false

local function debug(...)
    if Config.Debug then print('[genv_food]', ...) end
end

local function getSlotId(data, slot)
    if type(slot) == 'table' and slot.slot then return slot.slot end
    if type(slot) == 'number' then return slot end
    if type(data) == 'table' and data.slot then return data.slot end
end

---------------------------------------------------------------------
-- Kontrola plneho statusu
---------------------------------------------------------------------
-- vraci aktualni hodnotu 0-100 nebo nil, kdyz ji nejde zjistit
local function getStatus(name)
    if Config.Framework == 'esx' then
        local pct
        TriggerEvent('esx_status:getStatus', name, function(status)
            if not status then return end
            if status.getPercent then
                pct = status.getPercent()
            elseif status.percent then
                pct = status.percent
            elseif status.val then
                pct = status.val / 10000 -- esx_status: 0 - 1 000 000
            end
        end)
        return pct

    elseif Config.Framework == 'qb' then
        local data = exports['qb-core']:GetCoreObject().Functions.GetPlayerData()
        return data and data.metadata and data.metadata[name]

    elseif Config.Framework == 'qbox' then
        local data = exports.qbx_core:GetPlayerData()
        return data and data.metadata and data.metadata[name]
    end

    return Config.GetStatus and Config.GetStatus(name)
end

local warned = {}

-- true + text, pokud jsou VSECHNY statusy, ktere item zvysuje, uz plne
local function isFull(cfg)
    if not Config.BlockWhenFull then return false end

    local hunger, thirst = false, false
    local relevant, full = 0, 0

    for _, stat in ipairs({ 'hunger', 'thirst' }) do
        if cfg[stat] and cfg[stat] > 0 then
            relevant = relevant + 1
            if stat == 'hunger' then hunger = true else thirst = true end

            local value = getStatus(stat)
            debug('status', stat, '=', value, '| plny od:', Config.FullThreshold)

            if value == nil and not warned[stat] then
                warned[stat] = true
                print(('[genv_food] VAROVANI: nelze precist status "%s" (Config.Framework = "%s"). Kontrola plneho statusu NEFUNGUJE - zkontroluj Config.Framework / Config.GetStatus.'):format(stat, Config.Framework))
            end
            if value and value >= Config.FullThreshold then
                full = full + 1
            end
        end
    end

    if relevant == 0 or full < relevant then return false end

    if hunger and thirst then return true, Config.Locale.full_both end
    return true, hunger and Config.Locale.full_food or Config.Locale.full_drink
end

---------------------------------------------------------------------
-- Upozorneni na hlad / zizen (status pod Config.LowStatus.threshold %)
---------------------------------------------------------------------
CreateThread(function()
    local cfg = Config.LowStatus
    if not cfg or not cfg.enabled then return end

    local lastNotify = {} -- [stat] = cas posledniho upozorneni

    while true do
        Wait(cfg.check)

        if not IsEntityDead(cache.ped) then
            for _, stat in ipairs({ 'hunger', 'thirst' }) do
                local value = getStatus(stat)

                if value and value < cfg.threshold then
                    local now = GetGameTimer()
                    local last = lastNotify[stat]

                    if not last or (cfg.repeatEvery > 0 and (now - last) >= cfg.repeatEvery) then
                        lastNotify[stat] = now
                        lib.notify({
                            type = 'warning',
                            description = Config.Locale['low_' .. stat],
                            icon = cfg.notify[stat] and cfg.notify[stat].icon,
                        })
                    end
                elseif value then
                    lastNotify[stat] = nil -- status se zvedl, priste upozorni hned
                end
            end
        end
    end
end)

---------------------------------------------------------------------
-- Prop, animace, UI
---------------------------------------------------------------------
-- napit se (drink) nebo kousnout (food); kdyz typ chybi, odhadne se z efektu
local function isDrink(cfg)
    if cfg.type then return cfg.type == 'drink' end
    return (cfg.thirst or 0) > (cfg.hunger or 0)
end

local function playHold()
    if not held then return end
    local a = held.cfg.holdAnim
    lib.requestAnimDict(a.dict)
    TaskPlayAnim(cache.ped, a.dict, a.clip, 3.0, 3.0, -1, 49, 0.0, false, false, false)
end

local function showUI()
    if not held then return end
    local text = isDrink(held.cfg) and Config.Locale.ui_drink or Config.Locale.ui_food
    lib.showTextUI(text:format(Config.BiteKey, Config.PutAwayKey, held.left, held.cfg.uses), {
        position = 'right-center',
    })
end

local function spawnProp(cfg)
    local p = cfg.prop
    local ped = cache.ped
    lib.requestModel(p.model)
    local coords = GetEntityCoords(ped)
    local obj = CreateObject(p.model, coords.x, coords.y, coords.z + 0.2, true, true, false)
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, p.bone),
        p.pos.x, p.pos.y, p.pos.z, p.rot.x, p.rot.y, p.rot.z,
        true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(p.model)
    return obj
end

local function stopHolding(notifyServer)
    if not held then return end
    local h = held
    held = nil
    biting = false

    lib.hideTextUI()
    if h.prop and DoesEntityExist(h.prop) then DeleteEntity(h.prop) end
    local a = h.cfg.holdAnim
    StopAnimTask(cache.ped, a.dict, a.clip, 1.0)

    if notifyServer then lib.callback.await('genv_food:release', false) end
end

---------------------------------------------------------------------
-- Vzeti itemu do ruky (volano z ox_inventory pri "Use")
---------------------------------------------------------------------
local function startHolding(data, slot)
    debug('export zavolan | data:', json.encode(data), '| slot:', json.encode(slot))

    if held then
        return lib.notify({ type = 'error', description = Config.Locale.already:format(Config.PutAwayKey) })
    end

    local name = (type(data) == 'table' and data.name) or (type(slot) == 'table' and slot.name)
    local cfg = name and Config.Items[name]
    local slotId = getSlotId(data, slot)

    if not cfg or not slotId then
        debug('neplatny item nebo slot | name:', name, '| slotId:', slotId)
        return lib.notify({ type = 'error', description = Config.Locale.invalid })
    end

    local full, fullText = isFull(cfg)
    if full then
        return lib.notify({ type = 'inform', description = fullText })
    end

    local ok, uses = lib.callback.await('genv_food:hold', false, slotId)
    debug('server hold ->', ok, uses)
    if not ok then
        return lib.notify({ type = 'error', description = Config.Locale.invalid })
    end

    held = { name = name, cfg = cfg, left = uses }
    held.prop = spawnProp(cfg)
    playHold()
    showUI()

    -- hlidani: smrt, ztrata itemu nebo plny status = odlozit zpet do inventare
    CreateThread(function()
        while held and held.name == name do
            Wait(500)
            if held and (IsEntityDead(cache.ped) or exports.ox_inventory:Search('count', name) < 1) then
                stopHolding(true)
            elseif held and not biting then
                local full, fullText = isFull(held.cfg)
                if full then
                    lib.notify({ type = 'inform', description = fullText })
                    stopHolding(true)
                end
            end
        end
    end)
end

exports('use', function(data, slot)
    local ok, err = pcall(startHolding, data, slot)
    if not ok then
        print(('[genv_food] CHYBA: %s'):format(err))
        stopHolding(true)
    end
end)

---------------------------------------------------------------------
-- E = kousnout / napit se
---------------------------------------------------------------------
local function bite()
    if not held or biting then return end

    local full, fullText = isFull(held.cfg)
    if full then
        lib.notify({ type = 'inform', description = fullText })
        return stopHolding(true) -- nic se nespotrebuje, item se odlozi zpet
    end

    biting = true

    if not lib.callback.await('genv_food:biteStart', false) then
        biting = false
        return
    end

    local cfg = held.cfg
    local label = (isDrink(cfg) and Config.Locale.bite_drink or Config.Locale.bite_food):format(cfg.label)

    local completed = lib.progressCircle({
        duration = cfg.biteTime,
        label = label,
        position = 'bottom',
        canCancel = false,
        useWhileDead = false,
        disable = { move = false, car = false, combat = true, sprint = true },
        anim = cfg.biteAnim,
    })

    if not completed then
        lib.callback.await('genv_food:biteCancel', false)
        biting = false
        return
    end

    local ok, left = lib.callback.await('genv_food:biteFinish', false)
    debug('server biteFinish ->', ok, left)

    if not held then return end -- mezitim odlozeno

    if not ok then
        stopHolding(true)
    elseif left <= 0 then
        lib.notify({ type = 'success', description = isDrink(cfg) and Config.Locale.finished_drink or Config.Locale.finished_food })
        stopHolding(false) -- server uz item odebral a uvolnil
    else
        held.left = left
        biting = false
        playHold()
        showUI()
    end
    biting = false
end

lib.addKeybind({
    name = 'genv_food_bite',
    description = 'Ukousnout / napít se',
    defaultKey = Config.BiteKey,
    onPressed = function()
        local ok, err = pcall(bite)
        if not ok then
            print(('[genv_food] CHYBA (bite): %s'):format(err))
            biting = false
        end
    end,
})

lib.addKeybind({
    name = 'genv_food_putaway',
    description = 'Odložit jídlo / pití',
    defaultKey = Config.PutAwayKey,
    onPressed = function()
        if held and not biting then stopHolding(true) end
    end,
})

---------------------------------------------------------------------
RegisterNetEvent('genv_food:heal', function(amount)
    local ped = cache.ped
    SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + amount))
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        stopHolding(false)
    end
end)
