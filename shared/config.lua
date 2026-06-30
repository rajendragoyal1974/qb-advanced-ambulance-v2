Config = {}

Config.Debug = false
Config.JobName = 'ambulance'
Config.Locale = 'en'
Config.DefaultHospital = 'pillbox'
Config.MapPreset = 'qb_default_pillbox'

Config.UseTarget = true
Config.UseQbPhone = true
Config.UseQbManagement = true
Config.UseQbInventory = true

Config.MinimalDoctors = 2
Config.CheckInCost = 750
Config.ReviveReward = 600
Config.TreatReward = 250
Config.BillMaxAmount = 25000

Config.DeathTime = 300
Config.BleedTickRate = 30000
Config.DamageTickRate = 5000
Config.LastStandHealth = 150
Config.DownHealth = 101
Config.RespawnHealth = 200
Config.RespawnArmor = 0

Config.Items = {
    medbag = 'medbag',
    bandage = 'bandage',
    painkillers = 'painkillers',
    firstaid = 'firstaid',
    defib = 'defib',
    stretcher = 'stretcher',
    ifak = 'ifak'
}

Config.Consumables = {
    bandage = { label = 'Bandage', heal = 18, stress = 2, duration = 4500 },
    painkillers = { label = 'Painkillers', heal = 8, stress = 8, duration = 3500 },
    ifak = { label = 'IFAK', heal = 35, stress = 5, duration = 6500 }
}

Config.Hospitals = {
    vespucci = {
        label = 'Octavista | Vespucci EMS',
        -- Octavista Vespucci EMS MLO preset. If your MLO build is shifted,
        -- use /vector3 and /vector4 in-game and adjust only these points.
        blip = { coords = vector3(-1091.79, -831.85, 19.30), sprite = 61, color = 1, scale = 0.78 },
        duty = vector3(-1086.88, -828.42, 19.30),
        boss = vector3(-1082.35, -823.61, 19.30),
        stash = vector3(-1089.26, -826.14, 19.30),
        armory = vector3(-1093.18, -827.24, 19.30),
        checkin = vector3(-1095.36, -831.31, 19.30),
        garage = {
            menu = vector3(-1104.76, -832.84, 19.00),
            spawn = vector4(-1110.20, -834.53, 18.72, 36.0)
        },
        heli = {
            menu = vector3(-1088.62, -842.70, 37.70),
            spawn = vector4(-1088.62, -842.70, 37.70, 218.0)
        },
        beds = {
            vector4(-1098.40, -826.82, 19.30, 130.0),
            vector4(-1101.06, -829.37, 19.30, 130.0),
            vector4(-1103.73, -831.92, 19.30, 130.0),
            vector4(-1096.10, -824.56, 19.30, 130.0),
            vector4(-1093.71, -822.22, 19.30, 130.0),
            vector4(-1091.35, -819.94, 19.30, 130.0)
        },
        respawn = vector4(-1095.36, -831.31, 19.30, 220.0)
    },
    pillbox = {
        label = 'Pillbox Medical Center',
        blip = { coords = vector3(304.27, -600.33, 43.28), sprite = 61, color = 1, scale = 0.75 },
        duty = vector3(311.18, -599.25, 43.29),
        boss = vector3(335.54, -594.91, 43.29),
        stash = vector3(309.78, -596.60, 43.29),
        armory = vector3(306.26, -601.54, 43.29),
        checkin = vector3(308.19, -595.35, 43.29),
        garage = {
            menu = vector3(294.58, -574.76, 43.18),
            spawn = vector4(294.58, -574.76, 43.18, 35.79)
        },
        heli = {
            menu = vector3(351.58, -587.45, 74.16),
            spawn = vector4(351.58, -587.45, 74.16, 160.50)
        },
        beds = {
            vector4(353.10, -584.60, 43.11, 152.08),
            vector4(356.79, -585.86, 43.11, 152.08),
            vector4(354.12, -593.12, 43.10, 336.32),
            vector4(350.79, -591.80, 43.10, 336.32),
            vector4(346.99, -590.48, 43.10, 336.32),
            vector4(360.32, -587.19, 43.02, 152.08),
            vector4(349.82, -583.33, 43.02, 152.08),
            vector4(326.98, -576.17, 43.02, 152.08)
        },
        respawn = vector4(308.36, -595.25, 43.28, 70.00)
    },
    sandy = {
        label = 'Sandy Shores Clinic',
        blip = { coords = vector3(1839.49, 3672.03, 34.28), sprite = 61, color = 1, scale = 0.65 },
        duty = vector3(1838.78, 3673.82, 34.28),
        checkin = vector3(1839.84, 3672.14, 34.28),
        beds = {
            vector4(1834.68, 3678.79, 35.47, 210.0),
            vector4(1831.91, 3677.17, 35.47, 210.0)
        },
        respawn = vector4(1839.49, 3672.03, 34.28, 213.0)
    }
}

