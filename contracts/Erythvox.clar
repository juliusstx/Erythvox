;; Erythvox Oracle - Cross-Chain Environmental Data Oracle Platform
;; Channels vital environmental and sustainability data across blockchain networks

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_DATA (err u101))
(define-constant ERR_DATA_NOT_FOUND (err u102))
(define-constant ERR_INVALID_SOURCE (err u103))
(define-constant ERR_STALE_DATA (err u104))
(define-constant ERR_INVALID_PARAMETERS (err u105))
(define-constant ERR_UNSUPPORTED_CHAIN (err u106))
(define-constant ERR_BRIDGE_INACTIVE (err u107))
(define-constant ERR_INVALID_CHAIN_DATA (err u108))

;; Chain Constants
(define-constant CHAIN_STACKS "stacks")
(define-constant CHAIN_ETHEREUM "ethereum")
(define-constant CHAIN_POLYGON "polygon")
(define-constant CHAIN_AVALANCHE "avalanche")
(define-constant CHAIN_BSC "bsc")

;; Data Variables
(define-data-var contract-active bool true)
(define-data-var bridge-active bool true)
(define-data-var next-data-id uint u1)
(define-data-var cross-chain-nonce uint u1)

;; Data Maps
(define-map environmental-data 
  { data-id: uint }
  { 
    source-id: (string-ascii 50),
    data-type: (string-ascii 30),
    value: uint,
    timestamp: uint,
    verified: bool,
    metadata: (string-ascii 100),
    source-chain: (string-ascii 20)
  }
)

(define-map authorized-oracles principal bool)

(define-map carbon-footprint-data
  { project-id: (string-ascii 50) }
  {
    emissions: uint,
    timestamp: uint,
    verification-hash: (buff 32),
    data-source: (string-ascii 50),
    source-chain: (string-ascii 20)
  }
)

(define-map renewable-energy-data
  { source-id: (string-ascii 50) }
  {
    energy-type: (string-ascii 20),
    generation-mwh: uint,
    timestamp: uint,
    location: (string-ascii 50),
    verified: bool,
    source-chain: (string-ascii 20)
  }
)

;; Cross-Chain Bridge Maps
(define-map supported-chains (string-ascii 20) bool)

(define-map cross-chain-data
  { chain-name: (string-ascii 20), external-id: (string-ascii 100) }
  {
    local-data-id: uint,
    sync-timestamp: uint,
    verification-status: (string-ascii 20)
  }
)

(define-map chain-validators
  { chain-name: (string-ascii 20) }
  {
    validator-address: (string-ascii 100),
    active: bool,
    last-sync: uint
  }
)

(define-map cross-chain-sync-history
  { sync-id: uint }
  {
    source-chain: (string-ascii 20),
    target-chains: (string-ascii 200),
    data-hash: (buff 32),
    sync-timestamp: uint,
    status: (string-ascii 20)
  }
)

;; Authorization Functions
(define-public (add-authorized-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq oracle CONTRACT_OWNER)) ERR_INVALID_PARAMETERS)
    (ok (map-set authorized-oracles oracle true))
  )
)

(define-public (remove-authorized-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq oracle CONTRACT_OWNER)) ERR_INVALID_PARAMETERS)
    (ok (map-delete authorized-oracles oracle))
  )
)

(define-read-only (is-authorized-oracle (oracle principal))
  (default-to false (map-get? authorized-oracles oracle))
)

;; Cross-Chain Management Functions
(define-public (add-supported-chain (chain-name (string-ascii 20)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> (len chain-name) u0) ERR_INVALID_PARAMETERS)
    (ok (map-set supported-chains chain-name true))
  )
)

(define-public (remove-supported-chain (chain-name (string-ascii 20)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> (len chain-name) u0) ERR_INVALID_PARAMETERS)
    (ok (map-delete supported-chains chain-name))
  )
)

(define-read-only (is-supported-chain (chain-name (string-ascii 20)))
  (default-to false (map-get? supported-chains chain-name))
)

(define-public (set-chain-validator 
  (chain-name (string-ascii 20))
  (validator-address (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> (len chain-name) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> (len validator-address) u0) ERR_INVALID_PARAMETERS)
    (asserts! (is-supported-chain chain-name) ERR_UNSUPPORTED_CHAIN)
    
    (ok (map-set chain-validators
      { chain-name: chain-name }
      {
        validator-address: validator-address,
        active: true,
        last-sync: stacks-block-height
      }
    ))
  )
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

(define-public (pause-bridge)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set bridge-active false)
    (ok true)
  )
)

(define-public (resume-bridge)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set bridge-active true)
    (ok true)
  )
)

