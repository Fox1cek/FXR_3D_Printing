Config = Config or {}

Config.Recipes = {
    ['lockpick'] = {
        label = 'Lockpick',
        category = 'tools',
        printTime = 60,
        propModel = 'prop_tool_pick',
        materials = {
            plastic_filament = 10,
            metal_filament = 2,
            printer_battery = 1,
        },
        blueprint = 'blueprint_lockpick',
        blueprintLabel = 'Model: Lockpick',
        isIllegal = false,
        result = { item = 'lockpick', count = 1 },
    },
    ['advancedlockpick'] = {
        label = 'Advanced Lockpick',
        category = 'tools',
        printTime = 120,
        propModel = 'prop_tool_pick',
        materials = {
            plastic_filament = 15,
            metal_filament = 5,
            printer_battery = 1,
        },
        blueprint = 'blueprint_advlockpick',
        blueprintLabel = 'Model: Advanced Lockpick',
        isIllegal = false,
        result = { item = 'advancedlockpick', count = 1 },
    },
    ['handcuffs'] = {
        label = 'Handcuffs',
        category = 'tools',
        printTime = 180,
        propModel = 'p_cs_cuffs_01_s',
        materials = {
            plastic_filament = 20,
            metal_filament = 10,
            printer_battery = 1,
        },
        blueprint = 'blueprint_handcuffs',
        blueprintLabel = 'Model: Handcuffs',
        isIllegal = false,
        result = { item = 'handcuffs', count = 1 },
    },
    ['at_suppressor_light'] = {
        label = 'Suppressor',
        category = 'attachments',
        printTime = 900,
        propModel = 'w_at_ar_supp',
        materials = {
            plastic_filament = 15,
            metal_filament = 25,
            printer_battery = 1,
        },
        blueprint = 'blueprint_suppressor',
        blueprintLabel = 'Model: Suppressor',
        isIllegal = true,
        result = { item = 'at_suppressor_light', count = 1 },
    },
    ['at_clip_extended'] = {
        label = 'Extended Magazine',
        category = 'attachments',
        printTime = 1200,
        propModel = 'w_pi_clip_02',
        materials = {
            plastic_filament = 10,
            metal_filament = 20,
            printer_battery = 1,
        },
        blueprint = 'blueprint_extmag',
        blueprintLabel = 'Model: Extended Magazine',
        isIllegal = true,
        result = { item = 'at_clip_extended', count = 1 },
    },
    ['weapon_snspistol'] = {
        label = 'SNS Pistol (3D)',
        category = 'weapons',
        printTime = 480,
        propModel = 'w_pi_sns_pistol',
        materials = {
            plastic_filament = 40,
            metal_filament = 30,
            printer_battery = 1,
        },
        blueprint = 'blueprint_sns_pistol',
        blueprintLabel = 'Model: SNS Pistol 3D',
        isIllegal = true,
        result = {
            item = 'weapon_snspistol',
            count = 1,
            metadata = {
                registered = false,
                serial = '3D-SNS',
                description = '3D Printed Weapon',
            }
        },
    },
    ['weapon_combatpistol'] = {
        label = 'Combat Pistol (3D)',
        category = 'weapons',
        printTime = 720,
        propModel = 'w_pi_combatpistol',
        materials = {
            plastic_filament = 50,
            metal_filament = 40,
            printer_battery = 1,
        },
        blueprint = 'blueprint_combat_pistol',
        blueprintLabel = 'Model: Combat Pistol 3D',
        isIllegal = true,
        result = {
            item = 'weapon_combatpistol',
            count = 1,
            metadata = {
                registered = false,
                serial = '3D-COMBAT',
                description = '3D Printed Weapon',
            }
        },
    },
    ['weapon_machinepistol'] = {
        label = 'Machine Pistol (3D)',
        category = 'weapons',
        printTime = 2100,
        propModel = 'w_ar_machinepistol',
        materials = {
            plastic_filament = 90,
            metal_filament = 75,
            printer_battery = 3,
        },
        blueprint = 'blueprint_machine_pistol',
        blueprintLabel = 'Model: Machine Pistol 3D',
        isIllegal = true,
        result = {
            item = 'weapon_machinepistol',
            count = 1,
            metadata = {
                registered = false,
                serial = '3D-MP',
                description = '3D Printed Weapon',
            }
        },
    },
    ['weapon_compactrifle'] = {
        label = 'Compact Rifle (3D)',
        category = 'weapons',
        printTime = 104400,
        propModel = 'w_ar_compactrifle',
        materials = {
            plastic_filament = 100,
            metal_filament = 130,
            printer_battery = 5,
        },
        blueprint = 'blueprint_compact_rifle',
        blueprintLabel = 'Model: Compact Rifle 3D',
        isIllegal = true,
        result = {
            item = 'weapon_compactrifle',
            count = 1,
            metadata = {
                registered = false,
                serial = '3D-RIFLE',
                description = '3D Printed Weapon',
            }
        },
    },
    ['weapon_switchblade'] = {
        label = 'Switchblade (3D)',
        category = 'weapons',
        printTime = 180,
        propModel = 'w_me_switchblade',
        materials = {
            plastic_filament = 25,
            metal_filament = 15,
            printer_battery = 1,
        },
        blueprint = 'blueprint_switchblade',
        blueprintLabel = 'Model: Switchblade 3D',
        isIllegal = true,
        result = {
            item = 'weapon_switchblade',
            count = 1,
            metadata = {
                registered = false,
                serial = '3D-KNIFE',
                description = '3D Printed Weapon',
            }
        },
    },
}
