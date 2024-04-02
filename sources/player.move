#[allow(unused_assignment, unused_use, unused_variable, lint(share_owned))]
module sui_suxo::player {
    use sui::object;
	use sui::tx_context::{Self, TxContext};
	use sui::transfer;
	use std::vector;

    struct Player has key {
        id: object::UID,
		version: u64,
        score: u64,
		redeemed: u64,
    }

    public fun new(ctx: &mut TxContext): Player {
		Player { 
			id: object::new(ctx),
			version: 0, 
			score: 0 ,
			redeemed: 0,
		}
    }

	public fun get_player_version(player: &Player) : u64 {
		player.version
	}

	public fun get_player_id(player: &Player) : address {
		object::uid_to_address(&player.id)
	}

	public fun set_player_score(player: &mut Player, score: u64) {
		player.score = score;
	}
	public fun get_player_score(player: &Player) : u64 {
		player.score
	}

	public fun set_player_redeemed(player: &mut Player, redeemed: u64) {
		player.redeemed = redeemed;
	}
	public fun get_player_redeemed(player: &Player) : u64 {
		player.redeemed
	}
	
	public fun transfer_player(player: Player, ctx: &mut TxContext) {
		transfer::transfer(player, tx_context::sender(ctx));
	}



	//  Tests
	#[test_only] use sui::test_scenario as ts;
	#[test_only] const USER: address = @0xAD;

	#[test]
	fun test_create_player() {
		let scenario = ts::begin(USER);
		
		// Creating a player
		{
			ts::next_tx(&mut scenario, USER);
			let player:Player = new(ts::ctx(&mut scenario));
			transfer_player(player, ts::ctx(&mut scenario));
		};
		
		// Verify the player
		{
			ts::next_tx(&mut scenario, USER);
			let player:Player = ts::take_from_sender(&scenario);
			assert!(player.version == 0, 101);
			assert!(player.score == 0, 102);
			ts::return_to_sender(&scenario, player);
		};
		
		// Increasing score
		{
			ts::next_tx(&mut scenario, USER);
			let player:Player = ts::take_from_sender(&scenario);
			let current_score = get_player_score(&player);
			let current_redeemed = get_player_redeemed(&player);
			set_player_score(&mut player, 10 + current_score);
			set_player_redeemed(&mut player, 10 + current_redeemed);
			ts::return_to_sender(&scenario, player);
		};

		// Checking the score
		{
			ts::next_tx(&mut scenario, USER);
			let player:Player = ts::take_from_sender(&scenario);
			assert!(player.score == 10, 103);
			assert!(player.redeemed == 10, 104);
			ts::return_to_sender(&scenario, player);
		};
		ts::end(scenario);
	}
}
