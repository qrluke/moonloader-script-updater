require "lib.moonloader"

script_name("V3")
script_url("https://github.com/qrlk/moonloader-script-updater")
script_version("30.11.2024")

-- https://github.com/qrlk/moonloader-script-updater
local enable_autoupdate = true -- Set to false to disable auto-update and telemetry
local autoupdate_loaded = false
local ScriptUpdater = nil

if enable_autoupdate then
    --[[
        To minify use:
        updater_loaded, getScriptUpdater = pcall(loadstring, [=[(function() local ScriptUpdater = {...} ... end)()]=])
    ]]
    local updater_loaded, getScriptUpdater =
        pcall(
        loadstring,
        [=[return (function()local a={cfg_prefix=string.format("[%s]: ",string.upper(thisScript().name)),cfg_log_prefix=string.format("v%s | github.com/qrlk/moonloader-script-updater: ",thisScript().version),cfg_json_url="",cfg_url="",cfg_debug_enabled=false,cfg_check_new_file=true,cfg_timeout_stage1=15,cfg_timeout_stage2=60,cfg_timeout_telemetry=5,cfg_max_allowed_clock=3600*24*30,cfg_chat_color=-1,cached_volume_serial=nil,cached_language=nil,cached_langid=nil,cached_json_data=nil,downloader_ids={},downloader_timeout_json=false,downloader_timeout_file=false,downloader_status_ids=require("moonloader").download_status,downloader_status_names=(function()local b=require("moonloader").download_status;local c={}for d,e in pairs(b)do c[e]=d end;return c end)(),i18n={data={["msg_cfg_max_allowed_clock"]={en="{FFD700}Update check canceled because the game uptime limit was exceeded. Current uptime: %s seconds. Limit: %s seconds.",ru="{FFD700}Проверка обновлений отменена из-за превышения лимита времени работы игры. Текущее время работы: %s секунд. Лимит: %s секунд."},["msg_new_version_available"]={en="{FFD700}A new version is available! Attempting to update from {FFFFFF}v%s{FFD700} to {FFFFFF}v%s",ru="{FFD700}Доступна новая версия! Пытаемся обновиться с {FFFFFF}v%s{FFD700} до {FFFFFF}v%s"},["msg_timeout_while_checking_for_updates"]={en="Timeout while checking for updates. Please check manually at %s.",ru="Время ожидания проверки обновлений истекло. Проверьте вручную на %s."},["msg_json_url_not_set"]={en="cfg_json_url is not set, auto-update is not possible.",ru="cfg_json_url не установлен, автообновление невозможно."},["msg_already_latest_version"]={en="You're already running the latest version!",ru="У вас уже установлена последняя версия!"},["msg_update_json_failure"]={en="{ff0000}update.json failure: %s",ru="{ff0000}Ошибка update.json: %s"},["msg_download_manually"]={en="{FFD700}Alternative: {ffffff}%s",ru="{FFD700}Альтернатива: {ffffff}%s"},["msg_manual_replace_instruction"]={en="{FFD700}Download the file and replace the old version in your moonloader folder.",ru="{FFD700}Скачайте файл и замените старую версию в папке moonloader."},["msg_restart_to_update"]={en="Restart the game to apply the update.",ru="Перезапустите игру, чтобы применить обновление."},["msg_script_updated"]={en="Script successfully updated. Reloading...",ru="Скрипт успешно обновлен. Перезагрузка..."},["err_decode_json"]={en="{ff0000}ERROR - Failed to decode JSON. Aborting update...",ru="{ff0000}ОШИБКА - Не удалось декодировать JSON. Отмена обновления..."},["err_download_failed"]={en="ERROR - Download failed. Aborting update...",ru="ОШИБКА - Загрузка не удалась. Отмена обновления..."},["err_new_file_missing"]={en="ERROR - New script file does not exist. Aborting update...",ru="ОШИБКА - Новый файл скрипта не существует. Отмена обновления..."},["err_same_version"]={en="ERROR - New file version is the same as the current one. Try again later.",ru="ОШИБКА - Версия нового файла совпадает с текущей. Попробуйте позже."},["err_version_not_found"]={en="{ff0000}WARNING - New script version not found in the new file.",ru="{ff0000}WARNING - Версия скрипта не найдена в новом файле."},["err_rename_current"]={en="ERROR - Could not rename the current script to .old",ru="ОШИБКА - Не удалось переименовать текущий скрипт в .old"},["err_rename_failed"]={en="ERROR - Failed to rename the current script: %s",ru="ОШИБКА - Не удалось переименовать текущий скрипт: %s"},["err_update_failed_restored"]={en="Failed to apply update. The old version was restored.",ru="Не удалось применить обновление. Старая версия восстановлена."},["err_critical_restore_failed"]={en="CRITICAL ERROR - Failed to restore the old script",ru="КРИТИЧЕСКАЯ ОШИБКА - Не удалось восстановить старый скрипт"}}}}function a:getMessage(f)local g=self:get_language()if self.i18n.data[f]and self.i18n.data[f][g]then return self.i18n.data[f][g]end;return"unknown string"end;function a:get_language()self:debug("Entering get_language")if not self.cached_language then self.cached_language,self.cached_langid=self:detect_language()end;self:debug(string.format("Exiting get_language with language: %s",self.cached_language))return self.cached_language end;function a:get_langid()self:debug("Entering get_langid")if not self.cached_langid then self.cached_language,self.cached_langid=self:detect_language()self:debug(string.format("LangID detected: %d, language: %s",self.cached_langid,self.cached_language))end;self:debug(string.format("Exiting get_langid with langid: %d",self.cached_langid))return self.cached_langid end;function a:detect_language()self:debug("Detecting language")local h="ru"local i={1049,1059,1063,1058,1071,2073}local j,k,l=pcall(function()local m=require"ffi"m.cdef"typedef struct _LANGID { unsigned short wLanguage; unsigned short wReserved; } LANGID; LANGID GetUserDefaultLangID();"local l=m.C.GetUserDefaultLangID().wLanguage;for n,o in ipairs(i)do if l==o then return"ru",l end end;return"en",l end)self:debug(string.format("Detection result - success: %s, result: %s, langid: %s",tostring(j),tostring(k),tostring(l)))if j then self:debug(string.format("Language detected: %s, langid: %s",k,tostring(l)))return k,l end;self:debug(string.format("Language detection failed, returning default language: %s",h))return h,0 end;function a:log(...)local p={...}for q,e in ipairs(p)do p[q]=tostring(e)end;print(string.format("%s%s",self.cfg_log_prefix,table.concat(p,", ")))end;function a:debug(...)if not self.cfg_debug_enabled then return end;local p={...}for q,e in ipairs(p)do p[q]=tostring(e)end;print(string.format("%s{808080}[DEBUG]: {ffffff}%s",self.cfg_log_prefix,table.concat(p,", ")))end;function a:message(...)local p={...}for q,e in ipairs(p)do p[q]=tostring(e)end;local r=table.concat(p,", ")if isSampLoaded()and isSampfuncsLoaded()and isSampAvailable()then sampAddChatMessage(string.format("%s%s",self.cfg_prefix,r),self.cfg_chat_color)end;self:log(string.format("{FFA500}Message displayed: {ffffff}%s",r))end;function a:get_volume_serial()self:debug("Entering get_volume_serial")if self.cached_volume_serial then self:debug(string.format("Volume serial already obtained: %d",self.cached_volume_serial))return self.cached_volume_serial end;local j,s=pcall(function()local m=require("ffi")m.cdef"int __stdcall GetVolumeInformationA(const char* lpRootPathName, char* lpVolumeNameBuffer, uint32_t nVolumeNameSize, uint32_t* lpVolumeSerialNumber, uint32_t* lpMaximumComponentLength, uint32_t* lpFileSystemFlags, char* lpFileSystemNameBuffer, uint32_t nFileSystemNameSize);"local t=m.new("unsigned long[1]",0)local k=m.C.GetVolumeInformationA(nil,nil,0,t,nil,nil,nil,0)if k==0 then self:debug("GetVolumeInformationA failed, returning 0")return 0 end;self:debug(string.format("Volume serial obtained: %d",t[0]))return t[0]end)if j then self.cached_volume_serial=s;self:debug(string.format("Volume serial set to: %d",self.cached_volume_serial))return self.cached_volume_serial else self:debug(string.format("Failed to get volume serial: %s",tostring(s)))self.cached_volume_serial=0;return 0 end end;function a:send_initial_telemetry(u)self:debug("Entering send_initial_telemetry")local s=self:get_volume_serial()local v="-"if isSampLoaded()and isSampfuncsLoaded()and isSampAvailable()then v=sampGetCurrentServerAddress()self:debug(string.format("Server IP obtained: %s",v))else self:debug("SAMP not available, using default server IP: -")end;local w=getMoonloaderVersion()local x=tostring(os.clock())local l=self:get_langid()local y=string.format("%s?id=%d&i=%s&v=%d&sv=%s&langid=%d&uptime=%s",u,s,v,w,thisScript().version,l,x)self:debug(string.format("Telemetry URL: %s",y))local z=os.clock()local A=false;local B=false;local function C(o,D,E,F)self:debug(string.format("Initial telemetry sending status: %s (%d)",self.downloader_status_names[D]or"Unknown",D))if A then self:debug("Telemetry sending timed out, suppressing handler")return false end;if D==self.downloader_status_ids.STATUSEX_ENDDOWNLOAD then self:debug(string.format("Telemetry sending completed in %.2f seconds",os.clock()-z))B=true end end;table.insert(self.downloader_ids,downloadUrlToFile(y,nil,C))self:debug("Waiting for initial telemetry to be sent.")while not B do if os.clock()-z>=self.cfg_timeout_telemetry then self:debug("Telemetry sending timeout reached.")A=true;break end;self:debug(string.format("Telemetry will timeout in: %.1fs",self.cfg_timeout_telemetry-(os.clock()-z)))wait(100)end;self:debug("Exiting send_initial_telemetry")end;function a:capture_event(G)self:debug(string.format("Entering capture_event with event_name: %s",G))if self.cached_json_data and self.cached_json_data.telemetry_capture then self:debug(string.format("Capturing event: %s",G))local D,k=pcall(function()local s=self:get_volume_serial()local x=tostring(os.clock())local H=thisScript().version;local v="-"if isSampLoaded()and isSampfuncsLoaded()and isSampAvailable()then v=sampGetCurrentServerAddress()self:debug(string.format("Server IP for telemetry: %s",v))end;local I=string.format("%s?volume_id=%d&server_ip=%s&script_version=%s&event=%s&uptime=%s",self.cached_json_data.telemetry_capture,s,v,H,G,x)self:debug(string.format("Sending event '%s' to %s",G,I))table.insert(self.downloader_ids,downloadUrlToFile(I))end)self:debug(string.format("Capture event pcall result - status: %s, result: %s",tostring(D),tostring(k)))else self:debug("Telemetry capture URL not set, event not captured.")end;self:debug("Exiting capture_event")end;function a:remove_file_if_exists(J,K)self:debug(string.format("remove_file_if_exists called with path: %s, file_type: %s",J,K))if doesFileExist(J)then self:debug(string.format("%s file exists, attempting to remove.",K))local j,L=os.remove(J)if j then self:debug(string.format("%s file removed successfully: %s",K,J))else self:debug(string.format("Failed to remove %s file: %s",K,tostring(L)))self:debug(string.format("Error removing file: %s",tostring(L)))end else self:debug(string.format("%s file does not exist, no action taken.",K))end end;function a:get_version_from_path(J)self:debug(string.format("Getting script version from path: %s",J))local M,L=io.open(J,"r")if not M then error(string.format("Could not open script file: %s",tostring(L)))end;local N=4096;local O=""local P='script_version%("([^"]+)"%)'local j,Q=pcall(function()while true do self:debug(string.format("Reading new script file chunk, size: %d",N))local R=M:read(N)if not R then break end;O=O..R;local Q=string.match(O,P)if Q then self:debug(string.format("Found script version: %s",Q))return Q end end end)M:close()if j then self:debug(string.format("Script version found in file: %s",Q))return Q else self:debug(string.format("Error occurred while reading file: %s",tostring(Q)))error(Q)end end;function a:check()self:debug("Starting update check")if self.cfg_json_url==""then self:message(self:getMessage("msg_json_url_not_set"))self:debug("Update check aborted: cfg_json_url not set")return end;if os.clock()>self.cfg_max_allowed_clock then self:log(string.format(self:getMessage("msg_cfg_max_allowed_clock"),os.clock(),self.cfg_max_allowed_clock))return end;local S=os.clock()local T=os.tmpname()self:debug(string.format("Temporary JSON path: %s",T))local U=false;local V=false;local W=false;local X=false;local Y=false;local Z=nil;local _=nil;local a0=tostring(thisScript().path):gsub("%.%w+$",".new")local a1=tostring(thisScript().path):gsub("%.%w+$",".old")if a0==tostring(thisScript().path)or a1==tostring(thisScript().path)then error("Failed to generate old/new script paths")end;self:remove_file_if_exists(a0,"new")self:remove_file_if_exists(a1,"old")local function a2(L)local a3=tostring(L)a3=a3:match(".*:.*:(.*)")if a3 then return a3:match("^%s*(.-)%s*$")end;return a3 end;local function a4()self:debug("Handling JSON download")local started_downloader;self:remove_file_if_exists(T,"temporary json")self:debug(string.format("Downloading update.json from URL: %s",self.cfg_json_url))local function a5()self:debug("Exiting JSON download handler")local D,k=pcall(function()self:debug(string.format("stage 1: STATUSEX_ENDDOWNLOAD done in %.2f seconds",os.clock()-started_downloader))if not doesFileExist(T)then error("JSON file does not exist after download")end;local M,L=io.open(T,"r")if not M then error(string.format("Unable to open JSON file: %s",tostring(L)))end;self:debug("Reading JSON file content")local O=M:read("*a")M:close()self:debug("JSON file read successfully")self:remove_file_if_exists(T,"temporary json after download")self:debug("Decoding JSON content")return decodeJson(O)end)if D then if not k then self:message(self:getMessage("err_decode_json"))self:debug(string.format("JSON decode failed: %s",tostring(k)))else self.cached_json_data=k;local a6=self.cached_json_data.latest~=thisScript().version;self:debug(string.format("Current script version: %s, Latest version from JSON: %s",thisScript().version,self.cached_json_data.latest))if not a6 then self:log(string.format("{00FF00}%s",self:getMessage("msg_already_latest_version")))end;if a6 then self:debug("Newer version detected, preparing for stage 2 update")V=true else self:debug("No newer version detected, ending update check")end end else self:message(string.format(self:getMessage("msg_update_json_failure"),a2(k)))self:debug(string.format("JSON download failed: %s",tostring(k)))end;self:debug("Stage 1 processing completed")U=true end;local function a7(o,D,E,F)self:debug(string.format("JSON download status: %s (%d)",self.downloader_status_names[D]or"Unknown",D))if self.downloader_timeout_json then self:debug("JSON downloader timed out, suppressing handler")return false end;if D==self.downloader_status_ids.STATUSEX_ENDDOWNLOAD then self:debug("JSON download completed")a5()end end;started_downloader=os.clock()table.insert(self.downloader_ids,downloadUrlToFile(self.cfg_json_url,T,a7))self:debug("JSON download initiated")end;local function a8()self:debug("Waiting for JSON download to complete")while not U do if os.clock()-Z>=self.cfg_timeout_stage1 then if self.cfg_url~=""then self:log(string.format("{ff0000}%s",string.format(self:getMessage("msg_timeout_while_checking_for_updates"),self.cfg_url)))else self:debug("Stage 1 timeout reached")end;self.downloader_timeout_json=true;break end;self:debug(string.format("Stage 1 will timeout in: %.1fs",self.cfg_timeout_stage1-(os.clock()-Z)))wait(100)end;self:debug("Exiting wait_for_json_download")end;local function a9()self:debug("Handling script download (Stage 2)")self:debug("Starting downloader for Stage 2")local function aa()self:debug(string.format("stage 2: STATUSEX_ENDDOWNLOAD done in %.2f seconds",os.clock()-started_downloader))local j,L=pcall(function()if not X then error(self:getMessage("err_download_failed"))end;if not doesFileExist(a0)then error(self:getMessage("err_new_file_missing"))end;if self.cfg_check_new_file then self:debug("Parsing new script version from downloaded file")local j,ab=pcall(self.get_version_from_path,self,a0)if j then self:debug(string.format("New script version from new file: %s",tostring(ab)))if ab then if ab==thisScript().version then self:remove_file_if_exists(a0,"new")self:debug("CDN cache issue detected, removing hard_link from JSON data")self.cached_json_data.hard_link=nil;error(self:getMessage("err_same_version"))end else self:message(self:getMessage("err_version_not_found"))self:debug("New script version not found in the downloaded file")end else self:debug(string.format("Failed to get script version from new file: %s",tostring(ab)))end end;local ac,ad=os.rename(thisScript().path,a1)if ac then self:debug(string.format("Current script renamed to %s",a1))else self:log(string.format(self:getMessage("err_rename_failed"),tostring(ad)))error(self:getMessage("err_rename_current"))end;local ae,af=os.rename(a0,thisScript().path)if ae then self:debug(string.format("New script renamed to %s",thisScript().path))self:message(string.format("{00FF00}%s",self:getMessage("msg_script_updated")))local ag=string.format("%s.bak",a1)self:remove_file_if_exists(ag,"backup")local ah,ai=os.rename(a1,ag)if ah then self:debug(string.format("Old script backed up to %s",ag))else self:debug(string.format("Failed to rename the old script to backup: %s",tostring(ai)))end;Y=true else self:debug(string.format("ERROR - Failed to rename the new script: %s",tostring(af)))local aj,ak=os.rename(a1,thisScript().path)if aj then self:debug(string.format(".old script renamed to current path: %s",thisScript().path))error(self:getMessage("err_update_failed_restored"))else self:debug(string.format("Failed to restore the old script: %s",tostring(ak)))error(self:getMessage("err_critical_restore_failed"))end end end)if not j then self:debug(string.format("Update downloader failure: %s",tostring(L)))self:message(string.format("{ff0000}%s",a2(L)))if self.cached_json_data and self.cached_json_data.hard_link then self:message(string.format(self:getMessage("msg_download_manually"),self.cached_json_data.hard_link))self:message(self:getMessage("msg_manual_replace_instruction"))end else self:debug(string.format("Update downloader succeeded, request_to_reload: %s",tostring(Y)))end;self:debug("Stage 2 processing completed")if Y and W then self:message(self:getMessage("msg_restart_to_update"))end;W=true end;local function al(o,D,E,F)self:debug(string.format("Script download status: %s (%d)",self.downloader_status_names[D]or"Unknown",D))if self.downloader_timeout_file then self:message("Downloader file timeout, suppressing handler")return false end;if D==self.downloader_status_ids.STATUS_DOWNLOADINGDATA then self:debug(string.format("Downloading new file: %d out of %d bytes",E,F))elseif D==self.downloader_status_ids.STATUS_ENDDOWNLOADDATA then self:debug("Download data phase completed")X=true;self:debug("Download completed successfully")elseif D==self.downloader_status_ids.STATUSEX_ENDDOWNLOAD then self:debug("End of download status received")aa()end end;started_downloader=os.clock()table.insert(self.downloader_ids,downloadUrlToFile(self.cached_json_data.updateurl,a0,al))self:debug("Script download initiated")end;local function am()self:debug("Waiting for script download to complete")while not W do if os.clock()-_>=self.cfg_timeout_stage2 then self:debug("Stage 2 timeout reached")self.downloader_timeout_file=true;break end;self:debug(string.format("Stage 2 will timeout in: %.1fs",self.cfg_timeout_stage2-(os.clock()-_)))wait(100)end;self:debug("Exiting wait_for_script_download")end;Z=os.clock()self:debug("Starting stage 1: JSON download")a4()a8()self:debug(string.format("Stage 1 completed in %.2f seconds",os.clock()-Z))self:debug("Waiting 250ms before starting stage 2")wait(250)_=os.clock()self:debug(string.format("Starting stage 2: Do we need it? %s",tostring(V)))if V and self.cached_json_data then self:message(string.format(self:getMessage("msg_new_version_available"),thisScript().version,self.cached_json_data.latest))a9()am()end;self:debug(string.format("Stage 2 completed in %.2f seconds",os.clock()-_))if V then self:debug("Waiting 250ms before finishing")wait(250)end;if Y then self:debug("Reloading the script as requested")thisScript():reload()self:debug("Script reloaded, waiting 10s to ensure stability")wait(10000)else if self.cached_json_data and self.cached_json_data.telemetry_v2 then self:debug("Preparing to send initial telemetry")local j,L=pcall(self.send_initial_telemetry,self,self.cached_json_data.telemetry_v2)if not j then self:debug(string.format("TELEMETRY ERROR - %s",tostring(L)))end end;self:debug("removing .old.bak if exists")local ag=tostring(thisScript().path):gsub("%.%w+$",".old.bak")if ag~=tostring(thisScript().path)then self:remove_file_if_exists(ag,"backup")else self:debug("NOT GOOD - Debug path is the same as the current script path")end end;self:debug(string.format("--- all done in %.2f seconds",os.clock()-S))end;return a end)()]=]
    )

    if updater_loaded then
        autoupdate_loaded, ScriptUpdater = pcall(getScriptUpdater)
        if autoupdate_loaded then
            --[[
                Script Updater Configuration
                github repo: https://github.com/qrlk/moonloader-script-updater

                don't forget to call it in main() after isSampAvailable (if you want to use samp)
                like this:
                
                if updater_loaded and enable_autoupdate and ScriptUpdater then
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
            ScriptUpdater.cfg_json_url =
                string.format("https://raw.githubusercontent.com/qrlk/moonloader-script-updater/master/v2-minified.json?%s", tostring(os.clock()))

            -- Customize the prefix for sampAddChatMessage during auto-update
            -- you can delete this line
            ScriptUpdater.cfg_prefix = string.format("{00FF00}[%s]:{FFFFFF} ", string.upper(thisScript().name))

            -- Customize the prefix for logs
            -- you can delete this line
            ScriptUpdater.cfg_log_prefix = string.format("v%s | ScriptUpdater: ", thisScript().version)

            -- URL which prints to the console when the script fails to update, pretty much useless
            -- Default is "", meaning no URL will be printed
            -- you can delete this line
            ScriptUpdater.cfg_url = "https://github.com/qrlk/moonloader-script-updater/"

            -- Enable or disable debug messages in the console (recommended to set to false in production)
            -- Default: false
            -- you can delete this line
            ScriptUpdater.cfg_debug_enabled = true

            -- Enable or disable checking for new version
            -- if new version parsed from the new file is the same as the current version, the script will not be replaced
            -- this can prevent CDN caching issues
            -- If you set this to false, the script will not check for new version and will not auto-update
            -- Default: true
            -- you can delete this line
            ScriptUpdater.cfg_check_new_file = true

            -- If os.clock() (game uptime) exceeds this value, the update check will be aborted at the beginning of the check
            -- This is to prevent update checks during ctrl+r reload spam, which can cause game crashes on 026
            -- Default: 3600*24*30 (30 days)
            -- you can delete this line
            ScriptUpdater.cfg_max_allowed_clock = 30000

            -- Color for the sampAddChatMessage
            -- Default: -1 (white)
            -- you can delete this line
            ScriptUpdater.cfg_chat_color = 0x348cb2
        else
            print("ScriptUpdater module failed to load.")
            print(ScriptUpdater)
            ScriptUpdater = nil
        end
    end
end

function main()
    -- samp is not mandatory, but if you want to use samp functions, you should wait until samp is available
    -- sampfuncs is needed for a lot of samp-related functions
    if isSampLoaded() and isSampfuncsLoaded() then
        while not isSampAvailable() do
            wait(100)
            print("Waiting for SAMP to become available")
        end
    end

    if isSampLoaded() and isSampfuncsLoaded() and isSampAvailable() then
        sampAddChatMessage("check started", -1)
        print("SAMP is loaded and available")
    end

    if enable_autoupdate and autoupdate_loaded and ScriptUpdater then
        ScriptUpdater:debug("Initiating ScriptUpdater.check")
        local success, result = pcall(ScriptUpdater.check, ScriptUpdater)
        ScriptUpdater:debug(string.format("ScriptUpdater.check executed with success: %s, result: %s", tostring(success), tostring(result)))
    else
        print("Auto-update not enabled or ScriptUpdater not loaded")
    end

    if isSampLoaded() and isSampfuncsLoaded() and isSampAvailable() then
        sampAddChatMessage("script started", -1)
        print("Script started and SAMP is available")
    end
    wait(1000)
    -- thisScript():reload()
    print("Entering main loop")
    while true do
        wait(5000)
        -- ScriptUpdater:capture_event("test")
        -- ScriptUpdater:debug("Captured 'test' event")
    end
end
