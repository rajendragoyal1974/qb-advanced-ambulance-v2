CREATE TABLE IF NOT EXISTS `ambulance_patient_records` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `patient_name` varchar(100) NOT NULL,
  `doctor` varchar(100) NOT NULL,
  `notes` text DEFAULT NULL,
  `bill` int(11) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ambulance_health_reports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `patient_name` varchar(100) NOT NULL,
  `doctor_citizenid` varchar(50) NOT NULL,
  `doctor_name` varchar(100) NOT NULL,
  `procedure_type` varchar(30) NOT NULL,
  `procedure_name` varchar(100) NOT NULL,
  `category` varchar(50) NOT NULL,
  `summary` varchar(255) NOT NULL,
  `findings` longtext NOT NULL,
  `doctor_notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `health_reports_citizenid` (`citizenid`),
  KEY `health_reports_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ambulance_service_locations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `location_type` enum('pharmacy','hospital') NOT NULL DEFAULT 'pharmacy',
  `x` decimal(10,4) NOT NULL,
  `y` decimal(10,4) NOT NULL,
  `z` decimal(10,4) NOT NULL,
  `heading` decimal(10,4) NOT NULL DEFAULT 0,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `created_by` varchar(50) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ambulance_health_packages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `code` varchar(50) NOT NULL,
  `name` varchar(100) NOT NULL,
  `description` varchar(255) NOT NULL,
  `price` int(11) NOT NULL DEFAULT 0,
  `discount_percent` decimal(5,2) NOT NULL DEFAULT 0,
  `tests` longtext NOT NULL,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `is_custom` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `health_package_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `ambulance_health_packages`
  ADD COLUMN IF NOT EXISTS `discount_percent` decimal(5,2) NOT NULL DEFAULT 0 AFTER `price`,
  ADD COLUMN IF NOT EXISTS `is_custom` tinyint(1) NOT NULL DEFAULT 0 AFTER `active`;

CREATE TABLE IF NOT EXISTS `ambulance_test_prices` (
  `test_id` varchar(50) NOT NULL,
  `label` varchar(100) NOT NULL,
  `category` varchar(50) NOT NULL,
  `price` int(11) NOT NULL DEFAULT 0,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`test_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `ambulance_health_packages` (`code`, `name`, `description`, `price`, `tests`) VALUES
('essential', 'Essential Health Check', 'Physical examination, vital signs, CBC, metabolic panel and urinalysis.', 1500, '["physical","vitals","blood_cbc","blood_metabolic","urinalysis"]'),
('cardiac', 'Cardiac Care Package', 'Vital signs, metabolic panel, ECG and chest imaging.', 2800, '["vitals","blood_metabolic","ecg","xray_chest"]'),
('trauma', 'Trauma Assessment Package', 'Physical examination with head, chest and limb imaging plus CT.', 4500, '["physical","vitals","xray_head","xray_chest","xray_limb","ct_scan"]'),
('complete', 'Complete Executive Package', 'Complete laboratory, cardiac and diagnostic imaging assessment.', 7500, '["physical","vitals","blood_cbc","blood_metabolic","blood_type","toxicology","urinalysis","ecg","xray_chest","ct_scan","mri","ultrasound"]');

CREATE TABLE IF NOT EXISTS `ambulance_health_bookings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `booking_ref` varchar(24) NOT NULL,
  `citizenid` varchar(50) NOT NULL,
  `patient_name` varchar(100) NOT NULL,
  `package_id` int(11) NOT NULL,
  `package_name` varchar(100) NOT NULL,
  `package_tests` longtext NOT NULL,
  `location_id` int(11) DEFAULT NULL,
  `location_name` varchar(100) DEFAULT NULL,
  `payment_method` enum('card','cash','bank','hospital') NOT NULL,
  `payment_status` enum('pending','paid','refunded') NOT NULL DEFAULT 'pending',
  `amount` int(11) NOT NULL,
  `status` varchar(40) NOT NULL DEFAULT 'placed',
  `status_note` varchar(255) DEFAULT NULL,
  `invoice_number` varchar(30) DEFAULT NULL,
  `assigned_doctor` varchar(100) DEFAULT NULL,
  `samples_taken_at` timestamp NULL DEFAULT NULL,
  `scans_taken_at` timestamp NULL DEFAULT NULL,
  `report_published_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `health_booking_ref` (`booking_ref`),
  KEY `health_booking_citizenid` (`citizenid`),
  KEY `health_booking_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ambulance_booking_history` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `booking_id` int(11) NOT NULL,
  `status` varchar(40) NOT NULL,
  `note` varchar(255) DEFAULT NULL,
  `changed_by` varchar(100) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `booking_history_booking_id` (`booking_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
