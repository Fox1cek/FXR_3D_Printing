local PlacingPrinter = false
local PreviewProp = nil

function LoadModelSafely(modelName)
    local model = type(modelName) == 'number' and modelName or joaat(modelName or 'bzzz_electro_prop_3dprinter')

    RequestModel(model)
    local timeout = 1000
    while not HasModelLoaded(model) and timeout > 0 do
        Wait(10)
        timeout = timeout - 1
    end

    if not HasModelLoaded(model) then
        model = `prop_printer_01`
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(10) end
    end

    return model
end

local function RaycastCamera()
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local forwardVector = RotationToDirection(camRot)
    local targetCoords = camCoords + forwardVector * 10.0

    local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, targetCoords.x, targetCoords.y, targetCoords.z, -1, PlayerPedId(), 0)
    local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)
    return hit, endCoords, surfaceNormal
end

function RotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local num = math.abs(math.cos(x))
    return vec3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

RegisterNetEvent('qbx_3dprinter:client:startPlacement', function()
    if PlacingPrinter then return end
    PlacingPrinter = true

    local model = LoadModelSafely(Config.PrinterModel or 'bzzz_electro_prop_3dprinter')

    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    PreviewProp = CreateObject(model, pCoords.x, pCoords.y, pCoords.z, false, false, false)
    SetEntityAlpha(PreviewProp, 180, false)
    SetEntityCollision(PreviewProp, false, false)

    lib.showTextUI(_L('placement_controls'), { position = 'top-center' })

    local heading = GetEntityHeading(ped)

    CreateThread(function()
        while PlacingPrinter do
            Wait(0)
            DisableControlAction(0, 14, true)
            DisableControlAction(0, 15, true)
            DisableControlAction(0, 241, true)
            DisableControlAction(0, 242, true)
            DisableControlAction(0, 45, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 174, true)
            DisableControlAction(0, 175, true)
            DisableControlAction(0, 38, true)
            DisableControlAction(0, 47, true)

            local hit, worldCoords, normal = RaycastCamera()
            if hit then
                SetEntityCoords(PreviewProp, worldCoords.x, worldCoords.y, worldCoords.z)
                SetEntityHeading(PreviewProp, heading)

                local dist = #(GetEntityCoords(ped) - worldCoords)
                if dist <= 4.0 then
                    SetEntityDrawOutline(PreviewProp, true)
                    SetEntityDrawOutlineColor(0, 255, 0, 255)
                else
                    SetEntityDrawOutline(PreviewProp, true)
                    SetEntityDrawOutlineColor(255, 0, 0, 255)
                end

                if IsDisabledControlPressed(0, 15) or IsDisabledControlPressed(0, 241) or IsDisabledControlPressed(0, 175) or IsDisabledControlPressed(0, 45) or IsDisabledControlPressed(0, 140) then
                    heading = (heading + 3.0) % 360.0
                elseif IsDisabledControlPressed(0, 14) or IsDisabledControlPressed(0, 242) or IsDisabledControlPressed(0, 174) then
                    heading = (heading - 3.0) % 360.0
                end

                if IsDisabledControlJustPressed(0, 38) then
                    if dist <= 4.0 then
                        PlacingPrinter = false
                        lib.hideTextUI()
                        DeleteEntity(PreviewProp)
                        PreviewProp = nil

                        local coordsTable = { x = worldCoords.x, y = worldCoords.y, z = worldCoords.z }
                        local rotTable = { x = 0.0, y = 0.0, z = heading }
                        local success, err = lib.callback.await('qbx_3dprinter:server:placePrinter', false, coordsTable, rotTable)
                        if success then
                            lib.notify({ title = _L('printer_title'), description = _L('printer_placed'), type = 'success' })
                        else
                            lib.notify({ title = _L('printer_title'), description = err or _L('invalid_placement'), type = 'error' })
                        end
                        break
                    else
                        lib.notify({ title = _L('printer_title'), description = _L('invalid_placement'), type = 'error' })
                    end
                end

                if IsDisabledControlJustPressed(0, 47) then
                    PlacingPrinter = false
                    lib.hideTextUI()
                    DeleteEntity(PreviewProp)
                    PreviewProp = nil
                    lib.notify({ title = _L('printer_title'), description = _L('placement_cancelled'), type = 'inform' })
                    break
                end
            end
        end
    end)
end)
