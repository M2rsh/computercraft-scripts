local chunkSize = 125000

local function generateDiskPaths()
  local diskPaths = {}
  local diskIndex = 1
  while true do
    local diskPath = "/disk"
    if diskIndex > 1 then
      diskPath = diskPath .. diskIndex
    end
    if fs.exists(diskPath) and fs.isDir(diskPath) then
      table.insert(diskPaths, diskPath)
    else
      break
    end
    diskIndex = diskIndex + 1
  end
  return diskPaths
end

local diskPaths = generateDiskPaths()

local function getDiskForFile(filename, fileSize)
  local hash = 0
  local selectedDisk = nil
  for i = 1, #filename do
    hash = (hash + string.byte(filename, i)) % #diskPaths + 1
  end

  -- Check if any disk has sufficient space
  for i = 0, #diskPaths - 1 do
    local diskIndex = (hash + i) % #diskPaths + 1
    local diskPath = diskPaths[diskIndex]
    local freeSpace = fs.getFreeSpace(diskPath)
    if freeSpace >= fileSize then
      selectedDisk = diskPath
      break
    end
  end

  return selectedDisk
end

local function listDisks()
  return diskPaths
end

local function downloadFile(url)
  local response = http.get(url)
  if response then
    local content = response.readAll()
    response.close()
    return content
  else
    print("Failed to download file from URL:", url)
    return nil
  end
end

-- Function to store a chunk of file
local function storeChunk(diskPath, filename, content)
  local file = fs.open(diskPath .. "/" .. filename, "w")
  if file then
    file.write(content)
    file.close()
    return true
  else
    return false
  end
end

local function storeFile(filename, content)
  local fileSize = #content
  --local chunkSize = 128 * 1024 -- 128 KB chunk size
  local numChunks = math.ceil(fileSize / chunkSize)
  local success = true

  for i = 1, numChunks do
    local startByte = (i - 1) * chunkSize + 1
    local endByte = math.min(i * chunkSize, fileSize)
    local chunkContent = content:sub(startByte, endByte)

    local diskPath = getDiskForFile(filename, #chunkContent)
    if diskPath then
      local chunkFilename = i .. "_" .. filename
      if not storeChunk(diskPath, chunkFilename, chunkContent) then
        success = false
        print("Failed to store chunk " .. i .. " on disk:", diskPath)
      end
    else
      success = false
      print("No disk has sufficient space to store chunk " .. i)
    end
  end

  return success
end

local function getFileChunkPath(filename, chunkIndex)
  for _, diskPath in ipairs(diskPaths) do
    local chunkFilename = chunkIndex .. "_" .. filename
    local fullPath = diskPath .. "/" .. chunkFilename
    if fs.exists(fullPath) then
      return fullPath
    end
  end
  return nil
end

-- Function to retrieve a chunk of file
local function getFileChunk(filename, chunkIndex)
  local fullPath = getFileChunkPath(filename, chunkIndex)

  if fullPath ~= nil then
    local file = fs.open(fullPath, "r")
    local content = file.readAll()
    file.close()
    return content
  else
    return nil
  end
end

local function getFile(filename)
  local content = ""
  local i = 1
  local chunkFilename = i .. "_" .. filename
  local chunkContent = getFileChunk(filename, i)
  while chunkContent do
    content = content .. chunkContent
    i = i + 1
    chunkFilename = i .. "_" .. filename
    chunkContent = getFileChunk(filename, i)
  end
  if content ~= "" then
    return content
  else
    return nil
  end
end

-- Function to delete a file
local function deleteFile(filename)
  local i = 1
  local chunkPath = getFileChunkPath(filename, i)
  while chunkPath do
    fs.delete(chunkPath)
    i = i + 1
    chunkPath = getFileChunkPath(filename, i)
  end
  return true
end

function cfs_list()
  print("Files stored on disks:")
  local seenFiles = {}  -- Set to keep track of seen filenames
  for _, diskPath in ipairs(diskPaths) do
    local files = fs.list(diskPath)
    for _, filename in ipairs(files) do
      local basename = filename:match("%d+_(.*)")  -- Extract the basename after the partition number
      if not seenFiles[basename] then
        print("- " .. basename)
        seenFiles[basename] = true  -- Mark filename as seen
      end
    end
  end
end

function cfs_download(url)
  local filename = fs.getName(url)
  local content = downloadFile(url)
  if content then
    local success = storeFile(filename, content)
    if success then
      print("File downloaded and stored successfully.")
      return true
    else
      print("Failed to store downloaded file.")
      return false
    end
  else
    print("Failed to download file from URL:", url)
    return false
  end
end

function cfs_store(filepath)
  if not fs.exists(filepath) then
    print("File not found.")
    return nil
  end
  local filename = fs.getName(filepath)
  local fileSize = fs.getSize(filepath)
  local file = fs.open(filepath, "r")
  local content = file.readAll()
  file.close()
  local success = storeFile(filename, content)
  if success then
    print("File stored successfully on disk:", success)
    return true
  else
    print("Failed to store file on disk:", success)
    return false
  end
end

function cfs_get(filepath)
  local content = getFile(filepath)
  if content then
    return content
  else
    return nil
  end
end

function cfs_delete(filepath)
  local success = deleteFile(filepath)
  if success then
    print("File deleted successfully.")
    return true
  else
    print("Failed to delete file.")
    return false
  end
end

if not pcall(getfenv, 4) then
  -- Interactive command processing loop
  while true do
    -- Read command from the user
    io.write("> ")
    local command = io.read()

    -- Parse the command
    local parts = {}
    for part in string.gmatch(command, "%S+") do
      table.insert(parts, part)
    end

    if #parts == 0 then
      print("Please enter a command.")
    else
      local action = parts[1]
      if action == "store" then
        cfs_store(parts[2])
      elseif action == "get" then
        local result = cfs_get(parts[2])
        if result ~= nil then
          print(result)
        else
          print("File not found.")
        end
      elseif action == "delete" then
        cfs_delete(parts[2])
      elseif action == "ls" then
        cfs_list()
      elseif action == "download" then
        cfs_download(parts[2])
      elseif action == "exit" then
        print("Exiting..")
        return
      else
        print("Invalid command. Valid commands are: store, get, delete, ls, exit")
      end
    end
  end
else
  return
end
