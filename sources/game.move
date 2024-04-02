#[allow(unused_assignment, unused_use, unused_variable, lint(share_owned), unused_const)]
module sui_suxo::game {
	use std::vector::{Self};
	use std::option::{Self, Option};
	use sui::object::{UID, Self};
	use sui::coin::{Self, Coin, TreasuryCap};
	use sui::pay::{Self};
	use sui::balance::{Self, Balance};
	use sui::tx_context::{Self, TxContext};
	use sui::transfer;
	use sui::table::{Self, Table};
	use sui_suxo::player::{Self, Player};
	use sui_suxo::score::{Self, SCORE};
	use sui_suxo::life::{Self, LIFE};
	use sui_suxo::level::{Self, Level};

	struct AdminCap has key {
		id: UID,
	}

	struct Game has key, store {
		id: UID,
		players: Table<address, address>,
		levels: vector<Level>,
		grid_width: u8,
		grid_height: u8,
		version: u64,
	}
	
	const VERSION: u64 = 1;

	// Error codes
	const PLAYER_ALREADY_EXISTS: u64 = 100;
	const PLAYER_DOES_NOT_EXIST: u64 = 101;
	const EMPTY_VECTOR: u64 = 102;
	const GAME_VERSION_MISMATCH: u64 = 103;
	const LEVEL_ALREADY_EXISTS: u64 = 104;
	const LEVEL_NOT_FOUND: u64 = 105;
	const INSUFFICIENT_FUNDS: u64 = 106;

	fun init(ctx: &mut sui::tx_context::TxContext) {
		let admin_cap = AdminCap {
			id: object::new(ctx),
		};
		let game = Game {
			id: object::new(ctx),
			players: table::new<address, address>(ctx),
			levels: vector::empty<Level>(),
			grid_width: 40,
			grid_height: 64,
			version: VERSION,
		};
		
		transfer::transfer(admin_cap, tx_context::sender(ctx));
		transfer::public_share_object(game);
	}

	entry fun add_level(admin_cap: &AdminCap,game: &mut Game, new_level: Level, ctx: &TxContext) {
		let len = vector::length(&game.levels);
		let i = 0;
		while (i < len) {
			let level = vector::borrow(&game.levels, i);
			if (level::get_level_number(level) == level::get_level_number(&new_level)) {
				abort LEVEL_ALREADY_EXISTS
			};
			i = i + 1;
		};
		vector::push_back(&mut game.levels, new_level);
	}

	entry fun remove_level_by_number(admin_cap: &AdminCap, game: &mut Game, level_number: u16, ctx: &mut TxContext) {
		let len = vector::length(&game.levels);
		let index: Option<u64> = option::none<u64>();

		let i = 0;
		while (i < len) {
			let level = vector::borrow(&game.levels, i);
			if (level::get_level_number(level) == level_number) {
				option::fill(&mut index, i);
				break
			};
			i = i + 1;
		};

		if (option::is_some(&index)) {
			let removed_level = vector::remove(&mut game.levels, option::extract(&mut index));
			level::destroy_level(removed_level, ctx);
		} 
		else {
			abort LEVEL_NOT_FOUND
		}
	}

	entry fun play_level(game:&Game, player_obj: &Player, level_number: u16, score_coins: vector<Coin<SCORE>>, score_cap: &mut TreasuryCap<SCORE>, ctx: &mut TxContext):bool {
		let level = get_level_by_number(game, level_number);
		let cost = level::get_level_cost(level);
		let len = vector::length(&score_coins);
		if(cost > 0){
			if(len == 0){
				vector::destroy_empty(score_coins);
				abort INSUFFICIENT_FUNDS
			};
			let score_coin: Coin<SCORE> = vector::pop_back(&mut score_coins);
			pay::join_vec<SCORE>(&mut score_coin, score_coins);
			coin::burn(score_cap, coin::split(&mut score_coin, cost, ctx));
			if(balance::value(coin::balance(&score_coin)) > 0) {
				transfer::public_transfer(score_coin, tx_context::sender(ctx));
			}
			else {
				coin::destroy_zero(score_coin);
			};
			return true
		}
		else{
			while (vector::length(&score_coins) > 0) {
				let score_coin: Coin<SCORE> = vector::pop_back(&mut score_coins);
				transfer::public_transfer(score_coin, tx_context::sender(ctx));
			};
			vector::destroy_empty(score_coins);
		};
		true
	}

