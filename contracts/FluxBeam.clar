;; FluxBeam - Streaming Micropayments Across the Stacks Continuum
;; Version: 1.1.0
;; Enables real-time, per-second micropayments using smart contracts with batch processing

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

(define-constant MAX-BATCH-SIZE u50)

;; Data variables
(define-data-var next-session-id uint u1)
(define-data-var next-service-id uint u1)
(define-data-var next-batch-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; Data maps
(define-map services
    uint
    {
        provider: principal,
        service_name: (string-utf8 50),
        rate_per_second: uint,
        status: (string-utf8 15)
    }
)

(define-map payment-sessions
    uint
    {
        user: principal,
        service_id: uint,
        start_time: uint,
        end_time: uint,
        rate_per_second: uint,
        total_deposited: uint,
        total_consumed: uint,
        status: (string-utf8 15),
        batch_id: (optional uint)
    }
)

(define-map user-balances principal uint)

(define-map batch-settlements
    uint
    {
        provider: principal,
        session_count: uint,
        total_amount: uint,
        processed: bool,
        created_at: uint
    }
)

(define-map pending-batch-sessions
    {batch_id: uint, session_index: uint}
    uint
)

;; Private functions
(define-private (validate-service-name (name (string-utf8 50)))
    (and 
        (> (len name) u0)
        (<= (len name) u50)
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

(define-private (process-single-batch-session (session-id uint) (provider principal) (batch-total uint))
    (let
        (
            (session (unwrap! (map-get? payment-sessions session-id) (err u0)))
            (current-time (get-current-time))
            (session-duration (- current-time (get start_time session)))
            (actual-cost (calculate-session-cost session-duration (get rate_per_second session)))
            (deposited-amount (get total_deposited session))
            (refund-amount (if (> deposited-amount actual-cost) (- deposited-amount actual-cost) u0))
            (user-balance (default-to u0 (map-get? user-balances (get user session))))
        )
        ;; Validate session can be processed
        (asserts! (is-eq (get status session) u"active") (err u0))
        (asserts! (is-eq (get service_id session) (get service_id session)) (ok u0))
        
        ;; Update session status
        (map-set payment-sessions session-id (merge session {
            end_time: current-time,
            total_consumed: actual-cost,
            status: u"completed"
        }))
        
        ;; Handle refund if any
        (if (> refund-amount u0)
            (map-set user-balances (get user session) (+ user-balance refund-amount))
            true
        )
        
        (ok actual-cost)
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
            service_name: service-name,
            rate_per_second: rate-per-second,
            status: u"active"
        })
        
        (var-set next-service-id (+ service-id u1))
        (ok service-id)
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
            (rate (get rate_per_second service))
            (estimated-cost (calculate-session-cost estimated-duration rate))
            (user-balance (default-to u0 (map-get? user-balances tx-sender)))
            (current-time (get-current-time))
        )
        (asserts! (> estimated-duration u0) ERR-INVALID-DURATION)
        (asserts! (is-eq (get status service) u"active") ERR-SERVICE-NOT-FOUND)
        (asserts! (>= user-balance estimated-cost) ERR-INSUFFICIENT-BALANCE)
        
        (map-set payment-sessions session-id {
            user: tx-sender,
            service_id: service-id,
            start_time: current-time,
            end_time: u0,
            rate_per_second: rate,
            total_deposited: estimated-cost,
            total_consumed: u0,
            status: u"active",
            batch_id: none
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
            (service (unwrap! (map-get? services (get service_id session)) ERR-SERVICE-NOT-FOUND))
            (current-time (get-current-time))
            (session-duration (- current-time (get start_time session)))
            (actual-cost (calculate-session-cost session-duration (get rate_per_second session)))
            (deposited-amount (get total_deposited session))
            (refund-amount (if (> deposited-amount actual-cost) (- deposited-amount actual-cost) u0))
            (provider (get provider service))
            (user-balance (default-to u0 (map-get? user-balances (get user session))))
        )
        (asserts! (is-eq tx-sender (get user session)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status session) u"active") ERR-SESSION-INACTIVE)
        
        ;; Update session status
        (map-set payment-sessions session-id (merge session {
            end_time: current-time,
            total_consumed: actual-cost,
            status: u"completed",
            batch_id: none
        }))
        
        ;; Transfer payment to service provider
        (if (> actual-cost u0)
            (try! (as-contract (stx-transfer? actual-cost tx-sender provider)))
            true
        )
        
        ;; Refund excess amount to user
        (if (> refund-amount u0)
            (map-set user-balances (get user session) (+ user-balance refund-amount))
            true
        )
        
        (ok {
            session_duration: session-duration,
            actual_cost: actual-cost,
            refund_amount: refund-amount
        })
    )
)

;; Process multiple sessions in a batch for cost efficiency
(define-public (process-batch-sessions (session-ids (list 50 uint)))
    (let
        (
            (batch-id (var-get next-batch-id))
            (session-count (len session-ids))
            (first-session (unwrap! (element-at session-ids u0) ERR-EMPTY-BATCH))
            (session (unwrap! (map-get? payment-sessions first-session) ERR-SESSION-NOT-FOUND))
            (service (unwrap! (map-get? services (get service_id session)) ERR-SERVICE-NOT-FOUND))
            (provider (get provider service))
        )
        (asserts! (validate-batch-size session-count) ERR-BATCH-LIMIT-EXCEEDED)
        (asserts! (> session-count u0) ERR-EMPTY-BATCH)
        
        ;; Process each session in the batch
        (let
            (
                (batch-result (fold process-batch-session session-ids {total: u0, success: true, processed: u0}))
            )
            (asserts! (get success batch-result) ERR-BATCH-PROCESSING-FAILED)
            
            ;; Create batch settlement record
            (map-set batch-settlements batch-id {
                provider: provider,
                session_count: (get processed batch-result),
                total_amount: (get total batch-result),
                processed: false,
                created_at: (get-current-time)
            })
            
            ;; Transfer batch payment to provider
            (if (> (get total batch-result) u0)
                (try! (as-contract (stx-transfer? (get total batch-result) tx-sender provider)))
                true
            )
            
            ;; Mark batch as processed
            (map-set batch-settlements batch-id (merge (unwrap-panic (map-get? batch-settlements batch-id)) {processed: true}))
            
            (var-set next-batch-id (+ batch-id u1))
            (ok {
                batch_id: batch-id,
                sessions_processed: (get processed batch-result),
                total_amount: (get total batch-result)
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
        
        (ok (map-set services service-id (merge service { status: new-status })))
    )
)

;; Read-only functions

;; Get service details
(define-read-only (get-service (service-id uint))
    (map-get? services service-id)
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
    (let
        (
            (service (unwrap! (map-get? services service-id) ERR-SERVICE-NOT-FOUND))
            (rate (get rate_per_second service))
        )
        (ok (calculate-session-cost duration rate))
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
            (individual-gas-cost u1000) ;; Estimated gas per individual transaction
            (batch-gas-cost u2000) ;; Estimated gas for batch transaction
            (total-individual-cost (* session-count individual-gas-cost))
            (savings (if (> total-individual-cost batch-gas-cost) 
                        (- total-individual-cost batch-gas-cost) 
                        u0))
        )
        (ok {
            individual_cost: total-individual-cost,
            batch_cost: batch-gas-cost,
            savings: savings,
            savings_percentage: (if (> total-individual-cost u0) 
                                   (/ (* savings u100) total-individual-cost) 
                                   u0)
        })
    )
)

;; Get active sessions for a user
(define-read-only (get-user-active-sessions (user principal))
    (ok user) ;; Simplified for this version
)
