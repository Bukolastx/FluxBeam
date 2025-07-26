;; FluxBeam - Streaming Micropayments Across the Stacks Continuum
;; Version: 1.0.0
;; Enables real-time, per-second micropayments using smart contracts

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

;; Data variables
(define-data-var next-session-id uint u1)
(define-data-var next-service-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; Data maps
(define-map services
    uint
    {
        provider: principal,
        service-name: (string-utf8 50),
        rate-per-second: uint,
        status: (string-utf8 15)
    }
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
        status: (string-utf8 15)
    }
)

(define-map user-balances principal uint)

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
            status: u"active"
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
        
        ;; Update session status
        (map-set payment-sessions session-id (merge session {
            end-time: current-time,
            total-consumed: actual-cost,
            status: u"completed"
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
            session-duration: session-duration,
            actual-cost: actual-cost,
            refund-amount: refund-amount
        })
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
            (rate (get rate-per-second service))
        )
        (ok (calculate-session-cost duration rate))
    )
)

;; Get active sessions for a user
(define-read-only (get-user-active-sessions (user principal))
    (ok user) ;; Simplified for this version
)