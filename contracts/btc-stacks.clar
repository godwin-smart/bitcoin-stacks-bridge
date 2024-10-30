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

(define-public (pause-bridge)
    (begin
        (asserts! (is-eq tx-sender BRIDGE-ADMIN) ERR-NOT-AUTHORIZED)
        (var-set bridge-paused true)
        (ok true)
    )
)


(define-public (add-validator (validator principal))
    (begin
        (asserts! (is-eq tx-sender BRIDGE-ADMIN) ERR-NOT-AUTHORIZED)
        (map-set validators validator true)
        (ok true)
    )
)

(define-public (remove-validator (validator principal))
    (begin
        (asserts! (is-eq tx-sender BRIDGE-ADMIN) ERR-NOT-AUTHORIZED)
        (map-delete validators validator)
        (ok true)
    )
)

(define-public (initiate-deposit (tx-hash (buff 32)) (amount uint) (recipient principal))
    (begin
        (asserts! (not (var-get bridge-paused)) ERR-BRIDGE-PAUSED)
        (asserts! (validate-deposit-amount amount) ERR-INVALID-AMOUNT)
        (asserts! (map-get? validators tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? deposits {tx-hash: tx-hash})) ERR-ALREADY-PROCESSED)
        
        (map-set deposits
            {tx-hash: tx-hash}
            {
                amount: amount,
                recipient: recipient,
                processed: false,
                confirmations: u0,
                timestamp: block-height
            }
        )
        (ok true)
    )
)



(define-public (confirm-deposit 
    (tx-hash (buff 32))
    (signature (buff 65))
)
    (let (
        (deposit (unwrap! (map-get? deposits {tx-hash: tx-hash}) ERR-INVALID-BRIDGE-STATUS))
        (is-validator (unwrap! (map-get? validators tx-sender) ERR-NOT-AUTHORIZED))
    )
        (asserts! (not (var-get bridge-paused)) ERR-BRIDGE-PAUSED)
        (asserts! (not (get processed deposit)) ERR-ALREADY-PROCESSED)
        (asserts! (>= (get confirmations deposit) REQUIRED_CONFIRMATIONS) ERR-INVALID-BRIDGE-STATUS)
        
        ;; Store validator signature
        (map-set validator-signatures
            {tx-hash: tx-hash, validator: tx-sender}
            {signature: signature}
        )
        
        ;; Update deposit status and bridge balances
        (map-set deposits
            {tx-hash: tx-hash}
            (merge deposit {processed: true})
        )
        
        (map-set bridge-balances
            (get recipient deposit)
            (+ (get-balance (get recipient deposit)) (get amount deposit))
        )
        
        (var-set total-bridged-amount (+ (var-get total-bridged-amount) (get amount deposit)))
        (ok true)
    )
)


(define-public (withdraw 
    (amount uint)
    (btc-recipient (buff 34))
)
    (let (
        (current-balance (get-balance tx-sender))
    )
        (asserts! (not (var-get bridge-paused)) ERR-BRIDGE-PAUSED)
        (asserts! (>= current-balance amount) ERR-INSUFFICIENT-BALANCE)
        
        ;; Update user balance
        (map-set bridge-balances
            tx-sender
            (- current-balance amount)
        )
        
        ;; Emit withdrawal event for off-chain processing
        (print {
            type: "withdraw",
            sender: tx-sender,
            amount: amount,
            btc-recipient: btc-recipient
        })
        
        (var-set total-bridged-amount (- (var-get total-bridged-amount) amount))
        (ok true)
    )
)