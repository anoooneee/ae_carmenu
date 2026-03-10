fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Cyril'
Discord ".ano.ne."
description 'Advanced Car Menu '
version '0.0.4'

shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua',
    'config.lua',
    'locales.lua'
}

client_scripts {
    'client.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
