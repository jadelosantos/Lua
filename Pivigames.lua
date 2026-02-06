-- PiviGames.lua for Project GLD
-- SteamRip-style integration using PlayPaste
-- Compatible con HTML actual de pivigames.blog
-- Version: 2.4.0

local VERSION = "2.4.0"
client.auto_script_update(
    "https://raw.githubusercontent.com/jadelosantos/Lua/main/Pivigames.lua",
    VERSION
)

--------------------------------------------------
-- HEADERS
--------------------------------------------------
local headers = {
    ["User-Agent"] =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 ProjectGLD/2.15"
}

--------------------------------------------------
-- CLOUDFLARE
--------------------------------------------------
local cfcookie = ""

local function cfcallback(cookie, url)
    if url == "https://pivigames.blog/" then
        cfcookie = cookie
        headers["Cookie"] = "cf_clearance=" .. tostring(cfcookie)
        communication.RefreshScriptResults()
    end
end

--------------------------------------------------
-- UTILS
--------------------------------------------------
local function cleanName(name)
    name = name:gsub(":", "")
    name = name:gsub("%s+", " ")
    return name
end

local function extractDownloadLinksFromPlayPaste(playpasteUrl)
    local page = http.get(playpasteUrl, headers)
    local links = {}

    if not page or #page < 50 then
        return links
    end

    for link in string.gmatch(page, 'href="(.-)"') do
        if string.find(link, "mega%.nz") or
           string.find(link, "mediafire%.com") or
           string.find(link, "gofile%.io") or
           string.find(link, "pixeldrain%.com") then
            table.insert(links, link)
        end
    end

    return links
end

--------------------------------------------------
-- MAIN SCRAPER
--------------------------------------------------
local function webScrapePiviGames(gameName)
    gameName = cleanName(gameName)
    local searchUrl = "https://pivigames.blog/?s=" .. gameName:gsub(" ", "%%20")
    local body = http.get(searchUrl, headers)

    if not body or #body < 100 then
        Notifications.push_error("Lua Script", "No se pudo descargar la página o está vacía.")
        return {}
    end

    local results = {}
    local postMatches = {}

    -- Nuevo pattern para HTML actual
    for link, title in string.gmatch(body, '<h2 class="entry%-title">.-<a href="(.-)"[^>]->(.-)</a>') do
        table.insert(postMatches, {link = link, title = title})
    end

    if #postMatches == 0 then
        Notifications.push_error("Lua Script", "No se encontraron resultados en la búsqueda.")
        return {}
    end

    for _, post in ipairs(postMatches) do
        local page = http.get(post.link, headers)
        if page then
            local title = post.title or "Unknown Game"
            local size = string.match(page, "Tamaño del archivo.-:</strong>%s*(.-)<") or ""

            local gameResult = {
                name = "[" .. size .. "] " .. title,
                links = {},
                tooltip = "Size: " .. size,
                ScriptName = "PiviGames",
            }

            -- Extraer enlaces de PlayPaste
            for link in string.gmatch(page, 'href="(.-)"') do
                if string.find(link, "playpaste.net/pivi?v=") then
                    local finalLinks = extractDownloadLinksFromPlayPaste(link)
                    if #finalLinks > 0 then
                        for _, fl in ipairs(finalLinks) do
                            table.insert(gameResult.links, {
                                name = "Download",
                                link = fl,
                                addtodownloadlist = true
                            })
                        end
                    else
                        table.insert(gameResult.links, {
                            name = "Open PlayPaste",
                            link = link,
                            addtodownloadlist = false
                        })
                    end
                end
            end

            -- Si no hay links, fallback al post
            if #gameResult.links == 0 then
                table.insert(gameResult.links, {
                    name = "Open Post",
                    link = post.link,
                    addtodownloadlist = false
                })
            end

            -- Intentar obtener portada
            local cover = string.match(page, '<img class="[^"]-wp-post-image"[^>]-src="(.-)"')
            if cover then
                gameResult.cover = { url = cover }
            end

            table.insert(results, gameResult)
        end
    end

    return results
end

--------------------------------------------------
-- GLD INTEGRATION
--------------------------------------------------
local version = client.GetVersionDouble()
local defaultdir = "C:/Games" -- Carpeta por defecto

if version < 6.95 then
    Notifications.push_error("Lua Script", "Program is Outdated. Please Update to use this Script")
else
    Notifications.push_success("Lua Script", "PiviGames Script Loaded and Working")

    -- Menú visible para carpeta de instalación
    menu.add_input_text("PiviGames Game Dir")
    if menu.get_text("PiviGames Game Dir") == "" then
        menu.set_text("PiviGames Game Dir", defaultdir)
    end
    settings.load()

    local imagelink = ""
    local gamename = ""
    local pathcheck = ""

    local function onScriptSelected()
        if not cfcookie or cfcookie == "" then
            http.CloudFlareSolver("https://pivigames.blog/")
        else
            local gn = game.getgamename()
            if not gn or gn == "" then
                Notifications.push_error("Lua Script", "No game name provided!")
                return
            end
            local results = webScrapePiviGames(gn)
            communication.receiveSearchResults(results)
        end
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
        local gamedir = menu.get_text("PiviGames Game Dir") .. "/" .. gamename:gsub(":", "") .. "/"
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
                        Notifications.push_success("PiviGames Script", "Game Successfully Installed!")
                    else
                        GameLibrary.changeGameinfo(gameidl, fullExecutablePath)
                        Notifications.push_success("PiviGames Script", "Game Successfully Installed!")
                    end
                end
            end
        end
    end

    client.add_callback("on_scriptselected", onScriptSelected)
    client.add_callback("on_downloadclick", onDownloadClick)
    client.add_callback("on_downloadcompleted", onDownloadCompleted)
    client.add_callback("on_extractioncompleted", onExtractionCompleted)
    client.add_callback("on_cfdone", cfcallback)
end