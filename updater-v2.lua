require "lib.moonloader"

script_name("V2")
script_url("https://github.com/qrlk/moonloader-script-updater")
script_version("28.11.2024")

-- https://github.com/qrlk/moonloader-script-updater
local enable_autoupdate = true -- Set to false to disable auto-update and telemetry
local autoupdate_loaded = false
local ScriptUpdater = nil

if enable_autoupdate then
    --[[
        To minify use:
        local updater_loaded, getScriptUpdater = pcall(loadstring, [=[(function() local ScriptUpdater = {...} ... end)]=])
    ]]
    local updater_loaded, getScriptUpdater =
        true,
        (function()
            local ScriptUpdater = {
                prefix = "[" .. string.upper(thisScript().name) .. "]: ",
                log_prefix = string.format("v%s | github.com/qrlk/moonloader-script-updater: ", thisScript().version),
                json_url = "",
                url = "",
                hard_command = "",
                hard_registered = false,
                downloaders = {},
                debug_enabled = false,
                volume_serial = nil,
                downloader_json = nil,
                downloader_json_timeout = false,
                downloader_file = nil,
                downloader_file_timeout = false,
                json_data = nil
            }

            function ScriptUpdater:log(...)
                local args = {...}
                for i, v in ipairs(args) do
                    args[i] = tostring(v)
                end
                print(string.format("%s%s", self.log_prefix, table.concat(args, ", ")))
            end

            function ScriptUpdater:debug(...)
                if not self.debug_enabled then
                    return
                end
                self:log(...)
            end

            function ScriptUpdater:message(...)
                local args = {...}
                for i, v in ipairs(args) do
                    args[i] = tostring(v)
                end
                local txt = table.concat(args, ", ")
                if isSampLoaded() and isSampfuncsLoaded() and isSampAvailable() then
                    sampAddChatMessage(string.format("%sv%s | ScriptUpdater: %s", self.prefix, thisScript().version, txt), -1)
                end
                self:debug(txt)
            end

            function ScriptUpdater:openLink(link)
                local success, ffi = pcall(require, "ffi")
                if not success then
                    self:message("Failed to load FFI library")
                    return
                end

                local success_cdef =
                    pcall(
                    ffi.cdef,
                    [[
                    void* __stdcall ShellExecuteA(void* hwnd, const char* op, const char* file, const char* params, const char* dir, int show_cmd);
                    uint32_t __stdcall CoInitializeEx(void*, uint32_t);
                  ]]
                )
                if not success_cdef then
                    self:message("Failed to define FFI functions")
                    return
                end

                local success_shell32, shell32 = pcall(ffi.load, "Shell32")
                if not success_shell32 then
                    self:message("Failed to load Shell32.dll")
                    return
                end

                local success_ole32, ole32 = pcall(ffi.load, "Ole32")
                if not success_ole32 then
                    self:message("Failed to load Ole32.dll")
                    return
                end

                local success_coinit =
                    pcall(
                    function()
                        ole32.CoInitializeEx(nil, 2 + 4) -- COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE
                    end
                )
                if not success_coinit then
                    self:message("Failed to initialize COM")
                    return
                end

                self:message("opening link in your browser: " .. link)

                local success_shell =
                    pcall(
                    function()
                        print(shell32.ShellExecuteA(nil, "open", link, nil, nil, 1))
                    end
                )
                if not success_shell then
                    self:message("Failed to open link")
                end
            end

            function ScriptUpdater:get_volume_serial()
                if self.volume_serial then
                    return self.volume_serial
                end

                local success, volume_serial =
                    pcall(
                    function()
                        local ffi = require("ffi")
                        local success_cdef, err =
                            pcall(
                            ffi.cdef,
                            [[
                                int __stdcall GetVolumeInformationA(
                                    const char* lpRootPathName, 
                                    char* lpVolumeNameBuffer, 
                                    uint32_t nVolumeNameSize, 
                                    uint32_t* lpVolumeSerialNumber, 
                                    uint32_t* lpMaximumComponentLength, 
                                    uint32_t* lpFileSystemFlags, 
                                    char* lpFileSystemNameBuffer, 
                                    uint32_t nFileSystemNameSize
                                );
                            ]]
                        )
                        if not success_cdef then
                            self:debug(string.format("Failed to define FFI function: %s", tostring(err)))
                            return 0
                        end

                        local serial = ffi.new("unsigned long[1]", 0)
                        local result = ffi.C.GetVolumeInformationA(nil, nil, 0, serial, nil, nil, nil, 0)
                        if result == 0 then
                            self:debug("GetVolumeInformationA failed")
                            return 0
                        end
                        return serial[0]
                    end
                )
                if success then
                    self.volume_serial = volume_serial
                    return self.volume_serial
                else
                    self:debug(string.format("Failed to get volume serial: %s", tostring(volume_serial)))
                    self.volume_serial = 0
                    return 0
                end
            end

            function ScriptUpdater:send_initial_telemetry(telemetry_url)
                local volume_serial = self:get_volume_serial()

                local server_ip = "-"
                if isSampLoaded() and isSampfuncsLoaded() and isSampAvailable() then
                    server_ip = sampGetCurrentServerAddress()
                end

                local moonloader_version = getMoonloaderVersion()
                local uptime = tostring(os.clock())

                local telemetry_full_url = string.format("%s?id=%d&i=%s&v=%d&sv=%s&uptime=%s", telemetry_url, volume_serial, server_ip, moonloader_version, thisScript().version, uptime)

                table.insert(self.downloaders, downloadUrlToFile(telemetry_full_url))
            end

            function ScriptUpdater:capture_event(event_name)
                if self.capture_endpoint then
                    self:debug(string.format("capturing event: %s", event_name))
                    self:debug(
                        pcall(
                            function()
                                local volume_serial = self:get_volume_serial()
                                local uptime = tostring(os.clock())
                                local script_version = thisScript().version
                                local server_ip = "-"
                                if isSampLoaded() and isSampfuncsLoaded() and isSampAvailable() then
                                    server_ip = sampGetCurrentServerAddress()
                                end
                                local event_full_url =
                                    string.format(
                                    "%s?volume_id=%d&server_ip=%s&script_version=%s&event=%s&uptime=%s",
                                    self.capture_endpoint,
                                    volume_serial,
                                    server_ip,
                                    thisScript().version,
                                    event_name,
                                    uptime
                                )
                                self:debug(string.format("sending %s to %s", event_name, event_full_url))
                                table.insert(self.downloaders, downloadUrlToFile(event_full_url))
                            end
                        )
                    )
                end
            end

            function ScriptUpdater:remove_file_if_exists(path, file_type)
                self:debug(string.format("path for %s: %s", file_type, path))
                if doesFileExist(path) then
                    self:debug(string.format("path for %s script file is NOT empty: %s", file_type, path))
                    local success, err = os.remove(path)
                    if success then
                        self:debug(string.format("%s script file removed: %s", file_type, path))
                    else
                        self:debug(string.format("failed to remove %s script file: %s", file_type, path))
                        self:debug(string.format("error removing file: %s", tostring(err)))
                    end
                else
                    self:debug(string.format("path for %s script file is free: %s", file_type, path))
                end
            end

            function ScriptUpdater:get_version_from_path(path)
                local success, result =
                    pcall(
                    function()
                        local file = io.open(path, "r")
                        if not file then
                            error("Could not open new script file")
                        end
                        local new_script_content = file:read("*a")
                        file:close()
                        local _, _, script_version = string.find(new_script_content, 'script_version%("([^"]+)"%)')
                        return script_version
                    end,
                    path
                )
                return success, result
            end

            function ScriptUpdater:register_hard_command(link)
                if self.hard_command == "" then
                    return
                else
                    if isSampLoaded() and isSampfuncsLoaded() and isSampAvailable() then
                        sampRegisterChatCommand(
                            self.hard_command,
                            function()
                                self:debug(pcall(self.openLink, self, link))
                            end
                        )
                        self:message(string.format("If update fails, download manually using: /%s", self.hard_command))
                        self:message(string.format("It will open %s in your browser! Drop file in your script folder.", link))
                        self.hard_registered = true
                    end
                end
            end

            function ScriptUpdater:check()
                if self.json_url == "" then
                    self:message("json_url is not set, autoupdate is not possible")
                    return
                end
                local stop_waiting_stage1 = false
                local need_stage2 = false
                local stop_waiting_stage2 = false
                local downloaded = false
                local download_status = require("moonloader").download_status
                local status_names = {}
                for name, id in pairs(download_status) do
                    status_names[id] = name
                end
                local json = os.tmpname()

                local function error_stage_2(error_message)
                    self:message(error_message)
                    if self.hard_registered then
                        self:message(string.format("Use %s to download manually.", self.hard_command))
                        self:message(string.format("It will open %s in your browser!", self.json_data.hard_link))
                        self:message("Drop file in your script folder (moonloader), replacing old version.")
                    end
                    stop_waiting_stage2 = true
                end

                self:remove_file_if_exists(json, "temporary json")

                self:debug(string.format("update.json || url: %s", self.json_url))

                local started_stage1 = os.clock()
                self.downloader_json =
                    downloadUrlToFile(
                    self.json_url,
                    json,
                    function(id, status, p1, p2)
                        self:debug(string.format("update.json || download status: %s (%d)", status_names[status] or "Unknown", status))
                        if self.downloader_json_timeout then
                            self:debug("downloader_json timeout, suppressing handler")
                            -- this seems to stop only when download in progress, not when it has not begun yet
                            -- like if download via https://httpstat.us/200?sleep=5000 it will not stop
                            return false
                        end
                        if status == download_status.STATUSEX_ENDDOWNLOAD then
                            self:debug(string.format("stage 1: STATUSEX_ENDDOWNLOAD done in %.2f seconds", os.clock() - started_stage1))
                            local does_json_exist = doesFileExist(json)
                            if not does_json_exist then
                                self:debug("json file does not exist")
                                self:debug("auto-update failed")
                                stop_waiting_stage1 = true
                                return
                            end

                            local success, file = pcall(io.open, json, "r")
                            if not success or not file then
                                self:debug("Unable to open update.json")
                                self:debug(success, file)
                                self:debug("auto-update failed")
                                stop_waiting_stage1 = true
                                return
                            end

                            local content
                            local success, err =
                                pcall(
                                function()
                                    content = file:read("*a")
                                    file:close()
                                end
                            )
                            if not success then
                                self:debug("Error reading/closing file: " .. tostring(err))
                                self:debug("auto-update failed")
                                stop_waiting_stage1 = true
                                return
                            end

                            self:remove_file_if_exists(json, "temporary json after download")

                            local success, info = pcall(decodeJson, content)
                            if not success or not info then
                                self:debug("Failed to parse update.json.")
                                self:debug("auto-update failed")
                                stop_waiting_stage1 = true
                                return
                            else
                                self:debug(string.format("update.json parsed successfully, latest version: %s", info.latest))
                                self.json_data = info
                            end

                            local is_update_available = info.latest ~= thisScript().version
                            self:debug(string.format("current version from script: %s", thisScript().version))
                            self:debug(string.format("latest version from update.json: %s", info.latest))

                            if not is_update_available then
                                self:log("No new version available, guess you're stuck with the old one for now! c:")
                            end

                            if info.telemetry_capture then
                                self.capture_endpoint = info.telemetry_capture
                                self:debug(string.format("capture_endpoint: %s", self.capture_endpoint))
                            end

                            if is_update_available then
                                if info.hard_link then
                                    self:register_hard_command(info.hard_link)
                                end
                                need_stage2 = true
                                stop_waiting_stage1 = true
                            else
                                self:debug("newer version is not available, so ending auto-update check")
                                stop_waiting_stage1 = true
                            end
                        end
                    end
                )

                -- Wait for the download to complete or timeout after 10 seconds
                while not stop_waiting_stage1 do
                    self:debug(string.format("waiting in main() for 1s because of downloading update.json. time before timeout: %d seconds", 15 - math.floor(os.clock() - started_stage1)))
                    wait(1000)
                    if os.clock() - started_stage1 >= 15 and not need_stage2 then
                        if self.url ~= "" then
                            self:message(string.format("Timeout while checking for updates. Please check manually at %s.", self.url))
                        else
                            self:debug("Timeout while checking for updates.")
                        end
                        self.downloader_json_timeout = true
                        break
                    end
                end
                self:debug(string.format("stage 1 done (+waiting) in %.2f seconds", os.clock() - started_stage1))
                wait(500)
                local started_stage2 = os.clock()

                self:debug(string.format("starting stage 2, do we need it: %s", tostring(need_stage2)))
                local request_to_reload = false
                if need_stage2 and self.json_data then
                    local success, err =
                        pcall(
                        function()
                            self:message(string.format("New version is available! Trying %s -> %s.", thisScript().version, self.json_data.latest))
                            local path_for_new_script = tostring(thisScript().path):gsub("%.%w+$", ".new")
                            self:remove_file_if_exists(path_for_new_script, "new")

                            local path_for_old_script = tostring(thisScript().path):gsub("%.%w+$", ".old")
                            self:remove_file_if_exists(path_for_old_script, "old")

                            self.downloader_file =
                                downloadUrlToFile(
                                self.json_data.updateurl,
                                path_for_new_script,
                                function(id, status, p1, p2)
                                    self:debug(string.format("update downloader || download status: %s (%d)", status_names[status] or "Unknown", status))
                                    if self.downloader_file_timeout then
                                        self:message("downloader_file timeout, suppressing handler")
                                        -- this seems to stop only when download in progress, not when it has not begun yet
                                        -- like if download via https://httpstat.us/200?sleep=5000 it will not stop
                                        return false
                                    end
                                    if status == download_status.STATUS_DOWNLOADINGDATA then
                                        self:debug(string.format("downloaded %d out of %d.", p1, p2))
                                    elseif status == download_status.STATUS_ENDDOWNLOADDATA then
                                        downloaded = true
                                        self:debug("Download completed.")
                                    elseif status == download_status.STATUSEX_ENDDOWNLOAD then
                                        self:debug(string.format("stage 2: STATUSEX_ENDDOWNLOAD done in %.2f seconds", os.clock() - started_stage2))
                                        if not downloaded then
                                            error_stage_2("ERROR - Download failed.")
                                            return
                                        end

                                        local does_new_script_exist = doesFileExist(path_for_new_script)
                                        if not does_new_script_exist then
                                            error_stage_2("ERROR - New script file does not exist. Update failed. Launching the outdated version...")
                                            return
                                        end

                                        local success, script_version = self:get_version_from_path(path_for_new_script)
                                        if success then
                                            self:debug(string.format("New script version from new file: %s", script_version))
                                            if script_version then
                                                if script_version == thisScript().version then
                                                    self:remove_file_if_exists(path_for_new_script, "new")
                                                    error_stage_2("New file version is the same as the current. Try to update later...")
                                                    return
                                                end
                                            else
                                                self:message("New script version not found in the new file.")
                                            end
                                        else
                                            self:debug(string.format("Failed to get script version from new file: %s", tostring(script_version)))
                                        end

                                        local rename_current_to_old_success, err = os.rename(thisScript().path, path_for_old_script)
                                        if rename_current_to_old_success then
                                            self:debug(string.format("Current script renamed to %s", path_for_old_script))
                                        else
                                            self:debug(string.format("ERROR - Failed to rename the current script: %s", tostring(err)))
                                        end

                                        local rename_new_to_current_success, err = os.rename(path_for_new_script, thisScript().path)
                                        if rename_new_to_current_success then
                                            self:debug(string.format("New script renamed to %s", thisScript().path))
                                            self:message("Script successfully updated. Reloading...")
                                            local backup_path = path_for_old_script .. ".bak"
                                            self:remove_file_if_exists(backup_path, "backup")
                                            local rename_old_to_backup_success, err = os.rename(path_for_old_script, backup_path)
                                            if rename_old_to_backup_success then
                                                self:debug(string.format("Old script renamed for backup to %s", backup_path))
                                            else
                                                self:debug(string.format("ERROR - Failed to rename the old script to backup: %s", tostring(err)))
                                            end
                                            request_to_reload = true
                                        else
                                            self:debug(string.format("ERROR - Failed to rename the new script: %s", tostring(err)))
                                            local rename_new_to_current_success2, err2 = os.rename(path_for_old_script, thisScript().path)
                                            if rename_new_to_current_success2 then
                                                self:message("Script successfully updated. Reloading...")
                                                request_to_reload = true
                                            end
                                        end
                                    end
                                end
                            )
                        end
                    )
                    self:debug("done with downloader pcall", success, err)

                    while not stop_waiting_stage2 do
                        self:debug(string.format("waiting in main() for 1s because new version is downloading. time before timeout: %d seconds", 60 - math.floor(os.clock() - started_stage2)))
                        wait(1000)
                        if os.clock() - started_stage2 >= 60 then
                            self:message("Giving up on waiting for new version to download. Cancelling downloader_file.")
                            self.downloader_file_timeout = true
                            break
                        end
                    end
                end
                self:debug(string.format("stage 2 done (+waiting) in %.2f seconds", os.clock() - started_stage2))

                wait(500)
                if request_to_reload then
                    thisScript():reload()
                    wait(10000)
                else
                    if self.json_data and self.json_data.telemetry_v2 then
                        local success, err = pcall(self.send_initial_telemetry, self, self.json_data.telemetry_v2)
                        if not success then
                            self:debug(string.format("TELEMETRY ERROR - %s", tostring(err)))
                        end
                    end

                    self:debug("removing .old.bak if exists")
                    self:remove_file_if_exists(tostring(thisScript().path):gsub("%.%w+$", ".old.bak"), "backup")
                end
            end

            return ScriptUpdater
        end)

    if updater_loaded then
        autoupdate_loaded, ScriptUpdater = pcall(getScriptUpdater)
        if autoupdate_loaded then
            --[[
                Script Updater Configuration
                github repo: https://github.com/qrlk/moonloader-script-updater

                don't forget to call it in main() after isSampAvailable (if you want to use samp)
                like this:
                
                if autoupdate_loaded and enable_autoupdate and ScriptUpdater then
                    print(pcall(ScriptUpdater.check, ScriptUpdater))
                end

                Required JSON Fields:
                  - latest: The latest version of the script available for download.
                  - updateurl: URL to download the latest script version.

                Optional JSON Fields:
                  - hard_link: URL to download the latest script version directly via browser.
                  - telemetry_v2: URL endpoint for sending telemetry data.
                  - telemetry_capture: URL endpoint for capturing telemetry data.

                Example JSON:
                {
                    "latest": "25.06.2022",
                    "updateurl": "https://raw.githubusercontent.com/qrlk/moonloader-script-updater/main/example.lua"
                }

                Additional Features:
                  - If "hard_link" is included, ScriptUpdater.hard_command will be set to open the link in a browser when an update is available.
                  - If "telemetry_v2" is included, telemetry data will be sent in the following format:
                    http://domain.com/telemetry?id=<logical_volume_id:int>&i=<server_ip:str>&v=<moonloader_version:int>&sv=<script_version:str>&uptime=<uptime:float>
                  - If "telemetry_capture" is included, events can be sent to the endpoint using ScriptUpdater:capture_event("event_name").
                    http://domain.com/capture?id=<logical_volume_id:int>&i=<server_ip:str>&sv=<script_version:str>&event=<event_name:str>&uptime=<uptime:float>

                ]]
            -- Set the URL to fetch the update JSON, appending a timestamp to prevent caching
            -- you can NOT delete this line, it is required for the updater to work!!! replace it with your own json url
            ScriptUpdater.json_url = "https://raw.githubusercontent.com/qrlk/moonloader-script-updater/master/updater-v2.json?" .. tostring(os.clock())

            -- Customize the prefix for sampAddChatMessage during auto-update
            -- you can delete this line
            ScriptUpdater.prefix = string.format("[%s]: ", string.upper(thisScript().name))

            -- Customize the prefix for console logs
            -- you can delete this line
            ScriptUpdater.log_prefix = string.format("v%s | ScriptUpdater: ", thisScript().version)

            -- URL which prints to the console when the script is failed to update, pretty much useless
            -- you can delete this line
            ScriptUpdater.url = "https://github.com/qrlk/moonloader-script-updater/"

            -- Enable or disable debug messages in the console (recommended to set to false in production)
            -- you can delete this line
            ScriptUpdater.debug_enabled = true

            -- Chat command to execute for opening the 'hard_link' in browser if an update is available and json has 'hard_link'
            -- Example link:
            -- "https://github.com/qrlk/moonloader-script-updater/raw/refs/heads/master/moonloader-script-updater.lua"
            -- you can delete this line
            ScriptUpdater.hard_command = "download-script-updater"
        else
            print("Failed to initialize the ScriptUpdater.")
        end
    else
        print("ScriptUpdater module failed to load.")
    end
end

function main()
    -- samp is not mandatory, but if you want to use samp functions, you should wait until samp is available
    -- sampfuncs is needed for a lot of samp-related functions
    if isSampLoaded() and isSampfuncsLoaded() then
        while not isSampAvailable() do
            wait(100)
        end
    end

    if autoupdate_loaded and enable_autoupdate and ScriptUpdater then
        print("ScriptUpdater result:", pcall(ScriptUpdater.check, ScriptUpdater))
    end
    if isSampLoaded() and isSampfuncsLoaded() and isSampAvailable() then
        sampAddChatMessage("script started", -1)
    end
    wait(3000)
    while true do
        wait(5000)
        ScriptUpdater:capture_event("test")
    end
end
