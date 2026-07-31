-- Daily Mart Database Schema for VPS MySQL
CREATE DATABASE IF NOT EXISTS daily_mart;
USE daily_mart;

-- Sellers Table
CREATE TABLE IF NOT EXISTS sellers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(100) NOT NULL,
    mobile VARCHAR(15) DEFAULT '',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Customers Table
CREATE TABLE IF NOT EXISTS customers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    mobile VARCHAR(15) NOT NULL UNIQUE,
    name VARCHAR(100) DEFAULT 'Customer',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Messages Table (With is_read status for WhatsApp badge)
CREATE TABLE IF NOT EXISTS messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    seller_username VARCHAR(50) NOT NULL,
    customer_mobile VARCHAR(15) NOT NULL,
    message TEXT NOT NULL,
    sender_type VARCHAR(10) DEFAULT 'customer',
    is_read TINYINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
