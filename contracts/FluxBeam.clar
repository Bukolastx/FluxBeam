;; FluxBeam - Streaming Micropayments Across the Stacks Continuum
;; Version: 1.4.0
;; Enables real-time, per-second micropayments and subscription models with batch processing
;; New v1.4.0: Emergency pause system, provider withdrawal, and rate limiting

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
(define-constant ERR-CONTRACT-PAUSED (err u21))
(define-constant ERR-NO-PENDING-EARNINGS (err u22))
(define-constant ERR-RATE-LIMIT-EXCEEDED (err u23))

(define-constant MAX-BATCH-SIZE u50)
(define-constant BLOCKS-PER-DAY u144)
(define-constant BLOCKS-PER-MONTH u4320)
(define-constant RATE-LIMIT-BLOCKS u6)

;; Data variables
(define-data-var next-session-id uint u1)
(define-data-var next-service-id uint u1)
(define-data-var next-batch-id uint u1)
(define-data-var next-subscription-id uint u1)
(define-data-var next-tier-id uint u1)
(define-data-var contract-owner principal tx-sender)
(define-data-var contract-paused bool false)

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

(define-map user-activity
    principal
    {
        total-sessions: uint,
        total-spent: uint,
        active-subscriptions: uint,
        last-activity-block: uint
    }
)

;; NEW v1.4.0: Provider earnings tracking
(define-map provider-earnings
    principal
    {
        total-earned: uint,
        pending-withdrawal: uint,
        last-withdrawal-block: uint,
        total-withdrawn: uint
    }
)

;; NEW v1.4.0: Rate limiting for session creation
(define-map user-rate-limits
    principal
    {
        last-session-block: uint,
        sessions-in-window: uint
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

;; NEW v1.4.0: Update provider earnings
(define-private (update-provider-earnings (provider principal) (amount uint))
    (let
        (
            (current-earnings (default-to 
                {
                    total-earned: u0,
                    pending-withdrawal: u0,
                    last-withdrawal-block: u0,
                    total-withdrawn: u0
                } 
                (map-get? provider-earnings provider)))
        )
        (map-set provider-earnings provider {
            total-earned: (+ (get total-earned current-earnings) amount),
            pending-withdrawal: (+ (get pending-withdrawal current-earnings) amount),
            last-withdrawal-block: (get last-withdrawal-block current-earnings),
            total-withdrawn: (get total-withdrawn current-earnings)
        })
    )
)

;; NEW v1.4.0: Check rate limit
(define-private (check-rate-limit (user principal))
    (let
        (
            (current-block stacks-block-height)
            (rate-limit-data (default-to 
                {
                    last-session-block: u0,
                    sessions-in-window: u0
                } 
                (map-get? user-rate-limits user)))
            (last-block (get last-session-block rate-limit-data))
            (blocks-passed (if (> current-block last-block) (- current-block last-block) u0))
        )
        (if (>= blocks-passed RATE-LIMIT-BLOCKS)
            (begin
                (map-set user-rate-limits user {
                    last-session-block: current-block,
                    sessions-in-window: u1
                })
                (ok true)
            )
            (let
                (
                    (sessions-count (get sessions-in-window rate-limit-data))
                )
                (asserts! (< sessions-count u10) ERR-RATE-LIMIT-EXCEEDED)
                (map-set user-rate-limits user {
                    last-session-block: last-block,
                    sessions-in-window: (+ sessions-count u1)
                })
                (ok true)
            )
        )
    )
)

;; Public functions

;; NEW v1.4.0: Emergency pause toggle (owner only)
(define-public (toggle-contract-pause)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (var-set contract-paused (not (var-get contract-paused)))
        (ok (var-get contract-paused))
    )
)

;; NEW v1.4.0: Provider withdrawal function
(define-public (withdraw-provider-earnings)
    (let
        (
            (earnings-data (unwrap! (map-get? provider-earnings tx-sender) ERR-NO-PENDING-EARNINGS))
            (pending-amount (get pending-withdrawal earnings-data))
            (current-block stacks-block-height)
        )
        (asserts! (> pending-amount u0) ERR-NO-PENDING-EARNINGS)
        
        (map-set provider-earnings tx-sender {
            total-earned: (get total-earned earnings-data),
            pending-withdrawal: u0,
            last-withdrawal-block: current-block,
            total-withdrawn: (+ (get total-withdrawn earnings-data) pending-amount)
        })
        
        (try! (as-contract (stx-transfer? pending-amount tx-sender tx-sender)))
        (ok pending-amount)
    )
)

(define-public (register-service (service-name (string-utf8 50)) (rate-per-second uint))
    (let
        (
            (service-id (var-get next-service-id))
        )
        (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
        (asserts! (validate-service-name service-name) ERR-INVALID-NAME)
        (asserts! (> rate-per-second u0) ERR-INVALID-RATE)
        
        (map-set services service-id {
            provider: tx-sender,
            service-name: service-name,
            rate-per-second: rate-per-second,
            status: u"active",
            subscription-enabled: false
        })
        
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
        (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
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
            (provider (get provider service))
        )
        (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
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
        
        (update-service-analytics service-id price true)
        (update-user-activity tx-sender price true)
        (update-provider-earnings provider price)
        
        (try! (as-contract (stx-transfer? price tx-sender provider)))
        
        (var-set next-subscription-id (+ subscription-id u1))
        (ok subscription-id)
    )
)

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
            (provider (get provider service))
        )
        (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
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
            
            (update-service-analytics service-id price false)
            (update-user-activity tx-sender price false)
            (update-provider-earnings provider price)
            
            (try! (as-contract (stx-transfer? price tx-sender provider)))
            
            (ok new-end-block)
        )
    )
)

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

