local SpawnedPrinters = {}
local PrinterData = {}
local PrintedItemProps = {}
local PrintingPtfx = {}
local isUIOpen = false
local BlackmarketZoneId = nil

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    InitPrinters()
    InitBlackmarketTarget()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    InitPrinters()
    InitBlackmarketTarget()
end)

local function RemoveBlackmarketTarget()
    pcall(function()
        if BlackmarketZoneId then
            if GetResourceState('ox_target') == 'started' then
                exports.ox_target:removeZone(BlackmarketZoneId)
            end
            BlackmarketZoneId = nil
        end
        if GetResourceState('qb-target') == 'started' then
            exports['qb-target']:RemoveZone('qbx_3dprint_blackmarket_zone')
        end
    end)
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    RemoveBlackmarketTarget()
    for id, ptfx in pairs(PrintingPtfx) do
        StopParticleFxLooped(ptfx, false)
    end
    PrintingPtfx = {}
    for id, prop in pairs(PrintedItemProps) do
        if DoesEntityExist(prop) then DeleteEntity(prop) end
    end
    PrintedItemProps = {}
    for id, prop in pairs(SpawnedPrinters) do
        if DoesEntityExist(prop) then DeleteEntity(prop) end
    end
    SpawnedPrinters = {}
end)

local isTargetModelRegistered = false

function InitPrinterTargetModel()
    if isTargetModelRegistered then return end

    pcall(function()
        local printerModel = Config.PrinterModel or 'bzzz_electro_prop_3dprinter'
        if GetResourceState('ox_target') == 'started' then
            exports.ox_target:addModel(printerModel, {
                {
                    name = 'fxr_3dprinter_global_target',
                    icon = 'fas fa-print',
                    label = _L('printer_title') or '3D Printer',
                    distance = Config.TargetDistance or 2.5,
                    onSelect = function(data)
                        local ent = data and data.entity
                        local foundId = nil

                        if ent and DoesEntityExist(ent) then
                            for id, prop in pairs(SpawnedPrinters) do
                                if prop == ent then
                                    foundId = id
                                    break
                                end
                            end

                            if not foundId then
                                local eCoords = GetEntityCoords(ent)
                                for id, pData in pairs(PrinterData) do
                                    if #(pData.coords - eCoords) < 2.5 then
                                        foundId = id
                                        break
                                    end
                                end
                            end
                        end

                        if not foundId then
                            local pPed = PlayerPedId()
                            local pCoords = GetEntityCoords(pPed)
                            local closestDist = 3.5
                            for id, pData in pairs(PrinterData) do
                                local dist = #(pData.coords - pCoords)
                                if dist < closestDist then
                                    closestDist = dist
                                    foundId = id
                                end
                            end
                        end

                        if foundId then
                            OpenPrinterMenu(foundId)
                        else
                            lib.notify({ title = _L('printer_title'), description = _L('printer_not_found'), type = 'error' })
                        end
                    end
                }
            })
            isTargetModelRegistered = true
        elseif GetResourceState('qb-target') == 'started' then
            exports['qb-target']:AddTargetModel(printerModel, {
                options = {
                    {
                        icon = 'fas fa-print',
                        label = _L('printer_title') or '3D Printer',
                        action = function(entity)
                            local foundId = nil
                            if entity and DoesEntityExist(entity) then
                                for id, prop in pairs(SpawnedPrinters) do
                                    if prop == entity then foundId = id break end
                                end
                            end
                            if foundId then OpenPrinterMenu(foundId) end
                        end
                    }
                },
                distance = Config.TargetDistance or 2.5
            })
            isTargetModelRegistered = true
        end
    end)
end

RegisterNetEvent('qbx_3dprinter:client:initPrinters', function(printers)
    InitPrinterTargetModel()
    if printers then
        for id, data in pairs(printers) do
            CreatePrinterProp(id, data)
        end
    end
end)

function InitPrinters()
    InitPrinterTargetModel()
    CreateThread(function()
        local printers = nil
        local attempts = 0
        while not printers and attempts < 15 do
            attempts = attempts + 1
            pcall(function()
                printers = lib.callback.await('qbx_3dprinter:server:getPrinters', false)
            end)
            if not printers then Wait(300) end
        end

        if printers then
            for id, data in pairs(printers) do
                CreatePrinterProp(id, data)
            end
        end
    end)
end

