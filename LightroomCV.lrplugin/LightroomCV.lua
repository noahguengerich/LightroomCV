local back_end = require "back_end"

-- Local Python command
local commandForPython = 'python'
-- Path to Python script
local pathToPythonScript = '"' .. _PLUGIN['path'] .. '/test/pythonTestScript.py' .. '"'
-- Total command
local totalCommand = commandForPython .. ' ' .. pathToPythonScript

-- Start the socket connections
back_end.start_send_socket()
back_end.start_receive_socket()

-- Start the Python script
-- back_end.run_python_script(totalCommand)

back_end.run_python_script(_PLUGIN['path'] .. '/captioner/bryan_captioner_start.bat')