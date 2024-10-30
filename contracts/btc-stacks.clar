;; Bitcoin-Stacks Bridge Contract
;; Enables secure cross-chain transfers between Bitcoin and Stacks networks

(use-trait sip-010-trait .sip-010-trait.sip-010-trait)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INVALID-AMOUNT (err u1001))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1002))
(define-constant ERR-INVALID-BRIDGE-STATUS (err u1003))
(define-constant ERR-INVALID-SIGNATURE (err u1004))
(define-constant ERR-ALREADY-PROCESSED (err u1005))
(define-constant ERR-BRIDGE-PAUSED (err u1006))

;; Constants
(define-constant BRIDGE-ADMIN (as-contract tx-sender))
(define-constant MIN-DEPOSIT-AMOUNT u100000) ;; 0.001 BTC in sats
(define-constant MAX-DEPOSIT-AMOUNT u1000000000) ;; 10 BTC in sats
(define-constant REQUIRED_CONFIRMATIONS u6)

;; Data variables
(define-data-var bridge-paused bool false)
(define-data-var total-bridged-amount uint u0)
(define-data-var last-processed-height uint u0)

;; Data maps
(define-map deposits 
    { tx-hash: (buff 32) }
    {
        amount: uint,
        recipient: principal,
        processed: bool,
        confirmations: uint,
        timestamp: uint
    }
)

(define-map validators principal bool)
(define-map validator-signatures
    { tx-hash: (buff 32), validator: principal }
    { signature: (buff 65) }
)

(define-map bridge-balances principal uint)

;; Read-only functions
(define-read-only (get-deposit (tx-hash (buff 32)))
    (map-get? deposits {tx-hash: tx-hash})
)

(define-read-only (get-bridge-status)
    (var-get bridge-paused)
)

(define-read-only (get-validator-status (validator principal))
    (default-to false (map-get? validators validator))
)

(define-read-only (get-balance (user principal))
    (default-to u0 (map-get? bridge-balances user))
)

(define-read-only (verify-signature (tx-hash (buff 32)) (validator principal) (signature (buff 65)))
    (let (
        (stored-sig (map-get? validator-signatures {tx-hash: tx-hash, validator: validator}))
    )
        (and 
            (is-some stored-sig)
            (is-eq signature (get signature (unwrap-panic stored-sig)))
        )
    )
)

;; Private functions
(define-private (validate-deposit-amount (amount uint))
    (and 
        (>= amount MIN-DEPOSIT-AMOUNT)
        (<= amount MAX-DEPOSIT_AMOUNT)
    )
)


(define-private (update-deposit-confirmations (tx-hash (buff 32)) (new-confirmations uint))
    (let (
        (deposit (unwrap! (map-get? deposits {tx-hash: tx-hash}) ERR-INVALID-BRIDGE-STATUS))
    )
        (map-set deposits
            {tx-hash: tx-hash}
            (merge deposit {confirmations: new-confirmations})
        )
        (ok true)
    )
)

;; Public functions
(define-public (initialize-bridge)
    (begin
        (asserts! (is-eq tx-sender BRIDGE-ADMIN) ERR-NOT-AUTHORIZED)
        (var-set bridge-paused false)
        (ok true)
    )
)