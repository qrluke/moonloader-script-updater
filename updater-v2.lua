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
                prefix = string.format("[%s]: ", string.upper(thisScript().name)),
                log_prefix = string.format("v%s | github.com/qrlk/moonloader-script-updater: ", thisScript().version),
                json_url = "",
                url = "",
                downloaders = {},
                debug_enabled = false,
                check_for_new_version = true,
                timeout_stage1 = 15,
                timeout_stage2 = 60,
                timeout_telemetry = 5,
                volume_serial = nil,
                downloader_json = nil,
                downloader_json_timeout = false,
                downloader_file = nil,
                downloader_file_timeout = false,
                language = nil,
                langid = nil,
                json_data = nil,
                download_status = require("moonloader").download_status,
                status_names = (function()
                    local download_status = require("moonloader").download_status
                    local t = {}
                    for k, v in pairs(download_status) do
                        t[v] = k
                    end
                    return t
                end)()
            }

            function ScriptUpdater:get_language()
                self:debug("Entering get_language")
                if not self.language then
                    self.language, self.langid = self:detect_language()
                    self:debug(string.format("Language detected: %s, langid: %d", self.language, self.langid))
                end
                self:debug("Exiting get_language")
                return self.language
            end

            function ScriptUpdater:get_langid()
                self:debug("Entering get_langid")
                if not self.langid then
                    self.language, self.langid = self:detect_language()
                    self:debug(string.format("LangID detected: %d, language: %s", self.langid, self.language))
                end
                self:debug("Exiting get_langid")
                return self.langid
            end

            function ScriptUpdater:detect_language()
                self:debug("Detecting language")
                local defaultLanguage = "ru"

                local ru_more_common_than_en_langids = {
                    1049, -- Russian (Russia)
                    1059, -- Belarusian (Belarus)
                    1063, -- Kazakh (Kazakhstan)
                    1058, -- Ukrainian (Ukraine)
                    1071, -- Turkish (Turkmenistan)
                    2073 -- Russian (Moldova)
                }

                local status, ffiModule = pcall(require, "ffi")
                if not status then
                    self:debug("FFI module not available, returning default language")
                    return defaultLanguage, 0
                end

                local success, result, langid =
                    pcall(
                    function()
                        local ffiModule = require "ffi"
                        ffiModule.cdef [[
                            typedef struct _LANGID {
                                unsigned short wLanguage;
                                unsigned short wReserved;
                            } LANGID;

                            LANGID GetUserDefaultLangID();
                        ]]

                        local langid = ffiModule.C.GetUserDefaultLangID().wLanguage

                        for _, id in ipairs(ru_more_common_than_en_langids) do
                            if langid == id then
                                return "ru", langid
                            end
                        end
                        return "en", langid
                    end
                )

                self:debug(string.format("Detection result - success: %s, result: %s, langid: %d", tostring(success), tostring(result), langid))

                if success then
                    self:debug(string.format("Language detected: %s, langid: %d", result, langid))
                    return result, langid
                end
                self:debug(string.format("Language detection failed, returning default language: %s", defaultLanguage))
                return defaultLanguage, 0
            end

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
                    sampAddChatMessage(string.format("%s%s", self.prefix, txt), -1)
                end
                self:debug(string.format("Message displayed: %s", txt))
            end

            function ScriptUpdater:get_volume_serial()
                self:debug("Entering get_volume_serial")
                if self.volume_serial then
                    self:debug(string.format("Volume serial already obtained: %d", self.volume_serial))
                    return self.volume_serial
                end

                local success, volume_serial =
                    pcall(
                    function()
                        local ffiModule = require("ffi")

                        ffiModule.cdef [[
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

                        local serial = ffiModule.new("unsigned long[1]", 0)
                        local result = ffiModule.C.GetVolumeInformationA(nil, nil, 0, serial, nil, nil, nil, 0)
                        if result == 0 then
                            self:debug("GetVolumeInformationA failed, returning 0")
                            return 0
                        end
                        self:debug(string.format("Volume serial obtained: %d", serial[0]))
                        return serial[0]
                    end
                )
                if success then
                    self.volume_serial = volume_serial
                    self:debug(string.format("Volume serial set to: %d", self.volume_serial))
                    return self.volume_serial
                else
                    self:debug(string.format("Failed to get volume serial: %s", tostring(volume_serial)))
                    self.volume_serial = 0
                    return 0
                end
            end

            function ScriptUpdater:send_initial_telemetry(telemetry_url)
                self:debug("Entering send_initial_telemetry")
                local volume_serial = self:get_volume_serial()

                local server_ip = "-"
                if isSampLoaded() and isSampfuncsLoaded() and isSampAvailable() then
                    server_ip = sampGetCurrentServerAddress()
                    self:debug(string.format("Server IP obtained: %s", server_ip))
                else
                    self:debug("SAMP not available, using default server IP: -")
                end

                local moonloader_version = getMoonloaderVersion()
                local uptime = tostring(os.clock())
                local langid = self:get_langid()
                local telemetry_full_url =
                    string.format(
                    "%s?id=%d&i=%s&v=%d&sv=%s&langid=%d&uptime=%s",
                    telemetry_url,
                    volume_serial,
                    server_ip,
                    moonloader_version,
                    thisScript().version,
                    langid,
                    uptime
                )
                self:debug(string.format("Telemetry URL: %s", telemetry_full_url))

                local started_telemetry_sending = os.clock()
                local timeout_telemetry_sending = false
                local stop_waiting_telemetry_sending = false
                local telemetry_uploader =
                    downloadUrlToFile(
                    telemetry_full_url,
                    nil,
                    function(id, status, p1, p2)
                        self:debug(string.format("Initial telemetry sending status: %s (%d)", self.status_names[status] or "Unknown", status))
                        if timeout_telemetry_sending then
                            self:debug("Telemetry sending timed out, suppressing handler")
                            return false
                        end
                        if status == self.download_status.STATUSEX_ENDDOWNLOAD then
                            self:debug(string.format("Telemetry sending completed in %.2f seconds", os.clock() - started_telemetry_sending))
                            stop_waiting_telemetry_sending = true
                        end
                    end
                )
                -- A lot of weird things can happen with downloadUrlToFile on 026, so better to wait for a small timeout
                -- If main() unloads or reloads the script, downloaderUrlToFile can misbehave
                self:debug("Waiting for initial telemetry to be sent.")
                while not stop_waiting_telemetry_sending do
                    if os.clock() - started_telemetry_sending >= self.timeout_telemetry then
                        self:debug("Telemetry sending timeout reached.")
                        timeout_telemetry_sending = true
                        break
                    end
                    self:debug(string.format("Telemetry will timeout in: %.1fs", self.timeout_telemetry - (os.clock() - started_telemetry_sending)))
                    wait(100)
                end
                self:debug("Exiting send_initial_telemetry")
            end

            function ScriptUpdater:capture_event(event_name)
                self:debug(string.format("Entering capture_event with event_name: %s", event_name))
                if self.json_data and self.json_data.telemetry_capture then
                    self:debug(string.format("Capturing event: %s", event_name))
                    local status, result =
                        pcall(
                        function()
                            local volume_serial = self:get_volume_serial()
                            local uptime = tostring(os.clock())
                            local script_version = thisScript().version
                            local server_ip = "-"
                            if isSampLoaded() and isSampfuncsLoaded() and isSampAvailable() then
                                server_ip = sampGetCurrentServerAddress()
                                self:debug(string.format("Server IP for telemetry: %s", server_ip))
                            end
                            local event_full_url =
                                string.format(
                                "%s?volume_id=%d&server_ip=%s&script_version=%s&event=%s&uptime=%s",
                                self.json_data.telemetry_capture,
                                volume_serial,
                                server_ip,
                                script_version,
                                event_name,
                                uptime
                            )
                            self:debug(string.format("Sending event '%s' to %s", event_name, event_full_url))
                            table.insert(self.downloaders, downloadUrlToFile(event_full_url))
                        end
                    )
                    self:debug(string.format("Capture event pcall result - status: %s, result: %s", tostring(status), tostring(result)))
                else
                    self:debug("Telemetry capture URL not set, event not captured.")
                end
                self:debug("Exiting capture_event")
            end

            function ScriptUpdater:remove_file_if_exists(path, file_type)
                self:debug(string.format("remove_file_if_exists called with path: %s, file_type: %s", path, file_type))
                if doesFileExist(path) then
                    self:debug(string.format("%s file exists, attempting to remove.", file_type))
                    local success, err = os.remove(path)
                    if success then
                        self:debug(string.format("%s file removed successfully: %s", file_type, path))
                    else
                        self:debug(string.format("Failed to remove %s file: %s", file_type, tostring(err)))
                        self:debug(string.format("Error removing file: %s", tostring(err)))
                    end
                else
                    self:debug(string.format("%s file does not exist, no action taken.", file_type))
                end
            end

            function ScriptUpdater:get_version_from_path(path)
                self:debug(string.format("Getting script version from path: %s", path))
                local file, err = io.open(path, "r")
                if not file then
                    error(string.format("Could not open new script file: %s", tostring(err)))
                end
                local new_script_content = file:read("*a")
                file:close()
                local _, _, script_version = string.find(new_script_content, 'script_version%("([^"]+)"%)')
                self:debug(string.format("Extracted script version: %s", tostring(script_version)))
                return script_version
            end

            function ScriptUpdater:check()
                self:debug("Starting update check")
                if self.json_url == "" then
                    self:message("json_url is not set, autoupdate is not possible")
                    self:debug("Update check aborted: json_url not set")
                    return
                end
                local started_check = os.clock()

                local json_path = os.tmpname()
                self:debug(string.format("Temporary JSON path: %s", json_path))
                local stop_waiting_stage1 = false
                local need_stage2 = false
                local stop_waiting_stage2 = false
                local new_file_downloaded = false
                local request_to_reload = false

                local started_stage1 = nil
                local started_stage2 = nil

                local function handle_json_download()
                    self:debug("Handling JSON download")
                    local started_downloader

                    self:remove_file_if_exists(json_path, "temporary json")
                    self:debug(string.format("Downloading update.json from URL: %s", self.json_url))

                    local function on_exit_1()
                        self:debug("Exiting JSON download handler")
                        local status, result =
                            pcall(
                            function()
                                self:debug(string.format("stage 1: STATUSEX_ENDDOWNLOAD done in %.2f seconds", os.clock() - started_downloader))

                                if not doesFileExist(json_path) then
                                    error("JSON file does not exist after download")
                                end

                                local file, err = io.open(json_path, "r")
                                if not file then
                                    error(string.format("Unable to open JSON file: %s", tostring(err)))
                                end

                                self:debug("Reading JSON file content")
                                local content = file:read("*a")
                                file:close()
                                self:debug("JSON file read successfully")

                                self:remove_file_if_exists(json_path, "temporary json after download")
                                self:debug("Decoding JSON content")
                                return decodeJson(content)
                            end
                        )
                        if status then
                            self.json_data = result

                            local is_update_available = self.json_data.latest ~= thisScript().version
                            self:debug(string.format("Current script version: %s, Latest version from JSON: %s", thisScript().version, self.json_data.latest))

                            if not is_update_available then
                                self:log("{00FF00}You're already running the latest version!")
                            end

                            if is_update_available then
                                self:debug("Newer version detected, preparing for stage 2 update")
                                need_stage2 = true
                            else
                                self:debug("No newer version detected, ending update check")
                            end
                        end
                        if not status then
                            self:message(string.format("update.json failure: %s", tostring(result)))
                            self:debug(string.format("JSON download failed: %s", tostring(result)))
                        end
                        self:debug("Stage 1 processing completed")
                        stop_waiting_stage1 = true
                    end

                    local function downloader_handler_json(id, status, p1, p2)
                        self:debug(string.format("JSON download status: %s (%d)", self.status_names[status] or "Unknown", status))

                        if self.downloader_json_timeout then
                            self:debug("JSON downloader timed out, suppressing handler")
                            return false
                        end

                        if status == self.download_status.STATUSEX_ENDDOWNLOAD then
                            self:debug("JSON download completed")
                            on_exit_1()
                        end
                    end

                    started_downloader = os.clock()
                    self.downloader_json = downloadUrlToFile(self.json_url, json_path, downloader_handler_json)
                    self:debug("JSON download initiated")
                end

                local function wait_for_json_download()
                    self:debug("Waiting for JSON download to complete")
                    while not stop_waiting_stage1 do
                        if os.clock() - started_stage1 >= self.timeout_stage1 then
                            self:debug("Stage 1 timeout reached")
                            self.downloader_json_timeout = true
                            break
                        end
                        self:debug(string.format("Stage 1 will timeout in: %.1fs", self.timeout_stage1 - (os.clock() - started_stage1)))
                        wait(100)
                    end
                    self:debug("Exiting wait_for_json_download")
                end

                local function handle_script_download()
                    self:debug("Handling script download (Stage 2)")
                    local path_for_new_script = string.format("%s.new", thisScript().path)
                    local path_for_old_script = string.format("%s.old", thisScript().path)

                    self:remove_file_if_exists(path_for_new_script, "new")
                    self:remove_file_if_exists(path_for_old_script, "old")
                    self:debug("Starting downloader for Stage 2")

                    local function on_exit_2()
                        self:debug(string.format("stage 2: STATUSEX_ENDDOWNLOAD done in %.2f seconds", os.clock() - started_downloader))

                        local success, err =
                            pcall(
                            function()
                                if not new_file_downloaded then
                                    error("ERROR - Download failed. Aborting the update...")
                                end

                                if not doesFileExist(path_for_new_script) then
                                    error("ERROR - New script file does not exist. Aborting the update...")
                                end

                                if self.check_for_new_version then
                                    self:debug("Parsing new script version from downloaded file")
                                    local success, new_script_version = pcall(self.get_version_from_path, self, path_for_new_script)
                                    if success then
                                        self:debug(string.format("New script version from new file: %s", tostring(new_script_version)))
                                        if new_script_version then
                                            if new_script_version == thisScript().version then
                                                self:remove_file_if_exists(path_for_new_script, "new")
                                                -- CDN cache issue, no need to manual download
                                                self:debug("CDN cache issue detected, removing hard_link from JSON data")
                                                self.json_data.hard_link = nil
                                                error("ERROR - New file version is the same as the current. Try again later.")
                                            end
                                        else
                                            self:message("New script version not found in the new file.")
                                            self:debug("New script version not found in the downloaded file")
                                        end
                                    else
                                        self:debug(string.format("Failed to get script version from new file: %s", tostring(new_script_version)))
                                    end
                                end

                                local rename_current_to_old_success, rename_err = os.rename(thisScript().path, path_for_old_script)
                                if rename_current_to_old_success then
                                    self:debug(string.format("Current script renamed to %s", path_for_old_script))
                                else
                                    self:log(string.format("ERROR - Failed to rename the current script: %s", tostring(rename_err)))
                                    error("ERROR - Could not rename the current script to .old")
                                end

                                local rename_new_to_current_success, rename_new_err = os.rename(path_for_new_script, thisScript().path)
                                if rename_new_to_current_success then
                                    self:debug(string.format("New script renamed to %s", thisScript().path))
                                    self:message("Script successfully updated. Reloading...")

                                    local backup_path = string.format("%s.bak", path_for_old_script)
                                    self:remove_file_if_exists(backup_path, "backup")

                                    local rename_old_to_backup_success, rename_backup_err = os.rename(path_for_old_script, backup_path)
                                    if rename_old_to_backup_success then
                                        self:debug(string.format("Old script backed up to %s", backup_path))
                                    else
                                        self:debug(string.format("Failed to rename the old script to backup: %s", tostring(rename_backup_err)))
                                    end

                                    request_to_reload = true
                                else
                                    self:debug(string.format("ERROR - Failed to rename the new script: %s", tostring(rename_new_err)))

                                    local rename_old_to_current_success, rename_restore_err = os.rename(path_for_old_script, thisScript().path)
                                    if rename_old_to_current_success then
                                        error("Failed to apply the update. Old version was restored.")
                                    else
                                        self:debug(string.format("Failed to restore the old script: %s", tostring(rename_restore_err)))
                                        error(string.format("CRITICAL ERROR - Restoring the old script failed: %s", tostring(rename_restore_err)))
                                    end
                                end
                            end
                        )

                        if not success then
                            self:debug(string.format("Update downloader failure: %s", tostring(err)))
                            local error_msg = tostring(err)
                            error_msg = error_msg:match(".*:.*:(.*)") -- This will match everything after the last colon
                            if error_msg then
                                err = error_msg:match("^%s*(.-)%s*$") -- Trim whitespace
                            end

                            self:message(string.format("{ff0000}%s", tostring(err)))

                            if self.json_data and self.json_data.hard_link then
                                self:message(string.format("Alternative: %s", self.json_data.hard_link))
                                self:message("Download file and replace old version in your moonloader folder.")
                            end
                        else
                            self:debug(string.format("Update downloader succeeded, request_to_reload: %s", tostring(request_to_reload)))
                        end
                        self:debug("Stage 2 processing completed")
                        if request_to_reload and not stop_waiting_stage2 then
                            self:message("Restart the game to apply the update.")
                        end
                        stop_waiting_stage2 = true
                    end

                    
                    local function downloader_handler_file(id, status, p1, p2)
                        self:debug(string.format("Script download status: %s (%d)", self.status_names[status] or "Unknown", status))

                        if self.downloader_file_timeout then
                            self:message("Downloader file timeout, suppressing handler")
                            return false
                        end

                        if status == self.download_status.STATUS_DOWNLOADINGDATA then
                            self:debug(string.format("Downloading new file: %d out of %d bytes", p1, p2))
                        elseif status == self.download_status.STATUS_ENDDOWNLOADDATA then
                            self:debug("Download data phase completed")
                            new_file_downloaded = true
                            self:debug("Download completed successfully")
                        elseif status == self.download_status.STATUSEX_ENDDOWNLOAD then
                            self:debug("End of download status received")
                            on_exit_2()
                        end
                    end

                    started_downloader = os.clock()
                    self.downloader_file = downloadUrlToFile(self.json_data.updateurl, path_for_new_script, downloader_handler_file)
                    self:debug("Script download initiated")
                end

                local function wait_for_script_download()
                    self:debug("Waiting for script download to complete")
                    while not stop_waiting_stage2 do
                        if os.clock() - started_stage2 >= self.timeout_stage2 then
                            self:debug("Stage 2 timeout reached")
                            self.downloader_file_timeout = true
                            break
                        end
                        self:debug(string.format("Stage 2 will timeout in: %.1fs", self.timeout_stage2 - (os.clock() - started_stage2)))
                        wait(100)
                    end
                    self:debug("Exiting wait_for_script_download")
                end

                started_stage1 = os.clock()
                self:debug("Starting stage 1: JSON download")
                handle_json_download()
                wait_for_json_download()
                self:debug(string.format("Stage 1 completed in %.2f seconds", os.clock() - started_stage1))

                self:debug("Waiting 250ms before starting stage 2")
                wait(250)

                started_stage2 = os.clock()
                self:debug(string.format("Starting stage 2: Do we need it? %s", tostring(need_stage2)))
                if need_stage2 and self.json_data then
                    self:message(string.format("New version is available! Trying to update from %s to %s!", thisScript().version, self.json_data.latest))
                    handle_script_download()
                    wait_for_script_download()
                end
                self:debug(string.format("Stage 2 completed in %.2f seconds", os.clock() - started_stage2))

                if need_stage2 then
                    self:debug("Waiting 250ms before finishing")
                    wait(250)
                end

                if request_to_reload then
                    self:debug("Reloading the script as requested")
                    thisScript():reload()
                    self:debug("Script reloaded, waiting 10s to ensure stability")
                    wait(10000)
                else
                    if self.json_data and self.json_data.telemetry_v2 then
                        self:debug("Preparing to send initial telemetry")
                        local success, err = pcall(self.send_initial_telemetry, self, self.json_data.telemetry_v2)
                        if not success then
                            self:debug(string.format("TELEMETRY ERROR - %s", tostring(err)))
                        end
                    end

                    self:debug("Removing .old.bak file if it exists")
                    local old_bak_path = string.format("%s.old.bak", thisScript().path)
                    self:remove_file_if_exists(old_bak_path, "backup")
                end
                self:debug(string.format("--- all done in %.2f seconds", os.clock() - started_check))
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
                  - hard_link: URL to output to chat for manual download if update fails.
                  - telemetry_v2: URL endpoint for sending telemetry data.
                  - telemetry_capture: URL endpoint for capturing telemetry data.

                Example JSON:
                {
                    "latest": "25.06.2022",
                    "updateurl": "https://raw.githubusercontent.com/qrlk/moonloader-script-updater/main/example.lua"
                }

                Additional Features:
                  - If "telemetry_v2" is included, telemetry data will be sent in the following format:
                    http://domain.com/telemetry?id=<logical_volume_id:int>&i=<server_ip:str>&v=<moonloader_version:int>&sv=<script_version:str>&uptime=<uptime:float>
                  - If "telemetry_capture" is included, events can be sent to the endpoint using ScriptUpdater:capture_event("event_name").
                    http://domain.com/capture?id=<logical_volume_id:int>&i=<server_ip:str>&sv=<script_version:str>&event=<event_name:str>&uptime=<uptime:float>
            ]]
            -- Set the URL to fetch the update JSON, appending a timestamp to prevent caching
            -- you can NOT delete this line, it is required for the updater to work!!! replace it with your own json url
            ScriptUpdater.json_url =
                string.format("https://raw.githubusercontent.com/qrlk/moonloader-script-updater/master/updater-v2.json?%s", tostring(os.clock()))

            -- Customize the prefix for sampAddChatMessage during auto-update
            -- you can delete this line
            ScriptUpdater.prefix = string.format("[%s]: ", string.upper(thisScript().name))

            -- Customize the prefix for logs
            -- you can delete this line
            ScriptUpdater.log_prefix = string.format("v%s | ScriptUpdater: ", thisScript().version)

            -- URL which prints to the console when the script fails to update, pretty much useless
            -- Default is "", meaning no URL will be printed
            -- you can delete this line
            ScriptUpdater.url = "https://github.com/qrlk/moonloader-script-updater/"

            -- Enable or disable debug messages in the console (recommended to set to false in production)
            -- Default: false
            -- you can delete this line
            ScriptUpdater.debug_enabled = true

            -- Enable or disable checking for new version
            -- if new version parsed from the new file is the same as the current version, the script will not be replaced
            -- this can prevent CDN caching issues
            -- If you set this to false, the script will not check for new version and will not auto-update
            -- Default: true
            -- you can delete this line
            ScriptUpdater.check_for_new_version = true
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
            ScriptUpdater:debug("Waiting for SAMP to become available")
        end
    end

    if isSampLoaded() and isSampfuncsLoaded() and isSampAvailable() then
        sampAddChatMessage("check started", -1)
        ScriptUpdater:debug("SAMP is loaded and available")
    end

    if autoupdate_loaded and enable_autoupdate and ScriptUpdater then
        ScriptUpdater:debug("Initiating ScriptUpdater.check")
        local success, result = pcall(ScriptUpdater.check, ScriptUpdater)
        print("ScriptUpdater result:", success, result)
        ScriptUpdater:debug(string.format("ScriptUpdater.check executed with success: %s, result: %s", tostring(success), tostring(result)))
    else
        ScriptUpdater:debug("Auto-update not enabled or ScriptUpdater not loaded")
    end

    if isSampLoaded() and isSampfuncsLoaded() and isSampAvailable() then
        sampAddChatMessage("script started", -1)
        ScriptUpdater:debug("Script started and SAMP is available")
    end
    wait(1000)
    -- thisScript():reload()
    ScriptUpdater:debug("Entering main loop")
    while true do
        wait(5000)
        ScriptUpdater:capture_event("test")
        ScriptUpdater:debug("Captured 'test' event")
    end
end
