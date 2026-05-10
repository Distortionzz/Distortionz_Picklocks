fx_version 'cerulean'
game 'gta5'

author 'Distortionz'
description 'Distortionz Picklocks - Pick locked vehicles and rob/search them'
version '1.0.1'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua',
    'version_check.lua'
}

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory'
}