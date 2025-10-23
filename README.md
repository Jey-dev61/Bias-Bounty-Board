# BiasBounty Board

A decentralized bounty platform for identifying and mitigating bias in AI models and datasets, powered by community consensus on the Stacks blockchain.

## Features

- Create bounties for bias detection in AI models
- Submit detailed bias reports with evidence
- Community-driven verification through voting
- Automated reward distribution via smart contracts

## Smart Contract Functions

### Public Functions

- `create-bounty` - Post a new bias detection bounty with STX reward
- `submit-report` - Submit a bias detection report for a bounty
- `vote-on-report` - Vote for or against a submitted report
- `verify-and-pay-report` - Bounty creator verifies and releases payment

### Read-Only Functions

- `get-bounty` - Retrieve bounty details by ID
- `get-report` - Get report details including votes
- `has-voted-on-report` - Check if user voted on a report
- `get-next-bounty-id` - Get next available bounty ID

## Usage

Organizations can post bounties to incentivize bias detection in their AI systems. Community members submit reports with evidence, and the community votes on validity. Verified reports receive automatic payment.