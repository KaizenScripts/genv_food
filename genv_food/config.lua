Config = {}

-- 'esx' | 'qb' | 'custom' (custom = uprav funkci ApplyEffects v server.lua)
Config.Framework = 'esx'

-- Vypisuje do F8 konzole, co se deje pri pouziti itemu (po odladeni vypni)
Config.Debug = true

-- Nejmensi podil delky kousnuti, ktery musi uplynout, nez server uzna pouziti (anti-cheat)
Config.MinTimeRatio = 0.8

-- Kdyz je status plny, jidlo/piti se nepouzije a nic se nespotrebuje
Config.BlockWhenFull = true
Config.FullThreshold = 99 -- od kolika % (0-100) se status povazuje za plny

-- Pro Config.Framework = 'custom': vrat aktualni hodnotu 0-100 pro 'hunger' / 'thirst' (nebo nil = bez kontroly)
Config.GetStatus = function(name)
    return nil
end

-- Upozorneni na hlad/zizen
Config.LowStatus = {
    enabled  = true,
    threshold = 20,      -- pod kolik % (0-100) se upozorni
    check    = 5000,     -- jak casto se status kontroluje (ms)
    repeatEvery = 60000, -- jak casto se upozorneni opakuje, dokud je status nizky (ms); 0 = jen jednou
    notify = {
        hunger = { icon = 'drumstick-bite' },
        thirst = { icon = 'glass-water' },
    },
}

-- Jidlo/piti z obchodu (store = true u itemu) doplni jen cast efektu
-- 0.5 = polovina, 1.0 = stejne jako z restaurace
Config.StoreMultiplier = 0.5

-- Kontrola verze pri startu (vypis do server konzole)
-- url = odkaz na textovy soubor / JSON {"version":"1.0.1"} s nejnovejsi verzi (napr. GitHub raw)
Config.VersionCheck = {
    enabled = true,
    url = '',
}

-- Klavesy (hrac si je muze zmenit v nastaveni FiveM > Key Bindings)
Config.BiteKey = 'E'
Config.PutAwayKey = 'X'

-- Animace: hold = drzeni v ruce (smycka), bite = jedno kousnuti/loknuti
local EAT = {
    hold = { dict = 'amb@code_human_wander_eating_donut@male@idle_a', clip = 'idle_c' },
    bite = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger', flag = 49 },
}
local DRINK = {
    hold = { dict = 'amb@world_human_drinking@coffee@male@idle_a', clip = 'idle_a' },
    bite = { dict = 'mp_player_intdrink', clip = 'loop_bottle', flag = 49 },
}

-- Klic = nazev itemu v ox_inventory
-- type      = 'food' (kousnout) nebo 'drink' (napit se)
-- uses      = kolik kousnuti/loku item ma
-- biteTime  = delka jednoho kousnuti (ms)
-- hunger/thirst/health = kolik se prida ZA JEDNO kousnuti (v %)
-- emptyItem = co hrac dostane po poslednim kousnuti (volitelne)
-- store     = true -> item z obchodu, doplni jen Config.StoreMultiplier efektu (volitelne)
Config.Items = {
    burger = {
        label = 'Burger', type = 'food', uses = 3, biteTime = 2500, hunger = 12,
        holdAnim = EAT.hold, biteAnim = EAT.bite,
        prop = { model = `prop_cs_burger_01`, bone = 60309, pos = vec3(0.0, 0.0, -0.02), rot = vec3(0.0, 0.0, 0.0) },
    },

    pizza = {
        label = 'Pizza', type = 'food', uses = 4, biteTime = 2500, hunger = 10,
        holdAnim = EAT.hold, biteAnim = EAT.bite,
        prop = { model = `v_res_tt_pizzaplate`, bone = 60309, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
    },

    chips = {
        label = 'Chipsy', type = 'food', uses = 5, biteTime = 2000, hunger = 5, thirst = -2,
        holdAnim = EAT.hold, biteAnim = EAT.bite,
        prop = { model = `prop_food_chips`, bone = 60309, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
    },

    water = {
        label = 'Voda', type = 'drink', uses = 4, biteTime = 2500, thirst = 15, emptyItem = 'empty_bottle',
        holdAnim = DRINK.hold, biteAnim = DRINK.bite,
        prop = { model = `prop_ld_flow_bottle`, bone = 60309, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
    },

    cola = {
        label = 'Cola', type = 'drink', uses = 3, biteTime = 2500, thirst = 12, hunger = 2, emptyItem = 'empty_can',
        holdAnim = DRINK.hold, biteAnim = DRINK.bite,
        prop = { model = `prop_ecola_can`, bone = 60309, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 0.0, 0.0) },
    },
}

Config.Locale = {
    remaining  = 'Zbývá použití: %d/%d',
    already    = 'Už něco držíš. Odlož to (%s).',
    invalid    = 'Tento předmět nelze použít.',
    bite_food  = 'Kousáš: %s',
    bite_drink = 'Piješ: %s',
    finished_food  = 'Jídlo snědeno.',
    finished_drink = 'Pití vypito.',
    full_food  = 'Už nemáš hlad.',
    full_drink = 'Už nemáš žízeň.',
    full_both  = 'Už nemáš hlad ani žízeň.',
    low_hunger = 'Máš hlad!',
    low_thirst = 'Máš žízeň!',
    ui_food    = '[%s] Ukousnout  |  [%s] Odložit  \nZbývá: %d/%d',
    ui_drink   = '[%s] Napít se  |  [%s] Odložit  \nZbývá: %d/%d',
}
