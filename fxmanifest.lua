fx_version 'cerulean'
game 'gta5'

name        'mu-licenseplate'
description 'Mauritius License Plate System for QBCore — Standard + NLTA Custom Plates'
version     '1.0.0'
author      'mu-licenseplate'

-- Required: qb-core, oxmysql, qb-menu, qb-input
dependencies {
    'qb-core',
    'oxmysql',
}

shared_scripts {
    'config.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

lua54 'yes'
