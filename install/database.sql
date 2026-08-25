CREATE TABLE IF NOT EXISTS `fxr_3dprinter` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `owner` VARCHAR(50) DEFAULT NULL,
    `coords` LONGTEXT NOT NULL,
    `rotation` LONGTEXT NOT NULL,
    `materials` LONGTEXT DEFAULT '{}',
    `current_print` VARCHAR(50) DEFAULT NULL,
    `finish_time` INT(11) DEFAULT 0,
    `finished_item` VARCHAR(50) DEFAULT NULL,
    `finished_count` INT(11) DEFAULT 0,
    `durability` INT(11) DEFAULT 100,
    `bucket` INT(11) DEFAULT 0,
    PRIMARY KEY (`id`),
    INDEX `owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `fxr_3d_blueprints` (
    `citizenid` VARCHAR(50) NOT NULL,
    `blueprint` VARCHAR(50) NOT NULL,
    `purchased_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `blueprint`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
