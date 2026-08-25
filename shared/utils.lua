Utils = {}

function _L(key, ...)
    local lang = Config.Language or 'cs'
    local fileContent = LoadResourceFile(GetCurrentResourceName(), ('locales/%s.json'):format(lang))
    if fileContent then
        local locales = json.decode(fileContent)
        if locales and locales[key] then
            return (locales[key]):format(...)
        end
    end
    return key
end

function Utils.Generate3DSerial(prefix)
    prefix = prefix or '3D'
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local randomStr = ''
    for i = 1, 6 do
        local randIndex = math.random(1, #chars)
        randomStr = randomStr .. string.sub(chars, randIndex, randIndex)
    end
    return string.format('%s-%s', prefix, randomStr)
end
