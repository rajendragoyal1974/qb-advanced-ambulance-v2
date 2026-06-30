local QBCore = exports['qb-core']:GetCoreObject()
local DeadPlayers = {}
local AlertCooldowns = {}
local ActiveProcedures = {}

local function IsAmbulance(src)
    local Player = QBCore.Functions.GetPlayer(src)
    return Player and Player.PlayerData.job.name == Config.JobName
end

local function Notify(src, message, kind)
    TriggerClientEvent('QBCore:Notify', src, message, kind or 'primary')
end

local function GetOnlineDoctors()
    local count = 0
    for _, src in pairs(QBCore.Functions.GetPlayers()) do
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData.job.name == Config.JobName and Player.PlayerData.job.onduty then
            count = count + 1
        end
    end
    return count
end

local function SendMedicalAlert(src, coords, message)
    local now = os.time()
    if AlertCooldowns[src] and now - AlertCooldowns[src] < Config.Dispatch.cooldown then
        Notify(src, 'You recently sent an EMS alert.', 'error')
        return
    end
    AlertCooldowns[src] = now

    local Player = QBCore.Functions.GetPlayer(src)
    local name = Player and ('%s %s'):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname) or ('ID %s'):format(src)
    for _, medicSrc in pairs(QBCore.Functions.GetPlayers()) do
        local Medic = QBCore.Functions.GetPlayer(medicSrc)
        if Medic and Medic.PlayerData.job.name == Config.JobName and Medic.PlayerData.job.onduty then
            TriggerClientEvent('qa-ambulance:client:ReceiveAlert', medicSrc, {
                caller = name,
                source = src,
                coords = coords,
                message = message or 'Medical emergency'
            })
        end
    end
    Notify(src, 'EMS alert sent.', 'success')
end

QBCore.Functions.CreateCallback('qa-ambulance:server:GetDoctors', function(_, cb)
    cb(GetOnlineDoctors())
end)

QBCore.Functions.CreateCallback('qa-ambulance:server:GetPatient', function(source, cb, targetId)
    if not IsAmbulance(source) then cb(nil) return end
    local Target = QBCore.Functions.GetPlayer(tonumber(targetId))
    if not Target then cb(nil) return end

    cb({
        source = targetId,
        citizenid = Target.PlayerData.citizenid,
        name = ('%s %s'):format(Target.PlayerData.charinfo.firstname, Target.PlayerData.charinfo.lastname),
        status = DeadPlayers[targetId] and 'dead' or 'hurt',
        metadata = Target.PlayerData.metadata or {}
    })
end)

QBCore.Functions.CreateCallback('qa-ambulance:server:GetRecords', function(source, cb, citizenid)
    if not IsAmbulance(source) then cb({}) return end
    MySQL.query('SELECT * FROM ambulance_patient_records WHERE citizenid = ? ORDER BY created_at DESC LIMIT 20', { citizenid }, function(result)
        cb(result or {})
    end)
end)

local function PlayerName(Player)
    local charinfo = Player.PlayerData.charinfo
    return ('%s %s'):format(charinfo.firstname, charinfo.lastname)
end

local function DecodeReports(rows)
    for _, row in ipairs(rows or {}) do
        row.findings = json.decode(row.findings or '[]') or {}
    end
    return rows or {}
end

