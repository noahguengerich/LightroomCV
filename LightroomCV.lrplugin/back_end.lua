local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrStringUtils = import 'LrStringUtils'
--local LrMobdebug = import 'LrMobdebug'
local LrSocket = import 'LrSocket'
local LrFunctionContext = import 'LrFunctionContext'
local LrSelection = import 'LrSelection'
local LrLogger = import 'LrLogger'
local json = require "json"

-- Create a logger
local myLogger = LrLogger( 'libraryLogger' )
myLogger:enable( "logfile" )

local back_end = {}

local function protect(tbl)
  return setmetatable({}, {
      __index = tbl,
      __newindex = function(t, key, value)
          error("attempting to change constant " ..
                 tostring(key) .. " to " .. tostring(value), 2)
      end
  })
end

---------------------------------------------------------------------------
-- CONSTANTS
---------------------------------------------------------------------------

local SOCKETS = {
  -- Header size for the beginning of a socket message to convey following message size
  HEADER_SIZE = 10
}
-- Make immutable
SOCKETS = protect(SOCKETS)

local JPEG = {}
-- Low accuracy
JPEG[1] = 150
-- Medium accuracy
JPEG[2] = 400
-- High accuracy
JPEG[3] = 750
-- Make immutable
JPEG = protect(JPEG)

-- LrMobdebug.start()


---------------------------------------------------------------------------
-- Helper functions
---------------------------------------------------------------------------

-- Function to log messages
function back_end.log( message )
  myLogger:trace( message )
end



----------------------------------------------------------------------------
-- Python Script Functions

----------------------------------------------------------------------------

-- Starts the Python script
function back_end.run_python_script(script_path)
  LrTasks.startAsyncTask(function()
    local success = LrTasks.execute(script_path)
    back_end.log(success)
  end)
end


-- Python exe
local python_exe_command = 'start ' .. _PLUGIN['path'] .. '/test/dist/pythonTestScript.exe'

function back_end.run_python_exe()
  LrTasks.startAsyncTask(function()
    local success = LrTasks.execute(python_exe_command)
    back_end.log(success)
  end)
end



-----------------------------------------------------------------------------
-- JPEG Section

-----------------------------------------------------------------------------

local function request_jpeg(photo, accuracy)
  -- Local copy of jpeg data
  local _jpeg
  -- Size of the requested jpeg based on user-selected accuracy from dialog slider
  -- JPEG is a table in the CONSTANTS section
  local size = JPEG[accuracy]

  -- Request jpeg thumbnail for current photo
  local returnValue = photo:requestJpegThumbnail(size, size, function(jpeg)
    -- Get the size of the jpeg
    local size_jpeg = LrStringUtils.numberToString( string.len(jpeg), 0 )
      -- Ensure the string for the jpeg size is of size HEADER_SIZE
      while string.len(size_jpeg) < SOCKETS.HEADER_SIZE do
        size_jpeg = ' ' .. size_jpeg
      end
      back_end.log('From request_jpeg: ' .. size_jpeg)
      -- Prepend the header to the jpeg
      _jpeg = size_jpeg .. jpeg
  end) -- requestJpegThumbnail

  return _jpeg
end



------------------------------------------------------------------
-- Metadata functions

------------------------------------------------------------------

-- Global caption string
local caption

-- Add caption to a photo
local function add_metadata(catalog, photo, append)
  LrTasks.startAsyncTask(function()
    catalog:withWriteAccessDo("LightroomCV", function()
      local temp = photo:getFormattedMetadata('caption')
      if append == false or temp == "" then
        photo:setRawMetadata('caption', caption)
      else
        photo:setRawMetadata('caption', temp ..  ", " .. caption)
      end
    end)
  end)
end



----------------------------------------------------------------------------
-- Socket Send Functions
----------------------------------------------------------------------------

-- Callback for onConnected
local function send_socket_on_Connected()
  
end

-- Global received message variable
-- 0: Not ready for new jpeg
-- 1: Ready for new jpeg
-- 2: This is a caption
local received_message = 0


