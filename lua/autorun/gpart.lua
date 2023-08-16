local Cache = {}

local trash = {
    P = true,
    ["@"] = true,
    yDB = true,
    ["yD@"] = true,
    jFG = true,
    [";E-"] = true,
    [";ED"] = true,
    ['"D3'] = true,

}

local function ProcessFile( data, behind )
    data = data:Read(data:Size())
    local strings = string.Explode("\x03\x00", data)
    local definitions = {}
    for slot, line in pairs(strings) do
        local cursor = 1
        while (line[cursor] != "\x00" and cursor < #line) do
            cursor = cursor + 1
        end
        local result = string.match(string.sub(line, 1, cursor), "(%g+)")
        if not result or trash[result] or #result < 4 then continue end
        table.insert(definitions, result)
    end
    table.remove(definitions, 1)
    return definitions
end

local function GetList( fileName )
    if Cache[fileName] then
        return Cache[fileName]
    end

    game.AddParticles( fileName )

    local fileData = file.Open( fileName, "rb", "GAME" )
    local resultData = ProcessFile(fileData)

    Cache[fileName] = resultData
    return resultData
end

function util.GetParticleList(name)
    return GetList(name)
end
