-- EVENT STUDIO — migration 001 (initial schema)
-- Applied automatically by server/core/storage.lua when Config.Database.adapter = 'oxmysql'.

CREATE TABLE IF NOT EXISTS `es_migrations` (
  `version` INT NOT NULL PRIMARY KEY,
  `applied_at` INT NOT NULL
);

CREATE TABLE IF NOT EXISTS `es_documents` (
  `kind` VARCHAR(32) NOT NULL,
  `id` VARCHAR(64) NOT NULL,
  `data` LONGTEXT NOT NULL,
  `updated_by` VARCHAR(64) NULL,
  `updated_at` INT NOT NULL,
  PRIMARY KEY (`kind`, `id`)
);

CREATE TABLE IF NOT EXISTS `es_instances` (
  `id` INT NOT NULL PRIMARY KEY,
  `definition_id` VARCHAR(64) NOT NULL,
  `mode` VARCHAR(32) NOT NULL,
  `category` VARCHAR(32) NOT NULL,
  `final_state` VARCHAR(16) NOT NULL,
  `started_at` INT NULL,
  `ended_at` INT NOT NULL,
  `participants` SMALLINT NOT NULL DEFAULT 0,
  `winner` VARCHAR(128) NULL,
  `tournament_id` VARCHAR(64) NULL,
  `summary` LONGTEXT NULL,
  KEY `idx_def` (`definition_id`),
  KEY `idx_ended` (`ended_at`)
);

CREATE TABLE IF NOT EXISTS `es_results` (
  `instance_id` INT NOT NULL,
  `identifier` VARCHAR(64) NOT NULL,
  `name` VARCHAR(64) NOT NULL,
  `team` TINYINT NULL,
  `placement` SMALLINT NULL,
  `status` VARCHAR(16) NOT NULL,
  `score` INT NOT NULL DEFAULT 0,
  `points` INT NOT NULL DEFAULT 0,
  `kills` SMALLINT NOT NULL DEFAULT 0,
  `deaths` SMALLINT NOT NULL DEFAULT 0,
  `objectives` SMALLINT NOT NULL DEFAULT 0,
  `finish_ms` INT NULL,
  PRIMARY KEY (`instance_id`, `identifier`),
  KEY `idx_identifier` (`identifier`)
);

CREATE TABLE IF NOT EXISTS `es_player_stats` (
  `identifier` VARCHAR(64) NOT NULL,
  `season` VARCHAR(16) NOT NULL,
  `category` VARCHAR(32) NOT NULL,
  `name` VARCHAR(64) NOT NULL,
  `joined` INT NOT NULL DEFAULT 0,
  `completed` INT NOT NULL DEFAULT 0,
  `wins` INT NOT NULL DEFAULT 0,
  `podiums` INT NOT NULL DEFAULT 0,
  `kills` INT NOT NULL DEFAULT 0,
  `deaths` INT NOT NULL DEFAULT 0,
  `objectives` INT NOT NULL DEFAULT 0,
  `points` INT NOT NULL DEFAULT 0,
  `best_streak` INT NOT NULL DEFAULT 0,
  `updated_at` INT NOT NULL,
  PRIMARY KEY (`identifier`, `season`, `category`),
  KEY `idx_board` (`season`, `category`, `points`)
);

CREATE TABLE IF NOT EXISTS `es_personal_bests` (
  `identifier` VARCHAR(64) NOT NULL,
  `definition_id` VARCHAR(64) NOT NULL,
  `name` VARCHAR(64) NOT NULL,
  `best_ms` INT NOT NULL,
  `achieved_at` INT NOT NULL,
  PRIMARY KEY (`identifier`, `definition_id`),
  KEY `idx_def_best` (`definition_id`, `best_ms`)
);

CREATE TABLE IF NOT EXISTS `es_payouts` (
  `ledger_key` VARCHAR(160) NOT NULL PRIMARY KEY,
  `instance_id` INT NOT NULL,
  `identifier` VARCHAR(64) NOT NULL,
  `reward` TEXT NOT NULL,
  `status` VARCHAR(16) NOT NULL,
  `created_at` INT NOT NULL,
  KEY `idx_payout_identifier` (`identifier`)
);

CREATE TABLE IF NOT EXISTS `es_logs` (
  `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `created_at` INT NOT NULL,
  `level` VARCHAR(16) NOT NULL,
  `action` VARCHAR(64) NOT NULL,
  `actor` VARCHAR(96) NULL,
  `instance_id` INT NULL,
  `data` TEXT NULL,
  KEY `idx_log_time` (`created_at`),
  KEY `idx_log_level` (`level`)
);