Config.Vehicles = {
    { label = 'Ambulance', model = 'ambulance', grade = 0 },
    { label = 'EMS SUV', model = 'emssuv', grade = 1 },
    { label = 'Rapid Response', model = 'lguard', grade = 2 }
}

Config.Helicopters = {
    { label = 'Medical Maverick', model = 'polmav', grade = 2 }
}

Config.Armory = {
    { name = 'bandage', amount = 10, info = {}, type = 'item', slot = 1 },
    { name = 'painkillers', amount = 10, info = {}, type = 'item', slot = 2 },
    { name = 'firstaid', amount = 5, info = {}, type = 'item', slot = 3 },
    { name = 'defib', amount = 1, info = {}, type = 'item', slot = 4 },
    { name = 'medbag', amount = 1, info = {}, type = 'item', slot = 5 },
    { name = 'stretcher', amount = 1, info = {}, type = 'item', slot = 6 }
}

Config.Dispatch = {
    command = 'emsalert',
    cooldown = 60,
    autoAlertOnDeath = true
}

Config.StatusLabels = {
    healthy = 'Stable',
    hurt = 'Injured',
    critical = 'Critical',
    dead = 'Unconscious'
}

Config.Healthcare = {
    lbPhone = true,
    appIdentifier = 'ems-healthcare',
    reportLimit = 50,
    maxPatientDistance = 5.0,
    xrayModels = { 'v_med_xray', 'v_med_xray2' },
    tests = {
        physical = { label = 'Physical Examination', category = 'Examination', duration = 7000, animation = 'clipboard' },
        vitals = { label = 'Vital Signs', category = 'Examination', duration = 6000, animation = 'clipboard' },
        blood_cbc = { label = 'Complete Blood Count', category = 'Laboratory', duration = 9000, animation = 'blood' },
        blood_metabolic = { label = 'Metabolic Panel', category = 'Laboratory', duration = 9000, animation = 'blood' },
        blood_type = { label = 'Blood Group and Rh', category = 'Laboratory', duration = 9000, animation = 'blood' },
        toxicology = { label = 'Toxicology Screen', category = 'Laboratory', duration = 9000, animation = 'blood' },
        urinalysis = { label = 'Urinalysis', category = 'Laboratory', duration = 7000, animation = 'clipboard' },
        ecg = { label = '12-Lead ECG', category = 'Cardiology', duration = 10000, animation = 'machine' },
        xray_chest = { label = 'Chest X-Ray', category = 'Imaging', duration = 12000, animation = 'xray' },
        xray_head = { label = 'Head X-Ray', category = 'Imaging', duration = 12000, animation = 'xray' },
        xray_limb = { label = 'Limb X-Ray', category = 'Imaging', duration = 12000, animation = 'xray' },
        ct_scan = { label = 'CT Scan', category = 'Imaging', duration = 15000, animation = 'xray' },
        mri = { label = 'MRI Scan', category = 'Imaging', duration = 18000, animation = 'xray' },
        ultrasound = { label = 'Ultrasound', category = 'Imaging', duration = 12000, animation = 'machine' }
    },
    surgeries = {
        trauma = { label = 'Trauma Surgery', duration = 30000 },
        orthopedic = { label = 'Orthopedic Surgery', duration = 30000 },
        cardiovascular = { label = 'Cardiovascular Surgery', duration = 35000 },
        neurosurgery = { label = 'Neurosurgery', duration = 40000 },
        abdominal = { label = 'Abdominal Surgery', duration = 35000 },
        wound = { label = 'Wound Debridement and Sutures', duration = 20000 }
    }
}
