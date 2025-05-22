# Digital Asset Marketplace

A Clarity smart contract that enables a decentralized marketplace for digital assets (NFTs) on the Stacks blockchain.

## Features

- List NFTs for sale with customizable prices and expiry dates
- Purchase listed NFTs with automatic transfers
- Cancel active listings
- Marketplace fee system with configurable rates
- Track sales volume and seller statistics

## Functions

### Public Functions

- `create-listing`: List an NFT for sale with price and expiry
- `cancel-listing`: Cancel an active listing
- `purchase-listing`: Purchase a listed NFT
- `update-marketplace-fee`: Update the marketplace fee percentage (admin only)
- `update-fee-recipient`: Update the fee recipient address (admin only)

### Read-Only Functions

- `get-listing-details`: View details of a specific listing
- `get-seller-listings-info`: Get information about a seller's listings
- `get-marketplace-fee`: View current marketplace fee percentage
- `get-fee-recipient`: View current fee recipient address
- `get-total-volume`: View total sales volume of the marketplace

## Error Codes

- `ERR-NOT-AUTHORIZED (u100)`: User not authorized to perform action
- `ERR-LISTING-NOT-FOUND (u101)`: Listing does not exist or is inactive
- `ERR-ALREADY-LISTED (u102)`: NFT is already listed
- `ERR-INSUFFICIENT-FUNDS (u103)`: Insufficient funds for purchase
- `ERR-LISTING-EXPIRED (u104)`: Listing has expired
- `ERR-INVALID-PRICE (u105)`: Invalid price or fee value

## Marketplace Fee

The marketplace charges a 2.5% fee on all sales by default. This fee can be adjusted by the marketplace administrator.

## Usage Example

```clarity
;; List an NFT for sale
(contract-call? .digital-marketplace create-listing .my-nft u1 u1000000 (+ block-height u1440))

;; Purchase a listed NFT
(contract-call? .digital-marketplace purchase-listing u1)

;; Cancel a listing
(contract-call? .digital-marketplace cancel-listing u1)
