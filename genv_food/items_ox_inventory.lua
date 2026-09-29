-- Vloz do ox_inventory/data/items.lua
-- DULEZITE: `consume = 0`, aby ox_inventory item neodebral sam - odebira ho nas script po vycerpani pouziti.

['burger'] = {
    label = 'Burger', weight = 250, stack = false, close = true, consume = 0,
    description = 'Šťavnatý burger.',
    client = { export = 'genv_food.use' },
},
['pizza'] = {
    label = 'Pizza', weight = 500, stack = false, close = true, consume = 0,
    description = 'Horká pizza.',
    client = { export = 'genv_food.use' },
},
['chips'] = {
    label = 'Chipsy', weight = 150, stack = false, close = true, consume = 0,
    description = 'Slané chipsy.',
    client = { export = 'genv_food.use' },
},
['water'] = {
    label = 'Voda', weight = 400, stack = false, close = true, consume = 0,
    description = 'Láhev vody.',
    client = { export = 'genv_food.use' },
},
['cola'] = {
    label = 'Cola', weight = 350, stack = false, close = true, consume = 0,
    description = 'Ledově studená cola.',
    client = { export = 'genv_food.use' },
},

-- Prazdne obaly (volitelne)
['empty_bottle'] = { label = 'Prázdná láhev', weight = 50, stack = true, close = true },
['empty_can']    = { label = 'Prázdná plechovka', weight = 30, stack = true, close = true },
