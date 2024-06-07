# Loyalty Rewards Program Module

The Loyalty Rewards Program module facilitates the management of customer rewards within a decentralized system, enabling businesses to incentivize customer engagement and loyalty effectively. This module offers functionalities for creating rewards, validating them, adding funds, redeeming rewards, and updating reward attributes.

## Struct Definitions

### AdminCap
- **id**: Unique identifier granting administrative privileges within the rewards tracking system.

### Reward
- **id**: Unique identifier for each reward.
- **customer**: Address of the customer associated with the reward.
- **points**: Total points accumulated by the customer.
- **escrow**: Balance of SUI tokens held in escrow for the reward.
- **validated**: Boolean indicating if the reward has been validated.
- **redeemed**: Boolean indicating if the reward has been redeemed.
- **created_at**: Timestamp when the reward was created.
- **deadline**: Timestamp by which the reward must be redeemed.
- **expiry**: Timestamp indicating the expiry of the reward.
- **tier**: Tier level associated with the reward.
- **transferable**: Boolean indicating if the reward can be transferred.
- **event_trigger**: Boolean indicating if the reward is triggered by an event.

### RewardCap
- **id**: Unique identifier for capabilities related to reward management.

### RedemptionReceipt
- **id**: Unique identifier for each redemption receipt.
- **reward**: ID of the associated reward.
- **points_redeemed**: Points redeemed by the customer as recorded in the receipt.

## Public - Entry Functions

### create_reward
Creates a new reward with specified points, tier, transferability, and event trigger, setting deadlines and expiry times.

### validate_reward
Validates a reward, confirming ownership and marking it as validated.

### add_funds_to_reward
Allows adding SUI coins to a reward's escrow balance, restricted to the reward's owner.

### redeem_reward
Redeems a validated reward, transferring escrowed funds to the customer and marking the reward as redeemed.

### get_reward_points
Retrieves the total points associated with a reward.

### get_reward_deadline
Retrieves the deadline by which a reward must be redeemed.

### get_reward_expiry
Retrieves the expiry timestamp of a reward.

### is_reward_validated
Checks if a reward has been validated.

### is_reward_redeemed
Checks if a reward has been redeemed.

### is_reward_transferable
Checks if a reward is transferable.

### is_event_based_reward
Checks if a reward is triggered by an event.

### get_reward_tier
Retrieves the tier level associated with a reward.

## Additional Functions

### update_reward_points
Allows updating the total points associated with a reward.

### update_reward_deadline
Allows updating the deadline for redeeming a reward.

### update_reward_expiry
Allows updating the expiry timestamp of a reward.

### update_reward_tier
Allows updating the tier level associated with a reward.

### update_reward_transferability
Allows updating the transferability status of a reward.

### update_reward_event_trigger
Allows updating the event trigger status of a reward.

### update_reward_redeemed
Allows updating the redemption status of a reward.

## Setup

### Prerequisites

1. **Rust and Cargo**: Install Rust and Cargo on your development machine by following the official Rust installation instructions.

2. **SUI Blockchain**: Set up a local instance of the SUI blockchain for development and testing purposes. Refer to the SUI documentation for installation instructions.

### Build and Deploy

1. Clone the Loyalty Rewards Program repository and navigate to the project directory on your local machine.

2. Compile the smart contract code using the Rust compiler:

   ```bash
   cargo build --release
   ```

3. Deploy the compiled smart contract to your local SUI blockchain node using the SUI CLI or other deployment tools.

4. Note the contract address and other relevant identifiers for interacting with the deployed contract.

## Usage

### Creating a Reward

To create a new reward, invoke the `create_reward` function with specified parameters such as points, tier, transferability, event trigger, and duration.

### Validating a Reward

Validate a reward using the `validate_reward` function, ensuring ownership and confirming the reward's validity.

### Adding Funds to a Reward

Add SUI coins to a reward's escrow balance using the `add_funds_to_reward` function, restricted to the reward's owner.

### Redeeming a Reward

Redeem a validated reward by invoking the `redeem_reward` function, transferring escrowed funds to the customer and marking the reward as redeemed.

### Managing Reward Attributes

Update reward attributes such as points, deadline, expiry, tier, transferability, event trigger, and redemption status using respective update functions.

## Interacting with the Smart Contract

### Using the SUI CLI

1. Utilize the SUI CLI to interact with the deployed smart contract, providing function arguments and transaction contexts as required.

2. Monitor transaction outputs and blockchain events to track reward creations, validations, redemptions, and attribute updates.

### Using Web Interfaces (Optional)

1. Develop web interfaces or applications that interact with the smart contract using JavaScript libraries such as Web3.js or Ethers.js.

2. Implement user-friendly interfaces for managing customer rewards, tracking reward details, and monitoring reward transactions within the Loyalty Rewards Program platform.

## Conclusion

The Loyalty Rewards Program Smart Contract module provides a robust solution for managing customer rewards in a decentralized environment. By leveraging blockchain technology, businesses can effectively incentivize customer loyalty while ensuring transparency, security, and accountability in reward management processes. This module serves as a foundational component for implementing loyalty programs that drive customer engagement and retention strategies.