local function OpenBlackmarketMenu()
    local options = {}
    for _, item in ipairs(Config.Blackmarket.items or {}) do
        table.insert(options, {
            title = item.label,
            description = ('$%s'):format(tostring(item.price)),
            icon = 'fas fa-shopping-cart',
            onSelect = function()
                local input = lib.inputDialog(item.label, {
                    { type = 'number', label = _L('invalid_amount'), default = 1, min = 1, max = 50 }
                })
                if input and input[1] then
                    local amount = tonumber(input[1])
                    if amount and amount > 0 then
                        local success, msg = lib.callback.await('qbx_3dprinter:server:buyBlackmarketItem', false, item.name, amount)
                        if success then
                            lib.notify({ title = _L('blackmarket_label'), description = msg, type = 'success' })
                        else
                            lib.notify({ title = _L('blackmarket_label'), description = msg or _L('buy_failed'), type = 'error' })
                        end
                    end
                end
            end
        })
    end

    lib.registerContext({
        id = 'qbx_3dprint_blackmarket_menu',
        title = _L('blackmarket_label'),
        options = options
    })
    lib.showContext('qbx_3dprint_blackmarket_menu')
end

function InitBlackmarketTarget()
    if not Config.Blackmarket or not Config.Blackmarket.enabled then return end

    RemoveBlackmarketTarget()

    local coords = Config.Blackmarket.coords or vec3(-30.6873, -347.0736, 46.5316)
    local radius = Config.Blackmarket.radius or 1.8

    pcall(function()
        if GetResourceState('ox_target') == 'started' then
            BlackmarketZoneId = exports.ox_target:addSphereZone({
                coords = coords,
                radius = radius,
                debug = false,
                options = {
                    {
                        name = 'qbx_3dprint_blackmarket_zone',
                        icon = Config.Blackmarket.icon or 'fas fa-user-secret',
                        label = _L('blackmarket_label'),
                        onSelect = function()
                            OpenBlackmarketMenu()
                        end
                    }
                }
            })
        elseif GetResourceState('qb-target') == 'started' then
            exports['qb-target']:AddCircleZone('qbx_3dprint_blackmarket_zone', coords, radius, {
                name = 'qbx_3dprint_blackmarket_zone',
                useZ = true,
            }, {
                options = {
                    {
                        icon = Config.Blackmarket.icon or 'fas fa-user-secret',
                        label = _L('blackmarket_label'),
                        action = function()
                            OpenBlackmarketMenu()
                        end
                    }
                },
                distance = 2.5
            })
        end
    end)
end

local function ManagePrinterPtfx(id, isPrinting, printerProp)
    if isPrinting and printerProp and DoesEntityExist(printerProp) then
        if not PrintingPtfx[id] then
            RequestNamedPtfxAsset('core')
            local timeout = 50
            while not HasNamedPtfxAssetLoaded('core') and timeout > 0 do
                Wait(10)
                timeout = timeout - 1
            end

            if HasNamedPtfxAssetLoaded('core') then
                UseParticleFxAssetNextCall('core')
                local ptfx = StartParticleFxLoopedOnEntity('ent_amb_sparking', printerProp, 0.0, 0.0, 0.35, 0.0, 0.0, 0.0, 0.4, false, false, false)
                PrintingPtfx[id] = ptfx
            end
        end
    else
        if PrintingPtfx[id] then
            StopParticleFxLooped(PrintingPtfx[id], false)
            PrintingPtfx[id] = nil
        end
    end
end

local function UpdatePrintedItemProp(id, data)
    local printerProp = SpawnedPrinters[id]
    if not printerProp or not DoesEntityExist(printerProp) then return end

    local activeItemKey = data.finished_item or data.current_print

    if not activeItemKey then
        if PrintedItemProps[id] and DoesEntityExist(PrintedItemProps[id]) then
            DeleteEntity(PrintedItemProps[id])
            PrintedItemProps[id] = nil
        end
        return
    end

    local recipe = Config.Recipes[activeItemKey]
    if not recipe then return end

    local propModelName = recipe.propModel
    if not propModelName and recipe.result and recipe.result.item then
        local itemResult = recipe.result.item
        if itemResult == 'weapon_snspistol' then propModelName = 'w_pi_sns_pistol'
        elseif itemResult == 'weapon_combatpistol' then propModelName = 'w_pi_combatpistol'
        elseif itemResult == 'weapon_machinepistol' then propModelName = 'w_ar_machinepistol'
        elseif itemResult == 'weapon_compactrifle' then propModelName = 'w_ar_compactrifle'
        elseif itemResult == 'weapon_switchblade' then propModelName = 'w_me_switchblade'
        else
            local weapHash = joaat(itemResult)
            if IsWeaponValid(weapHash) then
                propModelName = GetWeapontypeModel(weapHash)
            end
        end
    end

    if not propModelName then propModelName = 'prop_tool_pick' end

    local modelHash = type(propModelName) == 'number' and propModelName or joaat(propModelName)

    RequestModel(modelHash)
    local timeout = 500
    while not HasModelLoaded(modelHash) and timeout > 0 do
        Wait(10)
        timeout = timeout - 1
    end

    if not HasModelLoaded(modelHash) then
        modelHash = `prop_tool_pick`
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do Wait(10) end
    end

    if not PrintedItemProps[id] or not DoesEntityExist(PrintedItemProps[id]) or GetEntityModel(PrintedItemProps[id]) ~= modelHash then
        if PrintedItemProps[id] and DoesEntityExist(PrintedItemProps[id]) then
            DeleteEntity(PrintedItemProps[id])
        end

        local pCoords = GetEntityCoords(printerProp)
        local itemProp = CreateObject(modelHash, pCoords.x, pCoords.y, pCoords.z + 0.45, false, false, false)
        SetEntityCollision(itemProp, false, false)

        AttachEntityToEntity(itemProp, printerProp, 0, 0.0, 0.0, 0.45, 0.0, 0.0, 0.0, false, false, false, false, 2, true)

        PrintedItemProps[id] = itemProp
    end
