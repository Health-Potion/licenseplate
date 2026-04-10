-- ============================================================
--  mu-licenseplate — SQL schema
--  Run once against your QBCore database before starting the resource.
-- ============================================================

-- ─── mu_plate_map ────────────────────────────────────────────────────────────
-- One row per GTA vehicle plate.
-- vehicle_plate : the plate the GTA engine assigned to the vehicle (8-char max)
-- mu_plate      : what is actually displayed (Mauritius format, 8-char max)
-- When a player purchases and assigns a custom plate the mu_plate column is
-- updated here so the lookup always returns the correct text.

CREATE TABLE IF NOT EXISTS `mu_plate_map` (
    `id`            INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `vehicle_plate` VARCHAR(15)     NOT NULL,
    `mu_plate`      VARCHAR(10)     NOT NULL,
    `citizenid`     VARCHAR(50)     DEFAULT NULL,
    `created_at`    TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_vehicle_plate` (`vehicle_plate`),
    UNIQUE KEY `uq_mu_plate`      (`mu_plate`),
    INDEX `idx_citizenid`         (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── mu_custom_plates ────────────────────────────────────────────────────────
-- Tracks every custom plate a citizen has purchased.
-- assigned_vehicle : the vehicle_plate this custom plate is currently showing on
--                    (NULL = purchased but not yet assigned to any vehicle)

CREATE TABLE IF NOT EXISTS `mu_custom_plates` (
    `id`               INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `citizenid`        VARCHAR(50)     NOT NULL,
    `mu_plate`         VARCHAR(10)     NOT NULL,
    `plate_type`       ENUM('tier1','tier2','tier3') NOT NULL,
    `assigned_vehicle` VARCHAR(15)     DEFAULT NULL,
    `purchased_price`  INT UNSIGNED    NOT NULL DEFAULT 0,
    `created_at`       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_mu_plate`  (`mu_plate`),
    INDEX `idx_citizenid`     (`citizenid`),
    INDEX `idx_assigned`      (`assigned_vehicle`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
