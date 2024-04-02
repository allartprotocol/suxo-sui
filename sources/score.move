#[allow(unused_assignment, unused_use, unused_variable, lint(share_owned))]
module sui_suxo::score {
    use std::option;
    use sui::coin::{Self, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct SCORE has drop {}
    
	fun init(witness: SCORE, ctx: &mut TxContext) {
		
		let (score_cap, score_metadata) = coin::create_currency<SCORE>(
			witness, 
			0, 
			b"SCORE", 
			b"SCORE", 
			b"Suxo Score Coin", 
			option::none(), 
			ctx
		);
		transfer::public_freeze_object(score_metadata);
		transfer::public_share_object(score_cap);
    }

    public fun mint(treasury_cap: &mut TreasuryCap<SCORE>, amount:u64, ctx: &mut TxContext) {
		coin::mint_and_transfer(treasury_cap, amount,tx_context::sender(ctx), ctx)
    }

	// TESTING
	#[test_only] use sui::test_scenario as ts;
    #[test_only] const ADMIN: address = @0xA1;
    #[test_only] const USER: address = @0xA2;
	#[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(SCORE {},ctx)
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
			let treasury_cap: TreasuryCap<SCORE> = ts::take_shared(&scenario);
			mint(&mut treasury_cap, 100,ts::ctx(&mut scenario));
			ts::return_shared(treasury_cap);
		};
		{
			ts::next_tx(&mut scenario, USER);
			let treasury_cap: TreasuryCap<SCORE> = ts::take_shared(&scenario);
			assert!(coin::total_supply(&treasury_cap) == 100, 101);
			ts::return_shared(treasury_cap);
		};
		ts::end(scenario);
	}
}