local function BuildTestFindings(testId, Target)
    local metadata = Target.PlayerData.metadata or {}
    local ped = GetPlayerPed(Target.PlayerData.source)
    local health = ped > 0 and GetEntityHealth(ped) or 200
    local condition = health < 130 and 'Abnormal - clinical review required' or 'Within expected limits'
    local findings = {
        physical = { Consciousness = DeadPlayers[Target.PlayerData.source] and 'Unconscious' or 'Alert', Trauma = health < 160 and 'Visible injury present' or 'No major external trauma', Mobility = health < 140 and 'Restricted' or 'Normal' },
        vitals = { HeartRate = math.random(68, 104) .. ' bpm', BloodPressure = math.random(108, 132) .. '/' .. math.random(68, 86) .. ' mmHg', OxygenSaturation = math.random(94, 99) .. '%', Temperature = string.format('%.1f C', math.random(365, 378) / 10) },
        blood_cbc = { Hemoglobin = string.format('%.1f g/dL', math.random(120, 165) / 10), WhiteCells = string.format('%.1f x10^9/L', math.random(40, 110) / 10), Platelets = math.random(160, 390) .. ' x10^9/L' },
        blood_metabolic = { Glucose = math.random(72, 132) .. ' mg/dL', Sodium = math.random(136, 145) .. ' mmol/L', Potassium = string.format('%.1f mmol/L', math.random(35, 50) / 10), Creatinine = string.format('%.1f mg/dL', math.random(7, 13) / 10) },
        blood_type = { BloodGroup = metadata.bloodtype or 'Unknown', AntibodyScreen = 'Negative' },
        toxicology = { Alcohol = 'Not detected', Opiates = 'Not detected', Stimulants = 'Not detected' },
        urinalysis = { Appearance = 'Clear', Protein = 'Negative', Glucose = 'Negative', InfectionMarkers = 'Negative' },
        ecg = { Rhythm = health < 120 and 'Sinus tachycardia' or 'Normal sinus rhythm', Rate = math.random(68, 104) .. ' bpm', STChanges = 'No acute ST elevation' },
        xray_chest = { ImageQuality = 'Diagnostic', Lungs = 'No focal opacity', Cardiomediastinal = 'Within normal limits', Bones = health < 130 and 'Possible traumatic change; correlate clinically' or 'No acute osseous abnormality' },
        xray_head = { ImageQuality = 'Diagnostic', Skull = health < 115 and 'Possible fracture; CT recommended' or 'No displaced fracture', SoftTissue = 'No radiopaque foreign body' },
        xray_limb = { Alignment = health < 125 and 'Possible malalignment' or 'Maintained', Fracture = health < 125 and 'Suspected; orthopedic review advised' or 'No acute fracture seen' },
        ct_scan = { Intracranial = 'No acute hemorrhage identified', ChestAbdomen = health < 115 and 'Traumatic findings require specialist review' or 'No acute abnormality identified' },
        mri = { SoftTissues = health < 120 and 'Post-traumatic signal change' or 'No significant abnormality', NeuralStructures = 'No compression identified' },
        ultrasound = { FreeFluid = health < 110 and 'Indeterminate trace fluid' or 'Not detected', Organs = 'No gross abnormality' }
    }
    return findings[testId] or { Result = condition }, condition
end

local function InsertHealthReport(Target, Medic, procedureType, procedureId, definition, notes, callback)
    local findings, summary
    if procedureType == 'surgery' then
        findings = { Outcome = 'Procedure completed', Complications = 'None observed', PostOperativeStatus = 'Stable', FollowUp = 'Monitor vitals and wound condition' }
        summary = 'Surgery completed; patient stable'
    else
        findings, summary = BuildTestFindings(procedureId, Target)
    end

    local doctorNotes = string.sub(tostring(notes or ''), 1, 2000)
    local parameters = {
        Target.PlayerData.citizenid,
        PlayerName(Target),
        Medic.PlayerData.citizenid,
        PlayerName(Medic),
        procedureType,
        definition.label,
        definition.category or 'Surgery',
        summary,
        json.encode(findings),
        doctorNotes
    }
    local query = 'INSERT INTO ambulance_health_reports (citizenid, patient_name, doctor_citizenid, doctor_name, procedure_type, procedure_name, category, summary, findings, doctor_notes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'

    MySQL.insert(query, parameters, function(reportId)
        if callback then callback(reportId) end
    })
end

