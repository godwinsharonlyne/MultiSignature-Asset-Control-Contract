
;; title: asset-control
;; version:
;; summary:
;; description:
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_SIGNED (err u101))
(define-constant ERR_NOT_ENOUGH_SIGNATURES (err u102))
(define-constant ERR_INVALID_PROPOSAL (err u103))
(define-constant ERR_PROPOSAL_EXPIRED (err u104))
(define-constant ERR_PROPOSAL_ALREADY_EXECUTED (err u105))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u106))
(define-constant ERR_INVALID_THRESHOLD (err u107))
(define-constant ERR_OWNER_ALREADY_EXISTS (err u108))
(define-constant ERR_OWNER_NOT_FOUND (err u109))
(define-constant ERR_CANNOT_REMOVE_LAST_OWNER (err u110))
(define-constant ERR_BATCH_SIZE_EXCEEDED (err u116))
(define-constant ERR_BATCH_EMPTY (err u117))
(define-constant ERR_TIMELOCK_NOT_READY (err u118))
(define-constant ERR_PROPOSAL_NOT_QUEUED (err u119))
(define-constant ERR_TIMELOCK_DELAY_TOO_SHORT (err u120))

(define-data-var proposal-nonce uint u0)
(define-data-var signature-threshold uint u2)
(define-data-var timelock-delay uint u144)

(define-map owners principal bool)
(define-map proposals
  { proposal-id: uint }
  {
    creator: principal,
    receiver: principal,
    amount: uint,
    description: (string-ascii 256),
    expiration: uint,
    executed: bool
  }
)

(define-map signatures
  { proposal-id: uint, signer: principal }
  { signed: bool }
)

(define-map proposal-signature-count
  { proposal-id: uint }
  { count: uint }
)

(define-map queued-proposals
  { proposal-id: uint }
  { queued-at: uint, ready-at: uint }
)

(define-read-only (get-signature-threshold)
  (var-get signature-threshold)
)

(define-read-only (is-owner (address principal))
  (default-to false (map-get? owners address))
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-proposal-signature-count (proposal-id uint))
  (default-to { count: u0 } (map-get? proposal-signature-count { proposal-id: proposal-id }))
)

(define-read-only (has-signed (proposal-id uint) (signer principal))
  (default-to false (get signed (map-get? signatures { proposal-id: proposal-id, signer: signer })))
)

(define-read-only (get-proposal-nonce)
  (var-get proposal-nonce)
)

(define-read-only (get-timelock-delay)
  (var-get timelock-delay)
)

(define-read-only (get-queued-proposal (proposal-id uint))
  (map-get? queued-proposals { proposal-id: proposal-id })
)

(define-read-only (is-proposal-ready (proposal-id uint))
  (match (get-queued-proposal proposal-id)
    queue-info (>= stacks-block-height (get ready-at queue-info))
    false
  )
)

(define-public (add-owner (new-owner principal))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (is-owner new-owner)) ERR_OWNER_ALREADY_EXISTS)
    (map-set owners new-owner true)
    (ok true)
  )
)

;; (define-public (remove-owner (owner principal))
;;   (begin
;;     (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
;;     (asserts! (is-owner owner) ERR_OWNER_NOT_FOUND)
;;     (let ((owner-count (len (get-owner-list))))
;;       (asserts! (> owner-count u1) ERR_CANNOT_REMOVE_LAST_OWNER)
;;       (map-delete owners owner)
;;       (ok true)
;;     )
;;   )
;; )

;; (define-read-only (get-owner-list)
;;   (fold check-owner (map-to-list owners) (list))
;; )

(define-private (check-owner (entry {key: principal, value: bool}) (result (list 100 principal)))
  (if (get value entry)
    (unwrap-panic (as-max-len? (append result (get key entry)) u100))
    result
  )
)

(define-private (count-owners (owner principal) (count uint))
  (+ count u1)
)

;; (define-public (set-threshold (new-threshold uint))
;;   (begin
;;     (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
;;     (asserts! (> new-threshold u0) ERR_INVALID_THRESHOLD)
;;     (let ((owner-count (fold count-owners (map-keys owners) u0)))
;;       (asserts! (<= new-threshold owner-count) ERR_INVALID_THRESHOLD)
;;       (var-set signature-threshold new-threshold)
;;       (ok true)
;;     )
;;   )
;; )

(define-public (create-proposal (receiver principal) (amount uint) (description (string-ascii 256)) (expiration uint))
  (let ((proposal-id (var-get proposal-nonce)))
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (>= expiration stacks-block-height) ERR_PROPOSAL_EXPIRED)
    (map-set proposals
      { proposal-id: proposal-id }
      {
        creator: tx-sender,
        receiver: receiver,
        amount: amount,
        description: description,
        expiration: expiration,
        executed: false
      }
    )
    (map-set proposal-signature-count
      { proposal-id: proposal-id }
      { count: u0 }
    )
    (var-set proposal-nonce (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (sign-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (signature-count (get-proposal-signature-count proposal-id))
  )
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (has-signed proposal-id tx-sender)) ERR_ALREADY_SIGNED)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
    (asserts! (>= (get expiration proposal) stacks-block-height) ERR_PROPOSAL_EXPIRED)
    
    (map-set signatures
      { proposal-id: proposal-id, signer: tx-sender }
      { signed: true }
    )
    
    (map-set proposal-signature-count
      { proposal-id: proposal-id }
      { count: (+ (get count signature-count) u1) }
    )
    
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (signature-count (get-proposal-signature-count proposal-id))
  )
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
    (asserts! (>= (get expiration proposal) stacks-block-height) ERR_PROPOSAL_EXPIRED)
    (asserts! (>= (get count signature-count) (var-get signature-threshold)) ERR_NOT_ENOUGH_SIGNATURES)
    
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { executed: true })
    )
    
    (as-contract (stx-transfer? (get amount proposal) tx-sender (get receiver proposal)))
  )
)

