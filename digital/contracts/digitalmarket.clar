;; Digital Asset Marketplace (Improved)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-LISTING-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-LISTED (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-LISTING-EXPIRED (err u104))
(define-constant ERR-INVALID-PRICE (err u105))
(define-constant ERR-INVALID-NFT-CONTRACT (err u106))
(define-constant ERR-INVALID-TOKEN-ID (err u107))
(define-constant ERR-INVALID-LISTING-ID (err u108))
(define-constant ERR-INVALID-EXPIRY (err u109))

;; NFT trait
(define-trait nft-trait
  (
    (transfer (uint principal principal) (response bool uint))
    (get-owner (uint) (response principal uint))
    (get-last-token-id () (response uint uint))
  )
)

;; Data structures
(define-map listings
  {listing-id: uint}
  {
    seller: principal,
    nft-contract: principal,
    token-id: uint,
    price: uint,
    expiry: uint,
    is-active: bool
  }
)

(define-map seller-listings
  {seller: principal}
  {
    listing-count: uint,
    active-listings: uint
  }
)

(define-map nft-contracts
  principal
  bool
)

(define-map active-nft-listings
  {nft-contract: principal, token-id: uint}
  bool
)

;; Storage variables
(define-data-var next-listing-id uint u0)
(define-data-var marketplace-fee uint u25) ;; 2.5% fee (out of 1000)
(define-data-var fee-recipient principal tx-sender)
(define-data-var total-volume uint u0)

;; Helper functions
(define-private (is-valid-listing-id (listing-id uint))
  (and (> listing-id u0) (<= listing-id (var-get next-listing-id)))
)

(define-private (is-valid-price (price uint))
  (> price u0)
)

(define-private (is-valid-expiry (expiry uint))
  (> expiry stacks-block-height)
)

;; Register NFT contract
(define-public (register-nft-contract (nft-contract-principal principal))
  (ok (map-set nft-contracts nft-contract-principal true))
)

;; Create listing
(define-public (create-listing 
  (nft-contract <nft-trait>)
  (token-id uint)
  (price uint)
  (expiry uint)
)
  (begin
    (asserts! (is-valid-price price) ERR-INVALID-PRICE)
    (asserts! (is-valid-expiry expiry) ERR-INVALID-EXPIRY)

    (let (
      (seller tx-sender)
      (nft-principal (contract-of nft-contract))
      (token-owner (unwrap! (contract-call? nft-contract get-owner token-id) ERR-INVALID-TOKEN-ID))
    )
      (asserts! (is-eq token-owner seller) ERR-NOT-AUTHORIZED)
      (asserts! (not (default-to false (map-get? active-nft-listings {nft-contract: nft-principal, token-id: token-id}))) ERR-ALREADY-LISTED)

      (map-set nft-contracts nft-principal true)

      (let (
        (listing-id (+ (var-get next-listing-id) u1))
        (seller-data (default-to {listing-count: u0, active-listings: u0} (map-get? seller-listings {seller: seller})))
      )
        (map-set listings {listing-id: listing-id}
          {
            seller: seller,
            nft-contract: nft-principal,
            token-id: token-id,
            price: price,
            expiry: expiry,
            is-active: true
          }
        )

        (map-set active-nft-listings {nft-contract: nft-principal, token-id: token-id} true)

        (map-set seller-listings {seller: seller}
          {
            listing-count: (+ (get listing-count seller-data) u1),
            active-listings: (+ (get active-listings seller-data) u1)
          }
        )

        (var-set next-listing-id listing-id)
        (ok listing-id)
      )
    )
  )
)

;; Cancel listing
(define-public (cancel-listing (listing-id uint))
  (begin
    (asserts! (is-valid-listing-id listing-id) ERR-INVALID-LISTING-ID)

    (let (
      (listing (unwrap! (map-get? listings {listing-id: listing-id}) ERR-LISTING-NOT-FOUND))
      (seller (get seller listing))
    )
      (asserts! (is-eq tx-sender seller) ERR-NOT-AUTHORIZED)
      (asserts! (get is-active listing) ERR-LISTING-NOT-FOUND)

      (map-set listings {listing-id: listing-id} (merge listing {is-active: false}))
      (map-delete active-nft-listings {nft-contract: (get nft-contract listing), token-id: (get token-id listing)})

      (let (
        (seller-data (unwrap-panic (map-get? seller-listings {seller: seller})))
      )
        (map-set seller-listings {seller: seller}
          {
            listing-count: (get listing-count seller-data),
            active-listings: (- (get active-listings seller-data) u1)
          }
        )
      )
      (ok true)
    )
  )
)

;; Purchase listing
(define-public (purchase-listing (nft-contract <nft-trait>) (listing-id uint))
  (begin
    (asserts! (is-valid-listing-id listing-id) ERR-INVALID-LISTING-ID)

    (let (
      (listing (unwrap! (map-get? listings {listing-id: listing-id}) ERR-LISTING-NOT-FOUND))
      (buyer tx-sender)
      (seller (get seller listing))
      (price (get price listing))
      (nft-contract-principal (get nft-contract listing))
      (token-id (get token-id listing))
      (fee-amount (/ (* price (var-get marketplace-fee)) u1000))
      (seller-amount (- price fee-amount))
    )
      (asserts! (get is-active listing) ERR-LISTING-NOT-FOUND)
      (asserts! (<= stacks-block-height (get expiry listing)) ERR-LISTING-EXPIRED)
      (asserts! (default-to false (map-get? nft-contracts nft-contract-principal)) ERR-INVALID-NFT-CONTRACT)

      ;; Update state before external calls
      (map-set listings {listing-id: listing-id} (merge listing {is-active: false}))
      (map-delete active-nft-listings {nft-contract: nft-contract-principal, token-id: token-id})

      (let (
        (seller-data (unwrap-panic (map-get? seller-listings {seller: seller})))
      )
        (map-set seller-listings {seller: seller}
          {
            listing-count: (get listing-count seller-data),
            active-listings: (- (get active-listings seller-data) u1)
          }
        )
      )

      (var-set total-volume (+ (var-get total-volume) price))

      ;; Transfers
      (try! (stx-transfer? seller-amount buyer seller))
      (try! (stx-transfer? fee-amount buyer (var-get fee-recipient)))
      (try! (contract-call? nft-contract transfer token-id seller buyer))

      (ok true)
    )
  )
)

;; Admin functions
(define-public (update-marketplace-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get fee-recipient)) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee u100) ERR-INVALID-PRICE)
    (var-set marketplace-fee new-fee)
    (ok true)
  )
)

(define-public (update-fee-recipient (new-recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get fee-recipient)) ERR-NOT-AUTHORIZED)
    (var-set fee-recipient new-recipient)
    (ok true)
  )
)

;; Read-only views
(define-read-only (get-listing-details (listing-id uint))
  (if (not (is-valid-listing-id listing-id))
      ERR-INVALID-LISTING-ID
      (match (map-get? listings {listing-id: listing-id})
        listing (ok listing)
        ERR-LISTING-NOT-FOUND
      )
  )
)

(define-read-only (get-seller-listings-info (seller principal))
  (default-to {listing-count: u0, active-listings: u0} (map-get? seller-listings {seller: seller}))
)

(define-read-only (get-marketplace-fee)
  (var-get marketplace-fee)
)

(define-read-only (get-fee-recipient)
  (var-get fee-recipient)
)

(define-read-only (get-total-volume)
  (var-get total-volume)
)