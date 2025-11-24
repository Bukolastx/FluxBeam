;; FluxBeam - Streaming Micropayments Across the Stacks Continuum
;; Version: 1.3.0
;; Enables real-time, per-second micropayments and subscription models with batch processing
;; New: Service analytics and usage tracking

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-SESSION-NOT-FOUND (err u2))
(define-constant ERR-INVALID-AMOUNT (err u3))
(define-constant ERR-INVALID-RATE (err u4))
(define-constant ERR-SESSION-ACTIVE (err u5))
(define-constant ERR-SESSION-INACTIVE (err u6))
(define-constant ERR-INSUFFICIENT-BALANCE (err u7))
(define-constant ERR-INVALID-DURATION (err u8))
(define-constant ERR-SERVICE-NOT-FOUND (err u9))
(define-constant ERR-INVALID-NAME (err u10))
(define-constant ERR-BATCH-LIMIT-EXCEEDED (err u11))
(define-constant ERR-EMPTY-BATCH (err u12))
(define-constant ERR-BATCH-PROCESSING-FAILED (err u13))
(define-constant ERR-SUBSCRIPTION-NOT-FOUND (err u14))
(define-constant ERR-SUBSCRIPTION-ACTIVE (err u15))
(define-constant ERR-SUBSCRIPTION-INACTIVE (err u16))
(define-constant ERR-INVALID-TIER (err u17))
(define-constant ERR-TIER-NOT-FOUND (err u18))
(define-constant ERR-RENEWAL-TOO-EARLY (err u19))
(define-constant ERR-INVALID-PERIOD (err u20))

(define-constant MAX-BATCH-SIZE u50)
(define-constant BLOCKS-PER-DAY u144)
(define-constant BLOCKS-PER-MONTH u4320)

