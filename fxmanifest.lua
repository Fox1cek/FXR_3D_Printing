fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fxr_3dprinter'
author 'Fox1cek'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua',
    'config/recipes.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/printer.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
    'server/main.lua'
}

data_file 'DLC_ITYP_REQUEST' 'stream/bzzz_electro_prop_3dprinter.ytyp'

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql',
    'ox_target',
    'ox_inventory'
}
