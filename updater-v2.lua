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
                if not self.language then
                    self.language, self.langid = self:detect_language()
                end
                return self.language
            end

            function ScriptUpdater:get_langid()
                if not self.langid then
                    self.language, self.langid = self:detect_language()
                end
                return self.langid
            end

            function ScriptUpdater:detect_language()
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
                    return self.defaultLanguage
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

                self:debug(success, result, langid)
                self:debug(string.format("language: %s, langid: %d", result, langid))

                if success then
                    return result, langid
                end
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
                self:debug(txt)
            end

            function ScriptUpdater:get_volume_serial()
                if self.volume_serial then
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
                self:message(string.format("Sending initial telemetry to %s", telemetry_full_url))

                local started_telemetry_sending = os.clock()
                local timeout_telemetry_sending = false
                local stop_waiting_telemetry_sending = false
                local telemetry_uploader =
                    downloadUrlToFile(
                    telemetry_full_url,
                    nil,
                    function(id, status, p1, p2)
                        self:debug(string.format("initial telemetry sending status: %s (%d)", self.status_names[status] or "Unknown", status))
                        if timeout_telemetry_sending then
                            return false
                        end
                        if status == self.download_status.STATUSEX_ENDDOWNLOAD then
                            self:debug(
                                string.format("exiting telemetry sending handler, done in %.2f seconds", os.clock() - started_telemetry_sending)
                            )
                            stop_waiting_telemetry_sending = true
                        end
                    end
                )
                -- a lot of weird things can happen with downloadUrlToFile on 026, so better to wait for small timeout
                -- if main() unloads or reloads the script, downloaderUrlToFile can misbehave
                self:debug("waiting for initial telemetry to be sent.")
                while not stop_waiting_telemetry_sending do
                    if os.clock() - started_telemetry_sending >= self.timeout_telemetry then
                        self:debug("telemetry timeout")
                        timeout_telemetry_sending = true
                        break
                    end
                    self:debug(
                        string.format("initial telemetry will timeout in: %.1fs", self.timeout_telemetry - (os.clock() - started_telemetry_sending))
                    )
                    wait(100)
                end
            end

            function ScriptUpdater:capture_event(event_name)
                if self.json_data and self.json_data.telemetry_capture then
                    self:debug(string.format("capturing event: %s", event_name))
                    local status, result =
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
                                self.json_data.telemetry_capture,
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
                    self:debug("done with capture_event pcall", success, result)
                end
            end

            function ScriptUpdater:remove_file_if_exists(path, file_type)
                self:debug(string.format("path for %s: %s", file_type, path))
                if doesFileExist(path) then
                    self:debug(string.format("%s file DOES exist, removing it", file_type))
                    local success, err = os.remove(path)
                    if success then
                        self:debug(string.format("%s script file removed: %s", file_type, path))
                    else
                        self:debug(string.format("failed to remove %s script file: %s", file_type, path))
                        self:debug(string.format("error removing file: %s", tostring(err)))
                    end
                else
                    self:debug(string.format("%s file does not exist", file_type))
                end
            end

            function ScriptUpdater:get_version_from_path(path)
                local file = io.open(path, "r")
                if not file then
                    error("Could not open new script file")
                end
                local new_script_content = file:read("*a")
                file:close()
                local _, _, script_version = string.find(new_script_content, 'script_version%("([^"]+)"%)')
                return script_version
            end

            function ScriptUpdater:check()
                if self.json_url == "" then
                    self:message("json_url is not set, autoupdate is not possible")
                    return
                end
                local started_check = os.clock()

                local json_path = os.tmpname()
                local stop_waiting_stage1 = false
                local need_stage2 = false
                local stop_waiting_stage2 = false
                local new_file_downloaded = false
                local request_to_reload = false

                local started_stage1 = nil
                local started_stage2 = nil

                local function handle_json_download()
                    self:remove_file_if_exists(json_path, "temporary json")
                    self:debug(string.format("update.json || url: %s", self.json_url))

                    started_downloader = os.clock()
                    self.downloader_json =
                        downloadUrlToFile(
                        self.json_url,
                        json_path,
                        function(id, status, p1, p2)
                            self:debug(string.format("update.json || download status: %s (%d)", self.status_names[status] or "Unknown", status))

                            if self.downloader_json_timeout then
                                self:debug("downloader_json timeout, suppressing handler")
                                return false
                            end

                            if status == self.download_status.STATUSEX_ENDDOWNLOAD then
                                local status, result =
                                    pcall(
                                    function()
                                        self:debug(
                                            string.format("stage 1: STATUSEX_ENDDOWNLOAD done in %.2f seconds", os.clock() - started_downloader)
                                        )

                                        if not doesFileExist(json_path) then
                                            error("json file does not exist")
                                        end

                                        local file = io.open(json_path, "r")
                                        if not file then
                                            error("unable to open json file")
                                        end

                                        self:debug("reading json file")
                                        local content = file:read("*a")
                                        file:close()
                                        self:debug("json file read")

                                        self:remove_file_if_exists(json_path, "temporary json after download")
                                        self:debug("decoding json...")
                                        return decodeJson(content)
                                    end
                                )
                                if status then
                                    self.json_data = result

                                    local is_update_available = self.json_data.latest ~= thisScript().version
                                    self:debug(string.format("current version from script: %s", thisScript().version))
                                    self:debug(string.format("latest version from update.json: %s", self.json_data.latest))

                                    if not is_update_available then
                                        self:log("No new version available, guess you're stuck with the old one for now! c:")
                                    end

                                    if is_update_available then
                                        self:debug("newer version is available, marking stage 2 as needed")
                                        need_stage2 = true
                                    else
                                        self:debug("newer version is not available, so ending auto-update check")
                                    end
                                end
                                if not status then
                                    self:message(string.format("update.json failure: %s", tostring(result)))
                                end
                                self:debug("end of stage 1")
                                stop_waiting_stage1 = true
                            end
                        end
                    )
                end

                local function wait_for_json_download()
                    self:debug("waiting for json to download")
                    while not stop_waiting_stage1 do
                        if os.clock() - started_stage1 >= self.timeout_stage1 then
                            self:debug("stage1 timeout")
                            self.downloader_json_timeout = true
                            break
                        end
                        self:debug(string.format("stage1 will timeout in: %.1fs", self.timeout_stage1 - (os.clock() - started_stage1)))
                        wait(100)
                    end
                end

                local function handle_script_download()
                    local path_for_new_script = tostring(thisScript().path):gsub("%.%w+$", ".new")
                    local path_for_old_script = tostring(thisScript().path):gsub("%.%w+$", ".old")

                    self:remove_file_if_exists(path_for_new_script, "new")
                    self:remove_file_if_exists(path_for_old_script, "old")
                    self:debug("starting downloader for stage 2")
                    local started_downloader = os.clock()
                    self.downloader_file =
                        downloadUrlToFile(
                        self.json_data.updateurl,
                        path_for_new_script,
                        function(id, status, p1, p2)
                            self:debug(string.format("update downloader || download status: %s (%d)", self.status_names[status] or "Unknown", status))

                            if self.downloader_file_timeout then
                                self:message("downloader_file timeout, suppressing handler")
                                return false
                            end

                            if status == self.download_status.STATUS_DOWNLOADINGDATA then
                                self:debug(string.format("new_file_downloaded %d out of %d.", p1, p2))
                            elseif status == self.download_status.STATUS_ENDDOWNLOADDATA then
                                self:debug("marking download as completed")
                                new_file_downloaded = true
                                self:debug("download completed.")
                            elseif status == self.download_status.STATUSEX_ENDDOWNLOAD then
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
                                            self:debug("parsing new script version")
                                            local success, new_script_version = pcall(self.get_version_from_path, self, path_for_new_script)
                                            if success then
                                                self:debug(string.format("New script version from new file: %s", tostring(new_script_version)))
                                                if new_script_version then
                                                    if new_script_version == thisScript().version then
                                                        self:remove_file_if_exists(path_for_new_script, "new")
                                                        -- cdn cache issue, no need to manual download
                                                        self:debug("cdn cache issue, no need to manual download, removing self.json_data.hard_link")
                                                        self.json_data.hard_link = nil
                                                        error("ERROR - New file version is the same as the current. Try again later.")
                                                    end
                                                else
                                                    self:message("New script version not found in the new file.")
                                                end
                                            else
                                                self:debug(string.format("Failed to get script version from new file: %s", tostring(script_version)))
                                            end
                                        end

                                        local rename_current_to_old_success, err = os.rename(thisScript().path, path_for_old_script)
                                        if rename_current_to_old_success then
                                            self:debug(string.format("Current script renamed to %s", path_for_old_script))
                                        else
                                            self:log(string.format("ERROR - Failed to rename the current script: %s", tostring(err)))
                                            error("ERROR - could not rename the current script to .old")
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
                                                self:debug(string.format("Failed to rename the old script to backup: %s", tostring(err)))
                                            end

                                            request_to_reload = true
                                        else
                                            self:debug(string.format("ERROR - Failed to rename the new script: %s", tostring(err)))

                                            local rename_old_to_current_success, err2 = os.rename(path_for_old_script, thisScript().path)
                                            if rename_old_to_current_success then
                                                error("Failed to apply the update. Old version was restored.")
                                            else
                                                self:debug(string.format("Failed to rename the new script to the current script: %s", tostring(err2)))
                                                error("CRITICAL ERROR - Restoring the old script failed: " .. tostring(err2))
                                            end
                                        end
                                    end
                                )

                                if not success then
                                    self:debug(string.format("update downloader failure: %s", tostring(err)))
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
                                    self:debug("update downloader success, is request_to_reload: " .. tostring(request_to_reload))
                                end
                                self:debug("end of stage 2")
                                if request_to_reload and stop_waiting_stage2 == false then
                                    self:message("Restart the game to apply the update.")
                                end
                                stop_waiting_stage2 = true
                            end
                        end
                    )
                end

                local function wait_for_script_download()
                    self:debug("waiting for script to download")
                    while not stop_waiting_stage2 do
                        if os.clock() - started_stage2 >= self.timeout_stage2 then
                            self:debug("stage2 timeout")
                            self.downloader_file_timeout = true
                            break
                        end
                        self:debug(string.format("stage2 will timeout in: %.1fs", self.timeout_stage2 - (os.clock() - started_stage2)))
                        wait(100)
                    end
                end

                started_stage1 = os.clock()
                self:debug(string.format("starting stage 1"))
                handle_json_download()
                wait_for_json_download()
                self:debug(string.format("stage 1 done (+waiting) in %.2f seconds", os.clock() - started_stage1))

                self:debug("waiting 250ms before starting stage 2")
                wait(250)

                started_stage2 = os.clock()
                self:debug(string.format("starting stage 2, do we need it: %s", tostring(need_stage2)))
                if need_stage2 and self.json_data then
                    self:message("New version is available!")
                    self:message(string.format("Trying to update from %s to %s...", thisScript().version, self.json_data.latest))
                    handle_script_download()
                    wait_for_script_download()
                end
                self:debug(string.format("stage 2 done (+waiting) in %.2f seconds", os.clock() - started_stage2))

                if need_stage2 then
                    self:debug("waiting 250ms before finishing")
                    wait(250)
                end

                if request_to_reload then
                    self:debug("reloading the script as requested")
                    thisScript():reload()
                    self:debug("reloaded the script, waiting 10s to prevent what is unlikely to happen anyway")
                    wait(10000)
                else
                    if self.json_data and self.json_data.telemetry_v2 then
                        self:debug("need to send initial telemetry")
                        local success, err = pcall(self.send_initial_telemetry, self, self.json_data.telemetry_v2)
                        if not success then
                            self:debug(string.format("TELEMETRY ERROR - %s", tostring(err)))
                        end
                    end

                    self:debug("removing .old.bak if exists")
                    self:remove_file_if_exists(tostring(thisScript().path):gsub("%.%w+$", ".old.bak"), "backup")
                end
                self:debug(string.format("all done in %.2f seconds", os.clock() - started_check))
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
                "https://raw.githubusercontent.com/qrlk/moonloader-script-updater/master/updater-v2.json?" .. tostring(os.clock())

            -- Customize the prefix for sampAddChatMessage during auto-update
            -- you can delete this line
            ScriptUpdater.prefix = string.format("[%s]: ", string.upper(thisScript().name))

            -- Customize the prefix for logs
            -- you can delete this line
            ScriptUpdater.log_prefix = string.format("v%s | ScriptUpdater: ", thisScript().version)

            -- URL which prints to the console when the script is failed to update, pretty much useless
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
        end
    end

    if isSampLoaded() and isSampfuncsLoaded() and isSampAvailable() then
        sampAddChatMessage("check started", -1)
    end

    if autoupdate_loaded and enable_autoupdate and ScriptUpdater then
        print("ScriptUpdater result:", pcall(ScriptUpdater.check, ScriptUpdater))
    end
    if isSampLoaded() and isSampfuncsLoaded() and isSampAvailable() then
        sampAddChatMessage("script started", -1)
    end
    wait(1000)
    -- thisScript():reload()
    while true do
        wait(5000)
        ScriptUpdater:capture_event("test")
    end
end
