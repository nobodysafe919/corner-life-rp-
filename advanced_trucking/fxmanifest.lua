fx_version 'cerulean'
game 'gta5'

author 'Corner Life RP'
description 'Corner Life RP Trucking & Logistics - advanced trucking career, company, cargo, and RP supply-run system'
version '1.0.0'

lua54 'yes'

dependency 'oxmysql'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}
