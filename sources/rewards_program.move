module LoyaltyRewards::rewards_program {

    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::Coin;
    use sui::object::{UID, ID};
    use sui::balance::Balance;
    use sui::tx_context::{TxContext, sender};
    use sui::clock::Clock;
    use sui::event::emit_event;

    const ENotOwner: u64 = 2;
    const ENotValidated: u64 = 3;
    const EAlreadyRedeemed: u64 = 4;
    const EDeadlinePassed: u64 = 6;
    const EInsufficientBalance: u64 = 7;
    const EInvalidPoints: u64 = 8;
    const EInvalidDuration: u64 = 9;
    const ERewardExpired: u64 = 10;
    const ENotAdmin: u64 = 11;

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

    struct RewardEvent {
        reward_id: ID,
        event_type: vector<u8>,
        timestamp: u64,
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(AdminCap {
            id: object::new(ctx),
        }, sender(ctx));
    }

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

    // Create reward - Only Admins can create rewards
    public entry fun create_reward(admin_cap: &AdminCap, points: u64, tier: u8, transferable: bool, event_trigger: bool, clock: &Clock, duration: u64, ctx: &mut TxContext) {
        assert!(points > 0, EInvalidPoints);
        assert!(duration > 0, EInvalidDuration);
        assert!(sender(ctx) == object::owner(&admin_cap.id), ENotAdmin);

        let reward_id = object::new(ctx);
        let deadline = clock::timestamp_ms(clock) + duration;
        let expiry = clock::timestamp_ms(clock) + (duration * 2);

        transfer::public_share_object(Reward {
            id: reward_id,
            customer: sender(ctx),
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
        }, sender(ctx));
    }

    // Only the reward owner can validate the reward
    public entry fun validate_reward(reward: &mut Reward, ctx: &mut TxContext) {
        assert!(reward.customer == sender(ctx), ENotOwner);
        reward.validated = true;

        emit_event(RewardEvent {
            reward_id: object::id(reward),
            event_type: b"validated".to_vec(),
            timestamp: clock::timestamp_ms(clock::Clock::global()),
        });
    }

    // Only the reward owner can add funds to the reward
    public entry fun add_funds_to_reward(reward: &mut Reward, amount: Coin<SUI>, ctx: &mut TxContext) {
        assert!(sender(ctx) == reward.customer, ENotOwner);
        let added_balance = coin::into_balance(amount);
        balance::join(&mut reward.escrow, added_balance);

        emit_event(RewardEvent {
            reward_id: object::id(reward),
            event_type: b"funds_added".to_vec(),
            timestamp: clock::timestamp_ms(clock::Clock::global()),
        });
    }

    // Ensure the reward has not expired before redeeming
    public entry fun redeem_reward(reward: &mut Reward, clock: &Clock, ctx: &mut TxContext) {
        assert!(reward.customer == sender(ctx), ENotOwner);
        assert!(reward.validated, ENotValidated);
        assert!(!reward.redeemed, EAlreadyRedeemed);
        assert!(clock::timestamp_ms(clock) < reward.deadline, EDeadlinePassed);
        assert!(clock::timestamp_ms(clock) < reward.expiry, ERewardExpired);

        let points = reward.points;
        let escrow_amount = balance::value(&reward.escrow);
        assert!(escrow_amount > 0, EInsufficientBalance);
        let escrow_coin = coin::take(&mut reward.escrow, escrow_amount, ctx);

        reward.redeemed = true;

        let receipt = RedemptionReceipt {
            id: object::new(ctx),
            reward: object::id(reward),
            points_redeemed: points,
        };

        transfer::public_share_object(receipt, sender(ctx));
        transfer::public_transfer(escrow_coin, reward.customer);

        emit_event(RewardEvent {
            reward_id: object::id(reward),
            event_type: b"redeemed".to_vec(),
            timestamp: clock::timestamp_ms(clock::Clock::global()),
        });
    }

    // Only the reward owner can update points
    public entry fun update_reward_points(reward: &mut Reward, new_points: u64, ctx: &mut TxContext) {
        assert!(reward.customer == sender(ctx), ENotOwner);
        reward.points = new_points;

        emit_event(RewardEvent {
            reward_id: object::id(reward),
            event_type: b"points_updated".to_vec(),
            timestamp: clock::timestamp_ms(clock::Clock::global()),
        });
    }

    // Only admins can update the reward deadline
    public entry fun update_reward_deadline(admin_cap: &AdminCap, reward: &mut Reward, new_deadline: u64, ctx: &mut TxContext) {
        assert!(sender(ctx) == object::owner(&admin_cap.id), ENotAdmin);
        reward.deadline = new_deadline;

        emit_event(RewardEvent {
            reward_id: object::id(reward),
            event_type: b"deadline_updated".to_vec(),
            timestamp: clock::timestamp_ms(clock::Clock::global()),
        });
    }

    // Only admins can update the reward expiry
    public entry fun update_reward_expiry(admin_cap: &AdminCap, reward: &mut Reward, new_expiry: u64, ctx: &mut TxContext) {
        assert!(sender(ctx) == object::owner(&admin_cap.id), ENotAdmin);
        reward.expiry = new_expiry;

        emit_event(RewardEvent {
            reward_id: object::id(reward),
            event_type: b"expiry_updated".to_vec(),
            timestamp: clock::timestamp_ms(clock::Clock::global()),
        });
    }

    // Only the reward owner can update the tier
    public entry fun update_reward_tier(reward: &mut Reward, new_tier: u8, ctx: &mut TxContext) {
        assert!(reward.customer == sender(ctx), ENotOwner);
        reward.tier = new_tier;

        emit_event(RewardEvent {
            reward_id: object::id(reward),
            event_type: b"tier_updated".to_vec(),
            timestamp: clock::timestamp_ms(clock::Clock::global()),
        });
    }

    // Only the reward owner can update transferability
    public entry fun update_reward_transferability(reward: &mut Reward, transferable: bool, ctx: &mut TxContext) {
        assert!(reward.customer == sender(ctx), ENotOwner);
        reward.transferable = transferable;

        emit_event(RewardEvent {
            reward_id: object::id(reward),
            event_type: b"transferability_updated".to_vec(),
            timestamp: clock::timestamp_ms(clock::Clock::global()),
        });
    }

    // Only the reward owner can update event triggers
    public entry fun update_reward_event_trigger(reward: &mut Reward, event_trigger: bool, ctx: &mut TxContext) {
        assert!(reward.customer == sender(ctx), ENotOwner);
        reward.event_trigger = event_trigger;

        emit_event(RewardEvent {
            reward_id: object::id(reward),
            event_type: b"event_trigger_updated".to_vec(),
            timestamp: clock::timestamp_ms(clock::Clock::global()),
        });
    }

    // Only admins can update the redeemed status for specific cases
    public entry fun update_reward_redeemed(admin_cap: &AdminCap, reward: &mut Reward, redeemed: bool, ctx: &mut TxContext) {
        assert!(sender(ctx) == object::owner
(&admin_cap.id), ENotAdmin);
        reward.redeemed = redeemed;

        emit_event(RewardEvent {
            reward_id: object::id(reward),
            event_type: b"redeemed_status_updated".to_vec(),
            timestamp: clock::timestamp_ms(clock::Clock::global()),
        });
    }

    // Event-based trigger example function
    public entry fun handle_event_trigger(reward: &mut Reward, event_data: vector<u8>, clock: &Clock, ctx: &mut TxContext) {
        assert!(reward.event_trigger, ENotValidated);

        // Example logic for event handling: if specific event data is received, mark reward as validated
        if event_data == b"specific_event".to_vec() {
            reward.validated = true;

            emit_event(RewardEvent {
                reward_id: object::id(reward),
                event_type: b"event_triggered".to_vec(),
                timestamp: clock::timestamp_ms(clock::Clock::global()),
            });
        }
    }
}