QBCore.Functions.CreateCallback('qa-ambulance:server:GetHealthReports', function(source, cb, citizenid)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb({}) return end
    local requested = citizenid or Player.PlayerData.citizenid
    if requested ~= Player.PlayerData.citizenid and not IsAmbulance(source) then cb({}) return end
    local limit = math.max(1, math.min(tonumber(Config.Healthcare.reportLimit) or 50, 100))
    MySQL.query(('SELECT * FROM ambulance_health_reports WHERE citizenid = ? ORDER BY created_at DESC LIMIT %d'):format(limit), { requested }, function(rows)
        cb(DecodeReports(rows))
    end)
end)

local BookingTransitions = {
    placed = 'awaiting_visit',
    awaiting_visit = 'samples_collected',
    samples_collected = 'scans_completed',
    scans_completed = 'awaiting_report',
    awaiting_report = 'report_published',
    report_published = 'completed'
}

local function DecodeServiceRows(rows)
    for _, row in ipairs(rows or {}) do
        if row.tests then row.tests = json.decode(row.tests) or {} end
        if row.package_tests then row.package_tests = json.decode(row.package_tests) or {} end
    end
    return rows or {}
end

local function ApplyPackageDiscounts(packages)
    for _, package in ipairs(packages or {}) do
        local discount = math.max(0, math.min(tonumber(package.discount_percent) or 0, 90))
        package.original_price = tonumber(package.price) or 0
        package.sale_price = math.floor(package.original_price * (1.0 - discount / 100.0) + 0.5)
    end
    return packages or {}
end

