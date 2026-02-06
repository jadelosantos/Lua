-- ElAmigos.lua for Project GLD
-- Author: Adaptado estilo SteamRip
-- Funciona con URLs directas de juegos de ElAmigos
-- Version: 1.0.0

local VERSION = "1.0.0"
client.auto_script_update(
    "https://raw.githubusercontent.com/jadelosantos/Lua/main/ElAmigos.lua",
    VERSION
)

--------------------------------------------------
-- HEADERS
--------------------------------------------------
local headers = {
    ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 ProjectGLD/2.15"
}

--------------------------------------------------
-- UTILS
--------------------------------------------------
local function cleanName(name)
    name = name:gsub(":", "")
    name = name:gsub("%s+", " ")
    return name
end

-- Extrae enlaces de descarga visibles en la página del juego
local function extractDownloadLinks(gamePageUrl)
    local body = http.get(gamePageUrl, headers)
    local links = {}

    if not body or #body < 50 then
        return links
    end

    -- Buscar enlaces de descarga Mega, Google Drive, Mediafire, Uploaded
    for link in string.gmatch(body, 'href="(https?://[^"]-)"') do
        if string.find(link, "mega%.nz") or
           string.find(link, "mediafire%.com") or
           string.find(link, "gofile%.io") or
           string.find(link, "drive%.google%.com") or
           string.find(link, "uploaded%.net") then
            table.insert(links, {
                name = "Download",
                link = link,
                addtodownloadlist = true
            })
        end
    end

    return links
end

--------------------------------------------------
-- MAIN SCRAPER
--------------------------------------------------
local function webScrapeElAmigos(gameUrl)
    if not gameUrl or gameUrl == "" then
        Notifications.push_error("Lua Script", "No se proporcionó URL del juego.")
        return {}
    end

    local body = http.get(gameUrl, headers)
    if not body then
        Notifications.push_error("Lua Script", "No se pudo cargar la página del juego.")
        return {}
    end

    -- Extraer nombre del juego
    local title = string.match(body, '<h1 class="entry%-title">(.-)</h1>') or "Unknown Game"

    -- Extraer tamaño si aparece
    local size = string.match(body, "Tamaño del archivo.-:</strong>%s*(.-)<") or ""

    local gameResult = {
        name = "[" .. size .. "] " .. title,
        links = extractDownloadLinks(gameUrl),
        tooltip = "Size: " .. size,
        ScriptName = "ElAmigos"
    }

    -- Intentar extraer portada
    local cover = string.match(body, '<img class="[^"]-wp-post-image"[^>]-src="(.-)"')
    if cover then
        gameResult.cover = { url = cover }
    end

    return { gameResult }
end

--------------------------------------------------
-- GLD INTEGRATION
--------------------------------------------------
local version = client.GetVersionDouble()
local defaultdir = "C:/Games"

if version < 6.95 then
    Notifications.push_error("Lua Script", "Program is Outdated. Please Update to use this Script")
else
    Notifications.push_success("Lua Script", "ElAmigos Script Loaded and Working")

    menu.add_input_text("ElAmigos Game URL")
    if menu.get_text("ElAmigos Game URL") == "" then
        menu.set_text("ElAmigos Game URL", "")
    end

    local gamename = ""
    local imagelink = ""
    local pathcheck = ""

    local function onScriptSelected()
        local gameUrl = menu.get_text("ElAmigos Game URL")
        if not gameUrl or gameUrl == "" then
            Notifications.push_error("Lua Script", "Debes ingresar la URL de un juego.")
            return
        end
        local results = webScrapeElAmigos(gameUrl)
        communication.receiveSearchResults(results)
    end

    local function onDownloadClick(gamejson, downloadurl, scriptname)
        local jsonResults = JsonWrapper.parse(gamejson)
        gamename = jsonResults.name
        local coverImageUrl = jsonResults["cover"] and jsonResults["cover"]["url"] or nil
        if coverImageUrl and coverImageUrl:sub(1, 2) == "//" then
            coverImageUrl = "https:" .. coverImageUrl
        end
        if coverImageUrl then
            coverImageUrl = coverImageUrl:gsub("t_thumb", "t_cover_big")
            imagelink = coverImageUrl
        end
    end

    local function onDownloadCompleted(path, url)
        path = path:gsub("\\", "/")
        pathcheck = path
        local gamedir = defaultdir .. "/" .. gamename:gsub(":", "") .. "/"
        zip.extract(path, gamedir, false)
    end

    local function onExtractionCompleted(origin, path)
        if pathcheck == origin then
            path = path:gsub("/", "\\")
            local folders = file.listfolders(path)
            local secondFolder = folders[1]
            if secondFolder then
                local fullFolderPath = path .. "\\" .. secondFolder
                local executables = file.listexecutables(fullFolderPath)
                if executables and #executables >= 1 then
                    local firstExecutable = executables[1]
                    local gameidl = GameLibrary.GetGameIdFromName(gamename)
                    if gameidl == -1 then
                        local imagePath = Download.DownloadImage(imagelink)
                        GameLibrary.addGame(fullExecutablePath, imagePath, gamename, "")
                        Notifications.push_success("ElAmigos Script", "Game Successfully Installed!")
                    else
                        GameLibrary.changeGameinfo(gameidl, fullExecutablePath)
                        Notifications.push_success("ElAmigos Script", "Game Successfully Installed!")
                    end
                end
            end
        end
    end

    client.add_callback("on_scriptselected", onScriptSelected)
    client.add_callback("on_downloadclick", onDownloadClick)
    client.add_callback("on_downloadcompleted", onDownloadCompleted)
    client.add_callback("on_extractioncompleted", onExtractionCompleted)
end