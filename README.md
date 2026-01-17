# FluxBeam 🌐

**Streaming Micropayments Across the Stacks Continuum**

FluxBeam enables real-time, per-second micropayments and flexible subscription models using smart contracts on the Stacks blockchain. Perfect for time-based access to APIs, streaming content, SaaS services, and remote work billing.

## 🆕 What's New in v1.4.0

### Emergency Controls & Provider Tools
- **Emergency Pause System**: Contract owner can pause all payment operations during security incidents
- **Provider Earnings Withdrawal**: Service providers can withdraw accumulated earnings separately from live payments
- **Rate Limiting**: Prevents spam with automatic session creation limits (10 sessions per 6 blocks)
- **Earnings Tracking**: Detailed tracking of provider earnings, withdrawals, and pending amounts

### Enhanced Security
- Protected against rapid-fire session creation attacks
- Graceful contract pause without losing user funds
- Separate earnings pool for provider withdrawals
- Better error handling and validation throughout

## Features

### Core Functionality
- **Real-time Micropayments**: Pay per second of service usage
- **Subscription Models**: Recurring payments with tiered pricing structures
- **Auto-Renewal**: Automatic subscription renewals with grace periods
- **Tiered Pricing**: Multiple subscription tiers per service with custom features
- **Analytics & Tracking**: Comprehensive service and user activity analytics
- **Performance Metrics**: Track revenue, sessions, and subscriber growth
- **Batch Payment Processing**: Process multiple sessions in a single transaction to reduce costs
- **Smart Contract Automation**: Automated payment release and refunds
- **Service Registration**: Providers can register services with custom rates
- **Balance Management**: Deposit, withdraw, and track usage in real-time
- **Session Control**: Start/stop sessions with automatic cost calculation
- **Secure Payments**: Built on Stacks blockchain with Bitcoin security
- **Cost Optimization**: Batch settlements reduce transaction fees for high-frequency usage

### v1.4.0 Security Features
- **Emergency Pause**: Halt all operations during security incidents
- **Rate Limiting**: Prevent session creation spam (max 10 sessions per 6 blocks)
- **Provider Withdrawal**: Separate earnings pool with withdrawal tracking
- **Earnings Monitoring**: Track total earned, pending, and withdrawn amounts

## How It Works

### Pay-Per-Use Model
1. **Service Providers** register their services with per-second rates
2. **Users** deposit STX tokens into their FluxBeam balance
3. **Sessions** are started with estimated duration and automatic escrow
4. **Real-time billing** calculates exact usage upon session end
5. **Batch processing** allows multiple sessions to be settled in one transaction
6. **Automatic settlement** pays providers via earnings pool
7. **Provider withdrawal** allows earnings to be claimed anytime
8. **Analytics tracking** records all activity for insights and optimization

### Subscription Model
1. **Service Providers** create subscription tiers with custom pricing and durations
2. **Users** subscribe to tiers with one-time or auto-renewing payments
3. **Automatic billing** handles renewals when auto-renew is enabled
4. **Flexible management** allows users to cancel or toggle auto-renewal anytime
5. **Grace periods** enable renewals up to 1 day before expiration
6. **Tiered access** provides different feature levels at various price points
7. **Subscriber analytics** helps providers understand user engagement

## Smart Contract Functions

### Public Functions

#### Emergency & Admin Functions 🆕
- `toggle-contract-pause()` - Emergency pause/unpause (owner only)
- `withdraw-provider-earnings()` - Withdraw accumulated provider earnings

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
- `start-session(service-id, estimated-duration)` - Begin a metered session (rate limited)
- `end-session(session-id)` - Stop session and calculate final payment
- `process-batch-sessions(session-ids)` - Process up to 50 sessions in one transaction
- `withdraw-balance(amount)` - Withdraw unused STX from balance

### Read-Only Functions

#### Emergency & Status Queries 🆕
- `get-contract-paused()` - Check if contract is paused
- `get-provider-earnings(provider)` - View provider earnings details
- `get-rate-limit-status(user)` - Check user's rate limit status

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

#### Analytics Functions
- `get-service-analytics(service-id)` - View service usage and revenue statistics
- `get-user-activity(user)` - View user's activity and spending history
- `get-service-metrics(service-id)` - Get comprehensive performance metrics including average revenue per session

## Analytics & Metrics

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

### Provider Earnings 🆕
Track your earnings and withdrawals:
- **Total Earned**: Lifetime earnings from all services
- **Pending Withdrawal**: Available amount to withdraw
- **Total Withdrawn**: Historical withdrawal amount
- **Last Withdrawal Block**: Most recent withdrawal timestamp

