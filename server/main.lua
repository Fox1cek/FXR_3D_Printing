local ActivePrinters = {}
local PrinterInUse = {}

local function SendDiscordLog(title, description, color, fields)
    if not Config.DiscordWebhook or Config.DiscordWebhook == '' or Config.DiscordWebhook == 'YOUR_DISCORD_WEBHOOK_URL_HERE' then
        return
    end

    local embed = {
        {
            ['title'] = title,
            ['description'] = description,
            ['color'] = color or 3447003,
            ['fields'] = fields or {},
            ['footer'] = {
                ['text'] = 'FXR 3D Printer System • ' .. os.date('%d.%m.%Y - %H:%M:%S')
            }
        }
    }

    PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers) end, 'POST', json.encode({
        username = 'FXR 3D Printer Logs',
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

lib.callback.register('qbx_3dprinter:server:usePrinter', function(source, printerId)
    printerId = tonumber(printerId) or printerId
    if not printerId then return false, _L('invalid_printer_id') end

    local player = exports.qbx_core:GetPlayer(source)
    local citizenid = player and player.PlayerData and player.PlayerData.citizenid or tostring(source)

    local currentOccupant = PrinterInUse[printerId]
    if currentOccupant then
        if currentOccupant.citizenid == citizenid then
            currentOccupant.time = os.time()
            return true
        end

        if (os.time() - (currentOccupant.time or 0)) < 30 and GetPlayerPing(currentOccupant.source) > 0 then
            return false, _L('printer_in_use')
        end
    end

    PrinterInUse[printerId] = { source = source, citizenid = citizenid, time = os.time() }
    return true
end)

RegisterNetEvent('qbx_3dprinter:server:releasePrinter', function(printerId)
    local src = source
    printerId = tonumber(printerId) or printerId
    if printerId and PrinterInUse[printerId] and PrinterInUse[printerId].source == src then
        PrinterInUse[printerId] = nil
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for pId, userSrc in pairs(PrinterInUse) do
        if userSrc == src then
            PrinterInUse[pId] = nil
        end
    end
end)

local ActivePrintersLoaded = false

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    PrinterInUse = {}
    ActivePrintersLoaded = false

    DB.Init(function()
        DB.LoadAllPrinters(function(printers)
            ActivePrinters = printers or {}
            ActivePrintersLoaded = true
            TriggerClientEvent('qbx_3dprinter:client:initPrinters', -1, ActivePrinters)
        end)
    end)
end)

CreateThread(function()
    Wait(1000)
    pcall(function()
        exports.qbx_core:CreateUseableItem('3d_printer', function(source, item)
            TriggerClientEvent('qbx_3dprinter:client:startPlacement', source)
        end)
    end)
end)

lib.callback.register('qbx_3dprinter:server:getPrinters', function(source)
    local timeout = 100
    while not ActivePrintersLoaded and timeout > 0 do
        Wait(50)
        timeout = timeout - 1
    end
    return ActivePrinters
end)

lib.callback.register('qbx_3dprinter:server:placePrinter', function(source, coords, rotation)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    local citizenid = player.PlayerData.citizenid
    local charName = (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or '')

    local cx = tonumber(coords and (coords.x or coords[1])) or 0.0
    local cy = tonumber(coords and (coords.y or coords[2])) or 0.0
    local cz = tonumber(coords and (coords.z or coords[3])) or 0.0
    local vecCoords = vec3(cx, cy, cz)

    local rx = tonumber(rotation and (rotation.x or rotation[1])) or 0.0
    local ry = tonumber(rotation and (rotation.y or rotation[2])) or 0.0
    local rz = tonumber(rotation and (rotation.z or rotation[3])) or 0.0
    local vecRot = vec3(rx, ry, rz)

    local ownedCount = 0
    for _, printer in pairs(ActivePrinters) do
        if printer.owner == citizenid then
            ownedCount = ownedCount + 1
        end
    end

    if ownedCount >= Config.MaxPrintersPerPlayer then
        return false, _L('max_printers_reached', Config.MaxPrintersPerPlayer)
    end

    local playerBucket = GetPlayerRoutingBucket(source) or 0

    pcall(function()
        exports.ox_inventory:RemoveItem(source, '3d_printer', 1)
    end)

    DB.CreatePrinter(citizenid, vecCoords, vecRot, playerBucket, function(insertId)
        if insertId then
            local pId = tostring(insertId)
            ActivePrinters[pId] = {
                id = insertId,
                owner = citizenid,
                coords = vecCoords,
                rotation = vecRot,
                materials = { plastic_filament = 0, metal_filament = 0, printer_battery = 0 },
                current_print = nil,
                finish_time = 0,
                finished_item = nil,
                finished_count = 0,
                durability = 100,
                bucket = playerBucket
            }

            TriggerClientEvent('qbx_3dprinter:client:addPrinter', -1, pId, ActivePrinters[pId])

            SendDiscordLog('3D Printer Placed', ('Player **%s** (`%s`) placed 3D printer **ID: %s**'):format(charName, citizenid, tostring(insertId)), 3066993, {
                { name = 'Position', value = ('vec3(%.2f, %.2f, %.2f)'):format(cx, cy, cz), inline = true },
            })
        end
    end)

    return true
end)

local function GetActivePrinter(printerId)
    if not printerId then return nil end
    local pStr = tostring(printerId)
    local pNum = tonumber(printerId)
    return ActivePrinters[pStr] or (pNum and ActivePrinters[pNum]) or nil
end

lib.callback.register('qbx_3dprinter:server:addMaterial', function(source, printerId, item, amount)
    local printer = GetActivePrinter(printerId)
    if not printer then return false, _L('printer_not_found') end

    amount = tonumber(amount) or 0
    if amount <= 0 then return false, _L('invalid_amount') end

    local player = exports.qbx_core:GetPlayer(source)
    local charName = player and ((player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or '')) or _L('unknown_player')

    local itemLabels = {
        plastic_filament = _L('plastic_label'),
        metal_filament = _L('metal_label'),
        printer_battery = _L('battery_label')
    }
    local itemLabel = itemLabels[item] or item

    local countInInv = exports.ox_inventory:GetItemCount(source, item) or 0
    if countInInv < amount then
        return false, _L('not_enough_inv_mat', itemLabel, tostring(countInInv), tostring(amount))
    end

    if not printer.materials then printer.materials = { plastic_filament = 0, metal_filament = 0, printer_battery = 0 } end

    local maxCap = Config.MaxMaterialStorage[item] or 100
    local currentMat = printer.materials[item] or 0

    local addUnits = amount
    local itemToRemove = item
    if item == 'printer_battery' then
        addUnits = amount * 2
    end

    if (currentMat + addUnits) > maxCap then
        if item == 'printer_battery' then
            addUnits = maxCap - currentMat
            amount = math.floor(addUnits / 2)
            if amount <= 0 then return false, _L('battery_cap_full') end
            addUnits = amount * 2
        else
            addUnits = maxCap - currentMat
            amount = addUnits
            if amount <= 0 then return false, _L('mat_cap_full') end
        end
    end

    local removed = exports.ox_inventory:RemoveItem(source, itemToRemove, amount)
    if not removed then return false, _L('rem_item_err', tostring(amount), itemLabel) end

    printer.materials[item] = (printer.materials[item] or 0) + addUnits
    DB.UpdatePrinter(printer.id, printer)

    TriggerClientEvent('qbx_3dprinter:client:syncPrinter', -1, printer.id, printer)

    SendDiscordLog('Material Refilled', ('Player **%s** refilled material in printer **ID: %s**.'):format(charName, tostring(printer.id)), 15105570, {
        { name = 'Material', value = itemLabel, inline = true },
        { name = 'Amount', value = tostring(amount), inline = true },
    })

    return true, _L('refill_success', tostring(amount), itemLabel)
end)

lib.callback.register('qbx_3dprinter:server:startPrint', function(source, printerId, recipeKey)
    local printer = GetActivePrinter(printerId)
    if not printer then return false, _L('printer_not_found') end

    if printer.current_print or printer.finished_item then
        return false, _L('already_busy')
    end

    local recipe = Config.Recipes[recipeKey]
    if not recipe then return false, _L('unknown_recipe') end

    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, _L('player_not_found') end
    local citizenid = player.PlayerData.citizenid
    local charName = (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or '')

    if printer.owner and printer.owner ~= citizenid then
        return false, _L('not_owner')
    end

    local currentDurability = printer.durability or 100
    if currentDurability <= 0 then
        return false, _L('printer_damaged')
    end

    for matItem, requiredCount in pairs(recipe.materials) do
        local available = (printer.materials and printer.materials[matItem]) or 0
        if available < requiredCount then
            local matLabels = { plastic_filament = _L('plastic_label'), metal_filament = _L('metal_label'), printer_battery = _L('battery_label') }
            local mLabel = matLabels[matItem] or matItem
            return false, _L('not_enough_mat_print', tostring(requiredCount), mLabel, tostring(available))
        end
    end

    if recipe.blueprint then
        local p = promise.new()
        DB.GetPlayerBlueprints(citizenid, function(owned)
            p:resolve(owned[recipe.blueprint] or false)
        end)

        local hasBlueprint = Citizen.Await(p)
        if not hasBlueprint then
            return false, _L('missing_blueprint')
        end
    end

    for matItem, requiredCount in pairs(recipe.materials) do
        printer.materials[matItem] = printer.materials[matItem] - requiredCount
    end

    local now = os.time()
    local finishTime = now + recipe.printTime

    local durabilityLoss = recipe.durabilityLoss or (Config.Durability and Config.Durability.lossPerPrint) or 10
    printer.durability = math.max(0, currentDurability - durabilityLoss)

    printer.current_print = recipeKey
    printer.finish_time = finishTime
    DB.UpdatePrinter(printerId, printer)

    TriggerClientEvent('qbx_3dprinter:client:syncPrinter', -1, printerId, printer)

    SendDiscordLog('Print Started', ('Player **%s** (`%s`) started printing on printer **ID: %s**.'):format(charName, citizenid, tostring(printerId)), 3447003, {
        { name = 'Model', value = recipe.label, inline = true },
        { name = 'Print Time', value = ('%s sec'):format(tostring(recipe.printTime)), inline = true },
    })

    return true
end)

lib.callback.register('qbx_3dprinter:server:repairPrinter', function(source, printerId)
    local printer = GetActivePrinter(printerId)
    if not printer then return false, _L('printer_not_found') end

    if (printer.durability or 100) >= 100 then
        return false, _L('perfect_condition')
    end

    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, _L('player_not_found') end
    local charName = (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or '')

    local item = (Config.Durability and Config.Durability.repairCostItem) or 'metal_filament'
    local cost = (Config.Durability and Config.Durability.repairCostAmount) or 15

    local hasItem = exports.ox_inventory:GetItemCount(source, item) or 0
    if hasItem < cost then
        return false, _L('not_enough_repair_mat', tostring(cost))
    end

    local removed = exports.ox_inventory:RemoveItem(source, item, cost)
    if not removed then return false, _L('repair_mat_remove_err') end

    printer.durability = 100
    DB.UpdatePrinter(printerId, printer)
    TriggerClientEvent('qbx_3dprinter:client:syncPrinter', -1, printerId, printer)

    SendDiscordLog('Printer Repaired', ('Player **%s** repaired printer **ID: %s**.'):format(charName, tostring(printerId)), 3066993)

    return true, _L('repaired_success')
end)

lib.callback.register('qbx_3dprinter:server:pickupPrint', function(source, printerId)
    local printer = GetActivePrinter(printerId)
    if not printer or not printer.finished_item then return false, _L('no_print_to_pickup') end

    local recipe = Config.Recipes[printer.finished_item]
    if not recipe then return false end

    local player = exports.qbx_core:GetPlayer(source)
    local charName = player and ((player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or '')) or _L('unknown_player')

    local itemToGive = recipe.result.item
    local countToGive = recipe.result.count or 1
    local metadata = recipe.result.metadata and table.clone(recipe.result.metadata) or {}

    if metadata and metadata.serial then
        metadata.serial = Utils.Generate3DSerial(metadata.serial)
    end

    local canCarry = exports.ox_inventory:CanCarryItem(source, itemToGive, countToGive)
    if not canCarry then
        return false, _L('inventory_full')
    end

    exports.ox_inventory:AddItem(source, itemToGive, countToGive, metadata)

    local pickedItem = printer.finished_item
    printer.finished_item = nil
    printer.finished_count = 0
    DB.UpdatePrinter(printerId, printer)

    TriggerClientEvent('qbx_3dprinter:client:syncPrinter', -1, printerId, printer)

    SendDiscordLog('Print Collected', ('Player **%s** collected print from printer **ID: %s**.'):format(charName, tostring(printerId)), 5763719)

    return true
end)

lib.callback.register('qbx_3dprinter:server:cancelPrint', function(source, printerId)
    local printer = GetActivePrinter(printerId)
    if not printer then return false end

    printer.current_print = nil
    printer.finish_time = 0
    DB.UpdatePrinter(printerId, printer)

    TriggerClientEvent('qbx_3dprinter:client:syncPrinter', -1, printerId, printer)
    return true
end)

lib.callback.register('qbx_3dprinter:server:packPrinter', function(source, printerId)
    local printer = GetActivePrinter(printerId)
    if not printer then return false, _L('printer_not_found') end

    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, _L('player_not_found') end
    local charName = (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or '')

    local isPrinting = (printer.current_print and printer.current_print ~= '' and printer.current_print ~= 'NULL')
    local isFinished = (printer.finished_item and printer.finished_item ~= '' and printer.finished_item ~= 'NULL')

    if isPrinting or isFinished then
        return false, _L('cannot_pack_busy')
    end

    local canCarry = exports.ox_inventory:CanCarryItem(source, '3d_printer', 1)
    if not canCarry then return false, _L('inventory_full') end

    exports.ox_inventory:AddItem(source, '3d_printer', 1)

    local returnedText = {}
    local mats = printer.materials or {}

    local plasticToReturn = mats.plastic_filament or 0
    if plasticToReturn > 0 then
        exports.ox_inventory:AddItem(source, 'plastic_filament', plasticToReturn)
        table.insert(returnedText, ('%sx %s'):format(tostring(plasticToReturn), _L('plastic_short')))
    end

    local metalToReturn = mats.metal_filament or 0
    if metalToReturn > 0 then
        exports.ox_inventory:AddItem(source, 'metal_filament', metalToReturn)
        table.insert(returnedText, ('%sx %s'):format(tostring(metalToReturn), _L('metal_short')))
    end

    local batteryCharges = mats.printer_battery or 0
    local batteriesToReturn = math.floor(batteryCharges / 2)
    if batteriesToReturn > 0 then
        exports.ox_inventory:AddItem(source, 'printer_battery', batteriesToReturn)
        table.insert(returnedText, ('%sx %s'):format(tostring(batteriesToReturn), _L('battery_short')))
    end

    DB.DeletePrinter(printer.id)
    ActivePrinters[tostring(printer.id)] = nil
    if tonumber(printer.id) then ActivePrinters[tonumber(printer.id)] = nil end

    TriggerClientEvent('qbx_3dprinter:client:removePrinter', -1, printer.id)

    local retSummary = #returnedText > 0 and (' ' .. table.concat(returnedText, ', ')) or ''
    SendDiscordLog('Printer Packed', ('Player **%s** packed printer **ID: %s**.'):format(charName, tostring(printerId)), 10038562)

    return true, (_L('printer_packed') .. retSummary)
end)

lib.callback.register('qbx_3dprinter:server:extractMaterials', function(source, printerId)
    local printer = GetActivePrinter(printerId)
    if not printer then return false, _L('printer_not_found') end

    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, _L('player_not_found') end

    if printer.current_print then
        return false, _L('cannot_extract_printing')
    end

    local mats = printer.materials or {}
    local plasticToReturn = mats.plastic_filament or 0
    local metalToReturn = mats.metal_filament or 0
    local batteryCharges = mats.printer_battery or 0
    local batteriesToReturn = math.floor(batteryCharges / 2)

    if plasticToReturn == 0 and metalToReturn == 0 and batteriesToReturn == 0 then
        return false, _L('no_mats_in_printer')
    end

    local returnedText = {}

    if plasticToReturn > 0 then
        exports.ox_inventory:AddItem(source, 'plastic_filament', plasticToReturn)
        table.insert(returnedText, ('%sx %s'):format(tostring(plasticToReturn), _L('plastic_short')))
        printer.materials.plastic_filament = 0
    end

    if metalToReturn > 0 then
        exports.ox_inventory:AddItem(source, 'metal_filament', metalToReturn)
        table.insert(returnedText, ('%sx %s'):format(tostring(metalToReturn), _L('metal_short')))
        printer.materials.metal_filament = 0
    end

    if batteriesToReturn > 0 then
        exports.ox_inventory:AddItem(source, 'printer_battery', batteriesToReturn)
        table.insert(returnedText, ('%sx %s'):format(tostring(batteriesToReturn), _L('battery_short')))
        printer.materials.printer_battery = printer.materials.printer_battery - (batteriesToReturn * 2)
    end

    DB.UpdatePrinter(printerId, printer)
    TriggerClientEvent('qbx_3dprinter:client:syncPrinter', -1, printerId, printer)

    local retSummary = table.concat(returnedText, ', ')
    return true, _L('extracted_mats', retSummary)
end)

lib.callback.register('qbx_3dprinter:server:buyBlueprint', function(source, itemKey)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, _L('player_not_found') end

    local citizenid = player.PlayerData.citizenid
    local charName = (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or '')

    local blueprintData = nil
    for _, bp in ipairs(Config.ShopBlueprints or {}) do
        if bp.item == itemKey then
            blueprintData = bp
            break
        end
    end

    if not blueprintData then
        return false, _L('bp_not_found')
    end

    local pCheck = promise.new()
    DB.GetPlayerBlueprints(citizenid, function(owned)
        pCheck:resolve(owned[itemKey] or false)
    end)
    local alreadyOwned = Citizen.Await(pCheck)

    if alreadyOwned then
        return false, _L('bp_already_owned')
    end

    local price = blueprintData.price
    local bankMoney = player.PlayerData.money.bank or 0
    local cashMoney = player.PlayerData.money.cash or 0

    if bankMoney < price and cashMoney < price then
        return false, _L('not_enough_money', tostring(price))
    end

    if bankMoney >= price then
        player.Functions.RemoveMoney('bank', price, '3dprinter-blueprint-buy')
    else
        player.Functions.RemoveMoney('cash', price, '3dprinter-blueprint-buy')
    end

    local pAdd = promise.new()
    DB.AddPlayerBlueprint(citizenid, itemKey, function(ok)
        pAdd:resolve(ok)
    end)
    Citizen.Await(pAdd)

    SendDiscordLog('CAD Blueprint Purchased', ('Player **%s** (`%s`) purchased CAD blueprint **%s**.'):format(charName, citizenid, blueprintData.label), 10181046)

    return true, _L('bp_buy_success', blueprintData.label, tostring(price))
end)

lib.callback.register('qbx_3dprinter:server:buyBlackmarketItem', function(source, itemName, amount)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, _L('player_not_found') end

    amount = tonumber(amount) or 1
    if amount <= 0 then return false, _L('invalid_amount') end

    local charName = (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or '')

    local shopItem = nil
    if Config.Blackmarket and Config.Blackmarket.items then
        for _, item in ipairs(Config.Blackmarket.items) do
            if item.name == itemName then
                shopItem = item
                break
            end
        end
    end

    if not shopItem then
        return false, _L('item_not_found')
    end

    local totalPrice = shopItem.price * amount
    local cash = player.PlayerData.money.cash or 0
    local bank = player.PlayerData.money.bank or 0

    if cash < totalPrice and bank < totalPrice then
        return false, _L('not_enough_money', tostring(totalPrice))
    end

    local canCarry = exports.ox_inventory:CanCarryItem(source, itemName, amount)
    if not canCarry then
        return false, _L('inventory_full')
    end

    if cash >= totalPrice then
        player.Functions.RemoveMoney('cash', totalPrice, '3dprinter-blackmarket')
    else
        player.Functions.RemoveMoney('bank', totalPrice, '3dprinter-blackmarket')
    end

    exports.ox_inventory:AddItem(source, itemName, amount)

    SendDiscordLog('Blackmarket Purchase', ('Player **%s** bought item **%s** x%s.'):format(charName, shopItem.label, tostring(amount)), 15844367)

    return true, _L('buy_success', tostring(amount), shopItem.label, tostring(totalPrice))
end)

MySQL.ready(function()
    if Config.Blackmarket and Config.Blackmarket.enabled then
        pcall(function()
            if GetResourceState('ox_inventory') == 'started' then
                local inventoryItems = {}
                for _, item in ipairs(Config.Blackmarket.items or {}) do
                    table.insert(inventoryItems, { name = item.name, price = item.price })
                end

                exports.ox_inventory:registerShop('3dprint_blackmarket', {
                    name = Config.Blackmarket.label or '3D Print Blackmarket',
                    inventory = inventoryItems,
                    locations = {
                        Config.Blackmarket.coords
                    }
                })
            end
        end)
    end
end)

lib.callback.register('qbx_3dprinter:server:checkPlayerBlueprints', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end

    local citizenid = player.PlayerData.citizenid
    local p = promise.new()

    DB.GetPlayerBlueprints(citizenid, function(owned)
        p:resolve(owned or {})
    end)

    return Citizen.Await(p) or {}
end)

CreateThread(function()
    while true do
        Wait(5000)
        local currentTime = os.time()

        for id, printer in pairs(ActivePrinters) do
            if printer.current_print and printer.finish_time > 0 then
                if currentTime >= printer.finish_time then
                    printer.finished_item = printer.current_print
                    printer.finished_count = 1
                    printer.current_print = nil
                    printer.finish_time = 0

                    DB.UpdatePrinter(id, printer)
                    TriggerClientEvent('qbx_3dprinter:client:syncPrinter', -1, id, printer)
                end
            end
        end
    end
end)