;; Data variables
(define-data-var next-session-id uint u1)
(define-data-var next-service-id uint u1)
(define-data-var next-batch-id uint u1)
(define-data-var next-subscription-id uint u1)
(define-data-var next-tier-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; Data maps
(define-map services
    uint
    {
        provider: principal,
        service-name: (string-utf8 50),
        rate-per-second: uint,
        status: (string-utf8 15),
        subscription-enabled: bool
    }
)

(define-map subscription-tiers
    uint
    {
        service-id: uint,
        tier-name: (string-utf8 30),
        price: uint,
        duration-blocks: uint,
        features: (string-utf8 200),
        status: (string-utf8 15)
    }
)

(define-map subscriptions
    uint
    {
        user: principal,
        tier-id: uint,
        service-id: uint,
        start-block: uint,
        end-block: uint,
        price: uint,
        auto-renew: bool,
        status: (string-utf8 15),
        renewal-count: uint
    }
)

(define-map user-subscriptions
    {user: principal, service-id: uint}
    uint
)

(define-map payment-sessions
    uint
    {
        user: principal,
        service-id: uint,
        start-time: uint,
        end-time: uint,
        rate-per-second: uint,
        total-deposited: uint,
        total-consumed: uint,
        status: (string-utf8 15),
        batch-id: (optional uint)
    }
)

(define-map user-balances principal uint)

(define-map batch-settlements
    uint
    {
        provider: principal,
        session-count: uint,
        total-amount: uint,
        processed: bool,
        created-at: uint
    }
)

(define-map pending-batch-sessions
    {batch-id: uint, session-index: uint}
    uint
)

;; NEW: Service analytics tracking
(define-map service-analytics
    uint
    {
        total-sessions: uint,
        total-revenue: uint,
        total-subscribers: uint,
        active-subscribers: uint,
        last-activity-block: uint
    }
)

;; NEW: User activity tracking
(define-map user-activity
    principal
    {
        total-sessions: uint,
        total-spent: uint,
        active-subscriptions: uint,
        last-activity-block: uint
    }
)

;; Private functions
(define-private (validate-service-name (name (string-utf8 50)))
    (and 
        (> (len name) u0)
        (<= (len name) u50)
    )
)

(define-private (validate-tier-name (name (string-utf8 30)))
    (and 
        (> (len name) u0)
        (<= (len name) u30)
    )
)

(define-private (calculate-session-cost (duration uint) (rate uint))
    (* duration rate)
)

(define-private (get-current-time)
    stacks-block-height
)

(define-private (validate-batch-size (size uint))
    (and (> size u0) (<= size MAX-BATCH-SIZE))
)

(define-private (is-subscription-valid (sub-id uint))
    (match (map-get? subscriptions sub-id)
        subscription 
            (and 
                (is-eq (get status subscription) u"active")
                (>= (get end-block subscription) stacks-block-height)
            )
        false
    )
)

(define-private (process-single-batch-session (session-id uint) (provider principal) (batch-total uint))
    (match (map-get? payment-sessions session-id)
        session
            (let
                (
                    (current-time (get-current-time))
                    (session-duration (- current-time (get start-time session)))
                    (actual-cost (calculate-session-cost session-duration (get rate-per-second session)))
                    (deposited-amount (get total-deposited session))
                    (refund-amount (if (> deposited-amount actual-cost) (- deposited-amount actual-cost) u0))
                    (user-balance (default-to u0 (map-get? user-balances (get user session))))
                )
                (asserts! (is-eq (get status session) u"active") (err u0))
                
                (map-set payment-sessions session-id (merge session {
                    end-time: current-time,
                    total-consumed: actual-cost,
                    status: u"completed"
                }))
                
                (if (> refund-amount u0)
                    (map-set user-balances (get user session) (+ user-balance refund-amount))
                    true
                )
                
                (ok actual-cost)
            )
        (err u0)
    )
)

;; NEW: Update service analytics
(define-private (update-service-analytics (service-id uint) (revenue uint) (is-subscription bool))
    (let
        (
            (current-analytics (default-to 
                {
                    total-sessions: u0,
                    total-revenue: u0,
                    total-subscribers: u0,
                    active-subscribers: u0,
                    last-activity-block: u0
                } 
                (map-get? service-analytics service-id)))
            (current-block stacks-block-height)
        )
        (map-set service-analytics service-id {
            total-sessions: (+ (get total-sessions current-analytics) u1),
            total-revenue: (+ (get total-revenue current-analytics) revenue),
            total-subscribers: (if is-subscription 
                                  (+ (get total-subscribers current-analytics) u1) 
                                  (get total-subscribers current-analytics)),
            active-subscribers: (get active-subscribers current-analytics),
            last-activity-block: current-block
        })
    )
)

;; NEW: Update user activity
(define-private (update-user-activity (user principal) (amount uint) (is-subscription bool))
    (let
        (
            (current-activity (default-to 
                {
                    total-sessions: u0,
                    total-spent: u0,
                    active-subscriptions: u0,
                    last-activity-block: u0
                } 
                (map-get? user-activity user)))
            (current-block stacks-block-height)
        )
        (map-set user-activity user {
            total-sessions: (+ (get total-sessions current-activity) u1),
            total-spent: (+ (get total-spent current-activity) amount),
            active-subscriptions: (if is-subscription 
                                     (+ (get active-subscriptions current-activity) u1) 
                                     (get active-subscriptions current-activity)),
            last-activity-block: current-block
        })
    )
)

;; Public functions

;; Register a new service
(define-public (register-service (service-name (string-utf8 50)) (rate-per-second uint))
    (let
        (
            (service-id (var-get next-service-id))
        )
        (asserts! (validate-service-name service-name) ERR-INVALID-NAME)
        (asserts! (> rate-per-second u0) ERR-INVALID-RATE)
        
        (map-set services service-id {
            provider: tx-sender,
            service-name: service-name,
            rate-per-second: rate-per-second,
            status: u"active",
            subscription-enabled: false
        })
        
        ;; Initialize analytics for new service
        (map-set service-analytics service-id {
            total-sessions: u0,
            total-revenue: u0,
            total-subscribers: u0,
            active-subscribers: u0,
            last-activity-block: stacks-block-height
        })
        
        (var-set next-service-id (+ service-id u1))
        (ok service-id)
    )
)

;; Create a subscription tier for a service
(define-public (create-subscription-tier 
    (service-id uint) 
    (tier-name (string-utf8 30)) 
    (price uint) 
    (duration-blocks uint)
    (features (string-utf8 200)))
    (let
        (
            (tier-id (var-get next-tier-id))
            (service (unwrap! (map-get? services service-id) ERR-SERVICE-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get provider service)) ERR-NOT-AUTHORIZED)
        (asserts! (validate-tier-name tier-name) ERR-INVALID-NAME)
        (asserts! (> price u0) ERR-INVALID-AMOUNT)
        (asserts! (> duration-blocks u0) ERR-INVALID-PERIOD)
        
        (map-set subscription-tiers tier-id {
            service-id: service-id,
            tier-name: tier-name,
            price: price,
            duration-blocks: duration-blocks,
            features: features,
            status: u"active"
        })
        
        (map-set services service-id (merge service {subscription-enabled: true}))
        
        (var-set next-tier-id (+ tier-id u1))
        (ok tier-id)
    )
)

;; Subscribe to a service tier
(define-public (subscribe (tier-id uint) (auto-renew bool))
    (let
        (
            (subscription-id (var-get next-subscription-id))
            (tier (unwrap! (map-get? subscription-tiers tier-id) ERR-TIER-NOT-FOUND))
            (service-id (get service-id tier))
            (service (unwrap! (map-get? services service-id) ERR-SERVICE-NOT-FOUND))
            (price (get price tier))
            (duration (get duration-blocks tier))
            (user-balance (default-to u0 (map-get? user-balances tx-sender)))
            (current-block stacks-block-height)
            (end-block (+ current-block duration))
        )
        (asserts! (is-eq (get status tier) u"active") ERR-TIER-NOT-FOUND)
        (asserts! (is-eq (get status service) u"active") ERR-SERVICE-NOT-FOUND)
        (asserts! (>= user-balance price) ERR-INSUFFICIENT-BALANCE)
        
        (map-set subscriptions subscription-id {
            user: tx-sender,
            tier-id: tier-id,
            service-id: service-id,
            start-block: current-block,
            end-block: end-block,
            price: price,
            auto-renew: auto-renew,
            status: u"active",
            renewal-count: u0
        })
        
        (map-set user-subscriptions {user: tx-sender, service-id: service-id} subscription-id)
        
        (map-set user-balances tx-sender (- user-balance price))
        
        ;; Update analytics
        (update-service-analytics service-id price true)
        (update-user-activity tx-sender price true)
        
        (try! (as-contract (stx-transfer? price tx-sender (get provider service))))
        
        (var-set next-subscription-id (+ subscription-id u1))
        (ok subscription-id)
    )
)

;; Renew a subscription
(define-public (renew-subscription (subscription-id uint))
    (let
        (
            (subscription (unwrap! (map-get? subscriptions subscription-id) ERR-SUBSCRIPTION-NOT-FOUND))
            (tier-id (get tier-id subscription))
            (tier (unwrap! (map-get? subscription-tiers tier-id) ERR-TIER-NOT-FOUND))
            (service-id (get service-id subscription))
            (service (unwrap! (map-get? services service-id) ERR-SERVICE-NOT-FOUND))
            (price (get price tier))
            (duration (get duration-blocks tier))
            (user-balance (default-to u0 (map-get? user-balances tx-sender)))
            (current-block stacks-block-height)
            (grace-period u144)
            (can-renew (>= current-block (- (get end-block subscription) grace-period)))
        )
        (asserts! (is-eq tx-sender (get user subscription)) ERR-NOT-AUTHORIZED)
        (asserts! can-renew ERR-RENEWAL-TOO-EARLY)
        (asserts! (>= user-balance price) ERR-INSUFFICIENT-BALANCE)
        (asserts! (is-eq (get status tier) u"active") ERR-TIER-NOT-FOUND)
        
        (let
            (
                (new-end-block (+ (get end-block subscription) duration))
            )
            (map-set subscriptions subscription-id (merge subscription {
                end-block: new-end-block,
                status: u"active",
                renewal-count: (+ (get renewal-count subscription) u1)
            }))
            
            (map-set user-balances tx-sender (- user-balance price))
            
            ;; Update analytics
            (update-service-analytics service-id price false)
            (update-user-activity tx-sender price false)
            
            (try! (as-contract (stx-transfer? price tx-sender (get provider service))))
            
            (ok new-end-block)
        )
    )
)

;; Cancel a subscription
(define-public (cancel-subscription (subscription-id uint))
    (let
        (
            (subscription (unwrap! (map-get? subscriptions subscription-id) ERR-SUBSCRIPTION-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get user subscription)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status subscription) u"active") ERR-SUBSCRIPTION-INACTIVE)
        
        (ok (map-set subscriptions subscription-id (merge subscription {
            status: u"cancelled",
            auto-renew: false
        })))
    )
)

