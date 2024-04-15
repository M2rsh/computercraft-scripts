local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")
local drives = require("drives")

local audio_data = cfs_get("name.dfpwm")

local decoder = dfpwm.make_decoder()

function linesFromString(str, chunkSize)
    local index = 1
    return function()
        if index <= #str then
            local chunk = str:sub(index, index + chunkSize - 1)
            index = index + chunkSize
            return chunk
        end
    end
end

for chunk in linesFromString(audio_data, 16*1024) do
    local buffer = decoder(chunk)

    while not speaker.playAudio(buffer) do
        os.pullEvent("speaker_audio_empty")
    end
end
