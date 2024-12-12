local skynet = require "skynet"
local socket = require "skynet.socket"

local tunpack = table.unpack

local hall

local client_fd, client_addr = ...
local CMD, client, heartbeat = {}, {}, 0
local redis = setmetatable({0}, {
    __index = function (t, k)
        t[k] = function (red, ...)
            return skynet.call(red[1], "lua", k, ...)
        end
        return t[k]
    end
})

local function heartbeat_fun()
    while true do
        skynet.sleep(1000)
        if heartbeat == 0 then
            socket.close(client_fd)
            return
        end
        heartbeat = 0
    end
end

function CMD.login(user, password)
    local ok = redis:exists("role:" .. user)
    if not ok then
        socket.write(client_fd, "TOKEN##noregister\n") -- 用户未注册
    else
        local fields = redis:hgetall("role:" .. user)
        for i = 1, #fields, 2 do
            client[fields[i]] = fields[i + 1]
        end
        if client.password == password then
            if client.isonline == "true" then
                client.user = nil
                socket.write(client_fd, "TOKEN##logined\n") -- 用户已登录
                return
            else
                socket.write(client_fd, "TOKEN##login\n") -- 用户登录
                client.client_fd = client_fd
                client.client_addr = client_addr
                client.room_id = -1
                client.isonline = "true"
                client.agnet = skynet.self();
                redis:hmset("role:" .. user, tunpack({
                    "room_id", client.room_id,
                    "isonline", client.isonline,
                }))
                skynet.fork(heartbeat_fun)
                skynet.send(hall, "lua", "ready", client)
            end
        else
            socket.write(client_fd, "TOKEN##password\n") -- 密码错误
        end
    end
end

function CMD.register(user, password)
    local ok = redis:exists("role:" .. user)
    if ok then
        socket.write(client_fd, "TOKEN##registered\n") -- 用户已注册
    else
        redis:hmset("role:" .. user, tunpack({
            "user", user,
            "password", password,
        }))
        socket.write(client_fd, "TOKEN##register\n") -- 用户注册
    end
end

function CMD.createroom()
    skynet.send(hall, "lua", "createroom", client)
end

function CMD.enterroom(room_id)
    skynet.send(hall, "lua", "enterroom", client, room_id)
end

function CMD.gamer(x, y)
    if client.room_id == -1 then
        client.room_id = tonumber(redis:hget("role:" .. client.user, "room_id"))
    end
    skynet.send(client.room_id, "lua", "gamer", client_fd, x, y)
end

function CMD.bullet(x, y, angle)
    if client.room_id == -1 then
        client.room_id = tonumber(redis:hget("role:" .. client.user, "room_id"))
    end
    skynet.send(client.room_id, "lua", "bullet", x, y, angle)
end

function CMD.heartbeat()
    -- skynet.error("receive client heartbeat " .. client_fd)
    heartbeat = heartbeat + 1
end

local function dispatch_message()
    while true do
        local data = socket.readline(client_fd)
        if data ~= "heartbeat" then
            skynet.error(data)
        end
        if not data then
            if client.user ~= nil then
                redis:hmset("role:" .. client.user, tunpack({
                    "isonline", "false",
                }))
            end
            skynet.fork(skynet.exit)
            return
        end
        local pms = {}
        for pm in string.gmatch(data, "%w+") do
            pms[#pms + 1] = pm
        end
        skynet.fork(CMD[pms[1]], select(2, tunpack(pms)))
    end
end

skynet.start(function ()
    client_fd = tonumber(client_fd)
    skynet.error("receive a client: " .. client_fd .. " " .. client_addr .. " " .. skynet.self())
    redis[1] = skynet.uniqueservice("redis")
    hall = skynet.uniqueservice("hall")
    socket.start(client_fd)
    skynet.fork(dispatch_message)
end)