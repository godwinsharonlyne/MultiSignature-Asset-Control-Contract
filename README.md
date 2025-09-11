# Multi-Signature Asset Control Contract

This Clarity smart contract implements a multi-signature wallet that requires multiple approvals before STX tokens can be transferred. It's designed for scenarios where shared control over assets is needed, such as treasury management, joint accounts, or secure fund management.

## Features

- Multiple owner management (add/remove owners)
- Configurable signature threshold
- Proposal creation with expiration dates
- Secure multi-signature execution
- Full tracking of proposal status and signatures
- **Delegation system** - temporary signing authority transfer with limits
- Timelock system for enhanced security
- Individual spending limits with bypass mechanism
- Emergency pause/unpause functionality
- Batch proposal execution

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
- `cancel-proposal`: Cancel a proposal (only by creator)
- `execute-batch-proposals`: Execute multiple proposals in one transaction

### Delegation System

- `create-delegation`: Delegate signing authority to another principal with limits
- `revoke-delegation`: Revoke a previously created delegation
- `update-delegation-limit`: Update the amount limit for a delegation
- `sign-proposal-as-delegate`: Sign a proposal on behalf of an owner (as delegate)
- `is-delegation-active`: Check if a delegation is currently active
- `can-delegate-sign`: Check if a delegate can sign for a specific amount
- `get-delegation`: Get delegation details between owner and delegate
- `get-owner-delegates`: Get all delegates for an owner
- `get-delegate-owners`: Get all delegators for a delegate

### Timelock System

- `set-timelock-delay`: Set the delay period for timelock proposals
- `queue-proposal`: Queue a proposal for timelock execution
- `execute-timelock-proposal`: Execute a queued proposal after delay
- `cancel-queued-proposal`: Cancel a queued proposal

### Spending Limits

- `toggle-spending-limits`: Enable/disable individual spending limits
- `set-default-spending-limit`: Set default spending limit for owners
- `set-owner-spending-limit`: Set individual owner spending limit
- `execute-small-transfer`: Execute transfer within spending limits (bypass multisig)
- `create-spending-override`: Create emergency spending limit override
- `disable-spending-override`: Disable spending limit override

### Pause/Unpause System

- `create-pause-proposal`: Create proposal to pause the contract
- `sign-pause-proposal`: Sign pause proposal
- `execute-pause`: Execute pause (requires threshold signatures)
- `create-unpause-proposal`: Create proposal to unpause the contract
- `sign-unpause-proposal`: Sign unpause proposal
- `execute-unpause`: Execute unpause (requires threshold signatures)

### Read-Only Functions

- `get-signature-threshold`: Get the current signature threshold
- `is-owner`: Check if an address is an owner
- `get-proposal`: Get details about a specific proposal
- `get-proposal-signature-count`: Get the number of signatures for a proposal
- `has-signed`: Check if an owner has signed a specific proposal
- `get-proposal-nonce`: Get the current proposal counter
- `is-contract-paused`: Check if the contract is currently paused
- `get-timelock-delay`: Get the current timelock delay
- `is-proposal-ready`: Check if a queued proposal is ready for execution

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

## Delegation System Usage

The delegation system allows contract owners to temporarily delegate their signing authority to other addresses, which is useful for:

- Temporary unavailability (travel, vacation)
- Business continuity planning
- Emergency backup signers
- Organizational role delegation

```clarity
;; Create a delegation allowing a delegate to sign for up to 10,000 STX worth of proposals
;; The delegation expires in 144 blocks (about 1 day)
(contract-call? .asset-control create-delegation 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG (+ block-height u144) u10000)

;; Delegate signs a proposal on behalf of the owner
(contract-call? .asset-control sign-proposal-as-delegate u0 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Owner revokes the delegation
(contract-call? .asset-control revoke-delegation 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)
```

## Security Considerations

- The contract requires at least one owner at all times
- Proposals expire after their expiration block height
- Each owner can only sign a proposal once
- Executed proposals cannot be executed again
- Delegations have spending limits and expiration dates
- Only contract owners can create delegations
- Delegates can only sign on behalf of specific owners who delegated to them
