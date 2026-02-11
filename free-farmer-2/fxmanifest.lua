fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'free-farmer'
description 'Hardcore ultrarealistic farming script — Michigan/Wisconsin agriculture'
version '2.0.0'
author 'free-farmer'

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_inventory',
    'ox_target',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua',
}

client_scripts {
    'client/utils.lua',
    'client/main.lua',
    'client/fields.lua',
    'client/planters.lua',
    'client/xp.lua',
    'client/animals.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/utils.lua',
    'server/main.lua',
    'server/weather.lua',
    'server/xp.lua',
    'server/fields.lua',
    'server/planters.lua',
    'server/animals.lua',
}
