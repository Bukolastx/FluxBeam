# FluxBeam 🌐

**Streaming Micropayments Across the Stacks Continuum**

FluxBeam enables real-time, per-second micropayments and flexible subscription models using smart contracts on the Stacks blockchain. Perfect for time-based access to APIs, streaming content, SaaS services, and remote work billing.

## Features

- **Real-time Micropayments**: Pay per second of service usage
- **Subscription Models**: 🆕 Recurring payments with tiered pricing structures
- **Auto-Renewal**: 🆕 Automatic subscription renewals with grace periods
- **Tiered Pricing**: 🆕 Multiple subscription tiers per service with custom features
- **Batch Payment Processing**: Process multiple sessions in a single transaction to reduce costs
- **Smart Contract Automation**: Automated payment release and refunds
- **Service Registration**: Providers can register services with custom rates
- **Balance Management**: Deposit, withdraw, and track usage in real-time
- **Session Control**: Start/stop sessions with automatic cost calculation
- **Secure Payments**: Built on Stacks blockchain with Bitcoin security
- **Cost Optimization**: Batch settlements reduce transaction fees for high-frequency usage

## How It Works

### Pay-Per-Use Model
1. **Service Providers** register their services with per-second rates
2. **Users** deposit STX tokens into their FluxBeam balance
3. **Sessions** are started with estimated duration and automatic escrow
4. **Real-time billing** calculates exact usage upon session end
5. **Batch processing** allows multiple sessions to be settled in one transaction
6. **Automatic settlement** pays providers and refunds excess to users

### Subscription Model 🆕
1. **Service Providers** create subscription tiers with custom pricing and durations
2. **Users** subscribe to tiers with one-time or auto-renewing payments
3. **Automatic billing** handles renewals when auto-renew is enabled
4. **Flexible management** allows users to cancel or toggle auto-renewal anytime
5. **Grace periods** enable renewals up to 1 day before expiration
6. **Tiered access** provides different feature levels at various price points

## Smart Contract Functions

### Public Functions

#### Service Management
- `register-service(service-name, rate-per-second)` - Register a new service
- `update-service-status(service-id, status)` - Enable/disable services

#### Subscription Functions 🆕
- `create-subscription-tier(service-id, tier-name, price, duration-blocks, features)` - Create a subscription tier
- `subscribe(tier-id, auto-renew)` - Subscribe to a service tier
- `renew-subscription(subscription-id)` - Manually renew an active subscription
- `cancel-subscription(subscription-id)` - Cancel a subscription (no refund)
- `toggle-auto-renew(subscription-id)` - Enable/disable automatic renewal
- `update-tier-status(tier-id, status)` - Activate/deactivate a subscription tier

#### Payment & Session Functions
- `deposit-funds(amount)` - Add STX to your FluxBeam balance
- `start-session(service-id, estimated-duration)` - Begin a metered session
- `end-session(session-id)` - Stop session and calculate final payment
- `process-batch-sessions(session-ids)` - Process up to 50 sessions in one transaction
- `withdraw-balance(amount)` - Withdraw unused STX from balance

### Read-Only Functions

#### Service Queries
- `get-service(service-id)` - View service details
- `get-session(session-id)` - View session information
- `estimate-session-cost(service-id, duration)` - Calculate estimated costs

#### Subscription Queries 🆕
- `get-tier(tier-id)` - View subscription tier details
- `get-subscription(subscription-id)` - View subscription information
- `get-user-subscription(user, service-id)` - Get user's subscription for a service
- `has-active-subscription(user, service-id)` - Check if user has active subscription
- `get-subscription-status(subscription-id)` - Get detailed subscription status with time remaining

#### Balance & Analytics
- `get-user-balance(user)` - Check user's FluxBeam balance
- `get-batch-settlement(batch-id)` - View batch settlement details
- `estimate-batch-savings(session-count)` - Calculate potential gas savings

## Subscription System

### Creating Subscription Tiers

Service providers can create multiple tiers for their services:

```clarity
;; Create a monthly Basic tier
(create-subscription-tier 
    u1                              ;; service-id
    u"Basic"                        ;; tier-name
    u1000000                        ;; price (1 STX in micro-STX)
    u4320                           ;; duration (30 days in blocks)
    u"100 API calls/day, Email support"  ;; features
)

;; Create a Premium tier
(create-subscription-tier 
    u1 
    u"Premium" 
    u5000000 
    u4320 
    u"Unlimited API calls, Priority support, Advanced analytics"
)