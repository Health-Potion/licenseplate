fx_version 'cerulean'
game 'gta5'

name        'mu-licenseplate'
description 'Mauritius License Plate System for QBCore — Standard + NLTA Custom Plates'
version     '1.0.0'
author      'mu-licenseplate'

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

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

lua54 'yes'
