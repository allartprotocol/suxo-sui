#[allow(unused_assignment, unused_use, unused_variable, lint(share_owned))]
module sui_suxo::life {
    use std::option;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
	use sui::object;

    struct LIFE has drop {}
    
	fun init(witness: LIFE, ctx: &mut TxContext) {
		let (life_cap, life_metadata) = coin::create_currency<LIFE>(
			witness,
			0,
			b"LIFE",
			b"LIFE",
			b"Suxo Life Coin",
			option::none(),
			ctx
		);
		transfer::public_freeze_object(life_metadata);
		transfer::public_share_object(life_cap);
    }

    public fun mint(treasury_cap: &mut TreasuryCap<LIFE>, amount: u64, ctx: &mut TxContext) {
		coin::mint_and_transfer(treasury_cap, amount, tx_context::sender(ctx), ctx)
    }

	// TESTING
	#[test_only] use sui::test_scenario as ts;
    #[test_only] const ADMIN: address = @0xA1;
    #[test_only] const USER: address = @0xA2;
	#[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(LIFE {},ctx)
    }

	#[test]
	fun test_mint(){
		let scenario = ts::begin(ADMIN);
		{
			ts::next_tx(&mut scenario, ADMIN);
			test_init(ts::ctx(&mut scenario));
		};
		{
			ts::next_tx(&mut scenario, USER);
			let treasury_cap: TreasuryCap<LIFE> = ts::take_shared(&scenario);
			mint(&mut treasury_cap, 100, ts::ctx(&mut scenario));
			ts::return_shared(treasury_cap);
		};
		{
			ts::next_tx(&mut scenario, USER);
			let treasury_cap: TreasuryCap<LIFE> = ts::take_shared(&scenario);
			assert!(coin::total_supply(&treasury_cap) == 100, 101);
			ts::return_shared(treasury_cap);
		};
		ts::end(scenario);
	}
}
