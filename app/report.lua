-- Autogenerated with DRAKON Editor 1.32
require('strict').on()

local table = table
local string = string
local pairs = pairs
local ipairs = ipairs
local io = io
local pcall = pcall
local xpcall = xpcall
local debug = debug
local box = box
local tostring = tostring
local clock = require("clock")
local log = require("log")
local digest = require("digest")
local fiber = require("fiber")
local json = require("json")
local fio = require("fio")
local log = require("log")
local os = os
local error = error
local print = print

local utf8 = require("lua-utf8")



local utils = require("utils")

setfenv(1, {}) 

function get_diagram_count_in_space(space_id)
    local count, folder
    -- item 53
    count = 0
    for _, row in box.space.folders:pairs(space_id) do
        -- item 58
        folder = row[3]
        -- item 55
        if (folder.deleted) or (folder.type == "folder") then
            
        else
            -- item 59
            count = count + 1
        end
    end
    -- item 54
    return count
end

function get_user_diagram_count(user_id)
    local count, diags, spaces
    -- item 30
    count = 0
    -- item 20
    spaces = get_user_spaces(user_id)
    for space_id, _ in pairs(spaces) do
        -- item 22
        if is_admin_for_space(space_id, user_id) then
            -- item 31
            diags = get_diagram_count_in_space(space_id)
            -- item 32
            count = count + diags
        end
    end
    -- item 33
    return count
end

function get_user_language(user_id)
    local row
    -- item 74
    row = box.space.usettings:get(user_id)
    -- item 75
    if row then
        -- item 78
        return row[2].language or ""
    else
        -- item 79
        return ""
    end
end

function get_user_spaces(user_id)
    local user
    -- item 49
    user = box.space.users:get(user_id)[3]
    -- item 50
    return user.spaces or {}
end

function is_admin_for_space(space_id, user_id)
    local row, space
    -- item 39
    row = box.space.spaces:get(space_id)
    -- item 99
    if row then
        -- item 102
        space = row[2]
        -- item 43
        return utils.contains(space.admins, user_id)
    else
        -- item 103
        return false
    end
end

function users_and_count(path)
    local item, result, str, text, user_id
    -- item 63
    result = {}
    for _, row in box.space.users:pairs() do
        -- item 64
        user_id = row[1]
        -- item 98
        print(user_id)
        -- item 65
        item = {}
        -- item 66
        item.user_id = user_id
        item.count = get_user_diagram_count(user_id)
        item.language = get_user_language(user_id)
        -- item 67
        table.insert(result, item)
    end
    -- item 92
    text = ""
    for _, line in ipairs(result) do
        -- item 95
        str = line.user_id .. ", " .. 
        	tostring(line.count) .. ", " ..
        	line.language
        -- item 97
        text = text .. str .. "\n"
    end
    -- item 96
    utils.write_all_bytes(path, text)
    -- item 68
    return result
end


return {
	users_and_count = users_and_count
}