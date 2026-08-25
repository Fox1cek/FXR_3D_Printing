DB = {}

function DB.Init(cb)
    CreateThread(function()
        pcall(function()
            MySQL.query.await([[
                CREATE TABLE IF NOT EXISTS `fxr_3dprinter` (
                    `id` INT AUTO_INCREMENT PRIMARY KEY,
                    `owner` VARCHAR(50) NOT NULL,
                    `coords` LONGTEXT NOT NULL,
                    `rotation` LONGTEXT NOT NULL,
                    `materials` LONGTEXT DEFAULT NULL,
                    `current_print` VARCHAR(50) DEFAULT NULL,
                    `finish_time` INT DEFAULT 0,
                    `finished_item` VARCHAR(50) DEFAULT NULL,
                    `finished_count` INT DEFAULT 0,
                    `durability` INT DEFAULT 100,
                    `bucket` INT DEFAULT 0
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            ]])
        end)

        pcall(function()
            MySQL.query.await([[
                ALTER TABLE `fxr_3dprinter` ADD COLUMN IF NOT EXISTS `bucket` INT DEFAULT 0;
            ]])
        end)

        pcall(function()
            MySQL.query.await([[
                CREATE TABLE IF NOT EXISTS `fxr_3d_blueprints` (
                    `citizenid` VARCHAR(50) NOT NULL,
                    `blueprint` VARCHAR(50) NOT NULL,
                    `purchased_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (`citizenid`, `blueprint`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            ]])
        end)

        if cb then cb() end
    end)
end

function DB.LoadAllPrinters(cb)
    MySQL.query('SELECT * FROM `fxr_3dprinter`', {}, function(results)
        local printers = {}
        if results and #results > 0 then
            for i = 1, #results do
                local row = results[i]
                local coords = type(row.coords) == 'string' and json.decode(row.coords) or row.coords
                local rotation = type(row.rotation) == 'string' and json.decode(row.rotation) or row.rotation
                local materials = type(row.materials) == 'string' and json.decode(row.materials) or (row.materials or {})

                local cx = tonumber(coords and (coords.x or coords[1])) or 0.0
                local cy = tonumber(coords and (coords.y or coords[2])) or 0.0
                local cz = tonumber(coords and (coords.z or coords[3])) or 0.0

                local rx = tonumber(rotation and (rotation.x or rotation[1])) or 0.0
                local ry = tonumber(rotation and (rotation.y or rotation[2])) or 0.0
                local rz = tonumber(rotation and (rotation.z or rotation[3])) or 0.0

                local currentPrint = (row.current_print and row.current_print ~= '' and row.current_print ~= 'NULL') and row.current_print or nil
                local finishedItem = (row.finished_item and row.finished_item ~= '' and row.finished_item ~= 'NULL') and row.finished_item or nil

                local pId = tostring(row.id)
                printers[pId] = {
                    id = row.id,
                    owner = row.owner,
                    coords = vec3(cx, cy, cz),
                    rotation = vec3(rx, ry, rz),
                    materials = materials,
                    current_print = currentPrint,
                    finish_time = row.finish_time or 0,
                    finished_item = finishedItem,
                    finished_count = row.finished_count or 0,
                    durability = row.durability or 100,
                    bucket = tonumber(row.bucket) or 0
                }
            end
        end
        if cb then cb(printers) end
    end)
end

function DB.CreatePrinter(owner, coords, rotation, bucket, cb)
    local cx = tonumber(coords.x or coords[1]) or 0.0
    local cy = tonumber(coords.y or coords[2]) or 0.0
    local cz = tonumber(coords.z or coords[3]) or 0.0

    local rx = tonumber(rotation and (rotation.x or rotation[1])) or 0.0
    local ry = tonumber(rotation and (rotation.y or rotation[2])) or 0.0
    local rz = tonumber(rotation and (rotation.z or rotation[3])) or 0.0

    local coordsJson = json.encode({ x = cx, y = cy, z = cz })
    local rotJson = json.encode({ x = rx, y = ry, z = rz })
    local defaultMaterials = json.encode({ plastic_filament = 0, metal_filament = 0, printer_battery = 0 })
    local bVal = tonumber(bucket) or 0

    MySQL.insert('INSERT INTO `fxr_3dprinter` (owner, coords, rotation, materials, bucket) VALUES (?, ?, ?, ?, ?)', {
        owner, coordsJson, rotJson, defaultMaterials, bVal
    }, function(insertId)
        if cb then cb(insertId) end
    end)
end

function DB.UpdatePrinter(id, printerData)
    if not id then return end
    local cx = tonumber(printerData.coords.x or printerData.coords[1]) or 0.0
    local cy = tonumber(printerData.coords.y or printerData.coords[2]) or 0.0
    local cz = tonumber(printerData.coords.z or printerData.coords[3]) or 0.0

    local rx = tonumber(printerData.rotation and (printerData.rotation.x or printerData.rotation[1])) or 0.0
    local ry = tonumber(printerData.rotation and (printerData.rotation.y or printerData.rotation[2])) or 0.0
    local rz = tonumber(printerData.rotation and (printerData.rotation.z or printerData.rotation[3])) or 0.0

    local coordsJson = json.encode({ x = cx, y = cy, z = cz })
    local rotJson = json.encode({ x = rx, y = ry, z = rz })
    local matJson = json.encode(printerData.materials or {})

    MySQL.update('UPDATE `fxr_3dprinter` SET coords = ?, rotation = ?, materials = ?, current_print = ?, finish_time = ?, finished_item = ?, finished_count = ?, durability = ? WHERE id = ?', {
        coordsJson,
        rotJson,
        matJson,
        printerData.current_print,
        printerData.finish_time or 0,
        printerData.finished_item,
        printerData.finished_count or 0,
        printerData.durability or 100,
        id
    })
end

function DB.DeletePrinter(id)
    if not id then return end
    MySQL.query('DELETE FROM `fxr_3dprinter` WHERE id = ?', { id })
end

function DB.GetPlayerBlueprints(citizenid, cb)
    if not citizenid then if cb then cb({}) end return end

    MySQL.query('SELECT blueprint FROM `fxr_3d_blueprints` WHERE citizenid = ?', { citizenid }, function(results)
        local owned = {}
        if results and #results > 0 then
            for i = 1, #results do
                owned[results[i].blueprint] = true
            end
        end
        if cb then cb(owned) end
    end)
end

function DB.AddPlayerBlueprint(citizenid, blueprint, cb)
    if not citizenid or not blueprint then if cb then cb(false) end return end

    MySQL.insert('INSERT IGNORE INTO `fxr_3d_blueprints` (citizenid, blueprint) VALUES (?, ?)', {
        citizenid, blueprint
    }, function(affectedRows)
        if cb then cb(true) end
    end)
end
