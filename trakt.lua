-- Copyright (c) 2017 Andrejs Mivreņiks
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
local mp = require 'mp'
local msg = require 'mp.msg'
local utils = require 'mp.utils'
local http = require 'socket.http'

-------------------------------------
-------------------------------------
function on_pause_change(name, value)
    if mp.get_property('filename') ~= nil then
        filename = mp.get_property('filename') 
    end
    if filename == nil then return end

    local name, season, episode = extract_data_from_filename(filename)
    if name == nil or season == nil or episode == nil then
        msg.debug("Could not extract show and episode information from the file name")
        return
    end

    if time_pos == nil then return end
    if duration == nil then return end

    -- Scrobble
    if not value then
        start_scrobble(name, season, episode)
    else
        stop_scrobble(name, season, episode)
    end
end

-------------------------------------
-------------------------------------
function on_time_pos_change(name, value)
    time_pos = value
end

-------------------------------------
-------------------------------------
function on_duration_change(name, value)
    duration = value
end

-------------------------------------
-------------------------------------
function on_file_loaded()
    time_pos = mp.get_property('time-pos')
    duration = mp.get_property('duration')
    if time_pos == nil then time_pos = 0.0 end

    local paused = false
    if mp.get_property('pause') == "yes" then
        paused = true
    end
    on_pause_change('pause', paused)
end

-------------------------------------
-------------------------------------
function on_end()
    on_pause_change('pause', true)
end

-------------------------------------
-------------------------------------
function start_scrobble(name, season, episode)
    msg.info("Starting scrobbling to Trakt.tv")
    --mp.osd_message("Starting scrobbling to Trakt.tv", 1)
    data = {
        ['progress'] = time_pos / duration,
        ['episode'] = {
            ['season'] = tonumber(season),
            ['number'] = tonumber(episode)
        },
        ['show'] = {
            ['title'] = name
        }
    }
    http_post('https://api.trakt.tv/scrobble/start', data)
end

-------------------------------------
-------------------------------------
function stop_scrobble(name, season, episode)
    msg.info("Stopping scrobbling to Trakt.tv")
    --mp.osd_message("Stopping scrobbling to Trakt.tv", 1)
    data = {
        ['progress'] = time_pos / duration,
        ['episode'] = {
            ['season'] = tonumber(season),
            ['number'] = tonumber(episode)
        },
        ['show'] = {
            ['title'] = name
        }
    }
    http_post('https://api.trakt.tv/scrobble/stop', data)
end

-------------------------------------
-- Loads and returns trakt.tv credentials
-------------------------------------
function load_credentials()
    local credentials_file = get_data_dir().."/mpv-trakt/credentials.json"
    if not file_exists(credentials_file) then
        msg.error("Credentials file not found: "..credentials_file)
        msg.error("Please launch `install.sh` script to authorize in trakt.tv before using this script")
        return
    end

    local credentials_json = read_file(credentials_file)
    return utils.parse_json(credentials_json)
end

-------------------------------------
-- Returns standard data home directory
-- Defaluts to ~/.local/share
-------------------------------------
function get_data_dir()
    local result = os.getenv("HOME").."/.local/share"
    if os.getenv("XDG_DATA_HOME") ~= nil then
        result =  os.getenv("XDG_DATA_HOME")
    end

    return result
end

-------------------------------------
-- Check if the file exists
-- @param file File path
-------------------------------------
function file_exists(file)
    local f = io.open(file, "rb")
    if f then f:close() end

    return f ~= nil
end

-------------------------------------
-- Read and return contents from file
-- @param file File path
-------------------------------------
function read_file(file)
    local f = io.open(file, "rb")
    local content = f:read("*all")
    f:close()

    return content
end

-------------------------------------
-- Extracts show name, season and episode number from file name
-- Currently supports only "Show.name.s01e01" format
-- @param filename File name
-------------------------------------
function extract_data_from_filename(filename)
    -- TODO Add more patterns
    local pattern = "^(.*)[Ss]([0-9]+)[\\.\\- ]?[Ee]([0-9]+)"
    local name, season, episode = filename:match(pattern)
    if name ~= nil then
        name = name:gsub('[\\.-]', ' '):match("^%s*(.-)%s*$")
    end

    return name, season, episode
end

-------------------------------------
-------------------------------------
function http_post(url, data)
    msg.error(utils.to_string(data))
    body = utils.format_json(data)
    msg.debug('POST '..url)
    msg.debug('Body: '..body)
    local response = {}
    local client, code, headers, status = http.request{
        url = url,
        sink = ltn12.sink.table(response),
        method = "POST",
        headers = {
            ['Authorization'] = 'Bearer '..credentials['access_token'],
            ['Accept'] = 'application/json',
            ['Content-Type'] = 'application/json',
            ['trakt-api-key'] = trakt_api_key,
            ['trakt-api-version'] = '2',
            ["Content-Length"] = body:len()
        },
        source = ltn12.source.string(body)
    }

    msg.debug('Response data: '..utils.to_string(client)..'; '..utils.to_string(code)..'; '..utils.to_string(status))
    msg.debug('Response body: '..utils.to_string(response))
    return code, response
end


-- Script entry point
trakt_api_key = 'fc9742bb96e86fdfdd163086eb95712f7657a86f051f75e04e5334a5d2b40f64'
credentials = load_credentials()
if credentials ~= nil then
    mp.observe_property("pause", "bool", on_pause_change)
    mp.observe_property("time-pos", "number", on_time_pos_change)
    mp.observe_property("duration", "number", on_duration_change)
    mp.register_event("file-loaded", on_file_loaded)
    mp.register_event("end-file", on_end)
end
