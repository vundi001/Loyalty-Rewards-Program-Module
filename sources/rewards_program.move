module LoyaltyRewards::rewards_program {

    // Imports
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Self, Clock};

    // Errors
    const ENotOwner: u64 = 2;
    const ENotValidated: u64 = 3;
    const EAlreadyRedeemed: u64 = 4;
    const EDeadlinePassed: u64 = 6;
    const EInsufficientBalance: u64 = 7;

    // Struct definitions
    struct AdminCap has key { id: UID }

    struct Reward has key, store {
        id: UID,
        customer: address,
        points: u64,
        escrow: Balance<SUI>,
        validated: bool,
        redeemed: bool,
        created_at: u64,
        deadline: u64,
        expiry: u64, // New field for reward expiry timestamp
        tier: u8,    // New field for reward tier
        transferable: bool, // New field for reward transferability
        event_trigger: bool, // New field for event-based trigger
    }

    struct RewardCap has key {
        id: UID,
    }

    struct RedemptionReceipt has key, store {
        id: UID,
        reward: ID,
        points_redeemed: u64,    
    }

    // Module initializer
    public entry fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap {
            id: object::new(ctx),
        }, tx_context::sender(ctx));
    }

    // Accessors
    public fun get_reward_points(reward: &Reward): u64 {
        reward.points
    }

    public fun get_reward_deadline(reward: &Reward): u64 {
        reward.deadline
    }

    public fun get_reward_expiry(reward: &Reward): u64 {
        reward.expiry
    }

    public fun is_reward_validated(reward: &Reward): bool {
        reward.validated
    }

    public fun is_reward_redeemed(reward: &Reward): bool {
        reward.redeemed
    }

    public fun is_reward_transferable(reward: &Reward): bool {
        reward.transferable
    }

    public fun is_event_based_reward(reward: &Reward): bool {
        reward.event_trigger
    }

    public fun get_reward_tier(reward: &Reward): u8 {
        reward.tier
    }

    // Public - Entry functions

    public entry fun create_reward(points: u64, tier: u8, transferable: bool, event_trigger: bool, clock: &Clock, duration: u64, ctx: &mut TxContext) {
        let reward_id = object::new(ctx);
        let now = clock::timestamp_ms(clock);
        let deadline = now + duration;
        let expiry = now + (duration * 2); // Example: Reward expires 2x duration after creation
        transfer::share_object(Reward {
            id: reward_id,
            customer: tx_context::sender(ctx),
            points: points,
            escrow: balance::zero(),
            validated: false,
            redeemed: false,
            created_at: now,
            deadline: deadline,
            expiry: expiry,
            tier: tier,
            transferable: transferable,
            event_trigger: event_trigger,
        });
    }

    public entry fun validate_reward(reward: &mut Reward, ctx: &mut TxContext) {
        assert!(reward.customer == tx_context::sender(ctx), ENotOwner);
        reward.validated = true;
    }

    public entry fun add_funds_to_reward(reward: &mut Reward, amount: Coin<SUI>, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == reward.customer, ENotOwner);
        let added_balance = coin::into_balance(amount);
        balance::join(&mut reward.escrow, added_balance);
    }

    public entry fun redeem_reward(reward: &mut Reward, clock: &Clock, ctx: &mut TxContext) {
        assert!(reward.customer == tx_context::sender(ctx), ENotOwner);
        assert!(reward.validated, ENotValidated);
        assert!(!reward.redeemed, EAlreadyRedeemed);
        assert!(clock::timestamp_ms(clock) < reward.deadline, EDeadlinePassed);

        let points = reward.points;
        let escrow_amount = balance::value(&reward.escrow);
        assert!(escrow_amount > 0, EInsufficientBalance); // Ensure there are enough funds in escrow
        let escrow_coin = coin::take(&mut reward.escrow, escrow_amount, ctx);

        // Mark the reward as redeemed
        reward.redeemed = true;

        // Create a new redemption receipt
        let receipt = RedemptionReceipt {
            id: object::new(ctx),
            reward: object::id(reward),
            points_redeemed: points,
        };

        // Change accessibility of the receipt
        transfer::public_transfer(receipt, tx_context::sender(ctx));

        // Transfer funds to the customer
        transfer::public_transfer(escrow_coin, reward.customer);
    }

    // Additional functions

    public entry fun update_reward_points(reward: &mut Reward, new_points: u64, ctx: &mut TxContext) {
        assert!(reward.customer == tx_context::sender(ctx), ENotOwner);
        reward.points = new_points;
    }

    public entry fun update_reward_deadline(reward: &mut Reward, new_deadline: u64, ctx: &mut TxContext) {
        assert!(reward.customer == tx_context::sender(ctx), ENotOwner);
        reward.deadline = new_deadline;
    }

    public entry fun update_reward_expiry(reward: &mut Reward, new_expiry: u64, ctx: &mut TxContext) {
        assert!(reward.customer == tx_context::sender(ctx), ENotOwner);
        reward.expiry = new_expiry;
    }

    public entry fun update_reward_tier(reward: &mut Reward, new_tier: u8, ctx: &mut TxContext) {
        assert!(reward.customer == tx_context::sender(ctx), ENotOwner);
        reward.tier = new_tier;
    }

    public entry fun update_reward_transferability(reward: &mut Reward, transferable: bool, ctx: &mut TxContext) {
        assert!(reward.customer == tx_context::sender(ctx), ENotOwner);
        reward.transferable = transferable;
    }

    public entry fun update_reward_event_trigger(reward: &mut Reward, event_trigger: bool, ctx: &mut TxContext) {
        assert!(reward.customer == tx_context::sender(ctx), ENotOwner);
        reward.event_trigger = event_trigger;
    }

    public entry fun update_reward_redeemed(reward: &mut Reward, redeemed: bool, ctx: &mut TxContext) {
        assert!(reward.customer == tx_context::sender(ctx), ENotOwner);
        reward.redeemed = redeemed;
    }

    // New functions for querying multiple rewards

    public fun get_all_rewards_for_customer(customer: address, rewards: vector<Reward>): vector<Reward> {
        rewards.filter(fn(r) { r.customer == customer })
    }

    public fun get_rewards_by_tier(tier: u8, rewards: vector<Reward>): vector<Reward> {
        rewards.filter(fn(r) { r.tier == tier })
    }

    public fun get_expired_rewards(clock: &Clock, rewards: vector<Reward>): vector<Reward> {
        let now = clock::timestamp_ms(clock);
        rewards.filter(fn(r) { r.expiry <= now })
    }

    public fun get_valid_rewards(clock: &Clock, rewards: vector<Reward>): vector<Reward> {
        let now = clock::timestamp_ms(clock);
        rewards.filter(fn(r) { r.validated && !r.redeemed && r.deadline > now })
    }

    // Utility function to transfer a reward to another customer

    public entry fun transfer_reward(reward: &mut Reward, new_customer: address, ctx: &mut TxContext) {
        assert!(reward.customer == tx_context::sender(ctx), ENotOwner);
        assert!(reward.transferable, ENotValidated); // Assuming non-transferable rewards cannot be transferred
        reward.customer = new_customer;
    }
}
