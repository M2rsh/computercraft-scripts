local dfpwm = require("cc.audio.dfpwm")
local speakers = table.pack(peripheral.find("speaker"))
local drives = require("drives")
local audio_data = cfs_get("liubushka.dfpwm")

local decoder = dfpwm.make_decoder()

-- Print some debug information
print("Number of speakers found:", speakers and 1 or 0)
print("Length of audio data:", #audio_data)

local chunkSize = 16 * 1024  -- Adjust chunk size as needed

function playAudioChunk(chunk)
  for _, speaker in ipairs(speakers) do
    local buffer = decoder(chunk)
    while not speaker.playAudio(buffer) do
      os.pullEvent("speaker_audio_empty")
    end
  end
end

-- Play the audio in chunks
for chunk in audio_data:gmatch(".-"..string.rep(".", chunkSize)) do
  playAudioChunk(chunk)
end