## Rate Limiting 🆕

To prevent spam and ensure fair usage:
- Users can create up to **10 sessions per 6-block window**
- Rate limits automatically reset after the window expires
- Check your status with `get-rate-limit-status(user)`
- Returns: current sessions in window, blocks until reset, and limit status

## Emergency Pause System 🆕

For security and crisis management:
- Contract owner can pause all payment operations
- Pausing blocks: deposits, session creation, subscriptions, batch processing
- Users can still withdraw balances and view data
- Providers can still withdraw accumulated earnings
- Check status with `get-contract-paused()`

## Provider Earnings System 🆕

### How It Works
1. **Earnings Accumulation**: Payments are tracked in the provider earnings pool
2. **Separate Tracking**: Pending withdrawals are tracked separately from total earnings
3. **Flexible Withdrawal**: Withdraw earnings anytime using `withdraw-provider-earnings()`
4. **Historical Data**: View total earned vs. total withdrawn for accurate accounting

### Monitoring Your Earnings
```clarity
;; Check your earnings
(get-provider-earnings tx-sender)

;; Returns:
;; {
;;   total-earned: u100000000,      ;; 100 STX total
;;   pending-withdrawal: u50000000,  ;; 50 STX available
;;   last-withdrawal-block: u12345,
;;   total-withdrawn: u50000000      ;; 50 STX already withdrawn
;; }
```

## Use Cases

### For Service Providers
- **API Services**: Charge per API call or offer subscription tiers
- **Streaming Platforms**: Bill per minute/second of content consumption
- **Cloud Computing**: Pay-per-use for compute resources
- **SaaS Applications**: Flexible pricing with usage-based or subscription models
- **Performance Tracking**: Monitor service health and revenue trends
- **Earnings Management**: 🆕 Withdraw accumulated earnings on your schedule

### For Users
- **Cost Control**: Only pay for actual usage with automatic refunds
- **Flexible Access**: Choose between pay-per-use or subscription models
- **Transparent Billing**: Track spending and activity in real-time
- **Activity History**: View complete usage statistics and spending patterns
- **Protected Access**: 🆕 Rate limiting prevents accidental overspending

## Security Considerations

### Built-in Protections
- Principal-based authentication for all functions
- Secure escrow for session deposits with automatic refunds
- Provider authorization checks for service management
- Balance validation before all transactions
- Protected admin functions (owner-only)
- **Emergency pause capability** 🆕
- **Rate limiting on session creation** 🆕
- **Separate earnings pool for providers** 🆕

### Best Practices
1. **For Providers**: 
   - Regularly monitor your earnings with `get-provider-earnings()`
   - Withdraw earnings periodically to minimize exposure
   - Set appropriate rate limits for your service
   - Monitor service analytics for unusual activity

2. **For Users**:
   - Start with smaller deposits to test services
   - Monitor your balance regularly with `get-user-balance()`
   - Check rate limit status before creating multiple sessions
   - Review analytics to optimize spending

3. **For Contract Owner**:
   - Only use emergency pause during verified security incidents
   - Communicate clearly when contract is paused
   - Monitor for suspicious patterns requiring intervention

## Technical Details

- **Blockchain**: Stacks (Bitcoin-secured)
- **Language**: Clarity Smart Contract
- **Version**: 1.4.0
- **Max Batch Size**: 50 sessions per batch
- **Rate Limit Window**: 6 blocks (max 10 sessions)
- **Time Unit**: Stacks block height
- **Currency**: STX (micro-STX for precision)

## Getting Started

1. **For Providers**: 
   - Register your service with `register-service`
   - Monitor earnings with `get-provider-earnings`
   - Withdraw when ready with `withdraw-provider-earnings`

2. **For Users**: 
   - Deposit funds with `deposit-funds`
   - Check rate limits with `get-rate-limit-status`
   - Start using services

3. **Track Performance**: 
   - Monitor analytics and optimize your services
   - Review earnings and withdrawal history

## Version History

- **v1.4.0** (Current): Emergency pause system, provider withdrawal, and rate limiting
- **v1.3.0**: Added comprehensive analytics and user activity tracking
- **v1.2.0**: Added subscription models with tiered pricing and auto-renewal
- **v1.1.0**: Introduced batch processing for cost optimization
- **v1.0.0**: Initial release with pay-per-use micropayments

## Support

For questions, feedback, or support, please reach out through our community channels or open an issue in the repository.

---

**FluxBeam** - Making micropayments seamless on Stacks 🚀