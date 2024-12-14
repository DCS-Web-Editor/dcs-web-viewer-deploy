-- DcsWebViewer - MovingMap - simple and lightweight JSON API for DCS by ops


DcsWebViewer = {}

-- create socket once sim is started
function DcsWebViewer:onSimulationStart()
    local socket = require("socket")
    self.server = assert(socket.bind("127.0.0.1", 31485))
    self.server:settimeout(0)
    self.targetCamera = nil  -- camera position for lerping
    self.staticObjects = {}  -- stores dynamically created static objects
    self.isRunning = true
end

-- close sockets
function DcsWebViewer:onSimulationStop()
    if self.server then
        self.server:close()
        self.server = nil
    end
end

-- runs every frame
function DcsWebViewer:onSimulationFrame()
    for _, server in ipairs({self.server}) do
        if server then
            local client = server:accept()
            if client then
                client:settimeout(60)
                local request, err = client:receive()
                if not err then
                    local method, path, slug, queryString = request:match("^(%w+)%s(/[^%?]+)([^%?]*)%??(.*)%sHTTP/%d%.%d$")
                    local headers = self:getHeaders(client)
                    local data = self:getBodyData(client, headers)
                    if slug == "" then slug = nil end
                    local query = {}
                    for key, value in queryString:gmatch("([^&=?]+)=([^&=?]+)") do
                        query[key] = value
                    end
                    local response = self.response200
                    if method == "OPTIONS" then
                        client:send(self:responseOptions())
                    else
                        local code = nil
                        if method == "GET" and path == "/health" then
                            code, result = self:getHealth()
                        elseif method == "GET" and path == "/mission-data" then
                            code, result = self:getMissionData()
                        elseif method == "GET" and path == "/position-player" then
                            code, result = self:getPositionPlayer()
                        elseif method == "GET" and path == "/player-id" then
                            code, result = self:getPlayerId()
                        elseif method == "GET" and path == "/export-world-objects" then
                            code, result = self:getExportWorldObjects()
                        end
                        if code == 200 then                            
                            client:send(self:response200(result))
                        else
                            client:send(self:response404())
                        end
                    end
                end
                client:close()
            end
        end
    end
end


-- yet another serialize helper
function DcsWebViewer:serializeTable(t)
    if type(t) ~= "table" then
        return tostring(t)
    end
    local str = "{"
    for k, v in pairs(t) do
        local key = type(k) == "string" and string.format("%q", k) or tostring(k)
        local value
        if type(v) == "table" then
            value = self:serializeTable(v)
        elseif type(v) == "string" then
            value = string.format("%q", v)
        else
            value = tostring(v)
        end
        str = str .. "[" .. key .. "]=" .. value .. ","
    end
    return str .. "}"
end

-- reads http headers
function DcsWebViewer:getHeaders(client)
    local headers = {}
    while true do
        local line, err = client:receive()
        if err or line == "" then break end
        local key, value = line:match("^(.-):%s*(.*)$")
        if key and value then
            headers[key:lower()] = value
        end
    end
    return headers
end

-- reads http body, returns json
function DcsWebViewer:getBodyData(client, headers)
    local body = nil
    if headers["content-length"] then
        local contentLength = tonumber(headers["content-length"])
        if contentLength > 0 then
            local json, err = client:receive(contentLength)
            if not err then
                local success, data = pcall(net.json2lua, json)
                if success then
                    body = data
                end
            end
        end
    end
    return body
end

-- default http headers
function DcsWebViewer:defaultHeaders()
    return "Access-Control-Allow-Origin: *\r\n"
        .. "Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS\r\n"
        .. "Access-Control-Allow-Headers: Content-Type\r\n"
end

-- options response
function DcsWebViewer:responseOptions()
    return "HTTP/1.1 204 No Content\r\n"
        .. "Access-Control-Max-Age: 86400\r\n"
        .. self:defaultHeaders() .. "\r\n"
end

-- 200 response
function DcsWebViewer:response200(data)
    return "HTTP/1.1 200 OK\r\n"
        .. "Content-Type: application/json\r\n"
        .. self:defaultHeaders() .. "\r\n"
        .. (data and net.lua2json(data) or "")
end

-- 404 response
function DcsWebViewer:response404()
    return "HTTP/1.1 404 Not Found\r\n"
        .. "Content-Type: text/plain\r\n"
        .. self:defaultHeaders() .. "\r\n"
        .. "404 Not Found"
end



-- degrees to radians
function DcsWebViewer:deg2rad(degrees)
    if degrees < 0 then
        degrees = degrees + 360
    end
    return degrees * (math.pi / 180)
end

-- health check
function DcsWebViewer:getHealth()
    local result = {
        missionServerRunning = true,
        missionRunning = DCS.getCurrentMission() ~= nil,
    }
    return 200, result
end

-- returns mission data
function DcsWebViewer:getMissionData()
    local result = DCS.getCurrentMission()
    return 200, result
end

-- returns player object
function DcsWebViewer:getPositionPlayer()
    local result = Export.LoGetSelfData()
    return 200, result
end

-- returns Export world objects
function DcsWebViewer:getExportWorldObjects()
    local result = Export.LoGetWorldObjects()
    return 200, result
end

function DcsWebViewer:getPlayerId()
    local id = DCS.getPlayerUnit()
    return 200, id
end



DCS.setUserCallbacks({
    onSimulationStart = function() DcsWebViewer:onSimulationStart() end,
    onSimulationStop = function() DcsWebViewer:onSimulationStop() end,
    onSimulationFrame = function() DcsWebViewer:onSimulationFrame() end	
})