(define-public (initialize (initial-owners (list 3 principal)) (threshold uint))
  (begin
    (asserts! (is-eq (len initial-owners) u3) ERR_INVALID_THRESHOLD)
    (asserts! (> threshold u0) ERR_INVALID_THRESHOLD)
    (asserts! (<= threshold u3) ERR_INVALID_THRESHOLD)
    
    (map-set owners (unwrap-panic (element-at initial-owners u0)) true)
    (map-set owners (unwrap-panic (element-at initial-owners u1)) true)
    (map-set owners (unwrap-panic (element-at initial-owners u2)) true)
    
    (var-set signature-threshold threshold)
    (ok true)
  )
)



(define-constant ERR_NOT_PROPOSAL_CREATOR (err u111))
(define-constant ERR_PROPOSAL_CANCELLED (err u112))

(define-map cancelled-proposals
  { proposal-id: uint }
  { cancelled: bool }
)

(define-read-only (is-proposal-cancelled (proposal-id uint))
  (default-to false (get cancelled (map-get? cancelled-proposals { proposal-id: proposal-id })))
)

(define-public (cancel-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get creator proposal)) ERR_NOT_PROPOSAL_CREATOR)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
    (asserts! (not (is-proposal-cancelled proposal-id)) ERR_PROPOSAL_CANCELLED)
    
    (map-set cancelled-proposals
      { proposal-id: proposal-id }
      { cancelled: true }
    )
    (ok true)
  )
)



(define-map owner-proposals
  { owner: principal }
  { proposal-ids: (list 50 uint) }
)

(define-read-only (get-owner-proposals (owner principal))
  (default-to { proposal-ids: (list) } (map-get? owner-proposals { owner: owner }))
)

(define-private (add-to-owner-history (owner principal) (proposal-id uint))
  (let (
    (current-history (get-owner-proposals owner))
  )
    (map-set owner-proposals
      { owner: owner }
      { proposal-ids: (unwrap-panic (as-max-len? (append (get proposal-ids current-history) proposal-id) u50)) }
    )
  )
)


(define-constant ERR_CONTRACT_PAUSED (err u113))
(define-constant ERR_CONTRACT_NOT_PAUSED (err u114))
(define-constant ERR_PAUSE_PROPOSAL_EXISTS (err u115))

(define-data-var contract-paused bool false)
(define-data-var pause-proposal-id (optional uint) none)
(define-data-var pause-proposal-expiration uint u0)

(define-read-only (is-contract-paused)
  (var-get contract-paused)
)

(define-read-only (get-pause-proposal-info)
  {
    proposal-id: (var-get pause-proposal-id),
    expiration: (var-get pause-proposal-expiration)
  }
)

(define-public (create-pause-proposal (expiration uint))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (is-none (var-get pause-proposal-id)) ERR_PAUSE_PROPOSAL_EXISTS)
    (asserts! (>= expiration stacks-block-height) ERR_PROPOSAL_EXPIRED)
    
    (let ((proposal-id (var-get proposal-nonce)))
      (var-set pause-proposal-id (some proposal-id))
      (var-set pause-proposal-expiration expiration)
      (var-set proposal-nonce (+ proposal-id u1))
      
      (map-set proposal-signature-count
        { proposal-id: proposal-id }
        { count: u0 }
      )
      
      (ok proposal-id)
    )
  )
)