end

CreateThread(function()
    while true do
        local now = GetCloudTimeAsInt() or os.time()

        for id, printerProp in pairs(SpawnedPrinters) do
            if DoesEntityExist(printerProp) then
                local data = PrinterData[id]
                if data then
                    UpdatePrintedItemProp(id, data)

                    local itemProp = PrintedItemProps[id]
                    if itemProp and DoesEntityExist(itemProp) then
                        if data.finished_item then
                            SetEntityAlpha(itemProp, 255, false)
                        elseif data.current_print and data.finish_time and data.finish_time > 0 then
                            local recipe = Config.Recipes[data.current_print]
                            local totalDuration = recipe and recipe.printTime or 60
                            local remaining = math.max(0, data.finish_time - now)
                            local elapsed = totalDuration - remaining
                            local pct = math.min(1.0, math.max(0.0, elapsed / totalDuration))

                            local alpha = math.floor(38 + (pct * 217))
                            SetEntityAlpha(itemProp, alpha, false)
                        end
                    end
                end
            end
        end

        Wait(500)
    end
end)

function CreatePrinterProp(id, data)
    if not data or not data.coords then return end

    id = tostring(id)

    local cx = tonumber(data.coords.x or data.coords[1]) or 0.0
    local cy = tonumber(data.coords.y or data.coords[2]) or 0.0
    local cz = tonumber(data.coords.z or data.coords[3]) or 0.0
    data.coords = vec3(cx, cy, cz)

    local rx = tonumber(data.rotation and (data.rotation.x or data.rotation[1])) or 0.0
    local ry = tonumber(data.rotation and (data.rotation.y or data.rotation[2])) or 0.0
    local rz = tonumber(data.rotation and (data.rotation.z or data.rotation[3])) or 0.0
    data.rotation = vec3(rx, ry, rz)

    PrinterData[id] = data

    if SpawnedPrinters[id] and DoesEntityExist(SpawnedPrinters[id]) then
        UpdatePrintedItemProp(id, data)
        return
    end

    local model = LoadModelSafely(Config.PrinterModel or 'bzzz_electro_prop_3dprinter')

    local prop = CreateObject(model, cx, cy, cz, false, false, false)
    SetEntityCoords(prop, cx, cy, cz, false, false, false, false)
    SetEntityRotation(prop, rx, ry, rz, 2, true)
    FreezeEntityPosition(prop, true)
    SetEntityCollision(prop, true, true)

    SpawnedPrinters[id] = prop
    UpdatePrintedItemProp(id, data)
end

CreateThread(function()
    while true do
        Wait(1500)
        pcall(function()
            local pPed = PlayerPedId()
            local pCoords = GetEntityCoords(pPed)
            local pBucket = GetEntityRoutingBucket(pPed) or 0

            for id, data in pairs(PrinterData) do
                if data and data.coords then
                    local cx = tonumber(data.coords.x or data.coords[1]) or 0.0
                    local cy = tonumber(data.coords.y or data.coords[2]) or 0.0
                    local cz = tonumber(data.coords.z or data.coords[3]) or 0.0
                    local targetVec = vec3(cx, cy, cz)

                    local dist = #(pCoords - targetVec)
                    local printerBucket = tonumber(data.bucket) or 0

                    local shouldSpawn = false
                    if dist <= 120.0 then
                        if printerBucket == pBucket then
                            shouldSpawn = true
                        end
                    end

                    if shouldSpawn then
                        if not SpawnedPrinters[id] or not DoesEntityExist(SpawnedPrinters[id]) then
                            CreatePrinterProp(id, data)
                        end
                    else
                        if SpawnedPrinters[id] and DoesEntityExist(SpawnedPrinters[id]) then
                            if PrintedItemProps[id] and DoesEntityExist(PrintedItemProps[id]) then
                                DeleteEntity(PrintedItemProps[id])
                                PrintedItemProps[id] = nil
                            end
                            DeleteEntity(SpawnedPrinters[id])
                            SpawnedPrinters[id] = nil
                        end
                    end
                end
            end
        end)
    end
end)