	entry fun complete_level(game:&Game, player_obj: &mut Player, level_number: u16, player_score:u64, percent:u64, score_cap: &mut TreasuryCap<SCORE>, ctx: &mut TxContext):bool {
		let level = get_level_by_number(game, level_number);
		let reward = level::get_level_reward(level);
		let max_bonus = level::get_level_bonus(level);
		let bonus:u64 = if(percent > 950){
			max_bonus
		}
		else{
			(percent - 750) * 5 * max_bonus / 1000
		};

		score::mint(score_cap, reward + bonus, ctx);
		let current_score = player::get_player_score(player_obj);
		player::set_player_score(player_obj, current_score + player_score);
		true
	}

	entry fun create_player(game:&mut Game, ctx: &mut TxContext):bool {
		assert!(game.version == VERSION, GAME_VERSION_MISMATCH);
		assert!(table::contains(&game.players, tx_context::sender(ctx)) == false, PLAYER_ALREADY_EXISTS);
		let player_obj = player::new(ctx);
		table::add(&mut game.players, tx_context::sender(ctx), object::id_address(&player_obj));
		player::transfer_player(player_obj, ctx);
		true
	}

	entry fun increase_score(obj:&mut Player, amount:u64, score_cap: &mut TreasuryCap<SCORE>, ctx: &mut TxContext):bool {
		let current_score = player::get_player_score(obj);
		player::set_player_score(obj, current_score + amount);
		score::mint(score_cap, amount, ctx);
		true
	}

	entry fun redeem_life(score: vector<Coin<SCORE>>, life_cap: &mut TreasuryCap<LIFE>, score_cap: &mut TreasuryCap<SCORE>, ctx: &mut TxContext):bool {
		assert!(vector::length(&score) > 0, EMPTY_VECTOR);
		let life_cost: u64 = 10;
		let score_coin: Coin<SCORE> = vector::pop_back(&mut score);
		pay::join_vec<SCORE>(&mut score_coin, score);
		coin::burn(score_cap, coin::split(&mut score_coin, life_cost, ctx));
		life::mint(life_cap, 1, ctx);
		
		if(balance::value(coin::balance(&score_coin)) > 0) {
			transfer::public_transfer(score_coin, tx_context::sender(ctx));
		}
		else {
			coin::destroy_zero(score_coin);
		};
		true
	}
	
	entry fun use_life(life_coins: vector<Coin<LIFE>>, life_cap: &mut TreasuryCap<LIFE>, ctx: &mut TxContext):bool {
		assert!(vector::length(&life_coins) > 0, EMPTY_VECTOR);
		let life_coin: Coin<LIFE> = vector::pop_back(&mut life_coins);
		pay::join_vec<LIFE>(&mut life_coin, life_coins);
		coin::burn(life_cap, coin::split(&mut life_coin, 1, ctx));
		
		if(balance::value(coin::balance(&life_coin)) > 0) {
			transfer::public_transfer(life_coin, tx_context::sender(ctx));
		}
		else {
			coin::destroy_zero(life_coin);
		};
		true
	}

	fun get_level_by_number(game: &Game, level_number: u16): &Level {
		let len = vector::length(&game.levels);
		let i = 0;
		while (i < len) {
			let level = vector::borrow(&game.levels, i);
			if (level::get_level_number(level) == level_number) {
				return level
			};
			i = i + 1;
		};
		abort LEVEL_NOT_FOUND
	}

	#[test_only] use sui::test_scenario as ts;
    #[test_only] const ADMIN: address = @0xA1;
    #[test_only] const USER: address = @0xA2;

	#[test]
	fun test_init() {
		let scenario = ts::begin(ADMIN);
		{
			ts::next_tx(&mut scenario, ADMIN);
			init(ts::ctx(&mut scenario));
		};
		{
			ts::next_tx(&mut scenario, ADMIN);
			let admin_cap_option: Option<AdminCap> = option::some<AdminCap>(ts::take_from_sender<AdminCap>(&scenario));
			let game_option: Option<Game> = option::some<Game>(ts::take_shared(&scenario));
			assert!(option::is_some(&admin_cap_option), 101);
			assert!(option::is_some(&game_option), 102);
			let admin_cap = option::destroy_some(admin_cap_option);
			let game = option::destroy_some(game_option);
			ts::return_to_sender(&scenario, admin_cap);
			ts::return_shared(game);
		};
		ts::end(scenario);
	}

	#[test, expected_failure(abort_code = 100)]
	fun test_create_player() {
		let scenario = ts::begin(ADMIN);
		{
			ts::next_tx(&mut scenario, ADMIN);
			init(ts::ctx(&mut scenario));
		};
		{
			ts::next_tx(&mut scenario, USER);
			let game: Game = ts::take_shared(&scenario);
			create_player(&mut game, ts::ctx(&mut scenario));
			ts::return_shared(game);
		};
		{
			ts::next_tx(&mut scenario, USER);
			let game: Game = ts::take_shared(&scenario);
			assert!(table::length(&game.players) == 1, 103);
			let player_option: Option<Player> = option::some<Player>(ts::take_from_sender<Player>(&scenario));
			assert!(option::is_some(&player_option), 104);
			let player = option::destroy_some(player_option);
			ts::return_to_sender(&scenario, player);
			ts::return_shared(game);
		};
		{
			ts::next_tx(&mut scenario, USER);
			let game: Game = ts::take_shared(&scenario);
			create_player(&mut game, ts::ctx(&mut scenario));
			ts::return_shared(game);
		};

		ts::end(scenario);
	}

