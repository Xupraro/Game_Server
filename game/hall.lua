local skynet = require "skynet"
local socket = require "skynet.socket"
local json = require "cjson"

local clients = {}
local rooms = {}

local CMD = {}
function CMD.ready(client)
    clients[client.client_fd] = client
    if #rooms > 0 then
        socket.write(client.client_fd, json.encode(rooms) .. "\n")
    end
end

function CMD.createroom(client)
    local id = skynet.newservice("room")
    skynet.send(id, "lua", "start", client)
    table.insert(rooms, {
        user = client.user,
        room_id = id,
    })
    for _, value in pairs(clients) do
        print(value.client_fd)
        socket.write(value.client_fd, "ROOM##new##" .. client.user .. "##" .. id .. "\n")
    end
end

function CMD.enterroom(client, room_id)
    room_id = tonumber(room_id)
    skynet.send(room_id, "lua", "start", client)
end

skynet.start(function ()
    skynet.dispatch("lua", function (_, _, cmd, ...)
            skynet.fork(CMD[cmd], ...)
    end)
end)