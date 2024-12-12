local skynet = require "skynet"

local socket = require "skynet.socket"

local bullet_count = 0

local bullets = {}

local roles = {}

local redis

local CMD = {}
function CMD.start(client)
    roles[client.client_fd] = {
        client = client
    }
    client.room_id = skynet.self();
    skynet.call(redis, "lua", "hset", "role:" .. client.user, "room_id", client.room_id)
    for _, value in pairs(roles) do
        if value.client.client_fd ~= client.client_fd then
            socket.write(value.client.client_fd, "ROOM##add##" .. client.client_fd .. "\n")
            socket.write(client.client_fd, "ROOM##add##" .. value.client.client_fd .. "\n")
        end
    end
end

function CMD.gamer(client_fd, x, y)
    roles[client_fd].x = x
    roles[client_fd].y = y
    for _, value in pairs(roles) do
        if value.client.client_fd ~= client_fd then
            -- skynet.error("ROOM##role##" .. client_fd.. "##" .. x .. "##" .. y)
            if not value.isdied then
                socket.write(value.client.client_fd, "ROOM##role##" .. client_fd.. "##" .. x .. "##" .. y .. "\n")
            end
        end
    end
end

local function sendzd(id, x, y, angle)
    x = tonumber(x)
    y = tonumber(y)
    while true do
        if angle == "1" then
            y = y - 2
        elseif angle == "2" then
            x = x + 2
            y = y - 2
        elseif angle == "3" then
            x = x + 2
        elseif angle == "4" then
            x = x + 2
            y = y + 2
        elseif angle == "5" then
            y = y + 2
        elseif angle == "6" then
            x = x - 2
            y = y + 2
        elseif angle == "7" then
            x = x - 2
        elseif angle == "8" then
            x = x - 2
            y = y - 2
        end
        skynet.error("angle is " .. angle)
        skynet.fork(function ()
            for _, role in pairs(roles) do
                -- skynet.error("ROOM##bullet##" .. id .. "##" .. x .. "##" .. y)
                if not role.isdied then
                    socket.write(role.client.client_fd, "ROOM##bullet##" .. id .. "##" .. x .. "##" .. y .. "\n")
                end
            end
        end)
        skynet.fork(function ()
            for _, value in pairs(roles) do
                skynet.fork(function ()
                    bullets[id] = (((x - value.x) * (x - value.x) + (y - value.y) * (y - value.y)) > (6.5 * 6.5))
                    if not bullets[id] then
                        for _, role in pairs(roles) do
                            if value.client.client_fd ~= role.client.client_fd then
                                socket.write(role.client.client_fd, "ROOM##died##" .. value.client.client_fd .. "\n")
                            else
                                value.isdied = true
                                socket.write(value.client.client_fd, "ROOM##died\n")
                            end
                        end
                    end
                end)
            end
        end)
        if not bullets[id] then
            for _, value in pairs(roles) do
                socket.write(value.client.client_fd, "ROOM##bullet##" .. id .. "##500##500\n")
            end
            return
        end
        if x <= 0 or x >= 400 or y <= 0 or y >=400 then
            return
        end
        skynet.sleep(1)
    end
end

function CMD.bullet(x, y, angle)
    bullet_count = bullet_count + 1
    skynet.fork(sendzd, bullet_count, x, y, angle)
    bullets[bullet_count] = true
end

skynet.start(function ()
    redis = skynet.uniqueservice("redis")
    skynet.dispatch("lua", function (_, _, cmd, ...)
        skynet.fork(CMD[cmd], ...)
    end)
end)