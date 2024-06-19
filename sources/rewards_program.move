#[allow(unused_variable)]
module LoyaltyRewards::rewards_program {

    // Imports
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{self, Coin};
    use sui::object::{self, UID, ID};
    use sui::balance::{self, Balance};
    use sui::tx_context::{self, TxContext};
    use sui::clock::{self, Clock};

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
        expiry: u64,
        tier: u8,
        transferable: bool,
        event_trigger: bool,
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
    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap {
            id: object::new(ctx),
        }, tx_context::sender(ctx));
    }

    // Accessors
    public entry fun get_reward_points(reward: &Reward): u64 {
        reward.points
    }

    public entry fun get_reward_deadline(reward: &Reward): u64 {
        reward.deadline
    }

    public entry fun get_reward_expiry(reward: &Reward): u64 {
        reward.expiry
    }

    public entry fun is_reward_validated(reward: &Reward): bool {
        reward.validated
    }

    public entry fun is_reward_redeemed(reward: &Reward): bool {
        reward.redeemed
    }

    public entry fun is_reward_transferable(reward: &Reward): bool {
        reward.transferable
    }

    public entry fun is_event_based_reward(reward: &Reward): bool {
        reward.event_trigger
    }

    public entry fun get_reward_tier(reward: &Reward): u8 {
        reward.tier
    }

    // Public - Entry functions
    public entry fun create_reward(points: u64, tier: u8, transferable: bool, event_trigger: bool, clock: &Clock, duration: u64, ctx: &mut TxContext) {
        let reward_id = object::new(ctx);
        let deadline = clock::timestamp_ms(clock) + duration;
        let expiry = clock::timestamp_ms(clock) + (duration * 2); // Example: Reward expires 2x duration after creation
        transfer::share_object(Reward {
            id: reward_id,
            customer: tx_context::sender(ctx),
            points,
            escrow: balance::zero(),
            validated: false,
            redeemed: false,
            created_at: clock::timestamp_ms(clock),
            deadline,
            expiry,
            tier,
            transferable,
            event_trigger,
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
        assert!(escrow_amount > 0, EInsufficientBalance);
        let escrow_coin = coin::take(&mut reward.escrow, escrow_amount, ctx);

        // Mark the reward as redeemed
        reward.redeemed = true;

        // Create a new redemption receipt
        let receipt = RedemptionReceipt {
            id: object::new(ctx),
            reward: object::id(reward),
            points_redeemed: points,
        };

        // Transfer the receipt
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

    // New Feature: Transfer reward ownership
    public entry fun transfer_reward_ownership(reward: &mut Reward, new_owner: address, ctx: &mut TxContext) {
        assert!(reward.customer == tx_context::sender(ctx), ENotOwner);
        assert!(reward.transferable, ENotValidated); // Using ENotValidated as a generic error for non-transferable reward
        reward.customer = new_owner;
    }
}