;; Toggle auto-renewal for a subscription
(define-public (toggle-auto-renew (subscription-id uint))
    (let
        (
            (subscription (unwrap! (map-get? subscriptions subscription-id) ERR-SUBSCRIPTION-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get user subscription)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status subscription) u"active") ERR-SUBSCRIPTION-INACTIVE)
        
        (ok (map-set subscriptions subscription-id (merge subscription {
            auto-renew: (not (get auto-renew subscription))
        })))
    )
)

;; Update subscription tier status
(define-public (update-tier-status (tier-id uint) (new-status (string-utf8 15)))
    (let
        (
            (tier (unwrap! (map-get? subscription-tiers tier-id) ERR-TIER-NOT-FOUND))
            (service (unwrap! (map-get? services (get service-id tier)) ERR-SERVICE-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get provider service)) ERR-NOT-AUTHORIZED)
        (asserts! (or (is-eq new-status u"active") (is-eq new-status u"inactive")) ERR-INVALID-AMOUNT)
        
        (ok (map-set subscription-tiers tier-id (merge tier {status: new-status})))
    )
)

;; Deposit funds to user balance
(define-public (deposit-funds (amount uint))
    (let
        (
            (current-balance (default-to u0 (map-get? user-balances tx-sender)))
        )
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set user-balances tx-sender (+ current-balance amount))
        (ok true)
    )
)

