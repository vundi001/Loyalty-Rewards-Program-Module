#[allow(unused_variable)]
module LoyaltyRewards::rewards_program {

    // Imports
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use std::string::String;
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Self, Clock};

    // Errors (keeping only used constants)
    const ENotOwner: u64 = 2;
    const ENotValidated: u64 = 3;
    const EAlreadyRedeemed: u64 = 4;
    const EDeadlinePassed: u64 = 6;
    const EInsufficientBalance: u64 = 7;
    const ERewardNotTransferable: u64 = 8;
    const EReferralAlreadyUsed: u64 = 9;

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
        referral_used: bool, // New field to track referral usage
    }

    struct RewardCap has key {
        id: UID,
    }

    struct RedemptionReceipt has key, store {
        id: UID,
        reward: ID,
        points_redeemed: u64,    
    }

    struct LeaderboardEntry has key, store {
        id: UID,
        customer: address,
        points: u64,
    }
    
    struct Badge has key, store {
        id: UID,
        name: String,
        description: String,
        image_url: String,
    }

    struct Challenge has key, store {
        id: UID,
        name: String,
        description: String,
        reward_points: u64,
        completion_condition: bool,
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
            points: points,
            escrow: balance::zero(),
            validated: false,
            redeemed: false,
            created_at: clock::timestamp_ms(clock),
            deadline: deadline,
            expiry: expiry,
            tier: tier,
            transferable: transferable,
            event_trigger: event_trigger,
            referral_used: false,
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

    public entry fun transfer_reward(reward: &mut Reward, new_owner: address, ctx: &mut TxContext) {
        assert!(reward.transferable, ERewardNotTransferable);
        assert!(reward.customer == tx_context::sender(ctx), ENotOwner);
        reward.customer = new_owner;
    }

    public entry fun use_referral(reward: &mut Reward, points_bonus: u64, ctx: &mut TxContext) {
        assert!(reward.customer == tx_context::sender(ctx), ENotOwner);
        assert!(!reward.referral_used, EReferralAlreadyUsed);
        reward.points = reward.points + points_bonus;
        reward.referral_used = true;
    }

    public entry fun split_reward(reward: &mut Reward, split_points: u64, clock: &Clock, ctx: &mut TxContext) {
        assert!(reward.customer == tx_context::sender(ctx), ENotOwner);
        assert!(reward.points >= split_points, EInsufficientBalance);

        let new_reward_id = object::new(ctx);
        let deadline = clock::timestamp_ms(clock) + (reward.deadline - reward.created_at);
        let expiry = clock::timestamp_ms(clock) + (reward.expiry - reward.created_at);
        reward.points = reward.points - split_points;

        transfer::share_object(Reward {
            id: new_reward_id,
            customer: reward.customer,
            points: split_points,
            escrow: balance::zero(),
            validated: reward.validated,
            redeemed: false,
            created_at: clock::timestamp_ms(clock),
            deadline: deadline,
            expiry: expiry,
            tier: reward.tier,
            transferable: reward.transferable,
            event_trigger: reward.event_trigger,
            referral_used: false,
        });
    }

    public entry fun update_leaderboard(customer: address, points: u64, ctx: &mut TxContext) {
        let leaderboard_entry = LeaderboardEntry {
            id: object::new(ctx),
            customer: customer,
            points: points,
        };
        transfer::public_transfer(leaderboard_entry, tx_context::sender(ctx));
    }

    public entry fun trigger_event_based_reward(reward: &mut Reward, event_points: u64, ctx: &mut TxContext) {
        assert!(reward.event_trigger, ENotValidated);
        reward.points = reward.points + event_points;
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

    // Gamification functions
    public entry fun create_badge(name: String, description: String, image_url: String, ctx: &mut TxContext) {
        let badge_id = object::new(ctx);
        transfer::share_object(Badge {
            id: badge_id,
            name: name,
            description: description,
            image_url: image_url,
        });
    }

    public entry fun update_badge_name(badge: &mut Badge, new_name: String, ctx: &mut TxContext) {
        badge.name = new_name;
    }

    public entry fun update_badge_description(badge: &mut Badge, new_description: String, ctx: &mut TxContext) {
        badge.description = new_description;
    }

    public entry fun update_badge_image_url(badge: &mut Badge, new_image_url: String, ctx: &mut TxContext) {
        badge.image_url = new_image_url;
    }

    public entry fun create_challenge(name: String, description: String, reward_points: u64, completion_condition: bool, ctx: &mut TxContext) {
        let challenge_id = object::new(ctx);
        transfer::share_object(Challenge {
            id: challenge_id,
            name: name,
            description: description,
            reward_points: reward_points,
            completion_condition: completion_condition,
        });
    }

    public entry fun update_challenge_name(challenge: &mut Challenge, new_name: String, ctx: &mut TxContext) {
        challenge.name = new_name;
    }

    public entry fun update_challenge_description(challenge: &mut Challenge, new_description: String, ctx: &mut TxContext) {
        challenge.description = new_description;
    }

    public entry fun update_challenge_reward_points(challenge: &mut Challenge, new_reward_points: u64, ctx: &mut TxContext) {
        challenge.reward_points = new_reward_points;
    }

    public entry fun update_challenge_completion_condition(challenge: &mut Challenge, new_completion_condition: bool, ctx: &mut TxContext) {
        challenge.completion_condition = new_completion_condition;
    }
}
