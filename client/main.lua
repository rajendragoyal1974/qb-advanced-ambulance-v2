local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local isDead = false
local deathTimer = 0
local currentBed = nil
local nuiOpen = false
local healthcareAppRegistered = false

local function Debug(message)
    if Config.Debug then print(('[qa-ambulance] %s'):format(message)) end
end

local function Notify(message, kind)
    QBCore.Functions.Notify(message, kind or 'primary')
end

local function IsMedic()
    return PlayerData.job and PlayerData.job.name == Config.JobName
end

local function IsOnDutyMedic()
    return IsMedic() and PlayerData.job.onduty
end

local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
end

local function PlayProgress(label, duration, animDict, anim)
    if animDict then
        LoadAnimDict(animDict)
        TaskPlayAnim(PlayerPedId(), animDict, anim, 8.0, -8.0, duration, 49, 0, false, false, false)
    end
    local p = promise.new()
    QBCore.Functions.Progressbar(
        'qa_ambulance_action',
        label,
        duration,
        false,
        true,
        {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true
        },
        {},
        {},
        {},
        function()
            p:resolve(true)
        end,
        function()
            p:resolve(false)
        end
    )
    local finished = Citizen.Await(p)
    ClearPedTasks(PlayerPedId())
    return finished
end

local function SendUi(action, payload)
    SendNUIMessage({
        action = action,
        payload = payload or {}
    })
end

local function OpenTablet(patient)
    if not IsOnDutyMedic() then Notify('You must be on duty.', 'error') return end
    nuiOpen = true
    SetNuiFocus(true, true)
    SendUi('open', {
        player = {
            name = ('%s %s'):format(PlayerData.charinfo.firstname, PlayerData.charinfo.lastname),
            grade = PlayerData.job.grade.name,
            callsign = PlayerData.metadata.callsign or 'EMS'
        },
        patient = patient,
        config = {
            billMax = Config.BillMaxAmount,
            hospitals = Config.Hospitals,
            tests = Config.Healthcare.tests,
            surgeries = Config.Healthcare.surgeries
        }
    })
end

local function CloseTablet()
    nuiOpen = false
    SetNuiFocus(false, false)
    SendUi('close')
end

local function RevivePed()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    isDead = false
    deathTimer = 0
    TriggerServerEvent('qa-ambulance:server:SetDeathStatus', false)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
    ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    SetPedCanRagdoll(ped, true)
    ClearPedBloodDamage(ped)
    SetEntityHealth(ped, Config.RespawnHealth)
    SetPedArmour(ped, Config.RespawnArmor)
    ClearPedTasksImmediately(ped)
    SendUi('death', { active = false })
end

local function SetDeadState()
    if isDead then return end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    isDead = true
    deathTimer = Config.DeathTime
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
    ped = PlayerPedId()
    SetEntityHealth(ped, Config.DownHealth)
    TriggerServerEvent('qa-ambulance:server:SetDeathStatus', true)
    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, false)
    LoadAnimDict('dead')
    TaskPlayAnim(ped, 'dead', 'dead_a', 8.0, -8.0, -1, 1, 0.0, false, false, false)
    SendUi('death', { active = true, seconds = deathTimer })
    if Config.Dispatch.autoAlertOnDeath then
        TriggerServerEvent('qa-ambulance:server:SendAlert', GetEntityCoords(ped), 'Person down and needs medical assistance')
    end
end

local function SendToHospital(hospitalKey)
    local hospital = Config.Hospitals[hospitalKey] or Config.Hospitals[Config.DefaultHospital] or Config.Hospitals.pillbox
    local respawn = hospital.respawn
    DoScreenFadeOut(700)
    Wait(900)
    RevivePed()
    SetEntityCoords(PlayerPedId(), respawn.x, respawn.y, respawn.z, false, false, false, false)
    SetEntityHeading(PlayerPedId(), respawn.w)
    DoScreenFadeIn(700)
end

