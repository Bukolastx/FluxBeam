# FluxBeam 🌐

**Streaming Micropayments Across the Stacks Continuum**

FluxBeam enables real-time, per-second micropayments using smart contracts on the Stacks blockchain. Perfect for time-based access to APIs, streaming content, and remote work billing.

## Features

- **Real-time Micropayments**: Pay per second of service usage
- **Batch Payment Processing**: Process multiple sessions in a single transaction to reduce costs
- **Smart Contract Automation**: Automated payment release and refunds
- **Service Registration**: Providers can register services with custom rates
- **Balance Management**: Deposit, withdraw, and track usage in real-time
- **Session Control**: Start/stop sessions with automatic cost calculation
- **Secure Payments**: Built on Stacks blockchain with Bitcoin security
- **Cost Optimization**: Batch settlements reduce transaction fees for high-frequency usage

## How It Works

1. **Service Providers** register their services with per-second rates
2. **Users** deposit STX tokens into their FluxBeam balance
3. **Sessions** are started with estimated duration and automatic escrow
4. **Real-time billing** calculates exact usage upon session end
5. **Batch processing** allows multiple sessions to be settled in one transaction
6. **Automatic settlement** pays providers and refunds excess to users

## Smart Contract Functions

### Public Functions

- `register-service(service-name, rate-per-second)` - Register a new service
- `deposit-funds(amount)` - Add STX to your FluxBeam balance
- `start-session(service-id, estimated-duration)` - Begin a metered session
- `end-session(session-id)` - Stop session and calculate final payment
- `process-batch-sessions(session-ids)` - **NEW**: Process up to 50 sessions in one transaction
- `withdraw-balance(amount)` - Withdraw unused STX from balance
- `update-service-status(service-id, status)` - Enable/disable services

### Read-Only Functions

- `get-service(service-id)` - View service details
- `get-session(session-id)` - View session information
- `get-user-balance(user)` - Check user's FluxBeam balance
- `estimate-session-cost(service-id, duration)` - Calculate estimated costs
- `get-batch-settlement(batch-id)` - **NEW**: View batch settlement details
- `estimate-batch-savings(session-count)` - **NEW**: Calculate potential gas savings

## Batch Payment Processing

### Benefits
- **Reduced Gas Costs**: Process up to 50 sessions in a single transaction
- **Improved Efficiency**: Lower overhead for high-frequency service usage
- **Bulk Operations**: Ideal for services with many short sessions
- **Cost Savings**: Significant gas fee reduction for providers and users

### Usage
```clarity
;; Process multiple sessions at once
(process-batch-sessions (list u1 u2 u3 u4 u5))
```

### Batch Limits
- Maximum 50 sessions per batch
- All sessions must be active and ready for settlement
- Automatic refund handling for each session
- Single payment to service provider

## Use Cases

- **API Access**: Pay per API call or data transfer with batch settlements
- **Streaming Content**: Per-second billing for video/audio streams
- **Remote Work**: Time-based billing for development or consulting
- **IoT Services**: Metered access to sensor data or device control
- **Cloud Resources**: Pay-per-use infrastructure services with cost optimization
- **Micro-SaaS**: Efficient billing for small, frequent service usage

## Getting Started

1. Deploy the FluxBeam contract to Stacks
2. Register your service using `register-service`
3. Users deposit funds with `deposit-funds`
4. Start sessions with `start-session`
5. Use `process-batch-sessions` for cost-efficient bulk settlements
6. Monitor usage and end individual sessions with `end-session`

## Gas Cost Optimization

### Individual Processing
- Each session settlement requires a separate transaction
- Higher cumulative gas costs for multiple sessions
- Suitable for single or few sessions

### Batch Processing
- Process up to 50 sessions in one transaction
- Significant gas savings (typically 60-80% reduction)
- Automatic cost calculation and settlement
- Built-in error handling and refund processing

## Security Features

- Input validation on all parameters
- Authorization checks for service management
- Automatic refunds for unused deposits
- Protected balance withdrawals
- Session state management
- Batch size limits to prevent abuse
- Comprehensive error handling for batch operations

## Technical Implementation

Built with Clarity smart contracts on Stacks blockchain, ensuring:
- Deterministic execution
- Bitcoin-level security
- Transparent and auditable code
- Gas-efficient operations
- Optimized batch processing algorithms
- Proper error handling and data validation

## Error Codes

- `ERR-BATCH-LIMIT-EXCEEDED (u11)`: Batch size exceeds maximum limit
- `ERR-EMPTY-BATCH (u12)`: No sessions provided for batch processing
- `ERR-BATCH-PROCESSING-FAILED (u13)`: Batch operation failed during processing

## Version History

### v1.1.0 - Batch Payment Processing
- Added `process-batch-sessions` function for bulk settlements
- Implemented batch settlement tracking and analytics
- Added gas cost estimation for batch vs individual processing
- Enhanced error handling for batch operations
- Improved contract efficiency and cost optimization

### v1.0.0 - Initial Release
- Core micropayment functionality
- Service registration and management
- Session-based billing system
- Real-time payment processing

## Future Roadmap

- **Advanced Analytics**: Detailed usage and cost analytics dashboard
- **Subscription Models**: Recurring payment options for long-term services
- **Dispute Resolution**: Automated dispute handling mechanisms
- **Multi-token Support**: Support for additional cryptocurrencies
- **Integration APIs**: RESTful APIs for easier service integration

---

**Version**: 1.1.0  
**Blockchain**: Stacks  
**Language**: Clarity