;; Conditional Batch Transfer Smart Contract
;; Handles payroll and other batch transfers with conditional execution

;; Constants for error handling
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_TIME (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_CONDITIONS_NOT_MET (err u103))
(define-constant ERR_TRANSFER_FAILED (err u104))
(define-constant ERR_INVALID_THRESHOLD (err u105))

;; Constants for business logic
(define-constant BUSINESS_START_HOUR u9)  ;; 9 AM
(define-constant BUSINESS_END_HOUR u17)   ;; 5 PM
(define-constant HIGH_VALUE_THRESHOLD u50000000000) ;; 50,000 STX
(define-constant BALANCE_BUFFER u110) ;; 110% balance requirement

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var performance-metrics uint u0)
(define-data-var last-execution-time uint u0)

;; Data maps
(define-map authorized-signers principal bool)
(define-map transfer-records
    uint  ;; transfer-id
    {
        timestamp: uint,
        total-amount: uint,
        success: bool,
        conditions-met: (list 10 bool)
    }
)

;; Transfer request structure
(define-data-var transfer-id uint u0)

;; Administrative functions
(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (var-set contract-owner new-owner))
    )
)

(define-public (add-authorized-signer (signer principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (map-set authorized-signers signer true))
    )
)

(define-public (set-performance-metrics (metrics uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (var-set performance-metrics metrics))
    )
)

;; Helper functions
(define-private (is-business-hours)
    (let (
        (current-hour (get-current-hour block-height))
    )
        (and 
            (>= current-hour BUSINESS_START_HOUR)
            (<= current-hour BUSINESS_END_HOUR)
        )
    )
)

(define-private (get-current-hour (height uint))
    (mod (/ height u144) u24)  ;; Assuming 1 block per 10 minutes
)

(define-private (check-high-value-signatures (amount uint))
    (if (> amount HIGH_VALUE_THRESHOLD)
        (and 
            (default-to false (map-get? authorized-signers tx-sender))
            (> (len (get-signatures)) u1)
        )
        true
    )
)

(define-private (check-balance (total-amount uint))
    (>= (stx-get-balance tx-sender)
        (* total-amount (/ BALANCE_BUFFER u100)))
)

;; Main transfer function
(define-public (execute-batch-transfer
    (transfers (list 50 {
        recipient: principal,
        amount: uint,
        requires-high-value-check: bool
    }))
    (signatures (list 10 principal)))
    (let (
        (total-amount (fold + (map get-amount transfers) u0))
        (current-id (+ (var-get transfer-id) u1))
        (conditions-met (list
            (is-business-hours)
            (check-high-value-signatures total-amount)
            (check-balance total-amount)
            (> (var-get performance-metrics) u0)
        ))
    )
        (asserts! (is-business-hours) ERR_INVALID_TIME)
        (asserts! (check-high-value-signatures total-amount) ERR_UNAUTHORIZED)
        (asserts! (check-balance total-amount) ERR_INSUFFICIENT_BALANCE)
        
        (match (process-transfers transfers)
            success (begin
                (map-set transfer-records current-id {
                    timestamp: block-height,
                    total-amount: total-amount,
                    success: true,
                    conditions-met: conditions-met
                })
                (var-set transfer-id current-id)
                (var-set last-execution-time block-height)
                (ok true)
            )
            error (begin
                (map-set transfer-records current-id {
                    timestamp: block-height,
                    total-amount: total-amount,
                    success: false,
                    conditions-met: conditions-met
                })
                ERR_TRANSFER_FAILED
            )
        )
    )
)

;; Helper function to process individual transfers
(define-private (process-transfers (transfers (list 50 {
    recipient: principal,
    amount: uint,
    requires-high-value-check: bool
})))
    (match (fold process-single-transfer transfers (ok true))
        success (ok true)
        error ERR_TRANSFER_FAILED
    )
)

(define-private (process-single-transfer
    (transfer {
        recipient: principal,
        amount: uint,
        requires-high-value-check: bool
    })
    (previous-result (response bool uint)))
    (match previous-result
        prev-ok (stx-transfer? (get amount transfer) tx-sender (get recipient transfer))
        prev-err (err ERR_TRANSFER_FAILED)
    )
)

;; Getter functions for transfer records
(define-read-only (get-transfer-record (id uint))
    (map-get? transfer-records id)
)

(define-read-only (get-last-execution)
    (var-get last-execution-time)
)

;; Helper to get amount from transfer struct
(define-private (get-amount (transfer {
    recipient: principal,
    amount: uint,
    requires-high-value-check: bool
}))
    (get amount transfer)
)

;; Helper to get signatures count
(define-private (get-signatures)
    (filter is-authorized-signer (list tx-sender))
)

(define-private (is-authorized-signer (signer principal))
    (default-to false (map-get? authorized-signers signer))
)