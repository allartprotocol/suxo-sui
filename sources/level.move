#[allow(unused_assignment, unused_use, unused_variable, lint(share_owned))]
module sui_suxo::level {
	use std::vector::{Self};
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
	
	struct LevelCap has key {
		id: UID,
	}
	
	struct Level has key, store {
		id: UID,
		level_number: u16,
		cost: u64,
		reward: u64,
		bonus: u64,
		enemies: vector<Enemy>,
		spies: vector<Spy>,
	}
	public fun get_level_number(level: &Level): u16 {
		level.level_number
	}
	public fun get_level_cost(level: &Level): u64 {
		level.cost
	}
	public fun get_level_reward(level: &Level): u64 {
		level.reward
	}
	public fun get_level_bonus(level: &Level): u64 {
		level.bonus
	}

	struct Enemy has key, store {
		id: UID,
		type: vector<u8>,
		count: u8,
		speed: u64,
	}
	struct Spy has key, store {
		id: UID,
		count: u8,
		speed: u64,
	}

	const LEVELS_EINDEX_OUT_OF_BOUNDS: u64 = 100;

	fun init(ctx: &mut sui::tx_context::TxContext) {
		let level_cap = LevelCap {
			id: object::new(ctx),
		};
		transfer::transfer(level_cap, tx_context::sender(ctx));
	}

	public entry fun create_level(level_number:u16, cost:u64, reward:u64, bonus:u64, ctx: &mut TxContext) {
		let level = Level {
			id: object::new(ctx),
			level_number: level_number,
			cost: cost,
			reward: reward,
			bonus: bonus,
			enemies: vector::empty(),
			spies: vector::empty(),
		};
		transfer::transfer(level, tx_context::sender(ctx));
	}

	public entry fun destroy_level(level: Level, ctx: &mut TxContext) {
		while(vector::length(&level.enemies) > 0) {
			remove_enemy(&mut level, 0, ctx);
		};
		while(vector::length(&level.spies) > 0) {
			remove_spy(&mut level, 0, ctx);
		};
		let Level { 
			id, 
			enemies, 
			spies, 
			level_number: _, 
			cost: _, 
			reward: _,
			bonus: _,
		} = level;
		vector::destroy_empty(enemies);
		vector::destroy_empty(spies);
		object::delete(id);
	}

	public entry fun add_enemy(level: &mut Level, type: vector<u8>, count: u8, speed: u64, ctx: &mut TxContext) {
		let enemy = Enemy {
			id: object::new(ctx),
			type: type,
			count: count,
			speed: speed,
		};
		vector::push_back(&mut level.enemies, enemy);
	}

	public entry fun remove_enemy(level: &mut Level, index: u64, ctx: &mut TxContext) {
		assert!(index < vector::length(&level.enemies), LEVELS_EINDEX_OUT_OF_BOUNDS);
		let Enemy { id, type, count, speed } = vector::remove(&mut level.enemies, index);
		object::delete(id);
	}

	public entry fun add_spy(level: &mut Level, count: u8, speed: u64, ctx: &mut TxContext) {
		let spy = Spy {
			id: object::new(ctx),
			count: count,
			speed: speed,
		};
		vector::push_back(&mut level.spies, spy);
	}

	public entry fun remove_spy(level: &mut Level, index: u64, ctx: &mut TxContext) {
		assert!(index < vector::length(&level.spies), LEVELS_EINDEX_OUT_OF_BOUNDS);
		let Spy { id, count, speed } = vector::remove(&mut level.spies, index);
		object::delete(id);
	}


	#[test_only] use sui::test_scenario as ts;
	#[test_only] use std::option::{Self, Option};
    #[test_only] const ADMIN: address = @0xA1;
    #[test_only] const USER: address = @0xA2;

	#[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx)
    }

	#[test]
	fun test_domain() {
		let scenario = ts::begin(ADMIN);
		{
			ts::next_tx(&mut scenario, ADMIN);
			test_init(ts::ctx(&mut scenario));
		};
		{
			ts::next_tx(&mut scenario, ADMIN);
			let level_cap_option: Option<LevelCap> = option::some<LevelCap>(ts::take_from_sender<LevelCap>(&scenario));
			assert!(option::is_some(&level_cap_option), 101);
			let level_cap = option::destroy_some(level_cap_option);
			create_level(1, 10, 15, 20, ts::ctx(&mut scenario));
			ts::return_to_sender(&scenario, level_cap);
		};
		{
			ts::next_tx(&mut scenario, ADMIN);
			let level: Option<Level> = option::some<Level>(ts::take_from_sender<Level>(&scenario));
			assert!(option::is_some(&level), 102);
			let level = option::destroy_some(level);
			assert!(level.level_number == 1, 103);
			assert!(vector::length(&level.enemies) == 0, 104);
			assert!(vector::length(&level.spies) == 0, 105);
			
			add_enemy(&mut level, b"standard", 1, 1000, ts::ctx(&mut scenario));
			
			ts::return_to_sender(&scenario, level);
		};
		{
			ts::next_tx(&mut scenario, ADMIN);
			let level: Level = ts::take_from_sender(&scenario);
			assert!(vector::length(&level.enemies) == 1, 106);
			remove_enemy(&mut level, 0, ts::ctx(&mut scenario));
			ts::return_to_sender(&scenario, level);
		};
		{
			ts::next_tx(&mut scenario, ADMIN);
			let level: Level = ts::take_from_sender(&scenario);
			assert!(vector::length(&level.enemies) == 0, 107);
			
			add_spy(&mut level, 1, 2000, ts::ctx(&mut scenario));
			
			ts::return_to_sender(&scenario, level);
		};
		{
			ts::next_tx(&mut scenario, ADMIN);
			let level: Level = ts::take_from_sender(&scenario);
			assert!(vector::length(&level.spies) == 1, 108);
			remove_spy(&mut level, 0, ts::ctx(&mut scenario));
			ts::return_to_sender(&scenario, level);
		};
		{
			ts::next_tx(&mut scenario, ADMIN);
			let level: Level = ts::take_from_sender(&scenario);
			assert!(vector::length(&level.spies) == 0, 109);
			ts::return_to_sender(&scenario, level);
		};
		ts::end(scenario);
	}

}


