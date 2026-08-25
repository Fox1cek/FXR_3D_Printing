Config = {}

Config.Language = 'cs'
Config.DiscordWebhook = 'https://discord.com/api/webhooks'
Config.PrinterModel = 'bzzz_electro_prop_3dprinter'

Config.MaxMaterialStorage = {
    plastic_filament = 200,
    metal_filament = 200,
    printer_battery = 20,
}

Config.AllowPlacementAnywhere = true
Config.TargetDistance = 2.5
Config.MaxPrintersPerPlayer = 2

Config.Durability = {
    enabled = true,
    lossPerPrint = 10,
    repairCostItem = 'metal_filament',
    repairCostAmount = 15,
}

Config.ShopBlueprints = {
    { item = 'blueprint_lockpick', label = 'Model: Lockpick', price = 500, description = 'CAD model' },
    { item = 'blueprint_advlockpick', label = 'Model: Advanced Lockpick', price = 1200, description = 'CAD model' },
    { item = 'blueprint_handcuffs', label = 'Model: Handcuffs', price = 2000, description = 'CAD model' },
    { item = 'blueprint_suppressor', label = 'Model: Suppressor', price = 15500, description = 'CAD model' },
    { item = 'blueprint_extmag', label = 'Model: Extended Mag', price = 10200, description = 'CAD model' },
    { item = 'blueprint_sns_pistol', label = 'Model: SNS Pistol 3D', price = 7500, description = 'CAD model' },
    { item = 'blueprint_combat_pistol', label = 'Model: Combat Pistol 3D', price = 10000, description = 'CAD model' },
    { item = 'blueprint_machine_pistol', label = 'Model: Machine Pistol 3D', price = 25000, description = 'CAD model' },
    { item = 'blueprint_switchblade', label = 'Model: Switchblade 3D', price = 4500, description = 'CAD model' },
    { item = 'blueprint_compact_rifle', label = 'Model: Compact Rifle 3D', price = 50000, description = 'CAD model' },
}

Config.PoliceAlert = {
    enabled = false,
    chance = 35,
    dispatchSystem = 'ps-dispatch',
}

Config.FailChance = 5
Config.StaticPrinters = {}

Config.Blackmarket = {
    enabled = true,
    label = '3D Print Blackmarket',
    icon = 'fas fa-user-secret',
    coords = vec3(-30.6873, -347.0736, 46.5316),
    heading = 263.1046,
    radius = 1.8,
    items = {
        { name = '3d_printer', label = '3D Printer', price = 15000, description = '3D Printer' },
        { name = 'plastic_filament', label = 'Plastic Filament', price = 50, description = 'PLA / ABS' },
        { name = 'metal_filament', label = 'Metal Filament', price = 120, description = 'Metal' },
        { name = 'printer_battery', label = 'Printer Battery', price = 500, description = 'Battery' },
    }
}
