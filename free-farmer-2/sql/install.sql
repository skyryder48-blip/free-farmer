-- =============================================================================
-- free-farmer — Database Schema
-- Run this file once to create all required tables.
-- Uses INT for all timestamps (UNIX epoch) for simpler Lua math.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `farm_fields` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `field_id` VARCHAR(50) NOT NULL UNIQUE,
    `farm_zone` VARCHAR(50) NOT NULL,
    `status` VARCHAR(20) DEFAULT 'raw',
    `crop_type` VARCHAR(50) DEFAULT NULL,
    `growth_stage` INT DEFAULT 0,
    `planted_at` INT DEFAULT NULL,
    `stage_updated_at` INT DEFAULT NULL,
    `soil_quality` INT DEFAULT 100,
    `last_harvest` INT DEFAULT NULL,
    `last_crop` VARCHAR(50) DEFAULT NULL,
    `last_crop_family` VARCHAR(50) DEFAULT NULL,
    `times_harvested` INT DEFAULT 0,
    `consecutive_same_crop` INT DEFAULT 0,
    `weather_quality_modifier` FLOAT DEFAULT 1.0,
    `good_weather_ticks` INT DEFAULT 0,
    `bad_weather_ticks` INT DEFAULT 0,
    `fertilized` TINYINT(1) DEFAULT 0,
    `fertilizer_quality` VARCHAR(20) DEFAULT NULL,
    `last_fertilized` INT DEFAULT NULL,
    `created_at` INT DEFAULT NULL,
    `updated_at` INT DEFAULT NULL,
    INDEX(`farm_zone`),
    INDEX(`crop_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `farm_planters` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `planter_uuid` VARCHAR(36) NOT NULL UNIQUE,
    `owner_identifier` VARCHAR(50) NOT NULL,
    `coords_x` FLOAT NOT NULL,
    `coords_y` FLOAT NOT NULL,
    `coords_z` FLOAT NOT NULL,
    `heading` FLOAT DEFAULT 0.0,
    `crop_type` VARCHAR(50) DEFAULT NULL,
    `growth_stage` INT DEFAULT 0,
    `planted_at` INT DEFAULT NULL,
    `stage_updated_at` INT DEFAULT NULL,
    `created_at` INT DEFAULT NULL,
    `updated_at` INT DEFAULT NULL,
    INDEX(`owner_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `farm_animals` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `animal_uuid` VARCHAR(36) NOT NULL UNIQUE,
    `owner_identifier` VARCHAR(50) NOT NULL,
    `owner_name` VARCHAR(100) DEFAULT NULL,
    `animal_type` VARCHAR(50) NOT NULL,
    `animal_name` VARCHAR(100) DEFAULT NULL,
    `gender` VARCHAR(10) NOT NULL DEFAULT 'female',
    `farm_zone` VARCHAR(50) NOT NULL,
    `pen_id` VARCHAR(50) DEFAULT NULL,
    `is_stored` TINYINT(1) DEFAULT 0,
    `stored_at` INT DEFAULT NULL,
    `growth_stage` VARCHAR(50) NOT NULL,
    `age` INT DEFAULT 0,
    `quality` VARCHAR(50) DEFAULT 'average',
    `health` INT DEFAULT 100,
    `last_fed` INT DEFAULT NULL,
    `last_watered` INT DEFAULT NULL,
    `is_sick` TINYINT(1) DEFAULT 0,
    `sickness_type` VARCHAR(50) DEFAULT NULL,
    `production_ready` TINYINT(1) DEFAULT 0,
    `last_produced` INT DEFAULT NULL,
    `total_production` INT DEFAULT 0,
    `created_at` INT DEFAULT NULL,
    `updated_at` INT DEFAULT NULL,
    INDEX(`owner_identifier`),
    INDEX(`farm_zone`),
    INDEX(`pen_id`),
    INDEX(`is_stored`),
    INDEX(`animal_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `farm_player_data` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL UNIQUE,
    `character_name` VARCHAR(100) DEFAULT NULL,
    `xp` INT DEFAULT 0,
    `level` INT DEFAULT 1,
    `total_crops_harvested` INT DEFAULT 0,
    `total_crops_planted` INT DEFAULT 0,
    `total_animals_cared_for` INT DEFAULT 0,
    `total_production_collected` INT DEFAULT 0,
    `total_challenges_completed` INT DEFAULT 0,
    `created_at` INT DEFAULT NULL,
    `updated_at` INT DEFAULT NULL,
    INDEX(`level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tracks simplified auto-breeding state per pen (persistent across restarts)
CREATE TABLE IF NOT EXISTS `farm_pen_breeding` (
    `pen_id` VARCHAR(50) NOT NULL PRIMARY KEY,
    `well_kept_since` INT DEFAULT NULL,
    `last_birth` INT DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `farm_challenges` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL,
    `challenge_type` VARCHAR(50) NOT NULL,
    `requirements` TEXT DEFAULT NULL,
    `progress` TEXT DEFAULT NULL,
    `completed` TINYINT(1) DEFAULT 0,
    `expires_at` INT DEFAULT NULL,
    `created_at` INT DEFAULT NULL,
    INDEX(`identifier`),
    INDEX(`completed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `farm_leaderboard` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL UNIQUE,
    `character_name` VARCHAR(100) DEFAULT NULL,
    `total_score` INT DEFAULT 0,
    `weekly_score` INT DEFAULT 0,
    `monthly_score` INT DEFAULT 0,
    `updated_at` INT DEFAULT NULL,
    INDEX(`total_score`),
    INDEX(`weekly_score`),
    INDEX(`monthly_score`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tracks farm zone ownership for admin assignment
CREATE TABLE IF NOT EXISTS `farm_ownership` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `farm_zone` VARCHAR(50) NOT NULL UNIQUE,
    `owner_identifier` VARCHAR(50) NOT NULL,
    `assigned_at` INT DEFAULT NULL,
    INDEX(`owner_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
