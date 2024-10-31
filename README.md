# Bitcoin-Stacks Bridge Contract

A secure cross-chain bridge enabling trustless transfers between Bitcoin and Stacks networks. This smart contract implements a robust validation system with multi-signature support for secure cross-chain transactions.

## Features

- **Secure Cross-Chain Transfers**: Enable trustless transfers between Bitcoin and Stacks networks
- **Multi-Validator Architecture**: Distributed trust model with multiple validators
- **Comprehensive Security Controls**:
  - Input validation for all critical parameters
  - Safe arithmetic operations
  - Multiple security checks for transactions
  - Audit trail for validator operations
- **Emergency Controls**: Includes pause mechanism and emergency withdrawal functions
- **Configurable Parameters**: Adjustable minimum/maximum deposit amounts and confirmation requirements

## Technical Specifications

### Constants

- Minimum Deposit: 0.001 BTC (100,000 sats)
- Maximum Deposit: 10 BTC (1,000,000,000 sats)
- Required Confirmations: 6 blocks

### Error Codes

```clarity
ERR-NOT-AUTHORIZED (1000)           - Unauthorized access attempt
ERR-INVALID-AMOUNT (1001)           - Amount outside allowed range
ERR-INSUFFICIENT-BALANCE (1002)     - Insufficient funds for operation
ERR-INVALID-BRIDGE-STATUS (1003)    - Invalid bridge state
ERR-INVALID-SIGNATURE (1004)        - Invalid signature provided
ERR-ALREADY-PROCESSED (1005)        - Transaction already processed
ERR-BRIDGE-PAUSED (1006)           - Bridge is currently paused
ERR-INVALID-VALIDATOR-ADDRESS (1007) - Invalid validator address
ERR-INVALID-RECIPIENT-ADDRESS (1008) - Invalid recipient address
ERR-INVALID-BTC-ADDRESS (1009)      - Invalid Bitcoin address
ERR-INVALID-TX-HASH (1010)          - Invalid transaction hash
ERR-INVALID-SIGNATURE-FORMAT (1011)  - Invalid signature format
```

## Core Functions

### Administrative Functions

```clarity
(initialize-bridge)     - Initialize the bridge contract
(pause-bridge)         - Pause bridge operations
(resume-bridge)        - Resume bridge operations
(add-validator)        - Add a new validator
(remove-validator)     - Remove an existing validator
```

### User Functions

```clarity
(initiate-deposit)     - Initiate a deposit from Bitcoin
(confirm-deposit)      - Confirm a deposit with validator signature
(withdraw)            - Withdraw funds to Bitcoin
```

### Query Functions

```clarity
(get-deposit)          - Get deposit details
(get-bridge-status)    - Get bridge operational status
(get-validator-status) - Check validator status
(get-balance)         - Get user balance
(verify-signature)     - Verify validator signature
```

## Security Features

1. **Input Validation**

   - Principal address validation
   - Bitcoin address format checking
   - Transaction hash verification
   - Signature format validation

2. **Safe Operations**

   - Overflow protection in arithmetic operations
   - Balance checks before transfers
   - Duplicate transaction prevention

3. **Access Control**

   - Owner-only administrative functions
   - Validator-only confirmation functions
   - Protection against contract targeting

4. **Audit Trail**
   - Validator operations logging
   - Transaction history tracking
   - Timestamp recording for operations

## Usage Flow

1. **Deposit Process**:

   ```
   Bitcoin Transaction → Initiate Deposit → Validator Confirmation → Funds Available
   ```

2. **Withdrawal Process**:
   ```
   Withdrawal Request → Balance Check → Event Emission → Off-chain Processing
   ```

## Emergency Procedures

1. **Bridge Pause**

   - Owner can pause all operations in case of emergency
   - Existing balances remain secure
   - Only owner can resume operations

2. **Emergency Withdrawal**
   - Owner can process emergency withdrawals
   - Includes balance and recipient validation
   - Protected against overflow attacks

## Development and Testing

### Prerequisites

- Clarity CLI
- Bitcoin node (for testing)
- Stacks node (for deployment)

### Deployment Steps

1. Deploy contract to Stacks network
2. Initialize bridge
3. Add initial validators
4. Verify bridge status

## Security Considerations

- Keep private keys secure
- Regular validation of bridge state
- Monitor transaction confirmations
- Regular security audits recommended

## License

This smart contract is released under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact

For bug reports and feature requests, please open an issue in the repository.
