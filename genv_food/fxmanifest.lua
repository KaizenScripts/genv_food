fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'genv_food'
description 'Jidlo a piti s vice pouzitimi (ox_lib + ox_inventory)'
version '1.0.0'

dependencies {
    'ox_lib',
    'ox_inventory',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_script 'client.lua'
server_script 'server.lua'
