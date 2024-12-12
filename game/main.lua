local skynet = require "skynet"
local socket = require "skynet.socket"

skynet.start(function ()
    skynet.uniqueservice("redis")
    skynet.uniqueservice("hall")
    local listen_fd = socket.listen("0.0.0.0", 8888)
    socket.start(listen_fd, function (client_fd, client_addr)
        skynet.newservice("agent", client_fd, client_addr)
    end)
end)
