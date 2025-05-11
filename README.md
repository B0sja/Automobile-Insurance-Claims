# Automobile Insurance Claims

A decentralized application built on the Stacks blockchain for processing and verifying automobile insurance claims.

## Overview

This project provides a transparent and efficient system for managing automobile insurance policies and claims using blockchain technology. It allows insurers to issue policies, policyholders to file claims, and adjusters to process claims in a verifiable and immutable manner.

## Features

- Register insurers and claims adjusters
- Create and manage insurance policies
- File claims with evidence hashes for verification
- Assign adjusters to claims
- Process claims with approval or rejection
- Track claim status and resolution

## Smart Contract Functions

### Admin Functions
- `set-admin`: Update the contract administrator
- `register-insurer`: Register a new insurance provider

### Insurer Functions
- `register-adjuster`: Register a claims adjuster
- `create-policy`: Create a new insurance policy
- `assign-adjuster`: Assign an adjuster to a claim

### Policyholder Functions
- `file-claim`: File a new insurance claim

### Adjuster Functions
- `process-claim`: Process a claim with approval or rejection

### Read-Only Functions
- `get-policy`: Get details of an insurance policy
- `get-claim`: Get details of a specific claim
- `get-insurer`: Get information about an insurer
- `get-adjuster`: Get information about an adjuster

## Development

This project is built using Clarity, the smart contract language for the Stacks blockchain.

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet)
- [Stacks CLI](https://github.com/blockstack/stacks.js)