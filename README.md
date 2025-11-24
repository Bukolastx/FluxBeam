# FluxBeam 🌐

**Streaming Micropayments Across the Stacks Continuum**

FluxBeam enables real-time, per-second micropayments and flexible subscription models using smart contracts on the Stacks blockchain. Perfect for time-based access to APIs, streaming content, SaaS services, and remote work billing.

## Features

- **Real-time Micropayments**: Pay per second of service usage
- **Subscription Models**: Recurring payments with tiered pricing structures
- **Auto-Renewal**: Automatic subscription renewals with grace periods
- **Tiered Pricing**: Multiple subscription tiers per service with custom features
- **Analytics & Tracking**: 🆕 Comprehensive service and user activity analytics
- **Performance Metrics**: 🆕 Track revenue, sessions, and subscriber growth
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
7. **Analytics tracking** 🆕 records all activity for insights and optimization

### Subscription Model
1. **Service Providers** create subscription tiers with custom pricing and durations
2. **Users** subscribe to tiers with one-time or auto-renewing payments
3. **Automatic billing** handles renewals when auto-renew is enabled
4. **Flexible management** allows users to cancel or toggle auto-renewal anytime
5. **Grace periods** enable renewals up to 1 day before expiration
6. **Tiered access** provides different feature levels at various price points
7. **Subscriber analytics** 🆕 helps providers understand user engagement

## Smart Contract Functions

### Public Functions

#### Service Management
- `register-service(service-name, rate-per-second)` - Register a new service
- `update-service-status(service-id, status)` - Enable/disable services

#### Subscription Functions
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

#### Subscription Queries
- `get-tier(tier-id)` - View subscription tier details
- `get-subscription(subscription-id)` - View subscription information
- `get-user-subscription(user, service-id)` - Get user's subscription for a service
- `has-active-subscription(user, service-id)` - Check if user has active subscription
- `get-subscription-status(subscription-id)` - Get detailed subscription status with time remaining

#### Balance & Analytics
- `get-user-balance(user)` - Check user's FluxBeam balance
- `get-batch-settlement(batch-id)` - View batch settlement details
- `estimate-batch-savings(session-count)` - Calculate potential gas savings

#### Analytics Functions 🆕
- `get-service-analytics(service-id)` - View service usage and revenue statistics
- `get-user-activity(user)` - View user's activity and spending history
- `get-service-metrics(service-id)` - Get comprehensive performance metrics including average revenue per session

## Analytics & Metrics 🆕

### Service Analytics
Track your service performance with detailed metrics:
- **Total Sessions**: Number of sessions created for your service
- **Total Revenue**: Cumulative STX earned from sessions and subscriptions
- **Total Subscribers**: Lifetime subscriber count
- **Active Subscribers**: Currently active subscription count
- **Last Activity Block**: Most recent user interaction

### User Activity
Monitor user engagement:
- **Total Sessions**: Number of sessions started by the user
- **Total Spent**: Cumulative STX spent on services
- **Active Subscriptions**: Current active subscription count
- **Last Activity Block**: Most recent activity timestamp

### Performance Metrics
Get actionable insights:
- **Average Session Revenue**: Mean revenue per session
- **Service Status**: Active/inactive status
- **Subscriber Growth**: Track subscriber acquisition over time

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
```

### Monitoring Service Performance 🆕

```clarity
;; Get comprehensive service metrics
(get-service-metrics u1)

;; Returns:
;; {
;;   service-name: "API Service",
;;   total-sessions: u150,
;;   total-revenue: u75000000,
;;   total-subscribers: u25,
;;   active-subscribers: u20,
;;   avg-session-revenue: u500000,
;;   last-activity-block: u12345,
;;   is-active: true
;; }
```

## Use Cases

### For Service Providers
- **API Services**: Charge per API call or offer subscription tiers
- **Streaming Platforms**: Bill per minute/second of content consumption
- **Cloud Computing**: Pay-per-use for compute resources
- **SaaS Applications**: Flexible pricing with usage-based or subscription models
- **Performance Tracking**: 🆕 Monitor service health and revenue trends

### For Users
- **Cost Control**: Only pay for actual usage with automatic refunds
- **Flexible Access**: Choose between pay-per-use or subscription models
- **Transparent Billing**: Track spending and activity in real-time
- **Activity History**: 🆕 View complete usage statistics and spending patterns

## Technical Details

- **Blockchain**: Stacks (Bitcoin-secured)
- **Language**: Clarity Smart Contract
- **Version**: 1.3.0
- **Max Batch Size**: 50 sessions per batch
- **Time Unit**: Stacks block height
- **Currency**: STX (micro-STX for precision)

## Security Features

- Principal-based authentication
- Secure escrow for session deposits
- Automatic refund mechanism
- Provider authorization checks
- Balance validation before transactions
- Protected admin functions

## Getting Started

1. **For Providers**: Register your service with `register-service`
2. **For Users**: Deposit funds with `deposit-funds`
3. **Start Using**: Begin sessions or subscribe to tiers
4. **Track Performance**: 🆕 Monitor analytics and optimize your services

## Version History

- **v1.3.0** (Current): Added comprehensive analytics and user activity tracking
- **v1.2.0**: Added subscription models with tiered pricing and auto-renewal
- **v1.1.0**: Introduced batch processing for cost optimization
- **v1.0.0**: Initial release with pay-per-use micropayments

## Support

For questions, feedback, or support, please reach out through our community channels or open an issue in the repository.

---

**FluxBeam** - Making micropayments seamless on Stacks 🚀
