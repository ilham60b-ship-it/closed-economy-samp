# Closed Economy System Architecture

**Version:** 1.0  
**Last Updated:** July 2026  
**Status:** Design Phase

---

## Table of Contents

1. [Vision & Goals](#vision--goals)
2. [Core Principles](#core-principles)
3. [System Overview](#system-overview)
4. [Architecture Layers](#architecture-layers)
5. [Production Chains](#production-chains)
6. [Database Design](#database-design)
7. [Module Specifications](#module-specifications)
8. [Money Flow & Transactions](#money-flow--transactions)
9. [State Management & Persistence](#state-management--persistence)
10. [Integration Points](#integration-points)
11. [Performance & Scalability](#performance--scalability)
12. [Development Guidelines](#development-guidelines)

---

## Vision & Goals

### Mission
Replace traditional SA-MP economies (unlimited money generation) with a **closed-loop, player-driven economy** where:
- Money is finite and circulates between industries, businesses, and players
- Every profession depends on another, creating interdependencies
- Player interaction is encouraged through supply/demand dynamics
- Inflation is naturally controlled by the system's design

### Primary Goals
1. **Realism** — Economic behavior mirrors real-world supply chains
2. **Player Agency** — Players can influence economy through decisions
3. **Scalability** — System grows with server population without redesign
4. **Modularity** — Any industry/chain can be added/removed independently
5. **Auditability** — All transactions logged for admin oversight
6. **Performance** — Handles 500+ concurrent players without lag

---

## Core Principles

### 1. **Closed-Loop Currency**
- No money is created by NPCs; all money originates from players
- Total money in circulation is fixed per server reset
- Money only changes hands through production, trade, and taxation

### 2. **Production-Based Value**
- Players earn money by producing goods/services others need
- No "infinite" jobs; wages are tied to actual production output
- Scarcity of goods drives price and demand

### 3. **Atomic Transactions**
- Every money/item transfer is atomic (all-or-nothing)
- Failed transactions rollback completely
- All transactions are logged with timestamp, actor, and reason

### 4. **Modular Industry Design**
- Industries are self-contained modules with clear inputs/outputs
- New industries can be added without modifying core systems
- Each industry defines its own production recipes and economic role

### 5. **Player Autonomy**
- Players own businesses and make production decisions
- Market prices are emergent (supply/demand, not hard-coded)
- Government can only collect taxes, not dictate economy

### 6. **Data Integrity**
- MySQL is source of truth; server memory is cache only
- Critical operations use transactions to prevent corruption
- Audit trail enables rollback of admin/player errors

---

## System Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SA-MP Game Server                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           Integration Layer (Commands/Events)       │   │
│  │  ┌─────────────┬──────────────┬─────────────────┐   │   │
│  │  │  Commands   │ Player Events │ UI/Dialogs      │   │   │
│  │  └─────────────┴──────────────┴─────────────────┘   │   │
│  └────────────────────┬─────────────────────────────────┘   │
│                       │                                      │
│  ┌────────────────────▼─────────────────────────────────┐   │
│  │        Business Logic Layer (Economy)               │   │
│  │  ┌──────────┬──────────┬──────────┬────────────┐    │   │
│  │  │Production│Logistics │  Market  │ Taxation   │    │   │
│  │  ├──────────┼──────────┼──────────┼────────────┤    │   │
│  │  │Inventory │Crafting  │ Trading  │Government  │    │   │
│  │  └──────────┴──────────┴──────────┴────────────┘    │   │
│  └────────────────────┬─────────────────────────────────┘   │
│                       │                                      │
│  ┌────────────────────▼─────────────────────────────────┐   │
│  │    Core Services Layer (Transactions/State)         │   │
│  │  ┌────────────────┬────────────────────────────┐    │   │
│  │  │ Transaction    │ State Cache & Synchronizer│    │   │
│  │  │ Engine         │ (Memory ↔ MySQL Bridge)   │    │   │
│  │  └────────────────┴────────────────────────────┘    │   │
│  └────────────────────┬─────────────────────────────────┘   │
│                       │                                      │
│  ┌────────────────────▼─────────────────────────────────┐   │
│  │         Data Access Layer (DAO Pattern)             │   │
│  │  ┌────────────┬──────────────┬──────────────────┐   │   │
│  │  │Player DAO  │ Business DAO │ Transaction DAO  │   │   │
│  │  └────────────┴──────────────┴──────────────────┘   │   │
│  └────────────────────┬─────────────────────────────────┘   │
│                       │                                      │
└───────────────────────┼──────────────────────────────────────┘
                        │
        ┌───────────────▼───────────────┐
        │   MySQL Database              │
        │  (Source of Truth)            │
        │  ├── Player Accounts          │
        │  ├── Businesses/Industries    │
        │  ├── Inventory                │
        │  ├── Transactions (Ledger)    │
        │  └── Production Chains        │
        └───────────────────────────────┘
```

### Data Flow Diagram

```
Player Action (e.g., "Sell 10 fish")
  ↓
Command Handler (validates input)
  ↓
Business Logic Layer (calculates tax, fees, new balances)
  ↓
Transaction Engine (builds atomic transaction)
  ↓
DAO Layer (writes to MySQL)
  ↓
State Cache (updates server memory)
  ↓
Response to Player (confirms success/failure)
  ↓
Scheduled Sync (periodically verifies cache ↔ DB consistency)
```

---

## Architecture Layers

### 1. Integration Layer (Commands & Events)

**Purpose:** Convert player actions into system requests

**Responsibilities:**
- Parse player commands (`/sell`, `/produce`, `/market`)
- Validate user input and permissions
- Trigger appropriate business logic
- Format responses back to player

**Key Components:**
- `GameCommands.pwn` — Command definitions
- `GameEvents.pwn` — Login/logout, death, etc.
- `UISystem.pwn` — Dialog boxes, menus

**Example Flow:**
```
Player types: /sell fish 10
  → GameCommands.pwn parses command
  → Validates player has 10 fish
  → Calls MarketModule::SellItem(playerid, "fish", 10)
  → Returns success/failure to player dialog
```

---

### 2. Business Logic Layer (Economy Modules)

**Purpose:** Implement industry-specific rules and calculations

**Core Modules:**

#### A. **Production Module** (`ProductionModule.pwn`)
- Manages farming, fishing, mining, etc.
- Tracks production output rates
- Applies skill multipliers
- Calculates wages from production

**Functions:**
```
ProduceGoods(playerid, chainid, amount)
GetProductionOutput(playerid, chainid, amount)
CalculateWage(playerid, baseAmount, skillLevel)
```

#### B. **Manufacturing Module** (`ManufacturingModule.pwn`)
- Converts raw materials → finished goods
- Requires recipe definitions
- Tracks factory inventory and efficiency
- Calculates production costs

**Functions:**
```
CraftItem(playerid, recipeid, quantity)
GetRecipeRequirements(recipeid)
CalculateProductionCost(recipeid, quantity)
```

#### C. **Logistics Module** (`LogisticsModule.pwn`)
- Manages warehouse inventory
- Handles transport between locations
- Tracks delivery status
- Applies transport fees

**Functions:**
```
TransportGoods(playerid, fromLocation, toLocation, itemid, quantity)
StoreInventory(location, itemid, quantity)
RetrieveInventory(location, itemid, quantity)
```

#### D. **Market Module** (`MarketModule.pwn`)
- Manages buying/selling between players and businesses
- Tracks supply/demand for dynamic pricing
- Handles market listing creation
- Processes trades

**Functions:**
```
ListItem(playerid, itemid, quantity, price)
BuyItem(playerid, itemid, quantity)
SellItem(playerid, itemid, quantity)
GetMarketPrice(itemid)
```

#### E. **Taxation Module** (`TaxationModule.pwn`)
- Collects taxes from transactions
- Manages government budget
- Distributes government payouts
- Audits tax compliance

**Functions:**
```
CalculateTax(transactionAmount, taxRate)
CollectTax(playerid, amount, reason)
DistributeGovernmentPayment(playerid, amount)
GetPlayerTaxLiability(playerid)
```

#### F. **Inventory Module** (`InventoryModule.pwn`)
- Manages player and business inventories
- Applies weight/capacity limits
- Handles item stacking
- Validates inventory operations

**Functions:**
```
AddItem(ownerid, itemid, quantity)
RemoveItem(ownerid, itemid, quantity)
GetItemCount(ownerid, itemid)
GetInventoryValue(ownerid)
```

---

### 3. Core Services Layer (Transaction Engine & State)

**Purpose:** Ensure data consistency and handle persistence

#### A. **Transaction Engine** (`TransactionEngine.pwn`)
- Builds multi-step transactions (money + inventory changes)
- Validates before commit
- Logs all operations
- Handles rollback on failure

**Key Concept: Atomic Transactions**
```
Example: Player sells fish to market
  Transaction {
    1. Validate: Player has 10 fish
    2. Calculate: Tax (5%), Seller receives: 95 of 100
    3. Debit: Player inventory (-10 fish)
    4. Credit: Player cash (+95)
    5. Debit: Market cash (-95)
    6. Credit: Market inventory (+10 fish)
    7. Log: Transaction record (timestamp, actor, amount, reason)
    
    If ANY step fails → ROLLBACK ALL steps
    If ALL steps succeed → COMMIT ALL steps
  }
```

**Functions:**
```
BeginTransaction()
AddStep(stepType, playerid, amount, itemid, description)
ValidateTransaction()
CommitTransaction()
RollbackTransaction()
LogTransaction(txid, actor, description, amount)
```

#### B. **State Cache & Synchronizer** (`StateSynchronizer.pwn`)
- Maintains player cash/inventory in server memory
- Periodically syncs with MySQL
- Handles cache invalidation
- Detects and resolves inconsistencies

**Design Decision: Why Cache?**
- SA-MP Pawn → MySQL queries are slow (~5-10ms per query)
- Constant lookups would create lag
- Cache allows instant reads; periodic DB writes
- Synchronizer verifies cache accuracy every 30 seconds

**Functions:**
```
CachePlayer(playerid)
UpdateCache(playerid, fieldname, value)
SyncCacheToDatabase()
VerifyCacheIntegrity()
InvalidateCache(playerid)
```

---

### 4. Data Access Layer (DAO Pattern)

**Purpose:** Encapsulate all database operations

**Pattern: Data Access Objects**
- One DAO per major entity (Player, Business, Transaction)
- All queries go through DAOs
- Prevents SQL injection
- Centralizes query logic

#### A. **PlayerDAO** (`DAO/PlayerDAO.pwn`)
```
CreatePlayer(playerid)
LoadPlayer(playerid)
SavePlayer(playerid)
UpdateBalance(playerid, newBalance)
DeletePlayer(playerid)
```

#### B. **BusinessDAO** (`DAO/BusinessDAO.pwn`)
```
CreateBusiness(ownerid, businessName, type)
LoadBusiness(businessid)
UpdateInventory(businessid, itemid, quantity)
UpdateBalance(businessid, newBalance)
```

#### C. **TransactionDAO** (`DAO/TransactionDAO.pwn`)
```
LogTransaction(actor, amount, itemid, description)
GetTransactionHistory(playerid, limit)
ReverseTransaction(txid)
GetAuditTrail(playerid, startDate, endDate)
```

#### D. **ItemDAO** (`DAO/ItemDAO.pwn`)
```
GetItemPrice(itemid)
UpdateItemPrice(itemid, newPrice)
GetItemStats(itemid)
GetAllItems()
```

---

## Production Chains

### Chain Structure

Each production chain follows this pattern:

```
Raw Material → Production → Processing → Distribution → Retail → Consumer
    ↓            ↓             ↓            ↓            ↓         ↓
  Farmer    Producer       Manufacturer  Warehouse    Market    Player
  (earns)   (earns)        (earns)       (earns)      (earns)   (consumes)
```

### Example Chain: Farming → Food Distribution

```
┌─────────────────────────────────────────────────────────────┐
│                    FARMING CHAIN                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ Stage 1: PRODUCTION (Farmer)                               │
│   Job: /produce fish                                        │
│   Rate: 1 action = 1 fish                                   │
│   Wage: $5 per fish (after tax)                             │
│   Skill affects: Speed & output quantity                    │
│                                                              │
│ Stage 2: MARKET SALE (Farmer → Market)                     │
│   Farmer lists: 100 fish @ $8 each                          │
│   Market Tax: 5% (0.40 per fish)                            │
│   Farmer receives: $7.60 per fish                           │
│   Market profit: $0.40 per fish                             │
│                                                              │
│ Stage 3: RETAIL (Market → Players)                         │
│   Market sells: 100 fish @ $10 each                         │
│   Market profit: $2 per fish × 100 = $200                  │
│   Government Tax: 10% of market profit = $20               │
│   Market net: $180                                          │
│                                                              │
│ Stage 4: CONSUMPTION (Player)                              │
│   Player buys: 10 fish @ $10 each = $100                   │
│   Player uses for: Cooking, selling to NPCs, etc.          │
│                                                              │
│ Money Flow:                                                  │
│   Player -$100 → Market                                     │
│   Market -$76 → Farmer (100 × $0.76)                       │
│   Farmer +$760 (after 5% tax on sale price)                │
│   Government +$20 (5% of fish sale, 10% of market profit)  │
│   Market +$180 (profit after taxes)                         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Predefined Chains (MVP)

We'll implement these 5 chains in Phase 1:

| # | Chain | Raw | Process | Distributor | Retail | Player Use |
|---|-------|-----|---------|-------------|--------|-----------|
| 1 | **Farming** | Seeds | Fish/Crops | Market | Player | Cooking, Resale |
| 2 | **Mining** | Ore | Refined | Smelter | Blacksmith | Weapons, Tools |
| 3 | **Manufacturing** | Parts | Vehicles | Showroom | Player | Transportation |
| 4 | **Textiles** | Cotton | Fabric | Clothing Store | Player | Cosmetics |
| 5 | **Logistics** | Any Item | Transport | Warehouse | Market | Distribution |

---

## Database Design

### Schema Overview

```sql
-- PLAYER ACCOUNTS
CREATE TABLE players (
    playerid INT PRIMARY KEY,
    username VARCHAR(24) NOT NULL UNIQUE,
    cash BIGINT DEFAULT 0,
    bank BIGINT DEFAULT 0,
    skill_farming INT DEFAULT 0,
    skill_mining INT DEFAULT 0,
    skill_crafting INT DEFAULT 0,
    tax_rate FLOAT DEFAULT 0.05,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- BUSINESSES
CREATE TABLE businesses (
    businessid INT PRIMARY KEY AUTO_INCREMENT,
    ownerid INT NOT NULL,
    business_name VARCHAR(64),
    business_type ENUM('farm', 'factory', 'market', 'warehouse', 'bank'),
    cash BIGINT DEFAULT 0,
    inventory_value BIGINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ownerid) REFERENCES players(playerid) ON DELETE CASCADE
);

-- PLAYER INVENTORY
CREATE TABLE player_inventory (
    inventoryid INT PRIMARY KEY AUTO_INCREMENT,
    playerid INT NOT NULL,
    itemid INT NOT NULL,
    quantity INT DEFAULT 0,
    UNIQUE KEY (playerid, itemid),
    FOREIGN KEY (playerid) REFERENCES players(playerid) ON DELETE CASCADE
);

-- BUSINESS INVENTORY
CREATE TABLE business_inventory (
    inventoryid INT PRIMARY KEY AUTO_INCREMENT,
    businessid INT NOT NULL,
    itemid INT NOT NULL,
    quantity INT DEFAULT 0,
    UNIQUE KEY (businessid, itemid),
    FOREIGN KEY (businessid) REFERENCES businesses(businessid) ON DELETE CASCADE
);

-- PRODUCTION CHAINS (Configuration)
CREATE TABLE production_chains (
    chainid INT PRIMARY KEY AUTO_INCREMENT,
    chain_name VARCHAR(64) NOT NULL,
    input_itemid INT,
    output_itemid INT,
    conversion_rate FLOAT DEFAULT 1.0,
    base_wage FLOAT DEFAULT 0,
    skill_type VARCHAR(32)
);

-- ITEMS CATALOG
CREATE TABLE items (
    itemid INT PRIMARY KEY AUTO_INCREMENT,
    item_name VARCHAR(64) NOT NULL,
    item_type VARCHAR(32),
    base_price FLOAT DEFAULT 0,
    market_price FLOAT DEFAULT 0,
    weight FLOAT DEFAULT 0,
    stackable BOOLEAN DEFAULT TRUE
);

-- TRANSACTION LEDGER (Audit Trail)
CREATE TABLE transactions (
    transactionid BIGINT PRIMARY KEY AUTO_INCREMENT,
    actor_playerid INT,
    actor_businessid INT,
    transaction_type VARCHAR(32),
    amount BIGINT,
    itemid INT,
    quantity INT,
    reason VARCHAR(256),
    status ENUM('success', 'failed', 'reversed') DEFAULT 'success',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY (actor_playerid),
    KEY (created_at)
);

-- MARKET LISTINGS
CREATE TABLE market_listings (
    listingid INT PRIMARY KEY AUTO_INCREMENT,
    sellerid INT NOT NULL,
    itemid INT NOT NULL,
    quantity INT,
    price_per_unit FLOAT,
    listed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    status ENUM('active', 'sold', 'expired', 'cancelled') DEFAULT 'active',
    FOREIGN KEY (sellerid) REFERENCES players(playerid)
);

-- PRODUCTION RECORDS
CREATE TABLE production_records (
    recordid INT PRIMARY KEY AUTO_INCREMENT,
    playerid INT NOT NULL,
    chainid INT NOT NULL,
    quantity_produced INT,
    wage_earned BIGINT,
    produced_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (playerid) REFERENCES players(playerid),
    FOREIGN KEY (chainid) REFERENCES production_chains(chainid)
);

-- GOVERNMENT TREASURY
CREATE TABLE government_treasury (
    treasuryid INT PRIMARY KEY AUTO_INCREMENT,
    tax_collected BIGINT DEFAULT 0,
    total_distributed BIGINT DEFAULT 0,
    balance BIGINT DEFAULT 0,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- TAX RECORDS
CREATE TABLE tax_records (
    taxid INT PRIMARY KEY AUTO_INCREMENT,
    playerid INT,
    businessid INT,
    tax_amount BIGINT,
    tax_reason VARCHAR(256),
    paid_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (playerid) REFERENCES players(playerid),
    FOREIGN KEY (businessid) REFERENCES businesses(businessid)
);
```

### Key Design Decisions

1. **Ledger-based Audit Trail**
   - Every transaction (even failed ones) is logged
   - Enables rollback, investigation, and statistics
   - Immutable after creation

2. **Normalized Inventory**
   - Player inventory and business inventory in separate tables
   - Avoids querying entire business when checking one item
   - Uses unique constraints to prevent duplicate items

3. **Separation of Concerns**
   - Players have personal accounts (cash + bank)
   - Businesses have separate accounts (independent of owners)
   - Enables complex business structures

4. **Price Tracking**
   - `base_price` — Server-defined starting price
   - `market_price` — Dynamic price (updated by supply/demand algorithm)
   - Allows rollback to base if economy becomes unstable

5. **Transaction Status Tracking**
   - Records success/failure/reversal of all ops
   - Admins can audit and reverse transactions
   - Prevents loss of money due to server crashes

---

## Module Specifications

### Module 1: Core Transaction Engine

**File:** `src/core/TransactionEngine.pwn`

**Purpose:** Atomic, auditable money/item transfers

**Public Functions:**

```pawn
/**
 * BEGIN A NEW TRANSACTION
 * @return transactionid (unique ID for this transaction)
 */
public TransactionBegin() -> transactionid

/**
 * ADD A DEBIT STEP (remove money/items)
 * @param actor: Player ID or Business ID
 * @param amount: Money amount (if itemid = -1) or quantity
 * @param itemid: Item ID (or -1 for money operations)
 * @param description: Reason for debit (logged to database)
 */
public TransactionAddDebit(transactionid, actor, amount, itemid, description[])

/**
 * ADD A CREDIT STEP (add money/items)
 * @param actor: Player ID or Business ID
 * @param amount: Money amount (if itemid = -1) or quantity
 * @param itemid: Item ID (or -1 for money operations)
 */
public TransactionAddCredit(transactionid, actor, amount, itemid)

/**
 * VALIDATE TRANSACTION (checks all actors have sufficient funds)
 * @return true if valid, false if any step would fail
 */
public TransactionValidate(transactionid) -> bool

/**
 * COMMIT TRANSACTION (execute all steps atomically)
 * @return true if successful, false if any step failed (all rolled back)
 */
public TransactionCommit(transactionid) -> bool

/**
 * ROLLBACK TRANSACTION (undo without committing)
 */
public TransactionRollback(transactionid)

/**
 * GET TRANSACTION STATUS
 */
public TransactionGetStatus(transactionid) -> status
```

**Example Usage:**

```pawn
// Player sells 10 fish to market for $80
new txid = TransactionBegin();

// Step 1: Player loses 10 fish
TransactionAddDebit(txid, playerid, 10, ITEM_FISH, "Sold to market");

// Step 2: Market gains 10 fish
TransactionAddCredit(txid, businessid_market, 10, ITEM_FISH);

// Step 3: Calculate tax (5% of $80 = $4)
new tax = 80 * 0.05;

// Step 4: Player receives $76 ($80 - $4 tax)
TransactionAddCredit(txid, playerid, 76, -1); // -1 = money

// Step 5: Market spends $76
TransactionAddDebit(txid, businessid_market, 76, -1);

// Step 6: Government receives $4 tax
TransactionAddCredit(txid, GOVT_ACCOUNT, 4, -1);

// Validate and commit
if (TransactionValidate(txid)) {
    if (TransactionCommit(txid)) {
        SendClientMessage(playerid, GREEN, "Sold 10 fish for $76!");
    } else {
        SendClientMessage(playerid, RED, "Transaction failed!");
    }
}
```

---

### Module 2: Player DAO

**File:** `src/dao/PlayerDAO.pwn`

**Purpose:** All player account operations

```pawn
/**
 * LOAD PLAYER FROM DATABASE
 * Called on login; populates cache
 */
public PlayerDAO_Load(playerid) -> bool

/**
 * SAVE PLAYER TO DATABASE
 * Called periodically; persists cache
 */
public PlayerDAO_Save(playerid) -> bool

/**
 * UPDATE CASH BALANCE
 * @return true if successful
 */
public PlayerDAO_UpdateCash(playerid, newBalance) -> bool

/**
 * UPDATE BANK BALANCE
 */
public PlayerDAO_UpdateBank(playerid, newBalance) -> bool

/**
 * INCREMENT SKILL
 * @param skillType: "farming", "mining", "crafting"
 * @param amount: Points to add
 */
public PlayerDAO_AddSkill(playerid, skillType[], amount) -> bool

/**
 * GET PLAYER DATA FROM CACHE
 * @return true if player loaded, false if offline
 */
public PlayerDAO_GetCash(playerid) -> cash

public PlayerDAO_GetBank(playerid) -> bank

public PlayerDAO_GetSkill(playerid, skillType[]) -> skillLevel
```

---

### Module 3: Production Module

**File:** `src/economy/ProductionModule.pwn`

**Purpose:** Farming, mining, fishing, etc.

```pawn
/**
 * START PRODUCTION JOB
 * @param chainid: Which production chain (from database)
 * @param amount: How many units to produce
 * @return true if started
 */
public ProductionModule_Produce(playerid, chainid, amount) -> bool

/**
 * GET PRODUCTION OUTPUT
 * Accounts for player skill and chain conversion rate
 * @return Actual quantity produced
 */
public ProductionModule_GetOutput(playerid, chainid, baseAmount) -> actualAmount

/**
 * CALCULATE WAGE
 * @return Money earned after tax
 */
public ProductionModule_CalculateWage(playerid, baseAmount) -> wage

/**
 * GET CHAIN INFO
 * @return Chain name, input item, output item, etc.
 */
public ProductionModule_GetChainInfo(chainid, info[])
```

**Design: Skill Multiplier Example**

```
Base skill = 0%
Each skill point = 1% faster production + 0.5% more output

Farmer with Skill 50:
  - Produces 50% faster (can do 1.5 actions per minute instead of 1)
  - Each production gives 1.5 fish instead of 1 fish

Farmer with Skill 100 (max):
  - Produces 2x faster
  - Each production gives 2 fish instead of 1
  - Wage scales accordingly
```

---

### Module 4: Market Module

**File:** `src/economy/MarketModule.pwn`

**Purpose:** Trading between players/businesses

```pawn
/**
 * LIST ITEM FOR SALE
 * Creates market listing that other players can buy
 */
public MarketModule_ListItem(playerid, itemid, quantity, pricePerUnit) -> listingid

/**
 * BUY ITEM FROM MARKET
 * @param listingid: Which listing to buy from
 * @param quantity: How many to buy
 */
public MarketModule_BuyItem(playerid, listingid, quantity) -> bool

/**
 * SELL ITEM TO MARKET
 * Direct sale to business (e.g., farmer sells to market)
 */
public MarketModule_SellToBusiness(playerid, itemid, quantity, businessid) -> bool

/**
 * GET MARKET PRICE
 * Returns current market price (can fluctuate)
 */
public MarketModule_GetPrice(itemid) -> price

/**
 * UPDATE MARKET PRICE (Dynamic Pricing)
 * Called automatically based on supply/demand
 */
public MarketModule_UpdatePrices()
```

**Dynamic Pricing Algorithm:**

```
For each item:
  totalSupply = sum(market_listings.quantity for this item)
  totalDemand = estimated from transaction history
  
  if (totalSupply > totalDemand):
    priceAdjustment = -5% per week
  else if (totalDemand > totalSupply):
    priceAdjustment = +10% per week
  else:
    priceAdjustment = 0%
    
  newPrice = currentPrice * (1 + priceAdjustment)
  
  // Clamp to reasonable bounds
  if (newPrice < basePrice * 0.5):
    newPrice = basePrice * 0.5
  if (newPrice > basePrice * 2.0):
    newPrice = basePrice * 2.0
```

---

### Module 5: Taxation Module

**File:** `src/economy/TaxationModule.pwn`

**Purpose:** Government revenue and fund distribution

```pawn
/**
 * SET TAX RATE FOR PLAYER
 * @param taxRate: 0.0 to 0.99 (0% to 99%)
 */
public TaxationModule_SetTaxRate(playerid, taxRate) -> bool

/**
 * COLLECT TAX FROM TRANSACTION
 * Automatically deducted during transactions
 */
public TaxationModule_CollectTax(playerid, amount, reason[]) -> taxCollected

/**
 * GET GOVERNMENT BALANCE
 * Total taxes collected - total distributed
 */
public TaxationModule_GetBalance() -> balance

/**
 * DISTRIBUTE GOVERNMENT PAYMENT
 * Government pays money to player (e.g., subsidy, salary)
 */
public TaxationModule_DistributeFunds(playerid, amount, reason[]) -> bool

/**
 * GET PLAYER TAX LIABILITY
 * How much tax player owes (not yet paid)
 */
public TaxationModule_GetLiability(playerid) -> owed
```

**Tax Policy (Configurable):**

```
Transaction Tax:
  - 5% on item sales (both ways)
  - 5% on market profits
  - 10% on large transfers (>$1000)

Property Tax:
  - 2% of business value per game week

Income Tax:
  - Progressive: 0-10% based on player wealth
  - Higher earners pay more

Government Spending:
  - Can redistribute to players via subsidies
  - Must be auditable and logged
  - Cannot create new money
```

---

## Money Flow & Transactions

### End-to-End Example: Farmer Workflow

**Scenario:** Farmer produces 100 fish, sells to market, market resells to players

**Step 1: Production**
```
Player: /produce fish 100
  ↓ Database: Check farmer has 100 "Fishing" skill actions available
  ↓ Calculate: Skill 50 = 1.5 output per action = 150 fish produced
  ↓ Wage: 150 fish × $5 base = $750
  ↓ Tax: $750 × 5% = $37.50
  ↓ Result: Farmer gains 150 fish, $712.50 cash
       Government gains $37.50
```

**Step 2: Listing for Sale**
```
Farmer: /list fish 100 $8
  ↓ Create market listing: 100 fish @ $8 each = $800 total value
  ↓ Remove from farmer inventory: -100 fish (goes to "for sale" status)
  ↓ Database: Insert into market_listings
  ↓ Result: Listing created, waiting for buyer
```

**Step 3: Business Buys Wholesale**
```
Market Owner: /buy listing_id 100
  ↓ Transaction begins:
    Step 1: Check market has $800 cash → YES
    Step 2: Debit market: -$800 cash
    Step 3: Credit farmer: +$800 cash
    Step 4: Calculate tax: $800 × 5% = $40
    Step 5: Debit: Market -$40 (tax)
    Step 6: Credit: Government +$40
    Step 7: Farmer actual receives: $760 (after tax)
    Step 8: Market actual spends: $840 (purchase + tax)
  ↓ Transaction validates:
    - Market has $840? YES → Commit
  ↓ Inventory changes:
    - Farmer: -100 fish
    - Market: +100 fish
  ↓ Result: Fish transferred, taxes collected
```

**Step 4: Retail to Players**
```
Market Owner: /list fish 50 $10
  ↓ List 50 of 100 fish @ $10 each = $500 total value
  ↓ Result: Listing created in public market
  
Player arrives: /buy fish 10 $10
  ↓ Transaction begins:
    Step 1: Check player has $100? YES
    Step 2: Debit player: -$100 cash
    Step 3: Credit market: +$100 cash
    Step 4: Calculate tax: $100 × 5% = $5
    Step 5: Debit: Market -$5 (tax share)
    Step 6: Credit: Government +$5 (tax share)
    Step 7: Player inventory: +10 fish
    Step 8: Market inventory: -10 fish
  ↓ Result: Player buys 10 fish for $100
           Market receives $95
           Government receives $5
```

### Money Trail (Complete Flow)

```
Initial: Farmer has $0, Market has $1000, Government has $0

After Production:
  Farmer: $712.50 + 150 fish
  Government: $37.50

After Wholesale Purchase:
  Farmer: $1,472.50 (712.50 + 760 after tax)
  Market: $160 (1000 - 840)
  Government: $77.50 (37.50 + 40)
  
After Retail Sale (1 player, 10 fish):
  Player: $0 (started with $100 example money)
  Farmer: $1,472.50 (unchanged)
  Market: $255 (160 + 95 from sale)
  Government: $82.50 (77.50 + 5)
  
Total Circulating Money: $1472.50 + $255 + $82.50 = $1810
  (Increased from initial due to production creating value)
```

---

## State Management & Persistence

### Memory Cache Architecture

**Why Cache?**
- Direct DB queries on every action = 500+ players × 100 queries/second = bottleneck
- Cache = in-memory lookup (microseconds vs milliseconds)
- Periodically sync to DB ensures durability without constant I/O

**Cache Structure:**

```pawn
// Global cache for online players
new gPlayerCache[MAX_PLAYERS][PlayerCache];

enum PlayerCache {
    playerid,
    bool:loaded,
    cash,
    bank,
    skill_farming,
    skill_mining,
    skill_crafting,
    tax_rate,
    dirty, // Flag: needs DB sync
    lastSyncTime
};

// Business cache
new gBusinessCache[MAX_BUSINESSES][BusinessCache];

enum BusinessCache {
    businessid,
    ownerid,
    bool:loaded,
    cash,
    inventory_value,
    dirty,
    lastSyncTime
};
```

### Synchronization Strategy

```
┌─────────────────────────────────────────┐
│   Every Frame (OnGameModeExit or Timer) │
├─────────────────────────────────────────┤
│                                         │
│  For each online player:                │
│    IF (cache.dirty == true):            │
│      DB_SavePlayer(playerid)            │
│      cache.dirty = false                │
│                                         │
│  Every 30 seconds:                      │
│    Verify Cache Integrity()             │
│    - Spot-check random players          │
│    - Ensure cache ≈ database            │
│    - Log any discrepancies              │
│                                         │
└─────────────────────────────────────────┘
```

### Crash Recovery

**On Server Startup:**

```pawn
public OnGameModeInit() {
    // 1. Load all players from database (even if offline)
    LoadAllPlayersFromDatabase();
    
    // 2. Verify ledger integrity
    VerifyTransactionLedger();
    
    // 3. Detect incomplete transactions (crashed mid-op)
    RollbackIncompleteTransactions();
    
    // 4. Verify sums match (prevent money duplication)
    VerifyEconomyChecksum();
}
```

---

## Integration Points

### How to Add New Industries

**Step 1: Define Production Chain in Database**

```sql
INSERT INTO production_chains (chain_name, input_itemid, output_itemid, conversion_rate, base_wage, skill_type)
VALUES ('Mining Ore', ITEM_PICKAXE, ITEM_ORE, 1.0, 3.50, 'mining');
```

**Step 2: Extend ProductionModule**

```pawn
// In ProductionModule.pwn, add to switch statement:
if (chainid == CHAIN_MINING) {
    return 1; // Supported
}
```

**Step 3: Add to Command Handler**

```pawn
// /produce ore [amount]
if (!strcmp(cmd, "produce", true)) {
    if (player_job[playerid] != JOB_MINER) {
        return SendClientMessage(playerid, RED, "You're not a miner!");
    }
    ProductionModule_Produce(playerid, CHAIN_MINING, amount);
}
```

### How to Add New Markets/Sellers

**Step 1: Create Business**

```sql
INSERT INTO businesses (ownerid, business_name, business_type, cash)
VALUES (5, 'Joe's Fish Market', 'market', 10000);
```

**Step 2: Business Owner Lists Items**

```pawn
// /list fish 100 $8
MarketModule_ListItem(playerid, ITEM_FISH, 100, 800);
```

**Step 3: Players Buy Automatically**

```pawn
// Market listings appear in /market menu
// Players use /buy listing_id amount
MarketModule_BuyItem(playerid, listing_id, amount);
```

---

## Performance & Scalability

### Benchmarks (Target)

| Operation | Target Latency | Rationale |
|-----------|-----------------|-----------|
| Get Player Cash | < 1ms | In-memory lookup |
| List Item | < 50ms | Single DB insert |
| Buy Item | < 100ms | Multi-step transaction |
| Sync All Players | < 5s | Batch update, once per 30s |
| Update Market Prices | < 2s | Weekly recalculation |

### Scaling Strategies

**1. Database Optimization**
- Indexes on frequently queried columns (playerid, itemid, created_at)
- Partition transaction ledger by month (older months archived)
- Connection pooling (reuse connections, don't create new)

**2. Memory Optimization**
- Cache only online players (don't load offline into memory)
- Inventory stored as linked lists (not arrays for all 10k items)
- Business cache only loaded when accessed

**3. Query Batching**
- Batch multiple player syncs into one query
- Use multi-insert for transaction logging
- Defer non-critical writes to next sync cycle

**4. Horizontal Scaling (Future)**
- Separate read/write database instances
- Replicate ledger to analytics DB
- Cache layer (Redis) for hot data

### Expected Capacity

With proper optimization:
- **100-200 players** — Single DB connection sufficient
- **200-500 players** — Connection pooling recommended
- **500-1000+ players** — Read replicas, caching layer needed

---

## Development Guidelines

### Coding Standards

**1. Naming Conventions**

```pawn
// Functions
ModuleName_Action(parameters)
PlayerDAO_LoadPlayer(playerid)
MarketModule_BuyItem(playerid, listingid)

// Variables (camelCase for locals, snake_case for globals)
new transactionAmount;
new gPlayerCache[MAX_PLAYERS];

// Constants (UPPER_SNAKE_CASE)
#define MAX_PLAYERS 500
#define TAX_RATE 0.05
#define ITEM_FISH 1
```

**2. Documentation**

```pawn
/**
 * Brief description of function
 * 
 * Longer explanation if needed
 * 
 * @param paramName: Description
 * @return Description of return value
 */
public FunctionName(paramName) -> returnType {
    // Implementation
}
```

**3. Error Handling**

```pawn
// Always validate inputs
public DoSomething(playerid, amount) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) {
        print("ERROR: Invalid playerid");
        return false;
    }
    if (amount <= 0) {
        print("ERROR: Amount must be positive");
        return false;
    }
    // ... proceed
    return true;
}
```

### Testing Strategy

**1. Unit Tests (Inline Comments)**

```pawn
// TEST: Transaction validation
// Scenario: Player has $100, tries to spend $150
// Expected: Transaction fails, balance unchanged
public Test_TransactionValidation() {
    // ... test code
}
```

**2. Integration Tests**

```pawn
// Test complete workflow: Produce → List → Buy → Consume
// This covers end-to-end flow
```

**3. Manual Testing Checklist**

- [ ] Player production increases inventory
- [ ] Wage calculation accounts for skill
- [ ] Taxes are collected correctly
- [ ] Market listings appear in-game
- [ ] Buying transfers items and money
- [ ] Server restart doesn't lose data

### Version Control Workflow

```
main (stable releases)
  ↓
development (feature integration)
  ├── feature/production-system
  ├── feature/market-module
  ├── feature/taxation
  └── bugfix/transaction-validation
```

**Commit Message Format:**

```
[SYSTEM] Brief description

- Detailed change 1
- Detailed change 2

Issue: #123 (if applicable)
```

**Example:**

```
[ECONOMY] Implement transaction engine

- Add TransactionBegin/Commit/Rollback functions
- Implement atomic multi-step transactions
- Add transaction logging to database
- Fix money duplication bug in wholesale path

Closes #15
```

---

## Summary & Next Steps

### What This Document Defines

✅ **Architecture** — Layered design with clear responsibilities  
✅ **Database** — Normalized schema with audit trail  
✅ **Production Chains** — How value flows through economy  
✅ **Modules** — Specific systems to implement  
✅ **Money Flow** — Example transactions and edge cases  
✅ **Performance** — Caching, synchronization, scaling  
✅ **Development** — Standards and testing  

### Next Phase: Implementation

**Phase 1 (Core)** — 2 weeks
1. Database schema + MySQL setup
2. Transaction Engine
3. Player DAO + State Synchronizer
4. ProductionModule + Market Module

**Phase 2 (Features)** — 2 weeks
5. TaxationModule
6. 5 production chains
7. Dynamic pricing
8. Inventory management

**Phase 3 (Polish)** — 1 week
9. Admin commands
10. Balance tuning
11. Performance optimization
12. Documentation + examples

---

**Document Version:** 1.0  
**Last Updated:** July 2026  
**Next Review:** After Phase 1 implementation