-- Starts sending jpegs
local function send_socket_send_jpegs(sender, propertyTable)
  local catalog = LrApplication.activeCatalog()
  local photos = nil
  local append = false

  -- Generate photo list based on user selection
  -- NOTE: The findPhotos method needs to be started from LrTasks, which should be fine since the parent funcion
  --of this one (start_send_socket) is an LrTask-async task
  if propertyTable.radio_photoSelect == "radio_entireLibrary" then
    photos = catalog:getAllPhotos() -- this could be a HUUUGE list!
  elseif propertyTable.radio_photoSelect == "radio_previouslyImported" then
    --photos listed in the previous import collection
    --taken from here: https://feedback.photoshop.com/conversations/lightroom-classic/sdk-lightroom-is-it-possible-to-retrieve-photo-array-of-kpreviousimport-collection/5f5f46084b561a3d426f8c9b
    --This is a silly way of doing it, but there doesn't seeme to be an easy, direct method...
    --sleep() methods are needed to give the SDK time to make the changes we need
    local tempSources = catalog:getActiveSources()
    local tempView = catalog:getCurrentViewFilter()
    local tempSelection = nil
    if catalog:getTargetPhoto() ~= nil then
      tempSelection = catalog:getTargetPhotos()
    end
    catalog:setActiveSources(catalog.kPreviousImport)
    LrTasks.sleep(0.05)
    catalog:setViewFilter()
    LrTasks.sleep(0.05)
    LrSelection.selectNone()
    LrTasks.sleep(0.05)
    photos = catalog:getTargetPhotos()
    catalog:setActiveSources(tempSources)
    LrTasks.sleep(0.05)
    catalog:setViewFilter(tempView)
    LrTasks.sleep(0.05)
    if tempSelection ~= nil then
      catalog:setSelectedPhotos(tempSelection[1], tempSelection)
      LrTasks.sleep(0.05)
    end
  elseif propertyTable.radio_photoSelect == "radio_selected" then
    photos = catalog:getTargetPhotos()
  elseif propertyTable.radio_photoSelect == "radio_noKeywords" then
    photos = catalog:findPhotos {
      --photos with a blank caption field
      searchDesc = {
        criteria = "caption",
        operation = "==",
        value = "",
      }
    }
  else
    --ERROR
    photos = nil
    back_end.log("Error with photo selection UI")
  end
  back_end.log("Size of photo list: " .. #(photos))

  if propertyTable.radio_existingTags == "radio_overwrite" then
    append = false
  elseif propertyTable.radio_existingTags == "radio_append" then
    append = true
  else
    --ERROR
    back_end.log("Error with caption overwrite UI")
  end

  if photos == nil then
    LrDialogs.message("Welcome to LightroomCV", "Please select a photo")
    return
  end

  -- Wait for "ready" response from Python script
  -- receive_socket_on_Message() will set to 1 when 'ready' message received
  while received_message == 0 do
    LrTasks.sleep( 1/2 ) -- seconds
  end
  -- Reset message flag
  received_message = 0

  local jpeg_request_counter
  local max_jpeg_request_tries = 3
  local jpeg_timeout_counter

  -- Loop through selected photos
  for i, photo in ipairs(photos) do
    -- Request jpeg thumbnail for current photo
    local jpeg
    jpeg_request_counter = 0
    repeat
      jpeg_request_counter = jpeg_request_counter + 1
      jpeg = request_jpeg(photo, 2)
    until not (jpeg == nil) or jpeg_request_counter == 3
    if jpeg == nil then
      back_end.log("jpeg == nil")
    else
      back_end.log('send_socket_send_jpegs: ' .. string.len(jpeg))
      sender:send(jpeg)
      back_end.log('sent')

      -- Wait for caption response from Python script
      -- receive_socket_on_Message() will set received_message to 2 when caption message received
      jpeg_timeout_counter = 0
      while received_message == 0 do
        LrTasks.sleep( 1/2 ) -- seconds
        jpeg_timeout_counter = jpeg_timeout_counter + 1
        if jpeg_timeout_counter == 20 then
          sender:close()
          return
        end
      end
      -- Reset message flag
      received_message = 0

      add_metadata(catalog, photo, append)
    end -- if jpeg == nil

  end -- photo for-loop
  sender:close()
end


-- Starts a socket connection to send data
function back_end.start_send_socket(propertyTable)
  LrTasks.startAsyncTask(function()
    -- LrMobdebug.on()
    LrFunctionContext.callWithContext( 'socket_remote', function( context )
      local running = true
      local sender = LrSocket.bind {
        functionContext = context,
        plugin = _PLUGIN,
        port = 55623,
        mode = "send",
        onConnecting = function( socket, port )
          back_end.log('send socket connecting')
        end,
        onConnected = function( socket, port )
          back_end.log('send socket connected')
        end,
        onMessage = function( socket, message )
          -- nothing, we don't expect to get any messages back from a send port
        end,
        onClosed = function( socket )
          back_end.log('send socket closed')
          running = false
        end,
        onError = function( socket, err )
          if err == "timeout" then
            back_end.log('send socket timed out')
            socket:close()
            --socket:reconnect()
          end
          LrDialogs.message( "Send Socket " .. err, err, nil )
        end,
      } -- sender

      -- Start sending jpegs
      send_socket_send_jpegs(sender, propertyTable)

      sender:close()

      while running do
        LrTasks.sleep( 1/2 ) -- seconds
      end
      sender:close()

    end) -- LrFunctionContext

  end) -- LrTasks.startAsyncTask

end -- start_send_socket



--------------------------------------------------------------------------
-- Socket Receive Functions

--------------------------------------------------------------------------

-- Callback when message received
local function receive_socket_on_Message(socket, message)
  back_end.log('Received message: ' .. message)
  if message == 'ready' then
    received_message = 1
  else
    caption = message
    received_message = 2
  end -- end if
end


-- Starts a receive socket connection
-- Message received must be terminated with a newline character: '\n'
function back_end.start_receive_socket()
  LrTasks.startAsyncTask(function()
    -- LrMobdebug.on()
    LrFunctionContext.callWithContext( 'socket_remote', function( context )
      local running = true
      local receiver = LrSocket.bind {
        functionContext = context,
        plugin = _PLUGIN,
        port = 55624,
        mode = "receive",
        onConnecting = function( socket, port )
          back_end.log('receive socket connecting')
        end,
        onConnected = function( socket, port )
          back_end.log('receive socket connected')
        end,
        onMessage = function( socket, message )
          receive_socket_on_Message(socket, message)
        end,
        onClosed = function( socket )
          back_end.log('receive socket closed')
          running = false
        end,
        onError = function( socket, err )
          if err == "timeout" then
            back_end.log('receive socket timed out')
          end
          LrDialogs.message( "Receive Socket " .. err, err, nil )
          socket:close()
          --socket:reconnect()
        end,
      } -- receiver

      while running do
        LrTasks.sleep( 1/2 )
      end
      receiver:close()

    end)  -- LrFunctionContext

  end) -- LrTasks.startAsyncTask
end -- start_receive_socket




return back_end