(define-public (deposit-funds (amount uint))
    (let
        (
            (current-balance (default-to u0 (map-get? user-balances tx-sender)))
        )
        (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set user-balances tx-sender (+ current-balance amount))
        (ok true)
    )
)

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
        (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
        (try! (check-rate-limit tx-sender))
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
        
        (update-service-analytics (get service-id session) actual-cost false)
        (update-user-activity tx-sender actual-cost false)
        (update-provider-earnings provider actual-cost)
        
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
        (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
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
            
            (update-provider-earnings provider (get total batch-result))
            
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

(define-read-only (get-contract-paused)
    (ok (var-get contract-paused))
)

(define-read-only (get-service (service-id uint))
    (ok (map-get? services service-id))
)

(define-read-only (get-tier (tier-id uint))
    (ok (map-get? subscription-tiers tier-id))
)

(define-read-only (get-subscription (subscription-id uint))
    (ok (map-get? subscriptions subscription-id))
)

(define-read-only (get-user-subscription (user principal) (service-id uint))
    (ok (map-get? user-subscriptions {user: user, service-id: service-id}))
)

(define-read-only (has-active-subscription (user principal) (service-id uint))
    (match (map-get? user-subscriptions {user: user, service-id: service-id})
        sub-id (is-subscription-valid sub-id)
        false
    )
)

(define-read-only (get-session (session-id uint))
    (ok (map-get? payment-sessions session-id))
)

(define-read-only (get-user-balance (user principal))
    (ok (default-to u0 (map-get? user-balances user)))
)

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

(define-read-only (get-batch-settlement (batch-id uint))
    (ok (map-get? batch-settlements batch-id))
)

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

(define-read-only (get-service-analytics (service-id uint))
    (ok (map-get? service-analytics service-id))
)

(define-read-only (get-user-activity (user principal))
    (ok (map-get? user-activity user))
)

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

;; NEW v1.4.0: Get provider earnings
(define-read-only (get-provider-earnings (provider principal))
    (ok (map-get? provider-earnings provider))
)

;; NEW v1.4.0: Get user rate limit status
(define-read-only (get-rate-limit-status (user principal))
    (let
        (
            (rate-limit-data (default-to 
                {
                    last-session-block: u0,
                    sessions-in-window: u0
                } 
                (map-get? user-rate-limits user)))
            (current-block stacks-block-height)
            (last-block (get last-session-block rate-limit-data))
            (blocks-passed (if (> current-block last-block) (- current-block last-block) u0))
            (is-limited (and (< blocks-passed RATE-LIMIT-BLOCKS) (>= (get sessions-in-window rate-limit-data) u10)))
        )
        (ok {
            is-rate-limited: is-limited,
            sessions-in-window: (get sessions-in-window rate-limit-data),
            blocks-until-reset: (if (< blocks-passed RATE-LIMIT-BLOCKS) (- RATE-LIMIT-BLOCKS blocks-passed) u0),
            last-session-block: last-block
        })
    )
)