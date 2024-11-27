# Conditional Batch Transfer Smart Contract

The Conditional Batch Transfer smart contract is a Clarity-based solution for executing multiple STX transfers in a single transaction, with built-in conditional checks and atomic execution guarantees. This contract is particularly useful for corporate payroll systems, bulk payment processing, and any scenario requiring controlled batch transfers with specific execution conditions.

## Features
- **Conditional Execution**: Multiple safety checks before processing transfers
- **Atomic Execution**: All transfers succeed or all fail together
- **Multi-signature Support**: Required for high-value transfers
- **Business Hours Restriction**: Transfers only during specified hours
- **Audit Trail**: Detailed recording of all transfer attempts
- **Balance Protection**: Buffer requirement to ensure sufficient funds
- **Performance-based Execution**: Transfers can be tied to performance metrics

## Contract Constants
```clarity
BUSINESS_START_HOUR: u9           // 9 AM
BUSINESS_END_HOUR: u17           // 5 PM
HIGH_VALUE_THRESHOLD: u50000000000 // 50,000 STX
BALANCE_BUFFER: u110             // 110% balance requirement
```

## Error Codes
- `ERR_UNAUTHORIZED (u100)`: Unauthorized access attempt
- `ERR_INVALID_TIME (u101)`: Outside business hours
- `ERR_INSUFFICIENT_BALANCE (u102)`: Insufficient balance for transfer
- `ERR_CONDITIONS_NOT_MET (u103)`: Required conditions not satisfied
- `ERR_TRANSFER_FAILED (u104)`: Transfer execution failed
- `ERR_INVALID_THRESHOLD (u105)`: Invalid threshold value

## Key Functions

### Administrative Functions

#### set-contract-owner
```clarity
(define-public (set-contract-owner (new-owner principal)))
```
Changes the contract owner. Only callable by current owner.

#### add-authorized-signer
```clarity
(define-public (add-authorized-signer (signer principal)))
```
Adds a new authorized signer for high-value transfers.

#### set-performance-metrics
```clarity
(define-public (set-performance-metrics (metrics uint)))
```
Sets performance metrics used in conditional checks.

### Core Transfer Function

#### execute-batch-transfer
```clarity
(define-public (execute-batch-transfer
    (transfers (list 50 {
        recipient: principal,
        amount: uint,
        requires-high-value-check: bool
    }))
    (signatures (list 10 principal))))
```
Main function for executing batch transfers. Requires:
- List of transfers (max 50)
- List of signatures for high-value transfers
- All conditional checks to pass

### Read-Only Functions

#### get-transfer-record
```clarity
(define-read-only (get-transfer-record (id uint)))
```
Retrieves the record of a specific transfer batch.

#### get-last-execution
```clarity
(define-read-only (get-last-execution))
```
Returns the block height of the last successful execution.

## Security Measures
1. **Multi-signature Requirement**
   - High-value transfers (>50,000 STX) require multiple authorized signatures
   - Signers must be pre-approved by contract owner

2. **Time-based Restrictions**
   - Transfers only execute during business hours (9 AM - 5 PM)
   - Based on block height calculations

3. **Balance Protection**
   - Requires 110% of total transfer amount in balance
   - Prevents insufficient funds scenarios

4. **Atomic Execution**
   - All transfers in a batch must succeed
   - Automatic rollback if any transfer fails

## Usage Guide

### 1. Initial Setup
```clarity
;; Deploy contract
;; Set contract owner (automatic in deployment)

;; Add authorized signers
(contract-call? .conditional-batch-transfer add-authorized-signer 'SIGNER_ADDRESS)

;; Set initial performance metrics if needed
(contract-call? .conditional-batch-transfer set-performance-metrics u100)
```

### 2. Preparing Transfers
```clarity
;; Example transfer list structure
(define-data-var transfers
    (list 50 {
        recipient: principal,
        amount: uint,
        requires-high-value-check: bool
    })
    (list
        {
            recipient: 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7,
            amount: u1000000000,
            requires-high-value-check: false
        }
        ;; Add more transfers...
    )
)
```

### 3. Executing Transfers
```clarity
(contract-call? .conditional-batch-transfer 
    execute-batch-transfer
    transfers
    (list tx-sender 'SECOND_SIGNER))
```

## Audit Trail
Every batch transfer execution records:
- Timestamp (block height)
- Total amount transferred
- Success/failure status
- Conditions met during execution

## Best Practices
1. Always verify recipient addresses before submission
2. Test with small amounts first
3. Ensure all signers are available for high-value transfers
4. Monitor performance metrics if using bonus payments
5. Keep track of transfer IDs for audit purposes

## Limitations
- Maximum 50 transfers per batch
- Maximum 10 signatures per high-value transfer
- Transfers only during business hours
- Contract owner must maintain authorized signers list

## Future Improvements
1. Dynamic threshold adjustments
2. Enhanced audit logging
3. Support for different token types
4. More flexible time windows
5. Advanced performance metrics integration