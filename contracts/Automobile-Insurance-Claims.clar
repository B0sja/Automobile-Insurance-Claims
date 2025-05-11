;; Automobile Insurance Claims
;; A smart contract for processing and verifying insurance claims

;; Data maps
(define-map policies
  { policy-id: (string-utf8 20) }
  {
    owner: principal,
    vehicle-vin: (string-utf8 17),
    coverage-type: (string-utf8 50),
    coverage-limit: uint,
    deductible: uint,
    start-date: uint,
    end-date: uint,
    status: (string-utf8 10)
  }
)

(define-map claims
  { claim-id: (string-utf8 20) }
  {
    policy-id: (string-utf8 20),
    claimant: principal,
    incident-date: uint,
    description: (string-utf8 500),
    amount: uint,
    status: (string-utf8 20),
    evidence-hash: (buff 32),
    adjuster: (optional principal),
    resolution-date: (optional uint)
  }
)

(define-map insurers
  { insurer: principal }
  {
    name: (string-utf8 100),
    active: bool,
    registration-date: uint
  }
)

(define-map adjusters
  { adjuster: principal }
  {
    insurer: principal,
    active: bool,
    registration-date: uint
  }
)

;; Variables
(define-data-var admin principal tx-sender)
(define-data-var claim-counter uint u0)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-POLICY-EXISTS (err u101))
(define-constant ERR-POLICY-NOT-FOUND (err u102))
(define-constant ERR-NOT-OWNER (err u103))
(define-constant ERR-NOT-INSURER (err u104))
(define-constant ERR-NOT-ADJUSTER (err u105))
(define-constant ERR-CLAIM-NOT-FOUND (err u106))
(define-constant ERR-INVALID-STATUS (err u107))
(define-constant ERR-POLICY-EXPIRED (err u108))

;; Admin functions
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (ok (var-set admin new-admin))
  )
)

;; Insurer registration
(define-public (register-insurer (name (string-utf8 100)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (let ((current-time (get-block-height)))
      (map-set insurers
        { insurer: tx-sender }
        {
          name: name,
          active: true,
          registration-date: current-time
        }
      )
      (ok true)
    )
  )
)

;; Adjuster registration
(define-public (register-adjuster (adjuster principal))
  (let (
    (insurer (unwrap! (map-get? insurers { insurer: tx-sender }) ERR-NOT-INSURER))
    (current-time (get-block-height))
  )
    (map-set adjusters
      { adjuster: adjuster }
      {
        insurer: tx-sender,
        active: true,
        registration-date: current-time
      }
    )
    (ok true)
  )
)

;; Policy creation
(define-public (create-policy
    (policy-id (string-utf8 20))
    (vehicle-vin (string-utf8 17))
    (coverage-type (string-utf8 50))
    (coverage-limit uint)
    (deductible uint)
    (start-date uint)
    (end-date uint)
  )
  (let ((insurer (unwrap! (map-get? insurers { insurer: tx-sender }) ERR-NOT-INSURER)))
    (asserts! (is-none (map-get? policies { policy-id: policy-id })) ERR-POLICY-EXISTS)
    
    (map-set policies
      { policy-id: policy-id }
      {
        owner: tx-sender,
        vehicle-vin: vehicle-vin,
        coverage-type: coverage-type,
        coverage-limit: coverage-limit,
        deductible: deductible,
        start-date: start-date,
        end-date: end-date,
        status: "active"
      }
    )
    
    (ok true)
  )
)

;; File claim
(define-public (file-claim
    (policy-id (string-utf8 20))
    (incident-date uint)
    (description (string-utf8 500))
    (amount uint)
    (evidence-hash (buff 32))
  )
  (let (
    (policy (unwrap! (map-get? policies { policy-id: policy-id }) ERR-POLICY-NOT-FOUND))
    (current-time (get-block-height))
    (claim-id (concat (to-string (var-get claim-counter)) "-claim"))
  )
    (asserts! (is-eq (get status policy) "active") ERR-INVALID-STATUS)
    (asserts! (<= (get start-date policy) incident-date) ERR-INVALID-STATUS)
    (asserts! (>= (get end-date policy) incident-date) ERR-POLICY-EXPIRED)
    
    (map-set claims
      { claim-id: claim-id }
      {
        policy-id: policy-id,
        claimant: tx-sender,
        incident-date: incident-date,
        description: description,
        amount: amount,
        status: "pending",
        evidence-hash: evidence-hash,
        adjuster: none,
        resolution-date: none
      }
    )
    
    (var-set claim-counter (+ (var-get claim-counter) u1))
    
    (ok claim-id)
  )
)

;; Assign adjuster
(define-public (assign-adjuster
    (claim-id (string-utf8 20))
    (adjuster-principal principal)
  )
  (let (
    (claim (unwrap! (map-get? claims { claim-id: claim-id }) ERR-CLAIM-NOT-FOUND))
    (policy (unwrap! (map-get? policies { policy-id: (get policy-id claim) }) ERR-POLICY-NOT-FOUND))
    (adjuster-info (unwrap! (map-get? adjusters { adjuster: adjuster-principal }) ERR-NOT-ADJUSTER))
  )
    (asserts! (is-eq (get owner policy) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status claim) "pending") ERR-INVALID-STATUS)
    
    (map-set claims
      { claim-id: claim-id }
      (merge claim { 
        adjuster: (some adjuster-principal),
        status: "reviewing"
      })
    )
    
    (ok true)
  )
)

;; Process claim
(define-public (process-claim
    (claim-id (string-utf8 20))
    (approved bool)
    (approved-amount uint)
  )
  (let (
    (claim (unwrap! (map-get? claims { claim-id: claim-id }) ERR-CLAIM-NOT-FOUND))
    (adjuster-info (unwrap! (map-get? adjusters { adjuster: tx-sender }) ERR-NOT-ADJUSTER))
    (current-time (get-block-height))
  )
    (asserts! (is-eq (get status claim) "reviewing") ERR-INVALID-STATUS)
    (asserts! (is-eq (unwrap! (get adjuster claim) none) tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-set claims
      { claim-id: claim-id }
      (merge claim { 
        status: (if approved "approved" "rejected"),
        amount: (if approved approved-amount (get amount claim)),
        resolution-date: (some current-time)
      })
    )
    
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-policy (policy-id (string-utf8 20)))
  (map-get? policies { policy-id: policy-id })
)

(define-read-only (get-claim (claim-id (string-utf8 20)))
  (map-get? claims { claim-id: claim-id })
)

(define-read-only (get-insurer (insurer principal))
  (map-get? insurers { insurer: insurer })
)

(define-read-only (get-adjuster (adjuster principal))
  (map-get? adjusters { adjuster: adjuster })
)