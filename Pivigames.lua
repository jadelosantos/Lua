-- PiviGames.lua for Project GLD
-- Based on SteamRip script structure
-- Author: YOURD34TH style adaptation
-- Version: 1.0.0

local VERSION = "1.0.0"
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

--------------------------------------------------
-- MAIN SCRAPER
--------------------------------------------------
local function webScrapePiviGames(gameName)
    gameName = cleanName(gameName)
    local searchUrl =
        "https://pivigames.blog/?s=" .. gameName:gsub(" ", "%%20")

    local body = http.get(searchUrl, headers)
    if not body then
        return {}
    end

    local results = {}

    -- Result links
    local gameLinks = HtmlWrapper.findAttribute(
        body,
        "a",
        "rel",
        "bookmark",
        "href"
    )

    local gameTitles = HtmlWrapper.findAttribute(
        body,
        "h2",
        "class",
        "entry-title",
        ""
    )

    for i = 1, #gameLinks do
        local page = http.get(gameLinks[i], headers)
        if page then
            local title =
                gameTitles[i] or "Unknown Game"

            -- Try to extract size
            local size =
                string.match(page, "Tamaño del archivo.-:</strong>%s*(.-)<")
                or ""

            local gameResult = {
                name = "[" .. size .. "] " .. title,
                links = {},
                tooltip = "Size: " .. size,
                ScriptName = "PiviGames"
            }

            -- Download links
            local links = HtmlWrapper.findAttribute(
                page,
                "a",
                "",
                "",
                "href"
            )

            for _, link in ipairs(links) do
                if string.find(link, "mediafire")
                    or string.find(link, "mega")
                    or string.find(link, "pixeldrain")
                    or string.find(link, "gofile")
                then
                    table.insert(gameResult.links, {
                        name = "Download",
                        link = link,
                        addtodownloadlist = true
                    })
                end
            end

            if #gameResult.links > 0 then
                table.insert(results, gameResult)
            end
        end
    end

    return results
end

--------------------------------------------------
-- GLD INTEGRATION
--------------------------------------------------
local version = client.GetVersionDouble()

if version < 6.95 then
    Notifications.push_error(
        "Lua Script",
        "Program is Outdated. Please Update to use this Script"
    )
else
    Notifications.push_success(
        "Lua Script",
        "PiviGames Script Loaded and Working"
    )

    local function onscriptselected()
        if not cfcookie or cfcookie == "" then
            http.CloudFlareSolver("https://pivigames.blog/")
        else
            local gameName = game.getgamename()
            local results = webScrapePiviGames(gameName)
            communication.receiveSearchResults(results)
        end
    end

    client.add_callback("on_scriptselected", onscriptselected)
    client.add_callback("on_cfdone", cfcallback)
end