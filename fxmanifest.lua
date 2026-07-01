fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Codex'
description 'QBCore Advanced Ambulance Job V2 with modern NUI'
version '2.7.2'

ui_page 'html/index.html'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/migrations.lua',
    'server/updater.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/styles.css',
    'html/app.js',
    'html/health.html',
    'html/health.css',
    'html/health.js',
    'html/assets/*.svg'
}

dependencies {
    'qb-core',
    'qb-management',
    'qb-menu',
    'qb-target',
    'qb-input',
    'progressbar',
    'oxmysql'
}