(define-public (sign-pause-proposal)
  (let (
    (proposal-id (unwrap! (var-get pause-proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (signature-count (get-proposal-signature-count proposal-id))
  )
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (not (has-signed proposal-id tx-sender)) ERR_ALREADY_SIGNED)
    (asserts! (>= (var-get pause-proposal-expiration) stacks-block-height) ERR_PROPOSAL_EXPIRED)
    
    (map-set signatures
      { proposal-id: proposal-id, signer: tx-sender }
      { signed: true }
    )
    
    (map-set proposal-signature-count
      { proposal-id: proposal-id }
      { count: (+ (get count signature-count) u1) }
    )
    
    (ok true)
  )
)

(define-public (execute-pause)
  (let (
    (proposal-id (unwrap! (var-get pause-proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (signature-count (get-proposal-signature-count proposal-id))
  )
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (>= (var-get pause-proposal-expiration) stacks-block-height) ERR_PROPOSAL_EXPIRED)
    (asserts! (>= (get count signature-count) (var-get signature-threshold)) ERR_NOT_ENOUGH_SIGNATURES)
    
    (var-set contract-paused true)
    (var-set pause-proposal-id none)
    (var-set pause-proposal-expiration u0)
    
    (ok true)
  )
)

(define-public (create-unpause-proposal (expiration uint))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (var-get contract-paused) ERR_CONTRACT_NOT_PAUSED)
    (asserts! (is-none (var-get pause-proposal-id)) ERR_PAUSE_PROPOSAL_EXISTS)
    (asserts! (>= expiration stacks-block-height) ERR_PROPOSAL_EXPIRED)
    
    (let ((proposal-id (var-get proposal-nonce)))
      (var-set pause-proposal-id (some proposal-id))
      (var-set pause-proposal-expiration expiration)
      (var-set proposal-nonce (+ proposal-id u1))
      
      (map-set proposal-signature-count
        { proposal-id: proposal-id }
        { count: u0 }
      )
      
      (ok proposal-id)
    )
  )
)

(define-public (sign-unpause-proposal)
  (let (
    (proposal-id (unwrap! (var-get pause-proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (signature-count (get-proposal-signature-count proposal-id))
  )
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (var-get contract-paused) ERR_CONTRACT_NOT_PAUSED)
    (asserts! (not (has-signed proposal-id tx-sender)) ERR_ALREADY_SIGNED)
    (asserts! (>= (var-get pause-proposal-expiration) stacks-block-height) ERR_PROPOSAL_EXPIRED)
    
    (map-set signatures
      { proposal-id: proposal-id, signer: tx-sender }
      { signed: true }
    )
    
    (map-set proposal-signature-count
      { proposal-id: proposal-id }
      { count: (+ (get count signature-count) u1) }
    )
    
    (ok true)
  )
)

(define-public (execute-unpause)
  (let (
    (proposal-id (unwrap! (var-get pause-proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (signature-count (get-proposal-signature-count proposal-id))
  )
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (var-get contract-paused) ERR_CONTRACT_NOT_PAUSED)
    (asserts! (>= (var-get pause-proposal-expiration) stacks-block-height) ERR_PROPOSAL_EXPIRED)
    (asserts! (>= (get count signature-count) (var-get signature-threshold)) ERR_NOT_ENOUGH_SIGNATURES)
    
    (var-set contract-paused false)
    (var-set pause-proposal-id none)
    (var-set pause-proposal-expiration u0)
    
    (ok true)
  )
)

(define-public (create-proposals (receiver principal) (amount uint) (description (string-ascii 256)) (expiration uint))
  (let ((proposal-id (var-get proposal-nonce)))
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (>= expiration stacks-block-height) ERR_PROPOSAL_EXPIRED)
    (map-set proposals
      { proposal-id: proposal-id }
      {
        creator: tx-sender,
        receiver: receiver,
        amount: amount,
        description: description,
        expiration: expiration,
        executed: false
      }
    )
    (map-set proposal-signature-count
      { proposal-id: proposal-id }
      { count: u0 }
    )
    (var-set proposal-nonce (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (sign-proposals (proposal-id uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (signature-count (get-proposal-signature-count proposal-id))
  )
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (has-signed proposal-id tx-sender)) ERR_ALREADY_SIGNED)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
    (asserts! (>= (get expiration proposal) stacks-block-height) ERR_PROPOSAL_EXPIRED)
    
    (map-set signatures
      { proposal-id: proposal-id, signer: tx-sender }
      { signed: true }
    )
    
    (map-set proposal-signature-count
      { proposal-id: proposal-id }
      { count: (+ (get count signature-count) u1) }
    )
    
    (ok true)
  )
)

(define-public (execute-proposals (proposal-id uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (signature-count (get-proposal-signature-count proposal-id))
  )
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
    (asserts! (>= (get expiration proposal) stacks-block-height) ERR_PROPOSAL_EXPIRED)
    (asserts! (>= (get count signature-count) (var-get signature-threshold)) ERR_NOT_ENOUGH_SIGNATURES)
    
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { executed: true })
    )
    
    (as-contract (stx-transfer? (get amount proposal) tx-sender (get receiver proposal)))
  )
)



(define-private (validate-batch-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (signature-count (get-proposal-signature-count proposal-id))
  )
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
    (asserts! (not (is-proposal-cancelled proposal-id)) ERR_PROPOSAL_CANCELLED)
    (asserts! (>= (get expiration proposal) stacks-block-height) ERR_PROPOSAL_EXPIRED)
    (asserts! (>= (get count signature-count) (var-get signature-threshold)) ERR_NOT_ENOUGH_SIGNATURES)
    (ok proposal)
  )
)

(define-private (execute-single-proposal (proposal-id uint))
  (let (
    (proposal (unwrap-panic (get-proposal proposal-id)))
  )
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { executed: true })
    )
    (unwrap-panic (as-contract (stx-transfer? (get amount proposal) tx-sender (get receiver proposal))))
  )
)

(define-private (process-batch-proposal (proposal-id uint) (acc (response bool uint)))
  (match acc
    success (match (validate-batch-proposal proposal-id)
              valid-proposal (begin
                              (execute-single-proposal proposal-id)
                              (ok true))
              error-response (err error-response))
    error-response (err error-response)
  )
)

(define-public (execute-batch-proposals (proposal-ids (list 10 uint)))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> (len proposal-ids) u0) ERR_BATCH_EMPTY)
    (asserts! (<= (len proposal-ids) u10) ERR_BATCH_SIZE_EXCEEDED)
    
    (fold process-batch-proposal proposal-ids (ok true))
  )
)