local function PutInBed(hospitalKey)
    local hospital = Config.Hospitals[hospitalKey]
    if not hospital then return end
    currentBed = hospital.beds[math.random(#hospital.beds)]
    DoScreenFadeOut(600)
    Wait(800)
    local ped = PlayerPedId()
    SetEntityCoords(ped, currentBed.x, currentBed.y, currentBed.z + 0.02, false, false, false, false)
    SetEntityHeading(ped, currentBed.w)
    LoadAnimDict('anim@gangops@morgue@table@')
    TaskPlayAnim(ped, 'anim@gangops@morgue@table@', 'body_search', 8.0, -8.0, -1, 1, 0, false, false, false)
    DoScreenFadeIn(600)
    Wait(12000)
    RevivePed()
    ClearPedTasks(ped)
    Notify('You have been treated and discharged.', 'success')
end

local function SpawnVehicle(data, spawn)
    QBCore.Functions.SpawnVehicle(data.model, function(vehicle)
        SetVehicleNumberPlateText(vehicle, 'EMS' .. tostring(math.random(100, 999)))
        SetEntityHeading(vehicle, spawn.w)
        exports['LegacyFuel']:SetFuel(vehicle, 100.0)
        TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
        TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(vehicle))
        SetVehicleEngineOn(vehicle, true, true)
    end, spawn, true)
end

local function OpenGarage(hospitalKey, kind)
    if not IsOnDutyMedic() then Notify('You must be on duty.', 'error') return end
    local list = kind == 'heli' and Config.Helicopters or Config.Vehicles
    local hospital = Config.Hospitals[hospitalKey]
    local menu = {
        { header = kind == 'heli' and 'Air Ambulance' or 'EMS Garage', isMenuHeader = true }
    }
    for _, vehicle in ipairs(list) do
        if PlayerData.job.grade.level >= vehicle.grade then
            menu[#menu + 1] = {
                header = vehicle.label,
                txt = ('Required grade: %s'):format(vehicle.grade),
                params = {
                    event = 'qa-ambulance:client:SpawnGarageVehicle',
                    args = { vehicle = vehicle, spawn = kind == 'heli' and hospital.heli.spawn or hospital.garage.spawn }
                }
            }
        end
    end
    menu[#menu + 1] = { header = 'Close', params = { event = 'qb-menu:client:closeMenu' } }
    exports['qb-menu']:openMenu(menu)
end

local function OpenArmory()
    if not IsOnDutyMedic() then Notify('You must be on duty.', 'error') return end
    TriggerServerEvent('inventory:server:OpenInventory', 'shop', 'ems_armory', {
        label = 'EMS Armory',
        slots = #Config.Armory,
        items = Config.Armory
    })
end

local function OpenBossMenu()
    if not IsMedic() then Notify('EMS only.', 'error') return end
    if not PlayerData.job.isboss then Notify('You are not authorized.', 'error') return end
    TriggerEvent('qb-bossmenu:client:OpenMenu')
end

local function OpenPatientActions(targetId)
    QBCore.Functions.TriggerCallback('qa-ambulance:server:GetPatient', function(patient)
        if not patient then Notify('Patient not found.', 'error') return end
        OpenTablet(patient)
    end, targetId)
end

local function OpenXrayMachineMenu()
    if not IsOnDutyMedic() then Notify('You must be on duty.', 'error') return end
    local closestPlayer, distance = QBCore.Functions.GetClosestPlayer()
    if closestPlayer == -1 or distance > Config.Healthcare.maxPatientDistance then Notify('Position a patient beside the machine.', 'error') return end
    local targetId = GetPlayerServerId(closestPlayer)
    exports['qb-menu']:openMenu({
        { header = 'X-Ray Machine', isMenuHeader = true },
        { header = 'Chest X-Ray', params = { event = 'qa-ambulance:client:StartMachineTest', args = { target = targetId, test = 'xray_chest' } } },
        { header = 'Head X-Ray', params = { event = 'qa-ambulance:client:StartMachineTest', args = { target = targetId, test = 'xray_head' } } },
        { header = 'Limb X-Ray', params = { event = 'qa-ambulance:client:StartMachineTest', args = { target = targetId, test = 'xray_limb' } } },
        { header = 'Close', params = { event = 'qb-menu:client:closeMenu' } }
    })
end

RegisterNetEvent('qa-ambulance:client:StartMachineTest', function(data)
    TriggerServerEvent('qa-ambulance:server:StartProcedure', data.target, 'test', data.test, 'Machine imaging study')
end)

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(500) end
    PlayerData = QBCore.Functions.GetPlayerData()

    for key, hospital in pairs(Config.Hospitals) do
        if hospital.blip then
            local blip = AddBlipForCoord(hospital.blip.coords.x, hospital.blip.coords.y, hospital.blip.coords.z)
            SetBlipSprite(blip, hospital.blip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, hospital.blip.scale)
            SetBlipColour(blip, hospital.blip.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(hospital.label)
            EndTextCommandSetBlipName(blip)
        end

        if Config.UseTarget then
            exports['qb-target']:AddBoxZone('qa_ems_duty_' .. key, hospital.duty, 1.2, 1.2, {
                name = 'qa_ems_duty_' .. key,
                heading = 0,
                minZ = hospital.duty.z - 1,
                maxZ = hospital.duty.z + 1
            }, {
                options = {
                    { icon = 'fas fa-user-md', label = 'Toggle Duty', job = Config.JobName, action = function() TriggerServerEvent('QBCore:ToggleDuty') end }
                },
                distance = 2.0
            })

            exports['qb-target']:AddBoxZone('qa_ems_checkin_' .. key, hospital.checkin, 1.4, 1.4, {
                name = 'qa_ems_checkin_' .. key,
                heading = 0,
                minZ = hospital.checkin.z - 1,
                maxZ = hospital.checkin.z + 1
            }, {
                options = {
                    { icon = 'fas fa-notes-medical', label = 'Check In', action = function() TriggerServerEvent('qa-ambulance:server:CheckIn', key) end }
                },
                distance = 2.0
            })

            if hospital.garage then
                exports['qb-target']:AddBoxZone('qa_ems_garage_' .. key, hospital.garage.menu, 1.5, 1.5, {
                    name = 'qa_ems_garage_' .. key,
                    heading = 0,
                    minZ = hospital.garage.menu.z - 1,
                    maxZ = hospital.garage.menu.z + 1
                }, {
                    options = {
                        { icon = 'fas fa-truck-medical', label = 'EMS Garage', job = Config.JobName, action = function() OpenGarage(key, 'ground') end }
                    },
                    distance = 2.0
                })
            end

            if hospital.heli then
                exports['qb-target']:AddBoxZone('qa_ems_heli_' .. key, hospital.heli.menu, 2.0, 2.0, {
                    name = 'qa_ems_heli_' .. key,
                    heading = 0,
                    minZ = hospital.heli.menu.z - 1,
                    maxZ = hospital.heli.menu.z + 1
                }, {
                    options = {
                        { icon = 'fas fa-helicopter', label = 'Helipad', job = Config.JobName, action = function() OpenGarage(key, 'heli') end }
                    },
                    distance = 2.5
                })
            end

            if hospital.stash then
                exports['qb-target']:AddBoxZone('qa_ems_stash_' .. key, hospital.stash, 1.2, 1.2, {
                    name = 'qa_ems_stash_' .. key,
                    heading = 0,
                    minZ = hospital.stash.z - 1,
                    maxZ = hospital.stash.z + 1
                }, {
                    options = {
                        { icon = 'fas fa-box-open', label = 'Open EMS Stash', job = Config.JobName, action = function() TriggerServerEvent('qa-ambulance:server:OpenStash', key) end }
                    },
                    distance = 2.0
                })
            end

            if hospital.armory then
                exports['qb-target']:AddBoxZone('qa_ems_armory_' .. key, hospital.armory, 1.2, 1.2, {
                    name = 'qa_ems_armory_' .. key,
                    heading = 0,
                    minZ = hospital.armory.z - 1,
                    maxZ = hospital.armory.z + 1
                }, {
                    options = {
                        { icon = 'fas fa-kit-medical', label = 'Open EMS Armory', job = Config.JobName, action = OpenArmory }
                    },
                    distance = 2.0
                })
            end

            if hospital.boss then
                exports['qb-target']:AddBoxZone('qa_ems_boss_' .. key, hospital.boss, 1.2, 1.2, {
                    name = 'qa_ems_boss_' .. key,
                    heading = 0,
                    minZ = hospital.boss.z - 1,
                    maxZ = hospital.boss.z + 1
                }, {
                    options = {
                        { icon = 'fas fa-briefcase-medical', label = 'EMS Management', job = Config.JobName, action = OpenBossMenu }
                    },
                    distance = 2.0
                })
            end
        end
    end
end)

CreateThread(function()
    if Config.UseTarget and Config.Healthcare then
        exports['qb-target']:AddTargetModel(Config.Healthcare.xrayModels, {
            options = {
                {
                    icon = 'fas fa-x-ray',
                    label = 'Operate X-Ray Machine',
                    job = Config.JobName,
                    action = OpenXrayMachineMenu
                }
            },
            distance = 2.0
        })
    end
end)

local function RegisterHealthcareApp()
    if healthcareAppRegistered or not Config.Healthcare.lbPhone or GetResourceState('lb-phone') ~= 'started' then return end
    Wait(700)
    local success, errorMessage = exports['lb-phone']:AddCustomApp({
        identifier = Config.Healthcare.appIdentifier,
        name = 'Health Care',
        description = 'View medical tests, imaging and surgery reports',
        developer = 'EMS',
        defaultApp = true,
        size = 184,
        ui = GetCurrentResourceName() .. '/html/health.html',
        icon = 'https://cfx-nui-' .. GetCurrentResourceName() .. '/html/assets/medical.svg',
        fixBlur = true,
        onOpen = function()
            QBCore.Functions.TriggerCallback('qa-ambulance:server:GetPatientServices', function(data)
                exports['lb-phone']:SendCustomAppMessage(Config.Healthcare.appIdentifier, { action = 'services', data = data })
            end)
            QBCore.Functions.TriggerCallback('qa-ambulance:server:GetHealthReports', function(reports)
                exports['lb-phone']:SendCustomAppMessage(Config.Healthcare.appIdentifier, { action = 'reports', reports = reports })
            end)
        end
    })
    healthcareAppRegistered = success or errorMessage == 'App already exists'
    if not healthcareAppRegistered then Debug('LB Phone app registration failed: ' .. tostring(errorMessage)) end
end

CreateThread(RegisterHealthcareApp)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == 'lb-phone' then
        healthcareAppRegistered = false
        CreateThread(RegisterHealthcareApp)
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        if LocalPlayer.state.isLoggedIn then
            local ped = PlayerPedId()
            if not isDead and (IsEntityDead(ped) or GetEntityHealth(ped) <= Config.DownHealth) then
                SetDeadState()
            end
            if isDead then
                deathTimer = math.max(deathTimer - 1, 0)
                SendUi('death', { active = true, seconds = deathTimer })
            end
        end
    end
end)

CreateThread(function()
    while true do
        if not isDead then
            Wait(500)
        else
            Wait(0)
            local ped = PlayerPedId()
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            EnableControlAction(0, 245, true)
            EnableControlAction(0, 38, true)

            if not IsEntityPlayingAnim(ped, 'dead', 'dead_a', 3) then
                TaskPlayAnim(ped, 'dead', 'dead_a', 8.0, -8.0, -1, 1, 0.0, false, false, false)
            end

            if deathTimer <= 0 and IsControlJustPressed(0, 38) then
                SendToHospital(Config.DefaultHospital)
            end
        end
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerData.job = job
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(duty)
    if PlayerData.job then PlayerData.job.onduty = duty end
    SendUi('duty', { onduty = duty })
end)

RegisterNetEvent('qa-ambulance:client:SpawnGarageVehicle', function(data)
    SpawnVehicle(data.vehicle, data.spawn)
end)

RegisterNetEvent('qa-ambulance:client:Revive', function()
    RevivePed()
    Notify('You were revived.', 'success')
end)

RegisterNetEvent('qa-ambulance:client:Treat', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + 45))
    ClearPedBloodDamage(ped)
    Notify('Your wounds were treated.', 'success')