RegisterNetEvent('qbx_3dprinter:client:addPrinter', function(id, data)
    CreatePrinterProp(id, data)
end)

RegisterNetEvent('qbx_3dprinter:client:syncPrinter', function(id, data)
    if not data or not data.coords then return end
    id = tonumber(id) or id

    local cx = tonumber(data.coords.x or data.coords[1]) or 0.0
    local cy = tonumber(data.coords.y or data.coords[2]) or 0.0
    local cz = tonumber(data.coords.z or data.coords[3]) or 0.0
    data.coords = vec3(cx, cy, cz)

    local rx = tonumber(data.rotation and (data.rotation.x or data.rotation[1])) or 0.0
    local ry = tonumber(data.rotation and (data.rotation.y or data.rotation[2])) or 0.0
    local rz = tonumber(data.rotation and (data.rotation.z or data.rotation[3])) or 0.0
    data.rotation = vec3(rx, ry, rz)

    PrinterData[id] = data
    UpdatePrintedItemProp(id, data)

    if isUIOpen then
        SendNUIMessage({
            action = 'syncPrinter',
            printerId = id,
            data = data
        })
    end
end)

RegisterNetEvent('qbx_3dprinter:client:removePrinter', function(id)
    if not id then return end

    local pStr = tostring(id)
    local pNum = tonumber(id)

    local itemProp = PrintedItemProps[pStr] or (pNum and PrintedItemProps[pNum])
    if itemProp and DoesEntityExist(itemProp) then
        SetEntityAsMissionEntity(itemProp, true, true)
        DeleteEntity(itemProp)
    end
    PrintedItemProps[pStr] = nil
    if pNum then PrintedItemProps[pNum] = nil end

    local printerProp = SpawnedPrinters[pStr] or (pNum and SpawnedPrinters[pNum])
    if printerProp and DoesEntityExist(printerProp) then
        pcall(function()
            if GetResourceState('ox_target') == 'started' then
                exports.ox_target:removeLocalEntity(printerProp, 'qbx_3dprinter_' .. pStr)
            end
        end)
        SetEntityAsMissionEntity(printerProp, true, true)
        DeleteEntity(printerProp)
    end
    SpawnedPrinters[pStr] = nil
    if pNum then SpawnedPrinters[pNum] = nil end

    PrinterData[pStr] = nil
    if pNum then PrinterData[pNum] = nil end

    if isUIOpen then
        ClosePrinterNUI()
    end
end)

local currentOpenedPrinterId = nil

function OpenPrinterMenu(id, initialView)
    id = tonumber(id) or id or 1
    initialView = initialView or 'catalog'

    local success, errMsg = lib.callback.await('qbx_3dprinter:server:usePrinter', false, id)
    if not success then
        lib.notify({ title = _L('printer_title'), description = errMsg or _L('printer_in_use'), type = 'error' })
        return
    end

    currentOpenedPrinterId = id

    local data = PrinterData[id]
    if not data then
        local allPrinters = lib.callback.await('qbx_3dprinter:server:getPrinters', false) or {}
        data = allPrinters[id] or {
            id = id,
            owner = 'owner',
            coords = GetEntityCoords(PlayerPedId()),
            materials = { plastic_filament = 0, metal_filament = 0, printer_battery = 0 },
            current_print = nil,
            finish_time = 0,
            finished_item = nil
        }
        PrinterData[id] = data
    end

    local ownedBlueprints = {}
    pcall(function()
        ownedBlueprints = lib.callback.await('qbx_3dprinter:server:checkPlayerBlueprints', false) or {}
    end)

    local lang = Config.Language or 'cs'
    local langData = {}
    local localeStr = LoadResourceFile(GetCurrentResourceName(), ('locales/%s.json'):format(lang))
    if localeStr then
        langData = json.decode(localeStr) or {}
    end

    isUIOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'openPrinter',
        printerId = id,
        initialView = initialView,
        data = data,
        recipes = Config.Recipes or {},
        shopBlueprints = Config.ShopBlueprints or {},
        ownedBlueprints = ownedBlueprints,
        locales = langData
    })