local function GetBookingHistory(bookings, callback)
    if not bookings or #bookings == 0 then callback(bookings or {}) return end
    local ids = {}
    local byId = {}
    for _, booking in ipairs(bookings) do
        ids[#ids + 1] = booking.id
        booking.history = {}
        byId[booking.id] = booking
    end
    MySQL.query(('SELECT * FROM ambulance_booking_history WHERE booking_id IN (%s) ORDER BY created_at ASC'):format(table.concat(ids, ',')), {}, function(history)
        for _, entry in ipairs(history or {}) do
            if byId[entry.booking_id] then byId[entry.booking_id].history[#byId[entry.booking_id].history + 1] = entry end
        end
        callback(bookings)
    end)
end

local function NotifyBookingOwner(citizenid, title, content)
    local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if Player then TriggerClientEvent('qa-ambulance:client:BookingUpdated', Player.PlayerData.source, title, content) end
end

QBCore.Functions.CreateCallback('qa-ambulance:server:GetPatientServices', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb({ packages = {}, locations = {}, bookings = {} }) return end
    local packages = MySQL.query.await('SELECT * FROM ambulance_health_packages WHERE active = 1 ORDER BY price ASC') or {}
    local locations = MySQL.query.await('SELECT * FROM ambulance_service_locations WHERE active = 1 ORDER BY name ASC') or {}
    local bookings = MySQL.query.await('SELECT * FROM ambulance_health_bookings WHERE citizenid = ? ORDER BY created_at DESC LIMIT 50', { Player.PlayerData.citizenid }) or {}
    GetBookingHistory(DecodeServiceRows(bookings), function(rows)
        cb({ packages = ApplyPackageDiscounts(DecodeServiceRows(packages)), locations = locations, bookings = rows })
    end)
end)

QBCore.Functions.CreateCallback('qa-ambulance:server:GetPackageAdmin', function(source, cb)
    if not IsAmbulance(source) then cb({ packages = {}, tests = {} }) return end
    local packages = MySQL.query.await('SELECT * FROM ambulance_health_packages ORDER BY is_custom ASC, name ASC') or {}
    local tests = MySQL.query.await('SELECT * FROM ambulance_test_prices ORDER BY category ASC, label ASC') or {}
    cb({ packages = ApplyPackageDiscounts(DecodeServiceRows(packages)), tests = tests })
end)

RegisterNetEvent('qa-ambulance:server:SaveTestPrice', function(testId, price, active)
    local src = source
    if not IsAmbulance(src) or not Config.Healthcare.tests[testId] then return end
    price = math.max(0, math.min(math.floor(tonumber(price) or 0), 1000000))
    MySQL.update('UPDATE ambulance_test_prices SET price = ?, active = ? WHERE test_id = ?', { price, active and 1 or 0, testId }, function()
        Notify(src, 'Test price updated.', 'success')
        TriggerClientEvent('qa-ambulance:client:PackageDataChanged', -1)
    end)
end)

RegisterNetEvent('qa-ambulance:server:SaveHealthPackage', function(data)
    local src = source
    if not IsAmbulance(src) or type(data) ~= 'table' then return end
    local selected = {}
    local seen = {}
    for _, testId in ipairs(data.tests or {}) do
        if Config.Healthcare.tests[testId] and not seen[testId] then
            selected[#selected + 1] = testId
            seen[testId] = true
        end
    end
    if #selected == 0 then Notify(src, 'Select at least one active test.', 'error') return end
    local placeholders = {}
    for _ = 1, #selected do placeholders[#placeholders + 1] = '?' end
    local rows = MySQL.query.await(('SELECT test_id, price FROM ambulance_test_prices WHERE active = 1 AND test_id IN (%s)'):format(table.concat(placeholders, ',')), selected) or {}
    local basePrice = 0
    for _, row in ipairs(rows) do basePrice = basePrice + (tonumber(row.price) or 0) end
    if #rows ~= #selected then Notify(src, 'One or more selected tests are disabled.', 'error') return end

    local name = tostring(data.name or ''):sub(1, 100)
    local description = tostring(data.description or ''):sub(1, 255)
    local discount = math.max(0, math.min(tonumber(data.discount) or 0, 90))
    if #name < 3 then Notify(src, 'Package name is too short.', 'error') return end
    local packageId = tonumber(data.id)
    if packageId then
        MySQL.update.await('UPDATE ambulance_health_packages SET name = ?, description = ?, price = ?, discount_percent = ?, tests = ?, active = ? WHERE id = ?', {
            name, description, basePrice, discount, json.encode(selected), data.active and 1 or 0, packageId
        })
    else
        local code = ('custom_%s_%s'):format(os.time(), math.random(100, 999))
        MySQL.insert.await('INSERT INTO ambulance_health_packages (code, name, description, price, discount_percent, tests, active, is_custom) VALUES (?, ?, ?, ?, ?, ?, 1, 1)', {
            code, name, description, basePrice, discount, json.encode(selected)
        })
    end
    Notify(src, packageId and 'Health package updated.' or 'Custom health package created.', 'success')
    TriggerClientEvent('qa-ambulance:client:PackageDataChanged', -1)
end)

RegisterNetEvent('qa-ambulance:server:DeleteHealthPackage', function(packageId)
    local src = source
    if not IsAmbulance(src) then return end
    MySQL.update('DELETE FROM ambulance_health_packages WHERE id = ? AND is_custom = 1', { tonumber(packageId) }, function(affected)
        Notify(src, affected and affected > 0 and 'Custom health package deleted.' or 'Predefined packages cannot be deleted.', affected and affected > 0 and 'success' or 'error')
        TriggerClientEvent('qa-ambulance:client:PackageDataChanged', -1)
    end)
end)

QBCore.Functions.CreateCallback('qa-ambulance:server:GetBookingQueue', function(source, cb)
    if not IsAmbulance(source) then cb({ bookings = {}, locations = {} }) return end
    local bookings = MySQL.query.await("SELECT * FROM ambulance_health_bookings WHERE status NOT IN ('completed','cancelled') ORDER BY created_at ASC LIMIT 100") or {}
    local locations = MySQL.query.await('SELECT * FROM ambulance_service_locations ORDER BY active DESC, name ASC') or {}
    GetBookingHistory(DecodeServiceRows(bookings), function(rows) cb({ bookings = rows, locations = locations }) end)
end)

QBCore.Functions.CreateCallback('qa-ambulance:server:CreateHealthBooking', function(source, cb, packageId, locationId, paymentMethod)
    local Player = QBCore.Functions.GetPlayer(source)
    packageId = tonumber(packageId)
    locationId = tonumber(locationId)
    local methods = { card = true, cash = true, bank = true, hospital = true }
    if not Player or not packageId or not locationId or not methods[paymentMethod] then cb({ ok = false, error = 'Invalid booking details.' }) return end
    local package = MySQL.single.await('SELECT * FROM ambulance_health_packages WHERE id = ? AND active = 1', { packageId })
    local location = MySQL.single.await('SELECT * FROM ambulance_service_locations WHERE id = ? AND active = 1', { locationId })
    if not package or not location then cb({ ok = false, error = 'Package or location is unavailable.' }) return end

    local discount = math.max(0, math.min(tonumber(package.discount_percent) or 0, 90))
    local packagePrice = math.floor((tonumber(package.price) or 0) * (1.0 - discount / 100.0) + 0.5)
    local paymentStatus = 'pending'
    if paymentMethod ~= 'hospital' then
        local account = paymentMethod == 'cash' and 'cash' or 'bank'
        if not Player.Functions.RemoveMoney(account, packagePrice, 'ems-health-package') then cb({ ok = false, error = 'Insufficient funds.' }) return end
        paymentStatus = 'paid'
    end

    local bookingRef = ('HC%s%04d'):format(os.time(), math.random(1000, 9999))
    local invoiceNumber = ('INV-%s'):format(bookingRef)
    local id = MySQL.insert.await('INSERT INTO ambulance_health_bookings (booking_ref, citizenid, patient_name, package_id, package_name, package_tests, location_id, location_name, payment_method, payment_status, amount, status, status_note, invoice_number) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        bookingRef, Player.PlayerData.citizenid, PlayerName(Player), package.id, package.name, package.tests, location.id, location.name,
        paymentMethod, paymentStatus, packagePrice, 'placed', 'Booking received by EMS', invoiceNumber
    })
    MySQL.insert('INSERT INTO ambulance_booking_history (booking_id, status, note, changed_by) VALUES (?, ?, ?, ?)', { id, 'placed', 'Health package booked', PlayerName(Player) })
    cb({ ok = true, bookingRef = bookingRef })
end)

RegisterNetEvent('qa-ambulance:server:AddServiceLocation', function(name, locationType, coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not IsAmbulance(src) or type(coords) ~= 'table' then return end
    name = tostring(name or ''):sub(1, 100)
    locationType = locationType == 'hospital' and 'hospital' or 'pharmacy'
    if #name < 3 then Notify(src, 'Location name is too short.', 'error') return end
    MySQL.insert('INSERT INTO ambulance_service_locations (name, location_type, x, y, z, heading, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        name, locationType, tonumber(coords.x) or 0, tonumber(coords.y) or 0, tonumber(coords.z) or 0, tonumber(coords.w) or 0, Player.PlayerData.citizenid
    }, function()
        Notify(src, locationType == 'hospital' and 'Hospital location added.' or 'Pharmacy location added.', 'success')
        TriggerClientEvent('qa-ambulance:client:ServiceDataChanged', src)
    end)
end)

RegisterNetEvent('qa-ambulance:server:ToggleServiceLocation', function(locationId)
    local src = source
    if not IsAmbulance(src) then return end
    MySQL.update('UPDATE ambulance_service_locations SET active = IF(active = 1, 0, 1) WHERE id = ?', { tonumber(locationId) }, function()
        Notify(src, 'Service location availability updated.', 'success')
        TriggerClientEvent('qa-ambulance:client:ServiceDataChanged', src)
    end)
end)

local function PublishBookingReport(booking, Medic)
    local tests = json.decode(booking.package_tests or '[]') or {}
    local findings = {}
    for _, testId in ipairs(tests) do
        local definition = Config.Healthcare.tests[testId]
        findings[definition and definition.label or testId] = 'Completed - detailed findings reviewed by EMS'
    end
    MySQL.insert.await('INSERT INTO ambulance_health_reports (citizenid, patient_name, doctor_citizenid, doctor_name, procedure_type, procedure_name, category, summary, findings, doctor_notes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        booking.citizenid, booking.patient_name, Medic.PlayerData.citizenid, PlayerName(Medic), 'package', booking.package_name,
        'Health Package', 'Package completed; detailed results published', json.encode(findings), booking.status_note or ''
    })
end

RegisterNetEvent('qa-ambulance:server:AdvanceBooking', function(bookingId, note)
    local src = source
    local Medic = QBCore.Functions.GetPlayer(src)
    if not Medic or not IsAmbulance(src) or not Medic.PlayerData.job.onduty then return end
    local booking = MySQL.single.await('SELECT * FROM ambulance_health_bookings WHERE id = ?', { tonumber(bookingId) })
    local nextStatus = booking and BookingTransitions[booking.status]
    if not nextStatus then Notify(src, 'This booking cannot be advanced.', 'error') return end
    if nextStatus == 'samples_collected' and booking.payment_status ~= 'paid' then Notify(src, 'Collect payment before taking samples.', 'error') return end

    local timestampField = ''
    if nextStatus == 'samples_collected' then timestampField = ', samples_taken_at = CURRENT_TIMESTAMP' end
    if nextStatus == 'scans_completed' then timestampField = ', scans_taken_at = CURRENT_TIMESTAMP' end
    if nextStatus == 'report_published' then timestampField = ', report_published_at = CURRENT_TIMESTAMP' end
    local cleanNote = tostring(note or ''):sub(1, 255)
    local changed = MySQL.update.await(('UPDATE ambulance_health_bookings SET status = ?, status_note = ?, assigned_doctor = ?%s WHERE id = ? AND status = ?'):format(timestampField), {
        nextStatus, cleanNote, PlayerName(Medic), booking.id, booking.status
    })
    if not changed or changed < 1 then Notify(src, 'Booking was already updated by another doctor.', 'error') return end
    MySQL.insert('INSERT INTO ambulance_booking_history (booking_id, status, note, changed_by) VALUES (?, ?, ?, ?)', { booking.id, nextStatus, cleanNote, PlayerName(Medic) })
    if nextStatus == 'report_published' then PublishBookingReport(booking, Medic) end
    Notify(src, 'Booking advanced to ' .. nextStatus:gsub('_', ' ') .. '.', 'success')
    NotifyBookingOwner(booking.citizenid, 'Booking updated', booking.package_name .. ': ' .. nextStatus:gsub('_', ' '))
    TriggerClientEvent('qa-ambulance:client:ServiceDataChanged', src)
end)

RegisterNetEvent('qa-ambulance:server:CollectBookingPayment', function(bookingId, method)
    local src = source
    if not IsAmbulance(src) then return end
    local booking = MySQL.single.await('SELECT * FROM ambulance_health_bookings WHERE id = ?', { tonumber(bookingId) })
    if not booking or booking.payment_status == 'paid' then return end
    local Patient = QBCore.Functions.GetPlayerByCitizenId(booking.citizenid)
    local methods = { card = 'bank', bank = 'bank', cash = 'cash' }
    local account = methods[method]
    if not Patient or not account then Notify(src, 'Patient must be online and payment method valid.', 'error') return end
    local claimed = MySQL.update.await("UPDATE ambulance_health_bookings SET payment_status = 'paid', payment_method = ? WHERE id = ? AND payment_status = 'pending'", { method, booking.id })
    if not claimed or claimed < 1 then Notify(src, 'Payment was already processed.', 'error') return end
    if not Patient.Functions.RemoveMoney(account, booking.amount, 'ems-health-package-hospital') then
        MySQL.update("UPDATE ambulance_health_bookings SET payment_status = 'pending', payment_method = 'hospital' WHERE id = ?", { booking.id })
        Notify(src, 'Patient has insufficient funds.', 'error')
        return
    end
    MySQL.insert('INSERT INTO ambulance_booking_history (booking_id, status, note, changed_by) VALUES (?, ?, ?, ?)', { booking.id, booking.status, 'Payment collected by hospital', 'EMS' })
    Notify(src, ('Payment of $%s collected.'):format(booking.amount), 'success')
    Notify(Patient.PlayerData.source, ('Health package payment of $%s completed.'):format(booking.amount), 'success')
    TriggerClientEvent('qa-ambulance:client:ServiceDataChanged', src)
end)

RegisterNetEvent('qa-ambulance:server:StartProcedure', function(targetId, procedureType, procedureId, notes)
    local src = source
    targetId = tonumber(targetId)
    local Medic = QBCore.Functions.GetPlayer(src)
    local Target = targetId and QBCore.Functions.GetPlayer(targetId)
    local catalog = procedureType == 'surgery' and Config.Healthcare.surgeries or Config.Healthcare.tests
    local definition = catalog and catalog[procedureId]
    if not Medic or not Target or not IsAmbulance(src) or not Medic.PlayerData.job.onduty or not definition then return end
    if ActiveProcedures[src] or ActiveProcedures[targetId] then Notify(src, 'Doctor or patient is already in a procedure.', 'error') return end

    local doctorCoords = GetEntityCoords(GetPlayerPed(src))
    local patientCoords = GetEntityCoords(GetPlayerPed(targetId))
    if #(doctorCoords - patientCoords) > Config.Healthcare.maxPatientDistance then Notify(src, 'Patient is too far away.', 'error') return end

    ActiveProcedures[src] = true
    ActiveProcedures[targetId] = true
    Notify(src, definition.label .. ' started.', 'primary')
    TriggerClientEvent('qa-ambulance:client:ProcedureAnimation', src, procedureType, definition, false)
    TriggerClientEvent('qa-ambulance:client:ProcedureAnimation', targetId, procedureType, definition, true)

    SetTimeout(definition.duration, function()
        ActiveProcedures[src] = nil
        ActiveProcedures[targetId] = nil
        InsertHealthReport(Target, Medic, procedureType, procedureId, definition, notes, function()
            if procedureType == 'surgery' then TriggerClientEvent('qa-ambulance:client:Treat', targetId) end
            TriggerClientEvent('qa-ambulance:client:ProcedureComplete', src, definition.label)
            TriggerClientEvent('qa-ambulance:client:HealthReportReady', targetId, definition.label)
        end)
    end)
end)

RegisterNetEvent('qa-ambulance:server:SetDeathStatus', function(isDead)
    local src = source
    DeadPlayers[src] = isDead and true or nil
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        Player.Functions.SetMetaData('isdead', isDead and true or false)
        Player.Functions.SetMetaData('inlaststand', isDead and true or false)
    end
end)

RegisterNetEvent('qa-ambulance:server:RevivePlayer', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not IsAmbulance(src) or not targetId then return end
    local Target = QBCore.Functions.GetPlayer(targetId)
    if not Target then return end

    DeadPlayers[targetId] = nil
    Target.Functions.SetMetaData('isdead', false)
    Target.Functions.SetMetaData('inlaststand', false)
    TriggerClientEvent('qa-ambulance:client:Revive', targetId)

    local Medic = QBCore.Functions.GetPlayer(src)
    if Medic then Medic.Functions.AddMoney('bank', Config.ReviveReward, 'ems-revive-reward') end
    Notify(src, ('Patient revived. Reward: $%s'):format(Config.ReviveReward), 'success')
end)

RegisterNetEvent('qa-ambulance:server:TreatPlayer', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not IsAmbulance(src) or not targetId then return end
    local Target = QBCore.Functions.GetPlayer(targetId)
    if not Target then return end

    TriggerClientEvent('qa-ambulance:client:Treat', targetId)
    local Medic = QBCore.Functions.GetPlayer(src)
    if Medic then Medic.Functions.AddMoney('bank', Config.TreatReward, 'ems-treatment-reward') end
    Notify(src, ('Patient treated. Reward: $%s'):format(Config.TreatReward), 'success')
end)

RegisterNetEvent('qa-ambulance:server:CheckIn', function(hospitalKey)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Config.Hospitals[hospitalKey] then return end
    if GetOnlineDoctors() >= Config.MinimalDoctors then
        Notify(src, 'EMS is available. Please call a doctor.', 'error')
        return
    end

    if Player.Functions.RemoveMoney('bank', Config.CheckInCost, 'hospital-check-in') or Player.Functions.RemoveMoney('cash', Config.CheckInCost, 'hospital-check-in') then
        TriggerClientEvent('qa-ambulance:client:SendToBed', src, hospitalKey)
    else
        Notify(src, 'You do not have enough money for check-in.', 'error')
    end
end)

RegisterNetEvent('qa-ambulance:server:BillPatient', function(targetId, amount, notes)
    local src = source
    targetId = tonumber(targetId)
    amount = tonumber(amount)
    if not IsAmbulance(src) or not targetId or not amount then return end
    amount = math.min(math.max(math.floor(amount), 1), Config.BillMaxAmount)

    local Target = QBCore.Functions.GetPlayer(targetId)
    local Medic = QBCore.Functions.GetPlayer(src)
    if not Target or not Medic then return end

    if Config.UseQbPhone and GetResourceState('qb-phone') == 'started' then
        TriggerEvent('qb-phone:server:sendNewMailToOffline', Target.PlayerData.citizenid, {
            sender = 'Medical Billing',
            subject = 'Hospital invoice',
            message = ('You received a medical bill for $%s. Notes: %s'):format(amount, notes or 'Treatment')
        })
    end
    TriggerEvent('qb-banking:server:CreateInvoice', targetId, amount, 'Medical Services', Config.JobName)

    MySQL.insert('INSERT INTO ambulance_patient_records (citizenid, patient_name, doctor, notes, bill) VALUES (?, ?, ?, ?, ?)', {
        Target.PlayerData.citizenid,
        ('%s %s'):format(Target.PlayerData.charinfo.firstname, Target.PlayerData.charinfo.lastname),
        ('%s %s'):format(Medic.PlayerData.charinfo.firstname, Medic.PlayerData.charinfo.lastname),
        notes or 'Medical treatment',
        amount
    })

    Notify(src, 'Medical bill and record created.', 'success')
    Notify(targetId, ('You received a medical bill for $%s.'):format(amount), 'primary')
end)

RegisterNetEvent('qa-ambulance:server:SendAlert', function(coords, message)
    SendMedicalAlert(source, coords, message)
end)

RegisterNetEvent('qa-ambulance:server:OpenStash', function(hospitalKey)
    local src = source
    if not IsAmbulance(src) or not Config.Hospitals[hospitalKey] then return end
    local stashName = ('ems_%s_stash'):format(hospitalKey)
    exports['qb-inventory']:OpenInventory(src, stashName, { label = Config.Hospitals[hospitalKey].label .. ' Stash', maxweight = 400000, slots = 80 })
end)

for itemName, data in pairs(Config.Consumables) do
    QBCore.Functions.CreateUseableItem(itemName, function(source)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return end
        if Player.Functions.RemoveItem(itemName, 1) then
            TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[itemName], 'remove')
            TriggerClientEvent('qa-ambulance:client:UseMedicalItem', source, itemName, data)
        end
    end)
end

QBCore.Functions.CreateUseableItem(Config.Items.defib, function(source)
    TriggerClientEvent('qa-ambulance:client:UseDefib', source)
end)

QBCore.Functions.CreateUseableItem(Config.Items.medbag, function(source)
    TriggerClientEvent('qa-ambulance:client:OpenTablet', source)
end)

RegisterCommand(Config.Dispatch.command, function(source, args)
    local msg = table.concat(args, ' ')
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    SendMedicalAlert(source, coords, msg ~= '' and msg or 'Medical emergency')
end, false)
