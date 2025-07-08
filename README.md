# Multi-Signature Asset Control Contract

This Clarity smart contract implements a multi-signature wallet that requires multiple approvals before STX tokens can be transferred. It's designed for scenarios where shared control over assets is needed, such as treasury management, joint accounts, or secure fund management.

## Features

- Multiple owner management (add/remove owners)
- Configurable signature threshold
- Proposal creation with expiration dates
- Secure multi-signature execution
- Full tracking of proposal status and signatures

## How It Works

1. **Initialization**: The contract is initialized with a set of owner addresses and a signature threshold.
2. **Creating Proposals**: Any owner can create a proposal to transfer STX to a recipient.
3. **Signing Proposals**: Owners can sign proposals they agree with.
4. **Executing Proposals**: Once enough signatures are collected (meeting or exceeding the threshold), any owner can execute the proposal to transfer the funds.

## Contract Functions

### Administrative Functions

- `initialize`: Set up the initial owners and signature threshold
- `add-owner`: Add a new owner to the contract
- `remove-owner`: Remove an existing owner
- `set-threshold`: Change the number of required signatures

### Proposal Management

- `create-proposal`: Create a new transfer proposal
- `sign-proposal`: Sign an existing proposal
- `execute-proposal`: Execute a proposal that has enough signatures

### Read-Only Functions

- `get-signature-threshold`: Get the current signature threshold
- `is-owner`: Check if an address is an owner
- `get-proposal`: Get details about a specific proposal
- `get-proposal-signature-count`: Get the number of signatures for a proposal
- `has-signed`: Check if an owner has signed a specific proposal
- `get-proposal-nonce`: Get the current proposal counter

## Usage Example

```clarity
;; Initialize the contract with 3 owners and require 2 signatures
(contract-call? .asset-control initialize (list tx-sender 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG 'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC) u2)

;; Create a proposal to send 1000 STX to a recipient, expiring in 144 blocks (about 1 day)
(contract-call? .asset-control create-proposal 'ST2NEB84ASENDXKYGJPQW86YXQCEFEX2ZQPG7NBH u1000 "Treasury payment" (+ block-height u144))

;; Sign a proposal
(contract-call? .asset-control sign-proposal u0)

;; Execute a proposal after enough signatures
(contract-call? .asset-control execute-proposal u0)
```

## Security Considerations

- The contract requires at least one owner at all times
- Proposals expire after their expiration block height
- Each owner can only sign a proposal once
- Executed proposals cannot be executed again
