-- app.clipboard.clear() -- Should be available by v1.3.14 (I'm currently on 1.3.13)

local sprite = app.activeSprite
if not sprite then
    return app.alert("No active sprite.")
end

local layer = app.activeLayer
if not layer or not layer.isTilemap then
    return app.alert("Active layer is not a Tilemap.")
end

local cel = layer:cel(1)
if not cel then
    return app.alert("No cel found in frame 1.")
end

local function getBit(value, bit)
    return (value & (1 << bit)) ~= 0
end

local function decodeTileId(tileId)
    return {
        tileIndex = tileId & 0x0FFFFFFF,
        flipX = getBit(tileId, 31) or false,
        flipY = getBit(tileId, 30) or false,
        flipD = getBit(tileId, 29) or false
    }
end

local StringBuilder = {}
StringBuilder.__index = StringBuilder

function StringBuilder:new()
    return setmetatable({ buffer = {} }, self)
end

function StringBuilder:append(str)
    table.insert(self.buffer, str)
    return self -- allows chaining
end

function StringBuilder:toString()
    return table.concat(self.buffer)
end

local sb = StringBuilder:new()
sb:append("tile_map_data = PackedByteArray(0, 0")

local image = cel.image
local tileset = layer.tileset
local width, height = image.width, image.height

for mapPositionY = 0, height - 1 do
    for mapPositionX = 0, width - 1 do
        local tileId = image:getPixel(mapPositionX, mapPositionY)
        local tile = decodeTileId(tileId)
        local tilePositionX = tile.tileIndex
        local tilePositionY = 0
        local tileTransformation = 0

        local mapPositionRemainderX = math.fmod(mapPositionX, 256)
        local mapPositionOverflowX =  math.floor(mapPositionX / 256)
        local mapPositionRemainderY = math.fmod(mapPositionY, 256)
        local mapPositionOverflowY =  math.floor(mapPositionY / 256)

        if tile.flipX then
            tileTransformation = tileTransformation | 0x00000010
        end

        if tile.flipY then
            tileTransformation = tileTransformation | 0x00000020
        end

        if tile.flipD then
            tileTransformation = tileTransformation | 0x00000040
        end

        if tilePositionX > 0 then
            sb:append(string.format(", %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d",
                    mapPositionRemainderX, -- This is mapPositionX, but it can only go up to 255
                    mapPositionOverflowX,  -- This is how many times mapPositionX has exceeded 255
                    mapPositionRemainderY, -- This is mapPositionY, but it can only go up to 255
                    mapPositionOverflowY,  -- This is how many times mapPositionY has exceeded 255
                    0, -- I think this has something to do with which tileset is being used
                    0, -- <-- Don't know what this is for yet
                    tilePositionX,
                    0, -- <-- Don't know what this is for yet
                    tilePositionY,
                    0, -- <-- Don't know what this is for yet
                    0, -- <-- Don't know what this is for yet
                    tileTransformation
            ))
        end
    end
end

sb:append(")")

local path = app.fs.joinPath(app.fs.tempPath, "aseprite-tilemap-output.txt")
local f = io.open(path, "w")
f:write(sb:toString())
f:close()

local dlg = Dialog()
dlg:entry { id = "user_value", label = "tile_map_data saved to this file: ", text = path }
dlg:show()