;; Start a new payment session
(define-public (start-session (service-id uint) (estimated-duration uint))
    (let
        (
            (session-id (var-get next-session-id))
            (service (unwrap! (map-get? services service-id) ERR-SERVICE-NOT-FOUND))
            (rate (get rate-per-second service))
            (estimated-cost (calculate-session-cost estimated-duration rate))
            (user-balance (default-to u0 (map-get? user-balances tx-sender)))
            (current-time (get-current-time))
        )
        (asserts! (> estimated-duration u0) ERR-INVALID-DURATION)
        (asserts! (is-eq (get status service) u"active") ERR-SERVICE-NOT-FOUND)
        (asserts! (>= user-balance estimated-cost) ERR-INSUFFICIENT-BALANCE)
        
        (map-set payment-sessions session-id {
            user: tx-sender,
            service-id: service-id,
            start-time: current-time,
            end-time: u0,
            rate-per-second: rate,
            total-deposited: estimated-cost,
            total-consumed: u0,
            status: u"active",
            batch-id: none
        })
        
        (map-set user-balances tx-sender (- user-balance estimated-cost))
        (var-set next-session-id (+ session-id u1))
        (ok session-id)
    )
)

;; End a payment session and calculate final payment
(define-public (end-session (session-id uint))
    (let
        (
            (session (unwrap! (map-get? payment-sessions session-id) ERR-SESSION-NOT-FOUND))
            (service (unwrap! (map-get? services (get service-id session)) ERR-SERVICE-NOT-FOUND))
            (current-time (get-current-time))
            (session-duration (- current-time (get start-time session)))
            (actual-cost (calculate-session-cost session-duration (get rate-per-second session)))
            (deposited-amount (get total-deposited session))
            (refund-amount (if (> deposited-amount actual-cost) (- deposited-amount actual-cost) u0))
            (provider (get provider service))
            (user-balance (default-to u0 (map-get? user-balances (get user session))))
        )
        (asserts! (is-eq tx-sender (get user session)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status session) u"active") ERR-SESSION-INACTIVE)
        
        (map-set payment-sessions session-id (merge session {
            end-time: current-time,
            total-consumed: actual-cost,
            status: u"completed",
            batch-id: none
        }))
        
        ;; Update analytics
        (update-service-analytics (get service-id session) actual-cost false)
        (update-user-activity tx-sender actual-cost false)
        
        (if (> actual-cost u0)
            (try! (as-contract (stx-transfer? actual-cost tx-sender provider)))
            true
        )
        
        (if (> refund-amount u0)
            (map-set user-balances (get user session) (+ user-balance refund-amount))
            true
        )
        
        (ok {
            session-duration: session-duration,
            actual-cost: actual-cost,
            refund-amount: refund-amount
        })
    )
)

