local dfpwm = require("cc.audio.dfpwm")
local speakers = table.pack(peripheral.find("speaker"))
local drives = require("drives")
local audio_data = cfs_get("redsuninthesky.dfpwm")

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

for chunk in linesFromString(audio_data, 16 * 1024) do
  local buffer = decoder(chunk)
  for i = 1, speakers.n do
    while not speakers[i].playAudio(buffer) do
        os.pullEvent("speaker_audio_empty")
    end
  end
end