end)

RegisterNetEvent('qa-ambulance:client:SendToBed', function(hospitalKey)
    PutInBed(hospitalKey)
end)

RegisterNetEvent('qa-ambulance:client:UseMedicalItem', function(_, data)
    if PlayProgress('Applying ' .. data.label, data.duration, 'missheistdockssetup1clipboard@idle_a', 'idle_a') then
        local ped = PlayerPedId()
        SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + data.heal))
        TriggerServerEvent('hud:server:RelieveStress', data.stress)
        Notify(data.label .. ' applied.', 'success')
    end
end)

RegisterNetEvent('qa-ambulance:client:UseDefib', function()
    local closestPlayer, distance = QBCore.Functions.GetClosestPlayer()
    if closestPlayer == -1 or distance > 3.0 then Notify('No patient nearby.', 'error') return end
    if PlayProgress('Charging defibrillator', 9000, 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest') then
        TriggerServerEvent('qa-ambulance:server:RevivePlayer', GetPlayerServerId(closestPlayer))
    end
end)

RegisterNetEvent('qa-ambulance:client:OpenTablet', function()
    OpenTablet(nil)
end)

RegisterNetEvent('qa-ambulance:client:ReceiveAlert', function(alert)
    Notify(('EMS Alert: %s'):format(alert.message), 'error')
    SendUi('alert', alert)
    local blip = AddBlipForCoord(alert.coords.x, alert.coords.y, alert.coords.z)
    SetBlipSprite(blip, 153)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.9)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('EMS Alert')
    EndTextCommandSetBlipName(blip)
    SetBlipRoute(blip, true)
    SetTimeout(120000, function()
        RemoveBlip(blip)
    end)
end)

