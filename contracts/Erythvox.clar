;; Erythvox Oracle - Environmental Data Oracle Platform
;; Channels vital environmental and sustainability data into the blockchain ecosystem

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_DATA (err u101))
(define-constant ERR_DATA_NOT_FOUND (err u102))
(define-constant ERR_INVALID_SOURCE (err u103))
(define-constant ERR_STALE_DATA (err u104))
(define-constant ERR_INVALID_PARAMETERS (err u105))

;; Data Variables
(define-data-var contract-active bool true)
(define-data-var next-data-id uint u1)

;; Data Maps
(define-map environmental-data 
  { data-id: uint }
  { 
    source-id: (string-ascii 50),
    data-type: (string-ascii 30),
    value: uint,
    timestamp: uint,
    verified: bool,
    metadata: (string-ascii 100)
  }
)

(define-map authorized-oracles principal bool)

(define-map carbon-footprint-data
  { project-id: (string-ascii 50) }
  {
    emissions: uint,
    timestamp: uint,
    verification-hash: (buff 32),
    data-source: (string-ascii 50)
  }
)

(define-map renewable-energy-data
  { source-id: (string-ascii 50) }
  {
    energy-type: (string-ascii 20),
    generation-mwh: uint,
    timestamp: uint,
    location: (string-ascii 50),
    verified: bool
  }
)

;; Authorization Functions
(define-public (add-authorized-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq oracle CONTRACT_OWNER)) ERR_INVALID_PARAMETERS)
    (map-set authorized-oracles oracle true)
    (ok true)
  )
)

(define-public (remove-authorized-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq oracle CONTRACT_OWNER)) ERR_INVALID_PARAMETERS)
    (map-delete authorized-oracles oracle)
    (ok true)
  )
)

(define-read-only (is-authorized-oracle (oracle principal))
  (default-to false (map-get? authorized-oracles oracle))
)

;; Emergency Controls
(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-active false)
    (ok true)
  )
)

(define-public (resume-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-active true)
    (ok true)
  )
)

;; Data Submission Functions
(define-public (submit-environmental-data 
  (source-id (string-ascii 50))
  (data-type (string-ascii 30))
  (value uint)
  (metadata (string-ascii 100)))
  (let ((data-id (var-get next-data-id)))
    (begin
      (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
      (asserts! (is-authorized-oracle tx-sender) ERR_UNAUTHORIZED)
      (asserts! (> (len source-id) u0) ERR_INVALID_PARAMETERS)
      (asserts! (> (len data-type) u0) ERR_INVALID_PARAMETERS)
      (asserts! (> value u0) ERR_INVALID_PARAMETERS)
      (asserts! (> (len metadata) u0) ERR_INVALID_PARAMETERS)
      
      (map-set environmental-data 
        { data-id: data-id }
        {
          source-id: source-id,
          data-type: data-type,
          value: value,
          timestamp: stacks-block-height,
          verified: true,
          metadata: metadata
        }
      )
      
      (var-set next-data-id (+ data-id u1))
      (ok data-id)
    )
  )
)

(define-public (submit-carbon-footprint 
  (project-id (string-ascii 50))
  (emissions uint)
  (verification-hash (buff 32))
  (data-source (string-ascii 50)))
  (begin
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (is-authorized-oracle tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> (len project-id) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> emissions u0) ERR_INVALID_PARAMETERS)
    (asserts! (> (len data-source) u0) ERR_INVALID_PARAMETERS)
    (asserts! (is-eq (len verification-hash) u32) ERR_INVALID_PARAMETERS)
    
    (map-set carbon-footprint-data
      { project-id: project-id }
      {
        emissions: emissions,
        timestamp: stacks-block-height,
        verification-hash: verification-hash,
        data-source: data-source
      }
    )
    (ok true)
  )
)

(define-public (submit-renewable-energy 
  (source-id (string-ascii 50))
  (energy-type (string-ascii 20))
  (generation-mwh uint)
  (location (string-ascii 50)))
  (begin
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (is-authorized-oracle tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> (len source-id) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> (len energy-type) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> generation-mwh u0) ERR_INVALID_PARAMETERS)
    (asserts! (> (len location) u0) ERR_INVALID_PARAMETERS)
    
    (map-set renewable-energy-data
      { source-id: source-id }
      {
        energy-type: energy-type,
        generation-mwh: generation-mwh,
        timestamp: stacks-block-height,
        location: location,
        verified: true
      }
    )
    (ok true)
  )
)

;; Data Query Functions
(define-read-only (get-environmental-data (data-id uint))
  (match (map-get? environmental-data { data-id: data-id })
    data-entry (ok data-entry)
    ERR_DATA_NOT_FOUND
  )
)

(define-read-only (get-carbon-footprint (project-id (string-ascii 50)))
  (match (map-get? carbon-footprint-data { project-id: project-id })
    carbon-data (ok carbon-data)
    ERR_DATA_NOT_FOUND
  )
)

(define-read-only (get-renewable-energy-data (source-id (string-ascii 50)))
  (match (map-get? renewable-energy-data { source-id: source-id })
    energy-data (ok energy-data)
    ERR_DATA_NOT_FOUND
  )
)

;; Data Validation Functions
(define-read-only (is-data-fresh (timestamp uint) (max-age uint))
  (>= timestamp (- stacks-block-height max-age))
)

(define-read-only (calculate-sustainability-score (emissions uint) (renewable-energy uint))
  (let ((base-score u100))
    (if (> emissions u0)
      (if (> renewable-energy u0)
        (/ (* base-score renewable-energy) (+ emissions renewable-energy))
        (/ base-score (+ u1 emissions))
      )
      base-score
    )
  )
)

;; Verification Functions
(define-read-only (verify-data-integrity 
  (data-hash (buff 32)) 
  (expected-hash (buff 32)))
  (is-eq data-hash expected-hash)
)

;; Utility Functions
(define-read-only (get-contract-info)
  {
    active: (var-get contract-active),
    next-data-id: (var-get next-data-id),
    owner: CONTRACT_OWNER
  }
)

(define-read-only (get-current-timestamp)
  stacks-block-height
)

;; Initialize contract with owner as authorized oracle
(map-set authorized-oracles CONTRACT_OWNER true)