;; Process multiple sessions in a batch for cost efficiency
(define-public (process-batch-sessions (session-ids (list 50 uint)))
    (let
        (
            (batch-id (var-get next-batch-id))
            (session-count (len session-ids))
            (first-session-id (unwrap! (element-at session-ids u0) ERR-EMPTY-BATCH))
            (first-session (unwrap! (map-get? payment-sessions first-session-id) ERR-SESSION-NOT-FOUND))
            (service (unwrap! (map-get? services (get service-id first-session)) ERR-SERVICE-NOT-FOUND))
            (provider (get provider service))
        )
        (asserts! (validate-batch-size session-count) ERR-BATCH-LIMIT-EXCEEDED)
        (asserts! (> session-count u0) ERR-EMPTY-BATCH)
        
        (let
            (
                (batch-result (fold process-batch-session session-ids {total: u0, success: true, processed: u0}))
            )
            (asserts! (get success batch-result) ERR-BATCH-PROCESSING-FAILED)
            
            (map-set batch-settlements batch-id {
                provider: provider,
                session-count: (get processed batch-result),
                total-amount: (get total batch-result),
                processed: false,
                created-at: (get-current-time)
            })
            
            (if (> (get total batch-result) u0)
                (try! (as-contract (stx-transfer? (get total batch-result) tx-sender provider)))
                true
            )
            
            (map-set batch-settlements batch-id 
                (merge (unwrap! (map-get? batch-settlements batch-id) ERR-BATCH-PROCESSING-FAILED) 
                    {processed: true}))
            
            (var-set next-batch-id (+ batch-id u1))
            (ok {
                batch-id: batch-id,
                sessions-processed: (get processed batch-result),
                total-amount: (get total batch-result)
            })
        )
    )
)

;; Helper function for batch processing fold operation
(define-private (process-batch-session (session-id uint) (acc {total: uint, success: bool, processed: uint}))
    (if (get success acc)
        (match (process-single-batch-session session-id tx-sender (get total acc))
            session-cost (merge acc {
                total: (+ (get total acc) session-cost),
                processed: (+ (get processed acc) u1)
            })
            error-val (merge acc {success: false})
        )
        acc
    )
)

;; Withdraw user balance
(define-public (withdraw-balance (amount uint))
    (let
        (
            (user-balance (default-to u0 (map-get? user-balances tx-sender)))
        )
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (>= user-balance amount) ERR-INSUFFICIENT-BALANCE)
        
        (map-set user-balances tx-sender (- user-balance amount))
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (ok true)
    )
)

;; Update service status
(define-public (update-service-status (service-id uint) (new-status (string-utf8 15)))
    (let
        (
            (service (unwrap! (map-get? services service-id) ERR-SERVICE-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get provider service)) ERR-NOT-AUTHORIZED)
        (asserts! (or (is-eq new-status u"active") (is-eq new-status u"inactive")) ERR-INVALID-AMOUNT)
        
        (ok (map-set services service-id (merge service {status: new-status})))
    )
)

;; Read-only functions

;; Get service details
(define-read-only (get-service (service-id uint))
    (map-get? services service-id)
)

;; Get subscription tier details
(define-read-only (get-tier (tier-id uint))
    (map-get? subscription-tiers tier-id)
)