RegisterNetEvent('qa-ambulance:client:ProcedureAnimation', function(procedureType, definition, isPatient)
    local ped = PlayerPedId()
    local duration = definition.duration or 8000
    local equipment
    if isPatient then
        LoadAnimDict('anim@gangops@morgue@table@')
        FreezeEntityPosition(ped, true)
        TaskPlayAnim(ped, 'anim@gangops@morgue@table@', 'body_search', 8.0, -8.0, duration, 1, 0.0, false, false, false)
    elseif procedureType == 'surgery' then
        LoadAnimDict('mini@repair')
        TaskPlayAnim(ped, 'mini@repair', 'fixing_a_ped', 8.0, -8.0, duration, 1, 0.0, false, false, false)
    elseif definition.animation == 'blood' then
        LoadAnimDict('amb@medic@standing@tendtodead@base')
        TaskPlayAnim(ped, 'amb@medic@standing@tendtodead@base', 'base', 8.0, -8.0, duration, 49, 0.0, false, false, false)
        local model = joaat('prop_syringe_01')
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(10) end
        equipment = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
        AttachEntityToEntity(equipment, ped, GetPedBoneIndex(ped, 57005), 0.12, 0.02, -0.02, -90.0, 0.0, 0.0, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(model)
    else
        LoadAnimDict('missheistdockssetup1clipboard@idle_a')
        TaskPlayAnim(ped, 'missheistdockssetup1clipboard@idle_a', 'idle_a', 8.0, -8.0, duration, 49, 0.0, false, false, false)
    end
    SetTimeout(duration, function()
        FreezeEntityPosition(ped, false)
        ClearPedTasks(ped)
        if equipment and DoesEntityExist(equipment) then DeleteEntity(equipment) end
    end)
end)

RegisterNetEvent('qa-ambulance:client:ProcedureComplete', function(label)
    Notify(label .. ' completed. Report generated.', 'success')
    if nuiOpen then SendUi('reportReady', {}) end
end)

RegisterNetEvent('qa-ambulance:client:HealthReportReady', function(label)
    Notify('Your ' .. label .. ' report is now available.', 'success')
    if Config.Healthcare.lbPhone and GetResourceState('lb-phone') == 'started' then
        exports['lb-phone']:SendNotification({ app = Config.Healthcare.appIdentifier, title = 'New medical report', content = label .. ' is ready to view.' })
    end
end)

RegisterNetEvent('qa-ambulance:client:BookingUpdated', function(title, content)
    Notify(content, 'primary')
    if Config.Healthcare.lbPhone and GetResourceState('lb-phone') == 'started' then
        exports['lb-phone']:SendNotification({ app = Config.Healthcare.appIdentifier, title = title, content = content })
        QBCore.Functions.TriggerCallback('qa-ambulance:server:GetPatientServices', function(data)
            exports['lb-phone']:SendCustomAppMessage(Config.Healthcare.appIdentifier, { action = 'services', data = data })
        end)
    end
end)

RegisterNetEvent('qa-ambulance:client:ServiceDataChanged', function()
    if nuiOpen then SendUi('serviceDataChanged', {}) end
end)

RegisterNetEvent('qa-ambulance:client:PackageDataChanged', function()
    if nuiOpen then SendUi('packageDataChanged', {}) end
    if Config.Healthcare.lbPhone and GetResourceState('lb-phone') == 'started' then
        QBCore.Functions.TriggerCallback('qa-ambulance:server:GetPatientServices', function(data)
            exports['lb-phone']:SendCustomAppMessage(Config.Healthcare.appIdentifier, { action = 'services', data = data })
        end)
    end
end)

RegisterCommand('emstablet', function()
    if IsOnDutyMedic() then OpenTablet(nil) end
end, false)

RegisterCommand('revivep', function()
    if not IsOnDutyMedic() then return end
    local closestPlayer, distance = QBCore.Functions.GetClosestPlayer()
    if closestPlayer == -1 or distance > 3.0 then Notify('No patient nearby.', 'error') return end
    if PlayProgress('Reviving patient', 9000, 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest') then
        TriggerServerEvent('qa-ambulance:server:RevivePlayer', GetPlayerServerId(closestPlayer))
    end
end, false)

RegisterCommand('treatp', function()
    if not IsOnDutyMedic() then return end
    local closestPlayer, distance = QBCore.Functions.GetClosestPlayer()
    if closestPlayer == -1 or distance > 3.0 then Notify('No patient nearby.', 'error') return end
    if PlayProgress('Treating wounds', 6000, 'missheistdockssetup1clipboard@idle_a', 'idle_a') then
        TriggerServerEvent('qa-ambulance:server:TreatPlayer', GetPlayerServerId(closestPlayer))
    end
end, false)

RegisterCommand('patient', function(_, args)
    if not IsOnDutyMedic() then return end
    local id = tonumber(args[1])
    if id then OpenPatientActions(id) else Notify('Usage: /patient [id]', 'error') end
end, false)

RegisterNUICallback('close', function(_, cb)
    CloseTablet()
    cb('ok')
end)

RegisterNUICallback('revive', function(data, cb)
    if data.target then TriggerServerEvent('qa-ambulance:server:RevivePlayer', data.target) end
    cb('ok')
end)

RegisterNUICallback('treat', function(data, cb)
    if data.target then TriggerServerEvent('qa-ambulance:server:TreatPlayer', data.target) end
    cb('ok')
end)

RegisterNUICallback('bill', function(data, cb)
    if data.target and data.amount then
        TriggerServerEvent('qa-ambulance:server:BillPatient', data.target, data.amount, data.notes)
    end
    cb('ok')
end)

RegisterNUICallback('records', function(data, cb)
    QBCore.Functions.TriggerCallback('qa-ambulance:server:GetRecords', function(records)
        cb(records)
    end, data.citizenid)
end)

RegisterNUICallback('healthReports', function(data, cb)
    QBCore.Functions.TriggerCallback('qa-ambulance:server:GetHealthReports', function(reports)
        cb(reports)
    end, data.citizenid)
end)

RegisterNUICallback('healthRecords', function(_, cb)
    QBCore.Functions.TriggerCallback('qa-ambulance:server:GetHealthReports', function(reports)
        cb(reports)
    end)
end)

RegisterNUICallback('patientServices', function(_, cb)
    QBCore.Functions.TriggerCallback('qa-ambulance:server:GetPatientServices', function(data)
        cb(data)
    end)
end)

RegisterNUICallback('createHealthBooking', function(data, cb)
    QBCore.Functions.TriggerCallback('qa-ambulance:server:CreateHealthBooking', function(result)
        Notify(result.ok and ('Booking placed: ' .. result.bookingRef) or (result.error or 'Booking failed.'), result.ok and 'success' or 'error')
        cb(result)
    end, data.packageId, data.locationId, data.paymentMethod)
end)

RegisterNUICallback('serviceWaypoint', function(data, cb)
    if data.x and data.y then
        SetNewWaypoint(tonumber(data.x) + 0.0, tonumber(data.y) + 0.0)
        Notify('Route set to service location.', 'success')
    end
    cb({ ok = true })
end)

RegisterNUICallback('tabletNotify', function(data, cb)
    Notify(tostring(data.message or 'Action unavailable.'), data.type or 'primary')
    cb({ ok = true })
end)

RegisterNUICallback('bookingQueue', function(_, cb)
    QBCore.Functions.TriggerCallback('qa-ambulance:server:GetBookingQueue', function(data)
        cb(data)
    end)
end)

RegisterNUICallback('packageAdmin', function(_, cb)
    QBCore.Functions.TriggerCallback('qa-ambulance:server:GetPackageAdmin', function(data)
        cb(data)
    end)
end)

RegisterNUICallback('saveTestPrice', function(data, cb)
    TriggerServerEvent('qa-ambulance:server:SaveTestPrice', data.testId, data.price, data.active)
    cb({ ok = true })
end)

RegisterNUICallback('saveHealthPackage', function(data, cb)
    TriggerServerEvent('qa-ambulance:server:SaveHealthPackage', data)
    cb({ ok = true })
end)

RegisterNUICallback('deleteHealthPackage', function(data, cb)
    TriggerServerEvent('qa-ambulance:server:DeleteHealthPackage', data.id)
    cb({ ok = true })
end)

RegisterNUICallback('addServiceLocation', function(data, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    TriggerServerEvent('qa-ambulance:server:AddServiceLocation', data.name, data.locationType, {
        x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(ped)
    })
    cb({ ok = true })
end)

RegisterNUICallback('toggleServiceLocation', function(data, cb)
    TriggerServerEvent('qa-ambulance:server:ToggleServiceLocation', data.id)
    cb({ ok = true })
end)

RegisterNUICallback('advanceBooking', function(data, cb)
    TriggerServerEvent('qa-ambulance:server:AdvanceBooking', data.id, data.note)
    cb({ ok = true })
end)

RegisterNUICallback('collectBookingPayment', function(data, cb)
    TriggerServerEvent('qa-ambulance:server:CollectBookingPayment', data.id, data.method)
    cb({ ok = true })
end)

RegisterNUICallback('clinicalProcedure', function(data, cb)
    if data.target and data.procedureType and data.procedureId then
        TriggerServerEvent('qa-ambulance:server:StartProcedure', data.target, data.procedureType, data.procedureId, data.notes)
        cb({ ok = true })
        return
    end
    cb({ ok = false })
end)

RegisterNUICallback('waypoint', function(data, cb)
    if data.coords then
        SetNewWaypoint(data.coords.x + 0.0, data.coords.y + 0.0)
    end
    cb('ok')
end)