end

function ClosePrinterNUI()
    if isUIOpen then
        if currentOpenedPrinterId then
            TriggerServerEvent('qbx_3dprinter:server:releasePrinter', currentOpenedPrinterId)
            currentOpenedPrinterId = nil
        end
        isUIOpen = false
        SetNuiFocus(false, false)
    end
end

RegisterNUICallback('buyBlueprint', function(data, cb)
    if not data or not data.itemKey then cb('error') return end

    local success, message = lib.callback.await('qbx_3dprinter:server:buyBlueprint', false, data.itemKey)
    if success then
        lib.notify({ title = _L('darkweb_cad'), description = message, type = 'success' })
        local owned = lib.callback.await('qbx_3dprinter:server:checkPlayerBlueprints', false) or {}
        cb({ success = true, owned = owned })
    else
        lib.notify({ title = _L('darkweb_cad'), description = message or _L('buy_failed'), type = 'error' })
        cb({ success = false, message = message })
    end
end)

RegisterNUICallback('closeUI', function(data, cb)
    ClosePrinterNUI()
    cb('ok')
end)

RegisterNUICallback('addMaterial', function(data, cb)
    if not data.printerId or not data.item or not data.amount then cb('error') return end

    local success, message = lib.callback.await('qbx_3dprinter:server:addMaterial', false, data.printerId, data.item, data.amount)
    if success then
        lib.notify({ title = _L('printer_title'), description = message or _L('material_added'), type = 'success' })
        cb('ok')
    else
        lib.notify({ title = _L('printer_title'), description = message or _L('cannot_add_material'), type = 'error' })
        cb('error')
    end
end)

RegisterNUICallback('startPrint', function(data, cb)
    if not data.printerId or not data.recipeKey then cb('error') return end

    local success, message = lib.callback.await('qbx_3dprinter:server:startPrint', false, data.printerId, data.recipeKey)
    if success then
        lib.notify({ title = _L('printer_title'), description = _L('print_started_notify'), type = 'success' })
        cb('ok')
    else
        lib.notify({ title = _L('printer_title'), description = message or _L('cannot_start_print'), type = 'error' })
        cb('error')
    end
end)

RegisterNUICallback('pickupPrint', function(data, cb)
    if not data.printerId then cb('error') return end

    local success, message = lib.callback.await('qbx_3dprinter:server:pickupPrint', false, data.printerId)
    if success then
        lib.notify({ title = _L('printer_title'), description = _L('print_picked'), type = 'success' })
        cb('ok')
    else
        lib.notify({ title = _L('printer_title'), description = message or _L('cannot_pickup'), type = 'error' })
        cb('error')
    end
end)

RegisterNUICallback('repairPrinter', function(data, cb)
    if not data or not data.printerId then cb({ success = false }) return end

    local success, message = lib.callback.await('qbx_3dprinter:server:repairPrinter', false, data.printerId)
    if success then
        lib.notify({ title = _L('printer_title'), description = message, type = 'success' })
        cb({ success = true })
    else
        lib.notify({ title = _L('printer_title'), description = message or _L('repair_failed'), type = 'error' })
        cb({ success = false })
    end
end)

RegisterNUICallback('cancelPrint', function(data, cb)
    if not data.printerId then cb('error') return end

    local success = lib.callback.await('qbx_3dprinter:server:cancelPrint', false, data.printerId)
    if success then
        lib.notify({ title = _L('printer_title'), description = _L('print_cancelled'), type = 'inform' })
        cb('ok')
    else
        cb('error')
    end
end)

RegisterNUICallback('packPrinter', function(data, cb)
    if not data.printerId then cb('error') return end

    local success, message = lib.callback.await('qbx_3dprinter:server:packPrinter', false, data.printerId)
    if success then
        ClosePrinterNUI()
        lib.notify({ title = _L('printer_title'), description = message or _L('pack_success'), type = 'success' })
        cb('ok')
    else
        lib.notify({ title = _L('printer_title'), description = message or _L('cannot_pack_busy'), type = 'error' })
        cb('error')
    end
end)

RegisterNUICallback('extractMaterials', function(data, cb)
    if not data or not data.printerId then cb({ success = false }) return end

    local success, message = lib.callback.await('qbx_3dprinter:server:extractMaterials', false, data.printerId)
    if success then
        lib.notify({ title = _L('printer_title'), description = message, type = 'success' })
        cb({ success = true })
    else
        lib.notify({ title = _L('printer_title'), description = message or _L('cannot_extract'), type = 'error' })
        cb({ success = false })
    end
end)