(define-public (set-timelock-delay (new-delay uint))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (>= new-delay u1) ERR_TIMELOCK_DELAY_TOO_SHORT)
    (var-set timelock-delay new-delay)
    (ok true)
  )
)

(define-public (queue-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (signature-count (get-proposal-signature-count proposal-id))
  )
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
    (asserts! (not (is-proposal-cancelled proposal-id)) ERR_PROPOSAL_CANCELLED)
    (asserts! (>= (get expiration proposal) stacks-block-height) ERR_PROPOSAL_EXPIRED)
    (asserts! (>= (get count signature-count) (var-get signature-threshold)) ERR_NOT_ENOUGH_SIGNATURES)
    
    (let (
      (current-block stacks-block-height)
      (delay-blocks (var-get timelock-delay))
    )
      (map-set queued-proposals
        { proposal-id: proposal-id }
        { 
          queued-at: current-block,
          ready-at: (+ current-block delay-blocks)
        }
      )
      (ok true)
    )
  )
)

(define-public (execute-timelock-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (queue-info (unwrap! (get-queued-proposal proposal-id) ERR_PROPOSAL_NOT_QUEUED))
  )
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
    (asserts! (not (is-proposal-cancelled proposal-id)) ERR_PROPOSAL_CANCELLED)
    (asserts! (>= (get expiration proposal) stacks-block-height) ERR_PROPOSAL_EXPIRED)
    (asserts! (>= stacks-block-height (get ready-at queue-info)) ERR_TIMELOCK_NOT_READY)
    
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { executed: true })
    )
    
    (map-delete queued-proposals { proposal-id: proposal-id })
    
    (as-contract (stx-transfer? (get amount proposal) tx-sender (get receiver proposal)))
  )
)

(define-public (cancel-queued-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get creator proposal)) ERR_NOT_PROPOSAL_CREATOR)
    (asserts! (is-some (get-queued-proposal proposal-id)) ERR_PROPOSAL_NOT_QUEUED)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
    
    (map-delete queued-proposals { proposal-id: proposal-id })
    (ok true)
  )
)