;; Get subscription details
(define-read-only (get-subscription (subscription-id uint))
    (map-get? subscriptions subscription-id)
)

;; Get user's active subscription for a service
(define-read-only (get-user-subscription (user principal) (service-id uint))
    (map-get? user-subscriptions {user: user, service-id: service-id})
)

;; Check if user has active subscription
(define-read-only (has-active-subscription (user principal) (service-id uint))
    (match (map-get? user-subscriptions {user: user, service-id: service-id})
        sub-id (is-subscription-valid sub-id)
        false
    )
)

;; Get payment session details
(define-read-only (get-session (session-id uint))
    (map-get? payment-sessions session-id)
)

;; Get user balance
(define-read-only (get-user-balance (user principal))
    (default-to u0 (map-get? user-balances user))
)

;; Calculate estimated cost for a session
(define-read-only (estimate-session-cost (service-id uint) (duration uint))
    (match (map-get? services service-id)
        service
            (let
                (
                    (rate (get rate-per-second service))
                )
                (ok (calculate-session-cost duration rate))
            )
        ERR-SERVICE-NOT-FOUND
    )
)

;; Get batch settlement details
(define-read-only (get-batch-settlement (batch-id uint))
    (map-get? batch-settlements batch-id)
)

;; Estimate batch processing savings
(define-read-only (estimate-batch-savings (session-count uint))
    (let
        (
            (individual-gas-cost u1000)
            (batch-gas-cost u2000)
            (total-individual-cost (* session-count individual-gas-cost))
            (savings (if (> total-individual-cost batch-gas-cost) 
                        (- total-individual-cost batch-gas-cost) 
                        u0))
        )
        (ok {
            individual-cost: total-individual-cost,
            batch-cost: batch-gas-cost,
            savings: savings,
            savings-percentage: (if (> total-individual-cost u0) 
                                   (/ (* savings u100) total-individual-cost) 
                                   u0)
        })
    )
)

;; Get subscription status and time remaining
(define-read-only (get-subscription-status (subscription-id uint))
    (match (map-get? subscriptions subscription-id)
        subscription
            (let
                (
                    (current-block stacks-block-height)
                    (end-block (get end-block subscription))
                    (blocks-remaining (if (>= end-block current-block) 
                                         (- end-block current-block) 
                                         u0))
                    (is-active (and 
                                 (is-eq (get status subscription) u"active")
                                 (>= end-block current-block)))
                )
                (ok {
                    is-active: is-active,
                    blocks-remaining: blocks-remaining,
                    end-block: end-block,
                    auto-renew: (get auto-renew subscription),
                    renewal-count: (get renewal-count subscription)
                })
            )
        ERR-SUBSCRIPTION-NOT-FOUND
    )
)

;; NEW: Get service analytics
(define-read-only (get-service-analytics (service-id uint))
    (ok (map-get? service-analytics service-id))
)

;; NEW: Get user activity statistics
(define-read-only (get-user-activity (user principal))
    (ok (map-get? user-activity user))
)

;; NEW: Get service performance metrics
(define-read-only (get-service-metrics (service-id uint))
    (match (map-get? service-analytics service-id)
        analytics
            (match (map-get? services service-id)
                service
                    (let
                        (
                            (avg-session-revenue (if (> (get total-sessions analytics) u0)
                                                    (/ (get total-revenue analytics) (get total-sessions analytics))
                                                    u0))
                        )
                        (ok {
                            service-name: (get service-name service),
                            total-sessions: (get total-sessions analytics),
                            total-revenue: (get total-revenue analytics),
                            total-subscribers: (get total-subscribers analytics),
                            active-subscribers: (get active-subscribers analytics),
                            avg-session-revenue: avg-session-revenue,
                            last-activity-block: (get last-activity-block analytics),
                            is-active: (is-eq (get status service) u"active")
                        })
                    )
                ERR-SERVICE-NOT-FOUND
            )
        ERR-SERVICE-NOT-FOUND
    )
)

;; Get active sessions for a user
(define-read-only (get-user-active-sessions (user principal))
    (ok user)
)
