local resourceName = GetCurrentResourceName()
local currentVersion = GetResourceMetadata(resourceName, 'version', 0) or '0.0.0'
local updateRunning = false

local function Log(message, level)
    local colors = { info = '^5', success = '^2', warning = '^3', error = '^1' }
    print(('%s[QA AMBULANCE UPDATER]^7 %s'):format(colors[level or 'info'] or '^5', message))
end

local function IsNewer(remote, installed)
    local function parts(version)
        local major, minor, patch = tostring(version or '0.0.0'):match('^(%d+)%.(%d+)%.(%d+)')
        return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
    end
    local rMajor, rMinor, rPatch = parts(remote)
    local iMajor, iMinor, iPatch = parts(installed)
    if rMajor ~= iMajor then return rMajor > iMajor end
    if rMinor ~= iMinor then return rMinor > iMinor end
    return rPatch > iPatch
end

local function IsSafePath(path)
    if type(path) ~= 'string' or path == '' or path:find('..', 1, true) or path:sub(1, 1) == '/' or path:find('\\', 1, true) then return false end
    if path == 'shared/config.lua' then return false end
    return path:match('^client/.+%.lua$') or path:match('^server/.+%.lua$')
        or path:match('^shared/.+%.lua$') or path:match('^html/.+%.[%w]+$')
        or path == 'fxmanifest.lua' or path == 'README.md' or path == 'CHANGELOG.md' or path == 'sql.sql'
end

local function DownloadFiles(manifest, callback)
    local files = manifest.files or {}
    if #files == 0 then callback(false, 'Update manifest contains no files.') return end
    local completed, failed = 0, false
    for _, file in ipairs(files) do
        if not IsSafePath(file.path) or type(file.url) ~= 'string' or not file.url:match('^https://') then
            failed, completed = true, completed + 1
            Log(('Blocked unsafe update entry: %s'):format(tostring(file.path)), 'error')
            if completed == #files then callback(false, 'One or more update files were rejected.') end
        else
            PerformHttpRequest(file.url, function(status, body)
                if status ~= 200 or not body or body == '' then
                    failed = true
                    Log(('Download failed for %s (HTTP %s).'):format(file.path, status), 'error')
                elseif SaveResourceFile(resourceName, file.path, body, #body) then
                    Log(('Updated %s'):format(file.path), 'success')
                else
                    failed = true
                    Log(('Could not write %s'):format(file.path), 'error')
                end
                completed = completed + 1
                if completed == #files then callback(not failed, failed and 'Some files could not be updated.' or nil) end
            end, 'GET', '', { ['Accept'] = 'application/octet-stream', ['User-Agent'] = 'QA-Ambulance-Updater' })
        end
    end
end

local function CheckForUpdates(force)
    if updateRunning then Log('An update check is already running.', 'warning') return end
    local manifestUrl = GetConvar('qa_ambulance_update_url', '')
    if manifestUrl == '' then
        if force then Log('Set qa_ambulance_update_url to your HTTPS update manifest URL.', 'warning') end
        return
    end
    if not manifestUrl:match('^https://') then Log('Update URL must use HTTPS.', 'error') return end
    updateRunning = true
    Log(('Checking for updates. Installed version: %s'):format(currentVersion), 'info')
    PerformHttpRequest(manifestUrl, function(status, body)
        if status ~= 200 or not body then
            updateRunning = false
            Log(('Version check failed (HTTP %s).'):format(status), 'error')
            return
        end
        local ok, manifest = pcall(json.decode, body)
        if not ok or type(manifest) ~= 'table' or not manifest.version then
            updateRunning = false
            Log('Remote update manifest is invalid.', 'error')
            return
        end
        if not IsNewer(manifest.version, currentVersion) then
            updateRunning = false
            Log(('Resource is current (%s).'):format(currentVersion), 'success')
            return
        end
        Log(('Update available: %s -> %s'):format(currentVersion, manifest.version), 'warning')
        if manifest.changelog then Log(tostring(manifest.changelog), 'info') end
        if GetConvarInt('qa_ambulance_auto_update', 1) ~= 1 then
            updateRunning = false
            Log('Automatic installation is disabled.', 'warning')
            return
        end
        Log('Downloading update files...', 'info')
        DownloadFiles(manifest, function(success, reason)
            updateRunning = false
            if not success then Log(reason or 'Update failed.', 'error') return end
            Log(('Version %s installed successfully.'):format(manifest.version), 'success')
            if GetConvarInt('qa_ambulance_auto_restart', 1) == 1 then
                Log('Restarting resource in 3 seconds...', 'warning')
                SetTimeout(3000, function() ExecuteCommand(('restart %s'):format(resourceName)) end)
            else
                Log(('Run restart %s to load the update.'):format(resourceName), 'warning')
            end
        end)
    end, 'GET', '', { ['Accept'] = 'application/json', ['User-Agent'] = 'QA-Ambulance-Updater' })
end

RegisterCommand('emsupdate', function(source)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'command.emsupdate') then return end
    CheckForUpdates(true)
end, false)

CreateThread(function()
    Wait(5000)
    Log(('Updater ready. Version %s.'):format(currentVersion), 'success')
    CheckForUpdates(false)
    while true do
        Wait(math.max(15, GetConvarInt('qa_ambulance_update_interval', 60)) * 60000)
        CheckForUpdates(false)
    end
end)