;; Data Submission Functions
(define-public (submit-environmental-data 
  (source-id (string-ascii 50))
  (data-type (string-ascii 30))
  (value uint)
  (metadata (string-ascii 100))
  (source-chain (string-ascii 20)))
  (let ((data-id (var-get next-data-id)))
    (begin
      (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
      (asserts! (is-authorized-oracle tx-sender) ERR_UNAUTHORIZED)
      (asserts! (> (len source-id) u0) ERR_INVALID_PARAMETERS)
      (asserts! (> (len data-type) u0) ERR_INVALID_PARAMETERS)
      (asserts! (> value u0) ERR_INVALID_PARAMETERS)
      (asserts! (> (len metadata) u0) ERR_INVALID_PARAMETERS)
      (asserts! (> (len source-chain) u0) ERR_INVALID_PARAMETERS)
      (asserts! (is-supported-chain source-chain) ERR_UNSUPPORTED_CHAIN)
      
      (map-set environmental-data 
        { data-id: data-id }
        {
          source-id: source-id,
          data-type: data-type,
          value: value,
          timestamp: stacks-block-height,
          verified: true,
          metadata: metadata,
          source-chain: source-chain
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
  (data-source (string-ascii 50))
  (source-chain (string-ascii 20)))
  (begin
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (is-authorized-oracle tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> (len project-id) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> emissions u0) ERR_INVALID_PARAMETERS)
    (asserts! (> (len data-source) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> (len source-chain) u0) ERR_INVALID_PARAMETERS)
    (asserts! (is-eq (len verification-hash) u32) ERR_INVALID_PARAMETERS)
    (asserts! (is-supported-chain source-chain) ERR_UNSUPPORTED_CHAIN)
    
    (ok (map-set carbon-footprint-data
      { project-id: project-id }
      {
        emissions: emissions,
        timestamp: stacks-block-height,
        verification-hash: verification-hash,
        data-source: data-source,
        source-chain: source-chain
      }
    ))
  )
)

(define-public (submit-renewable-energy 
  (source-id (string-ascii 50))
  (energy-type (string-ascii 20))
  (generation-mwh uint)
  (location (string-ascii 50))
  (source-chain (string-ascii 20)))
  (begin
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (is-authorized-oracle tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> (len source-id) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> (len energy-type) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> generation-mwh u0) ERR_INVALID_PARAMETERS)
    (asserts! (> (len location) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> (len source-chain) u0) ERR_INVALID_PARAMETERS)
    (asserts! (is-supported-chain source-chain) ERR_UNSUPPORTED_CHAIN)
    
    (ok (map-set renewable-energy-data
      { source-id: source-id }
      {
        energy-type: energy-type,
        generation-mwh: generation-mwh,
        timestamp: stacks-block-height,
        location: location,
        verified: true,
        source-chain: source-chain
      }
    ))
  )
)

;; Cross-Chain Data Functions
(define-public (sync-cross-chain-data 
  (external-id (string-ascii 100))
  (chain-name (string-ascii 20))
  (local-data-id uint)
  (verification-hash (buff 32)))
  (begin
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (var-get bridge-active) ERR_BRIDGE_INACTIVE)
    (asserts! (is-authorized-oracle tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> (len external-id) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> (len chain-name) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> local-data-id u0) ERR_INVALID_PARAMETERS)
    (asserts! (is-eq (len verification-hash) u32) ERR_INVALID_PARAMETERS)
    (asserts! (is-supported-chain chain-name) ERR_UNSUPPORTED_CHAIN)
    
    (ok (map-set cross-chain-data
      { chain-name: chain-name, external-id: external-id }
      {
        local-data-id: local-data-id,
        sync-timestamp: stacks-block-height,
        verification-status: "verified"
      }
    ))
  )
)

(define-public (record-cross-chain-sync
  (source-chain (string-ascii 20))
  (target-chains (string-ascii 200))
  (data-hash (buff 32)))
  (let ((sync-id (var-get cross-chain-nonce)))
    (begin
      (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
      (asserts! (var-get bridge-active) ERR_BRIDGE_INACTIVE)
      (asserts! (is-authorized-oracle tx-sender) ERR_UNAUTHORIZED)
      (asserts! (> (len source-chain) u0) ERR_INVALID_PARAMETERS)
      (asserts! (> (len target-chains) u0) ERR_INVALID_PARAMETERS)
      (asserts! (is-eq (len data-hash) u32) ERR_INVALID_PARAMETERS)
      (asserts! (is-supported-chain source-chain) ERR_UNSUPPORTED_CHAIN)
      
      (map-set cross-chain-sync-history
        { sync-id: sync-id }
        {
          source-chain: source-chain,
          target-chains: target-chains,
          data-hash: data-hash,
          sync-timestamp: stacks-block-height,
          status: "completed"
        }
      )
      
      (var-set cross-chain-nonce (+ sync-id u1))
      (ok sync-id)
    )
  )
)

;; Data Query Functions
(define-read-only (get-environmental-data (data-id uint))
  (begin
    (asserts! (> data-id u0) ERR_INVALID_PARAMETERS)
    (match (map-get? environmental-data { data-id: data-id })
      data-entry (ok data-entry)
      ERR_DATA_NOT_FOUND
    )
  )
)

(define-read-only (get-carbon-footprint (project-id (string-ascii 50)))
  (begin
    (asserts! (> (len project-id) u0) ERR_INVALID_PARAMETERS)
    (match (map-get? carbon-footprint-data { project-id: project-id })
      carbon-data (ok carbon-data)
      ERR_DATA_NOT_FOUND
    )
  )
)

(define-read-only (get-renewable-energy-data (source-id (string-ascii 50)))
  (begin
    (asserts! (> (len source-id) u0) ERR_INVALID_PARAMETERS)
    (match (map-get? renewable-energy-data { source-id: source-id })
      energy-data (ok energy-data)
      ERR_DATA_NOT_FOUND
    )
  )
)

(define-read-only (get-cross-chain-data 
  (chain-name (string-ascii 20)) 
  (external-id (string-ascii 100)))
  (begin
    (asserts! (> (len chain-name) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> (len external-id) u0) ERR_INVALID_PARAMETERS)
    (match (map-get? cross-chain-data { chain-name: chain-name, external-id: external-id })
      chain-data (ok chain-data)
      ERR_DATA_NOT_FOUND
    )
  )
)

(define-read-only (get-chain-validator (chain-name (string-ascii 20)))
  (begin
    (asserts! (> (len chain-name) u0) ERR_INVALID_PARAMETERS)
    (match (map-get? chain-validators { chain-name: chain-name })
      validator-data (ok validator-data)
      ERR_DATA_NOT_FOUND
    )
  )
)

(define-read-only (get-sync-history (sync-id uint))
  (begin
    (asserts! (> sync-id u0) ERR_INVALID_PARAMETERS)
    (match (map-get? cross-chain-sync-history { sync-id: sync-id })
      sync-data (ok sync-data)
      ERR_DATA_NOT_FOUND
    )
  )
)

;; Data Validation Functions
(define-read-only (is-data-fresh (timestamp uint) (max-age uint))
  (begin
    (asserts! (> max-age u0) false)
    (>= timestamp (- stacks-block-height max-age))
  )
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

(define-read-only (verify-cross-chain-integrity 
  (data-hash (buff 32))
  (chain-list (list 5 (string-ascii 20))))
  (begin
    (asserts! (is-eq (len data-hash) u32) false)
    (asserts! (> (len chain-list) u0) false)
    ;; Simplified verification - in production would check multiple chain validators
    (fold verify-chain-data-helper chain-list true)
  )
)

(define-private (verify-chain-data-helper (chain-name (string-ascii 20)) (acc bool))
  (and acc (is-supported-chain chain-name))
)

;; Verification Functions
(define-read-only (verify-data-integrity 
  (data-hash (buff 32)) 
  (expected-hash (buff 32)))
  (begin
    (asserts! (is-eq (len data-hash) u32) false)
    (asserts! (is-eq (len expected-hash) u32) false)
    (is-eq data-hash expected-hash)
  )
)

;; Utility Functions
(define-read-only (get-contract-info)
  {
    active: (var-get contract-active),
    bridge-active: (var-get bridge-active),
    next-data-id: (var-get next-data-id),
    cross-chain-nonce: (var-get cross-chain-nonce),
    owner: CONTRACT_OWNER
  }
)

(define-read-only (get-current-timestamp)
  stacks-block-height
)

(define-read-only (get-supported-chains-list)
  (list 
    { chain: CHAIN_STACKS, supported: (is-supported-chain CHAIN_STACKS) }
    { chain: CHAIN_ETHEREUM, supported: (is-supported-chain CHAIN_ETHEREUM) }
    { chain: CHAIN_POLYGON, supported: (is-supported-chain CHAIN_POLYGON) }
    { chain: CHAIN_AVALANCHE, supported: (is-supported-chain CHAIN_AVALANCHE) }
    { chain: CHAIN_BSC, supported: (is-supported-chain CHAIN_BSC) }
  )
)

;; Initialize contract with owner as authorized oracle and setup supported chains
(map-set authorized-oracles CONTRACT_OWNER true)
(map-set supported-chains CHAIN_STACKS true)
(map-set supported-chains CHAIN_ETHEREUM true)
(map-set supported-chains CHAIN_POLYGON true)
(map-set supported-chains CHAIN_AVALANCHE true)
(map-set supported-chains CHAIN_BSC true)