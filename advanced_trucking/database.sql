CREATE TABLE IF NOT EXISTS trucking_profiles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    identifier VARCHAR(80) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    xp INT NOT NULL DEFAULT 0,
    level INT NOT NULL DEFAULT 1,
    reputation INT NOT NULL DEFAULT 0,
    completed_jobs INT NOT NULL DEFAULT 0,
    failed_jobs INT NOT NULL DEFAULT 0,
    licenses LONGTEXT NULL,
    stats LONGTEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS trucking_owned_trucks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    owner_identifier VARCHAR(80) NOT NULL,
    truck_key VARCHAR(40) NOT NULL,
    label VARCHAR(80) NOT NULL,
    plate VARCHAR(20) NOT NULL UNIQUE,
    engine_health FLOAT NOT NULL DEFAULT 1000,
    tire_wear FLOAT NOT NULL DEFAULT 100,
    brake_wear FLOAT NOT NULL DEFAULT 100,
    fuel_level FLOAT NOT NULL DEFAULT 100,
    oil_life FLOAT NOT NULL DEFAULT 100,
    mileage INT NOT NULL DEFAULT 0,
    metadata LONGTEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_trucking_owned_trucks_owner (owner_identifier)
);

CREATE TABLE IF NOT EXISTS trucking_jobs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    job_id VARCHAR(140) NOT NULL UNIQUE,
    identifier VARCHAR(80) NOT NULL,
    tier VARCHAR(50) NOT NULL,
    cargo VARCHAR(50) NOT NULL,
    origin VARCHAR(60) NOT NULL,
    destination VARCHAR(60) NOT NULL,
    trailer VARCHAR(50) NOT NULL,
    estimated_pay INT NOT NULL DEFAULT 0,
    actual_pay INT NOT NULL DEFAULT 0,
    status VARCHAR(30) NOT NULL DEFAULT 'available',
    started_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    metadata LONGTEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_trucking_jobs_identifier (identifier),
    INDEX idx_trucking_jobs_status (status)
);

CREATE TABLE IF NOT EXISTS trucking_companies (
    id INT AUTO_INCREMENT PRIMARY KEY,
    owner_identifier VARCHAR(80) NOT NULL UNIQUE,
    company_name VARCHAR(120) NOT NULL,
    reputation INT NOT NULL DEFAULT 0,
    garage_level INT NOT NULL DEFAULT 1,
    driver_slots INT NOT NULL DEFAULT 0,
    contract_slots INT NOT NULL DEFAULT 1,
    upgrades LONGTEXT NULL,
    balance INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS trucking_employees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    company_identifier VARCHAR(80) NOT NULL,
    employee_identifier VARCHAR(80) NOT NULL,
    employee_name VARCHAR(120) NOT NULL,
    employee_type VARCHAR(20) NOT NULL DEFAULT 'npc',
    reputation INT NOT NULL DEFAULT 0,
    status VARCHAR(30) NOT NULL DEFAULT 'active',
    metadata LONGTEXT NULL,
    hired_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_trucking_employees_company (company_identifier)
);

CREATE TABLE IF NOT EXISTS trucking_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    identifier VARCHAR(80) NOT NULL,
    job_id VARCHAR(140) NULL,
    event_type VARCHAR(50) NOT NULL,
    message VARCHAR(255) NOT NULL,
    amount INT NOT NULL DEFAULT 0,
    metadata LONGTEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_trucking_logs_identifier (identifier),
    INDEX idx_trucking_logs_job (job_id)
);