	#[test]
	fun test_gameplay() {
		let scenario = ts::begin(ADMIN);
		
		{
			ts::next_tx(&mut scenario, ADMIN);
			init(ts::ctx(&mut scenario));
			score::test_init(ts::ctx(&mut scenario));
			life::test_init(ts::ctx(&mut scenario));
		};
		{
			ts::next_tx(&mut scenario, ADMIN);
			level::create_level(1, 10, 15, 20, ts::ctx(&mut scenario));
		};
		{
			ts::next_tx(&mut scenario, ADMIN);
			let game: Game = ts::take_shared(&scenario);
			let admin_cap: AdminCap = ts::take_from_sender<AdminCap>(&scenario);
			let level = ts::take_from_sender<Level>(&scenario);
			add_level(&admin_cap, &mut game, level, ts::ctx(&mut scenario));
			ts::return_to_sender(&scenario, admin_cap);
			ts::return_shared(game);
		};
		{
			ts::next_tx(&mut scenario, USER);
			let game: Game = ts::take_shared(&scenario);
			assert!(table::length(&game.players) == 0, 106);
			create_player(&mut game, ts::ctx(&mut scenario));
			ts::return_shared(game);
		};
		{
			ts::next_tx(&mut scenario, USER);
			let game: Game = ts::take_shared(&scenario);
			let player = ts::take_from_sender<Player>(&scenario);
			let score_cap: TreasuryCap<SCORE> = ts::take_shared(&scenario);
			assert!(table::length(&game.players) > 0, 106);
			increase_score(&mut player, 10, &mut score_cap, ts::ctx(&mut scenario));
			
			ts::return_to_sender(&scenario, player);
			ts::return_shared(score_cap);
			ts::return_shared(game);
		};
		{
			ts::next_tx(&mut scenario, USER);
			let game: Game = ts::take_shared(&scenario);
			let player = ts::take_from_sender<Player>(&scenario);
			let score_cap: TreasuryCap<SCORE> = ts::take_shared(&scenario);
			let score: Coin<SCORE> = ts::take_from_sender<Coin<SCORE>>(&scenario);
			let score_coins = vector::empty<Coin<SCORE>>();
			vector::push_back(&mut score_coins, score);
			let result = play_level(&game, &player, 1, score_coins, &mut score_cap, ts::ctx(&mut scenario));
			assert!(result == true, 107);
			ts::return_to_sender(&scenario, player);
			ts::return_shared(score_cap);
			ts::return_shared(game);
		};

		ts::end(scenario);
	}

	#[test, expected_failure(abort_code = 3)]
	fun test_level_creation() {
		let scenario = ts::begin(ADMIN);
		
		{
			ts::next_tx(&mut scenario, ADMIN);
			init(ts::ctx(&mut scenario));
			level::test_init(ts::ctx(&mut scenario));
		};
		{
			ts::next_tx(&mut scenario, ADMIN);
			level::create_level(1, 10, 15, 20, ts::ctx(&mut scenario));
		};
		{
			ts::next_tx(&mut scenario, ADMIN);
			
			let game: Game = ts::take_shared(&scenario);
			let admin_cap: AdminCap = ts::take_from_sender<AdminCap>(&scenario);
			let level_option: Option<Level> = option::some<Level>(ts::take_from_sender<Level>(&scenario));
			assert!(option::is_some(&level_option), 100);
			let level = option::destroy_some(level_option);
			assert!(level::get_level_number(&level) == 1, 101);
			add_level(&admin_cap, &mut game, level, ts::ctx(&mut scenario));

			ts::return_to_sender(&scenario, admin_cap);
			ts::return_shared(game);
		};
		{
			ts::next_tx(&mut scenario, ADMIN);
			
			let game: Game = ts::take_shared(&scenario);
			assert!(vector::length(&game.levels) == 1, 102);
			ts::return_shared(game);
		};
		{
			ts::next_tx(&mut scenario, ADMIN);
			
			let level_option: Option<Level> = option::some<Level>(ts::take_from_sender<Level>(&scenario));
			assert!(option::is_none(&level_option), 100);
			option::destroy_none(level_option);
		};
		ts::end(scenario);
	}

}

