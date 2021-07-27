-- Access the Lightroom SDK namespaces.
local LrFunctionContext = import "LrFunctionContext"
local LrBinding = import "LrBinding"
local LrDialogs = import "LrDialogs"
local LrView = import "LrView"
local LrExportSession = import "LrExportSession"
local LrApplication = import "LrApplication"
local LrLogger = import "LrLogger"
local LrTasks = import "LrTasks"
local back_end = require 'back_end'

-- For debugging
local myLogger = LrLogger( 'libraryLogger' )
myLogger:enable( "logfile" )


-- Gets called whenever a UI element's value is updated
local function updateStatus(propertyTable)
    local error = false
    local message

    if propertyTable.radio_photoSelect == "" or propertyTable.radio_photoSelect == nil then
        message = "Please select which photos to send to LightroomCV"
        error = true
    end

    if propertyTable.radio_existingTags == "" or propertyTable.radio_existingTags == nil then
        message = "Please select what LightroomCV should do with any pre-existing tags"
        error = true
    end

    propertyTable.enableOK = not error
end

local function startExport(propertyTable)
    -- Python command
    local commandForPython = 'python'
    -- Path to Python script
    local pathToPythonScript = '"' .. _PLUGIN['path'] .. '/test/pythonTestScript.py' .. '"'
    -- Total command
    local totalCommand = commandForPython .. ' ' .. pathToPythonScript

    -- Start the socket connections
    back_end.start_send_socket(propertyTable)
    back_end.start_receive_socket()

    -- Start the Python script
    -- back_end.run_python_script(totalCommand)
    back_end.run_python_script('start ' .. _PLUGIN['path'] .. '/captioner/captioner_start.bat ' .. _PLUGIN['path'])

    return true
end

-- Defines the dialog window
local function showCustomDialog()
    local result = LrFunctionContext.callWithContext( "LightroomCV", function( context )
        -- setup property table to monitor UI element values
        local propertyTable = LrBinding.makePropertyTable(context)
        propertyTable.radio_photoSelect = "radio_selected"
        propertyTable.radio_existingTags = "radio_overwrite"
        propertyTable.enableOK = true
        propertyTable:addObserver("radio_photoSelect", updateStatus)
        propertyTable:addObserver("radio_existingTags", updateStatus)
        propertyTable:addObserver("enableOK", updateStatus)

        -- Defines the UI layout
        local myWidth = 400
        local f = LrView.osFactory()
        local c = f:column {
            bindToObject = propertyTable,
            spacing = f:control_spacing(),

            f:row {
                f:group_box {
                    title = "Which Photos Should Be Sent To LightroomCV?",
                    fill_horizontal = 1,
                    width = myWidth,
                    spacing = f:control_spacing(),

                    f:radio_button {
                        title = "Entire Photo Library",
                        value = LrView.bind("radio_photoSelect"),
                        checked_value = "radio_entireLibrary",
                    },
                    f:radio_button {
                        title = "Previously Imported Photos",
                        value = LrView.bind("radio_photoSelect"),
                        checked_value = "radio_previouslyImported",
                    },
                    f:radio_button {
                        title = "Selected Photos",
                        value = LrView.bind("radio_photoSelect"),
                        checked_value = "radio_selected",
                    },
                    f:radio_button {
                        title = "Photos Without Existing Keywords",
                        value = LrView.bind("radio_photoSelect"),
                        checked_value = "radio_noKeywords",
                    },
                },		
            },

            f:row {
                f:group_box {
                    title = "What Should LightroomCV Do To Any Existing Photo Tags?",
                    fill_horizontal = 1,
                    width = myWidth,

                    f:radio_button {
                        title = "Append",
                        value = LrView.bind("radio_existingTags"),
                        checked_value = "radio_append",
                    },
                    f:radio_button {
                        title = "Overwrite",
                        value = LrView.bind("radio_existingTags"),
                        checked_value = "radio_overwrite",
                    },
                },
            },
        }

        -- Presents the dialog window to the user
        local action = LrDialogs.presentModalDialog {
            title = "LightroomCV",
            contents = c,
            actionVerb = "Go",
            cancelVerb = "Cancel",
            actionBinding = {
                enabled = {
                    bind_to_object = propertyTable,
                    key = "enableOK"
                }
            }
        }

        local export_result
        -- user has clicked OK (or cancel), next step can go here
        if(action == 'ok') then 
            export_result = startExport(propertyTable)
        end

        return export_result
    end)

    return result
end

local dialog_result
--Actually start the dialogs & export process.
dialog_result = showCustomDialog()   --either 'ok' or 'cancel' depending on which button was clicked
--LrDialogs.message("Feedback", result, "info")
