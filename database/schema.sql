-- ============================================================================
-- CLOSED ECONOMY SYSTEM FOR SA-MP - DATABASE SCHEMA
-- ============================================================================
-- Version: 1.0
-- Purpose: Complete MySQL schema for player-driven closed economy
-- Notes:
--   - All timestamps use UTC
--   - Foreign keys enforce referential integrity
--   - Indexes on frequently queried columns for performance
--   - Ledger table uses BIGINT for transaction audit trail (never delete)
-- ============================================================================

-- Drop existing database (development only; comment out for production)
-- DROP DATABASE IF EXISTS samp_economy;
-- CREATE DATABASE samp_economy CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- USE samp_economy;

-- ============================================================================
-- TABLE: PLAYERS
-- Purpose: Player account information, balance, and skills
-- ============================================================================
CREATE TABLE IF NOT EXISTS players (
    playerid INT PRIMARY KEY COMMENT 'SA-MP player ID (not auto-increment)',
    username VARCHAR(24) NOT NULL UNIQUE COMMENT 'Player name',
    password_hash VARCHAR(255) COMMENT 'Password hash (bcrypt)',
    
    -- Account Balance
    cash BIGINT DEFAULT 0 COMMENT 'Money in pocket',
    bank BIGINT DEFAULT 0 COMMENT 'Money in bank account',
    
    -- Skills (0-100 scale)
    skill_farming INT DEFAULT 0 COMMENT 'Farming/Fishing skill level',
    skill_mining INT DEFAULT 0 COMMENT 'Mining skill level',
    skill_crafting INT DEFAULT 0 COMMENT 'Crafting/Manufacturing skill level',
    skill_logistics INT DEFAULT 0 COMMENT 'Logistics/Transport skill level',
    
    -- Taxation
    tax_rate FLOAT DEFAULT 0.05 COMMENT 'Personal tax rate (5% default)',
    
    -- Account Status
    account_status ENUM('active', 'frozen', 'banned') DEFAULT 'active',
    
    -- Metadata
    join_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    playtime_hours INT DEFAULT 0 COMMENT 'Total playtime in hours',
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Indexes
    KEY idx_username (username),
    KEY idx_cash (cash),
    KEY idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Player account information and balances';

-- ============================================================================
-- TABLE: BUSINESSES
-- Purpose: Business/Industry entities owned by players
-- ============================================================================
CREATE TABLE IF NOT EXISTS businesses (
    businessid INT PRIMARY KEY AUTO_INCREMENT,
    ownerid INT NOT NULL COMMENT 'Player who owns this business',
    
    -- Business Info
    business_name VARCHAR(64) NOT NULL,
    business_type ENUM('farm', 'factory', 'market', 'warehouse', 'bank', 'transport') COMMENT 'Type of business',
    business_description TEXT,
    
    -- Location
    location_x FLOAT COMMENT 'X coordinate of business',
    location_y FLOAT COMMENT 'Y coordinate of business',
    location_z FLOAT COMMENT 'Z coordinate of business',
    world_id INT DEFAULT 0 COMMENT 'SA-MP virtual world',
    
    -- Finances
    cash BIGINT DEFAULT 0 COMMENT 'Business bank account',
    inventory_value BIGINT DEFAULT 0 COMMENT 'Total value of stored items',
    
    -- Capacity
    max_inventory_slots INT DEFAULT 100 COMMENT 'Maximum items business can store',
    current_inventory_items INT DEFAULT 0 COMMENT 'Current number of item stacks stored',
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Metadata
    established_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Indexes
    FOREIGN KEY (ownerid) REFERENCES players(playerid) ON DELETE CASCADE,
    KEY idx_ownerid (ownerid),
    KEY idx_business_type (business_type),
    KEY idx_cash (cash)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Businesses and industries owned by players';

-- ============================================================================
-- TABLE: ITEMS_CATALOG
-- Purpose: Definition of all items in economy
-- ============================================================================
CREATE TABLE IF NOT EXISTS items_catalog (
    itemid INT PRIMARY KEY AUTO_INCREMENT,
    item_name VARCHAR(64) NOT NULL UNIQUE,
    item_type VARCHAR(32) COMMENT 'raw, produced, weapon, tool, consumable, etc.',
    item_description TEXT,
    
    -- Pricing
    base_price FLOAT DEFAULT 0 COMMENT 'Initial market price',
    market_price FLOAT DEFAULT 0 COMMENT 'Current dynamic market price',
    min_price FLOAT DEFAULT NULL COMMENT 'Minimum price cap',
    max_price FLOAT DEFAULT NULL COMMENT 'Maximum price cap',
    
    -- Physical Properties
    weight FLOAT DEFAULT 0 COMMENT 'Weight per unit (kg)',
    max_stack INT DEFAULT 100 COMMENT 'Maximum items per stack',
    is_stackable BOOLEAN DEFAULT TRUE,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Indexes
    KEY idx_item_name (item_name),
    KEY idx_item_type (item_type),
    KEY idx_market_price (market_price)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Catalog of all tradeable items';

-- ============================================================================
-- TABLE: PLAYER_INVENTORY
-- Purpose: Items owned by players
-- ============================================================================
CREATE TABLE IF NOT EXISTS player_inventory (
    inventoryid INT PRIMARY KEY AUTO_INCREMENT,
    playerid INT NOT NULL,
    itemid INT NOT NULL,
    quantity INT DEFAULT 0 COMMENT 'Number of items held',
    
    -- Metadata
    acquired_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Constraints
    UNIQUE KEY unique_player_item (playerid, itemid),
    FOREIGN KEY (playerid) REFERENCES players(playerid) ON DELETE CASCADE,
    FOREIGN KEY (itemid) REFERENCES items_catalog(itemid) ON DELETE RESTRICT,
    
    -- Indexes
    KEY idx_playerid (playerid),
    KEY idx_itemid (itemid),
    KEY idx_quantity (quantity)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Player inventory - items owned by individual players';

-- ============================================================================
-- TABLE: BUSINESS_INVENTORY
-- Purpose: Items stored in businesses/warehouses
-- ============================================================================
CREATE TABLE IF NOT EXISTS business_inventory (
    inventoryid INT PRIMARY KEY AUTO_INCREMENT,
    businessid INT NOT NULL,
    itemid INT NOT NULL,
    quantity INT DEFAULT 0 COMMENT 'Number of items stored',
    
    -- Metadata
    stored_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Constraints
    UNIQUE KEY unique_business_item (businessid, itemid),
    FOREIGN KEY (businessid) REFERENCES businesses(businessid) ON DELETE CASCADE,
    FOREIGN KEY (itemid) REFERENCES items_catalog(itemid) ON DELETE RESTRICT,
    
    -- Indexes
    KEY idx_businessid (businessid),
    KEY idx_itemid (itemid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Business inventory - items stored by businesses/warehouses';

-- ============================================================================
-- TABLE: PRODUCTION_CHAINS
-- Purpose: Define production recipes and conversion rates
-- ============================================================================
CREATE TABLE IF NOT EXISTS production_chains (
    chainid INT PRIMARY KEY AUTO_INCREMENT,
    chain_name VARCHAR(64) NOT NULL UNIQUE COMMENT 'Name of production chain',
    
    -- Input/Output
    input_itemid INT COMMENT 'Item required for production (tool/resource)',
    output_itemid INT NOT NULL COMMENT 'Item produced',
    
    -- Conversion
    input_quantity INT DEFAULT 1 COMMENT 'Units of input needed',
    output_quantity INT DEFAULT 1 COMMENT 'Units of output produced',
    conversion_rate FLOAT DEFAULT 1.0 COMMENT 'Multiplier for output (skill effect)',
    
    -- Economics
    base_wage FLOAT DEFAULT 0 COMMENT 'Base wage per production cycle',
    production_time_seconds INT DEFAULT 10 COMMENT 'Time to produce (game seconds)',
    difficulty_level INT DEFAULT 1 COMMENT '1=Easy, 5=Hard (affects skill gain)',
    
    -- Requirements
    required_skill_type VARCHAR(32) COMMENT 'farming, mining, crafting, etc.',
    required_skill_level INT DEFAULT 0 COMMENT 'Minimum skill to perform',
    
    -- Metadata
    chain_description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes
    FOREIGN KEY (input_itemid) REFERENCES items_catalog(itemid) ON DELETE SET NULL,
    FOREIGN KEY (output_itemid) REFERENCES items_catalog(itemid) ON DELETE RESTRICT,
    KEY idx_chain_name (chain_name),
    KEY idx_required_skill_type (required_skill_type),
    KEY idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Production chains - recipes and conversion rates';

-- ============================================================================
-- TABLE: CRAFTING_RECIPES
-- Purpose: Define item recipes for manufacturing/crafting
-- ============================================================================
CREATE TABLE IF NOT EXISTS crafting_recipes (
    recipeid INT PRIMARY KEY AUTO_INCREMENT,
    recipe_name VARCHAR(64) NOT NULL,
    output_itemid INT NOT NULL COMMENT 'What gets produced',
    output_quantity INT DEFAULT 1,
    
    -- Crafting Cost
    crafting_cost INT DEFAULT 0 COMMENT 'Money spent on materials',
    production_time_seconds INT DEFAULT 30 COMMENT 'Time to craft',
    
    -- Skill Requirements
    required_skill_type VARCHAR(32) COMMENT 'crafting, manufacturing, etc.',
    required_skill_level INT DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes
    FOREIGN KEY (output_itemid) REFERENCES items_catalog(itemid) ON DELETE RESTRICT,
    KEY idx_output_itemid (output_itemid),
    KEY idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Crafting recipes for manufacturing';

-- ============================================================================
-- TABLE: CRAFTING_RECIPE_INGREDIENTS
-- Purpose: Items required for each recipe
-- ============================================================================
CREATE TABLE IF NOT EXISTS crafting_recipe_ingredients (
    ingredientid INT PRIMARY KEY AUTO_INCREMENT,
    recipeid INT NOT NULL,
    itemid INT NOT NULL COMMENT 'Item needed',
    quantity INT DEFAULT 1 COMMENT 'Units needed',
    
    FOREIGN KEY (recipeid) REFERENCES crafting_recipes(recipeid) ON DELETE CASCADE,
    FOREIGN KEY (itemid) REFERENCES items_catalog(itemid) ON DELETE RESTRICT,
    KEY idx_recipeid (recipeid),
    KEY idx_itemid (itemid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Ingredient requirements for crafting recipes';

-- ============================================================================
-- TABLE: PRODUCTION_RECORDS
-- Purpose: Log of all production activities (audit trail)
-- ============================================================================
CREATE TABLE IF NOT EXISTS production_records (
    recordid BIGINT PRIMARY KEY AUTO_INCREMENT,
    playerid INT NOT NULL,
    chainid INT NOT NULL,
    
    -- Production Details
    quantity_produced INT,
    base_wage BIGINT COMMENT 'Wage before tax',
    tax_amount BIGINT COMMENT 'Tax paid',
    wage_received BIGINT COMMENT 'Wage after tax',
    
    -- Metadata
    production_started_at TIMESTAMP,
    produced_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes
    FOREIGN KEY (playerid) REFERENCES players(playerid) ON DELETE CASCADE,
    FOREIGN KEY (chainid) REFERENCES production_chains(chainid) ON DELETE CASCADE,
    KEY idx_playerid (playerid),
    KEY idx_chainid (chainid),
    KEY idx_produced_at (produced_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Audit trail of all production activities';

-- ============================================================================
-- TABLE: TRANSACTIONS (LEDGER)
-- Purpose: Complete audit trail of all money/item transfers
-- CRITICAL: This table is APPEND-ONLY. Never delete entries.
-- ============================================================================
CREATE TABLE IF NOT EXISTS transactions (
    transactionid BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT 'Unique transaction ID',
    
    -- Parties Involved
    actor_playerid INT COMMENT 'Player who initiated transaction',
    actor_businessid INT COMMENT 'Business involved (if any)',
    recipient_playerid INT COMMENT 'Player who received money/items',
    recipient_businessid INT COMMENT 'Business who received money/items',
    
    -- Transaction Details
    transaction_type VARCHAR(32) COMMENT 'sale, wage, tax, transfer, crafting, etc.',
    amount BIGINT DEFAULT 0 COMMENT 'Money amount (if money transaction)',
    itemid INT COMMENT 'Item ID (if item transaction)',
    quantity INT DEFAULT 0 COMMENT 'Quantity of items',
    
    -- Financial Info
    unit_price INT COMMENT 'Price per unit (for market reference)',
    total_value BIGINT COMMENT 'Total transaction value',
    tax_collected BIGINT DEFAULT 0 COMMENT 'Tax on transaction',
    
    -- Description & Reason
    description VARCHAR(256),
    reference_id INT COMMENT 'e.g., listing_id for market sale',
    
    -- Transaction Status
    status ENUM('success', 'failed', 'reversed', 'pending') DEFAULT 'success',
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reversed_at TIMESTAMP NULL,
    
    -- Indexes (for auditing & analytics)
    KEY idx_actor_playerid (actor_playerid),
    KEY idx_recipient_playerid (recipient_playerid),
    KEY idx_actor_businessid (actor_businessid),
    KEY idx_recipient_businessid (recipient_businessid),
    KEY idx_transaction_type (transaction_type),
    KEY idx_created_at (created_at),
    KEY idx_status (status),
    
    -- Foreign Keys (soft references, non-blocking)
    KEY idx_itemid (itemid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Transaction ledger - APPEND ONLY audit trail of all economy activity';

-- ============================================================================
-- TABLE: MARKET_LISTINGS
-- Purpose: Player-created marketplace listings
-- ============================================================================
CREATE TABLE IF NOT EXISTS market_listings (
    listingid INT PRIMARY KEY AUTO_INCREMENT,
    sellerid INT NOT NULL COMMENT 'Player selling items',
    itemid INT NOT NULL COMMENT 'Item for sale',
    
    -- Listing Details
    quantity INT COMMENT 'Number of items for sale',
    price_per_unit FLOAT COMMENT 'Price per item',
    total_price BIGINT COMMENT 'Total asking price',
    
    -- Listing Status
    status ENUM('active', 'sold', 'expired', 'cancelled') DEFAULT 'active',
    
    -- Metadata
    listed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL COMMENT 'When listing expires (e.g., 7 days)',
    sold_at TIMESTAMP NULL,
    
    -- Indexes
    FOREIGN KEY (sellerid) REFERENCES players(playerid) ON DELETE CASCADE,
    FOREIGN KEY (itemid) REFERENCES items_catalog(itemid) ON DELETE RESTRICT,
    KEY idx_sellerid (sellerid),
    KEY idx_itemid (itemid),
    KEY idx_status (status),
    KEY idx_listed_at (listed_at),
    KEY idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Player market listings for buying/selling';

-- ============================================================================
-- TABLE: MARKET_PRICES
-- Purpose: Historical price tracking for dynamic pricing algorithm
-- ============================================================================
CREATE TABLE IF NOT EXISTS market_prices (
    priceid INT PRIMARY KEY AUTO_INCREMENT,
    itemid INT NOT NULL,
    
    -- Price Data
    price_value FLOAT,
    supply_count INT COMMENT 'Number of items in listings',
    demand_count INT COMMENT 'Estimated demand',
    
    -- Calculation Method
    price_source VARCHAR(32) COMMENT 'base, supply_demand, auction, etc.',
    
    -- Metadata
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes
    FOREIGN KEY (itemid) REFERENCES items_catalog(itemid) ON DELETE CASCADE,
    KEY idx_itemid (itemid),
    KEY idx_recorded_at (recorded_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Historical market prices for tracking and analytics';

-- ============================================================================
-- TABLE: GOVERNMENT_TREASURY
-- Purpose: Government account and taxation records
-- ============================================================================
CREATE TABLE IF NOT EXISTS government_treasury (
    treasuryid INT PRIMARY KEY AUTO_INCREMENT DEFAULT 1 COMMENT 'Single row per server',
    
    -- Treasury Balance
    tax_collected BIGINT DEFAULT 0 COMMENT 'Total taxes collected (all time)',
    total_distributed BIGINT DEFAULT 0 COMMENT 'Total funds distributed',
    current_balance BIGINT DEFAULT 0 COMMENT 'Current treasury balance',
    
    -- Metadata
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Government treasury and taxation account (single row)';

-- ============================================================================
-- TABLE: TAX_RECORDS
-- Purpose: Detailed tax transaction history
-- ============================================================================
CREATE TABLE IF NOT EXISTS tax_records (
    taxid INT PRIMARY KEY AUTO_INCREMENT,
    
    -- Payer
    playerid INT COMMENT 'Player who paid tax',
    businessid INT COMMENT 'Business who paid tax',
    
    -- Tax Details
    tax_amount BIGINT,
    tax_rate FLOAT COMMENT 'Tax percentage applied',
    tax_type VARCHAR(32) COMMENT 'income, sales, property, transaction, etc.',
    tax_reason VARCHAR(256),
    
    -- Metadata
    paid_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tax_period VARCHAR(32) COMMENT 'daily, weekly, monthly, or "transaction"',
    
    -- Indexes
    KEY idx_playerid (playerid),
    KEY idx_businessid (businessid),
    KEY idx_tax_type (tax_type),
    KEY idx_paid_at (paid_at),
    FOREIGN KEY (playerid) REFERENCES players(playerid) ON DELETE SET NULL,
    FOREIGN KEY (businessid) REFERENCES businesses(businessid) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Tax payment history and records';

-- ============================================================================
-- TABLE: WAREHOUSE_STORAGE
-- Purpose: Items stored in warehouses (separate from business inventory)
-- ============================================================================
CREATE TABLE IF NOT EXISTS warehouse_storage (
    storageid INT PRIMARY KEY AUTO_INCREMENT,
    warehouseid INT NOT NULL COMMENT 'Warehouse business ID',
    itemid INT NOT NULL,
    quantity INT DEFAULT 0,
    
    -- Cost
    storage_fee_per_unit INT COMMENT 'Maintenance cost per unit per day',
    
    -- Metadata
    stored_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    retrieved_at TIMESTAMP NULL,
    
    -- Indexes
    FOREIGN KEY (warehouseid) REFERENCES businesses(businessid) ON DELETE CASCADE,
    FOREIGN KEY (itemid) REFERENCES items_catalog(itemid) ON DELETE RESTRICT,
    KEY idx_warehouseid (warehouseid),
    KEY idx_itemid (itemid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Warehouse storage management';

-- ============================================================================
-- TABLE: TRANSPORTATION_ORDERS
-- Purpose: Logistics and goods transportation tracking
-- ============================================================================
CREATE TABLE IF NOT EXISTS transportation_orders (
    orderid INT PRIMARY KEY AUTO_INCREMENT,
    
    -- Shipment Details
    shipper_playerid INT COMMENT 'Player paying for shipment',
    from_businessid INT COMMENT 'Pickup location',
    to_businessid INT COMMENT 'Delivery location',
    itemid INT NOT NULL,
    quantity INT,
    
    -- Financial
    transportation_cost BIGINT,
    
    -- Status
    order_status ENUM('pending', 'in_transit', 'delivered', 'failed', 'cancelled') DEFAULT 'pending',
    
    -- Metadata
    ordered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP NULL,
    delivered_at TIMESTAMP NULL,
    estimated_delivery TIMESTAMP NULL,
    
    -- Indexes
    FOREIGN KEY (shipper_playerid) REFERENCES players(playerid) ON DELETE SET NULL,
    FOREIGN KEY (from_businessid) REFERENCES businesses(businessid) ON DELETE SET NULL,
    FOREIGN KEY (to_businessid) REFERENCES businesses(businessid) ON DELETE SET NULL,
    FOREIGN KEY (itemid) REFERENCES items_catalog(itemid) ON DELETE RESTRICT,
    KEY idx_shipper_playerid (shipper_playerid),
    KEY idx_order_status (order_status),
    KEY idx_ordered_at (ordered_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Transportation and logistics orders';

-- ============================================================================
-- TABLE: ECONOMY_STATISTICS
-- Purpose: Periodic snapshots for analytics and monitoring
-- ============================================================================
CREATE TABLE IF NOT EXISTS economy_statistics (
    statsid INT PRIMARY KEY AUTO_INCREMENT,
    
    -- Aggregate Data
    total_players_active INT,
    total_money_in_circulation BIGINT,
    government_balance BIGINT,
    average_player_wealth BIGINT,
    
    -- Market Data
    total_listings_active INT,
    total_trades_today BIGINT,
    inflation_rate FLOAT COMMENT 'Month-over-month price change',
    
    -- Metadata
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes
    KEY idx_calculated_at (calculated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Economy statistics and analytics snapshots';

-- ============================================================================
-- TABLE: AUDIT_LOG
-- Purpose: System-level audit trail for admin actions and errors
-- ============================================================================
CREATE TABLE IF NOT EXISTS audit_log (
    auditid BIGINT PRIMARY KEY AUTO_INCREMENT,
    
    -- Action
    admin_playerid INT,
    action_type VARCHAR(64) COMMENT 'player_ban, money_wipe, transaction_reverse, etc.',
    target_playerid INT COMMENT 'Player affected by action',
    target_businessid INT COMMENT 'Business affected (if any)',
    
    -- Details
    action_description TEXT,
    parameters_json JSON COMMENT 'Any relevant parameters',
    
    -- Metadata
    action_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes
    KEY idx_admin_playerid (admin_playerid),
    KEY idx_action_type (action_type),
    KEY idx_action_at (action_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Admin and system action audit log';

-- ============================================================================
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- ============================================================================

-- Composite indexes for common queries
CREATE INDEX idx_player_economy ON players(cash, bank) COMMENT 'For wealth queries';
CREATE INDEX idx_business_economy ON businesses(ownerid, cash, business_type) COMMENT 'For business queries';
CREATE INDEX idx_inventory_lookup ON player_inventory(playerid, itemid) COMMENT 'For inventory lookups';
CREATE INDEX idx_transaction_search ON transactions(actor_playerid, created_at) COMMENT 'For player history';
CREATE INDEX idx_market_active ON market_listings(itemid, status, listed_at) COMMENT 'For active market listings';
CREATE INDEX idx_production_track ON production_records(playerid, produced_at) COMMENT 'For production history';

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- View: Player wealth (cash + bank)
CREATE OR REPLACE VIEW vw_player_wealth AS
SELECT 
    playerid,
    username,
    (cash + bank) AS total_wealth,
    cash,
    bank,
    account_status
FROM players;

-- View: Business summary
CREATE OR REPLACE VIEW vw_business_summary AS
SELECT 
    b.businessid,
    b.business_name,
    b.business_type,
    p.username AS owner_name,
    b.cash,
    b.inventory_value,
    (b.cash + b.inventory_value) AS total_assets,
    b.is_active,
    b.established_at
FROM businesses b
JOIN players p ON b.ownerid = p.playerid;

-- View: Active market listings with pricing
CREATE OR REPLACE VIEW vw_market_active_listings AS
SELECT 
    ml.listingid,
    p.username AS seller_name,
    ic.item_name,
    ml.quantity,
    ml.price_per_unit,
    ml.total_price,
    ic.market_price AS current_market_price,
    ml.listed_at,
    ml.expires_at
FROM market_listings ml
JOIN players p ON ml.sellerid = p.playerid
JOIN items_catalog ic ON ml.itemid = ic.itemid
WHERE ml.status = 'active'
AND (ml.expires_at IS NULL OR ml.expires_at > NOW());

-- View: Recent transactions for audit
CREATE OR REPLACE VIEW vw_recent_transactions AS
SELECT 
    transactionid,
    COALESCE(ap.username, ab.business_name) AS actor,
    transaction_type,
    amount,
    itemid,
    quantity,
    tax_collected,
    status,
    created_at
FROM transactions t
LEFT JOIN players ap ON t.actor_playerid = ap.playerid
LEFT JOIN businesses ab ON t.actor_businessid = ab.businessid
ORDER BY created_at DESC
LIMIT 1000;

-- ============================================================================
-- SAMPLE DATA (Remove or modify for production)
-- ============================================================================

-- Insert base items
INSERT INTO items_catalog (item_name, item_type, base_price, market_price, weight, is_stackable) VALUES
('Fish', 'raw', 8.00, 8.00, 0.5, TRUE),
('Ore', 'raw', 10.00, 10.00, 2.0, TRUE),
('Cotton', 'raw', 5.00, 5.00, 0.3, TRUE),
('Iron', 'produced', 15.00, 15.00, 1.5, TRUE),
('Steel', 'produced', 25.00, 25.00, 1.5, TRUE),
('Weapon', 'weapon', 500.00, 500.00, 3.0, FALSE),
('Cloth', 'produced', 12.00, 12.00, 0.5, TRUE),
('Food', 'consumable', 20.00, 20.00, 0.2, TRUE)
ON DUPLICATE KEY UPDATE market_price=VALUES(market_price);

-- Insert production chains
INSERT INTO production_chains (chain_name, output_itemid, output_quantity, base_wage, production_time_seconds, required_skill_type, required_skill_level) VALUES
('Fishing', 1, 1, 5.00, 10, 'farming', 0),
('Mining Ore', 2, 1, 7.50, 15, 'mining', 0),
('Cotton Picking', 3, 1, 3.00, 8, 'farming', 0),
('Iron Smelting', 4, 2, 20.00, 30, 'crafting', 10),
('Steel Forging', 5, 1, 40.00, 45, 'crafting', 30)
ON DUPLICATE KEY UPDATE base_wage=VALUES(base_wage);

-- Initialize government treasury
INSERT INTO government_treasury (treasuryid, tax_collected, total_distributed, current_balance) 
VALUES (1, 0, 0, 10000)
ON DUPLICATE KEY UPDATE current_balance=VALUES(current_balance);

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
