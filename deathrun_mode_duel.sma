#include <amxmodx>
#include <cstrike>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <deathrun_modes>

#define PLUGIN "Deathrun Mode: Duel"
#define VERSION "0.1"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define FIRE_TIME 5

#define TASK_TURNCHANGER 100

const DUELIST_CT = 0;
const DUELIST_T = 1;

const XO_CBASEPLAYERWEAPON = 4;
const XO_CBASEPLAYER = 5;
const m_pPlayer = 41;
const m_iId = 43;
const m_flNextPrimaryAttack = 46;
const m_iClip = 51;
const m_pActiveItem = 373;

new g_iModeDuel;
new g_bDuelStarted;

new g_iDuelPlayers[2];
new g_iDuelWeapon[2];
new g_iTimer;
new g_iCurTurn;

enum 
{
	DUELTYPE_KNIFE = 0,
	DUELTYPE_DEAGLE,
	DUELTYPE_AWP
};
enum
{
	TURNDUEL_DEAGLE = 0,
	TURNDUEL_AWP
};
new g_eDuelMenuItems[][] =
{
	"Knife",
	"Deagle",
	"AWP"
};
new g_eDuelWeaponWithTurn[][] =
{
	"weapon_deagle", "weapon_awp"
};

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_clcmd("say /dd", "Command_Duel");
	register_clcmd("say /duel", "Command_Duel");
	
	for(new i; i < sizeof(g_eDuelWeaponWithTurn); i++)
	{
		RegisterHam(Ham_Weapon_PrimaryAttack, g_eDuelWeaponWithTurn[i], "Ham_WeaponPrimaryAttack_Post", true);
	}
	
	RegisterHam(Ham_TakeDamage, "player", "Ham_PlayerTakeDamage_Pre", false);
	RegisterHam(Ham_Killed, "player", "Ham_PlayerKilled_Post", true);
	
	g_iModeDuel = dr_register_mode
	(
		.Name = "Duel",
		.RoundDelay = 0,
		.CT_BlockWeapons = 1,
		.TT_BlockWeapons = 1,
		.CT_BlockButtons = 1,
		.TT_BlockButtons = 1,
		.Bhop = 1,
		.Usp = 0,
		.Hide = 1
	);
}
public Command_Duel(id)
{
	if(g_bDuelStarted || !is_user_alive(id) || cs_get_user_team(id) != CS_TEAM_CT) return PLUGIN_HANDLED;
		
	new players[32], pnum; get_players(players, pnum, "aceh", "CT");
	if(pnum > 1) return PLUGIN_HANDLED;
	
	g_iDuelPlayers[DUELIST_CT] = id;
	
	get_players(players, pnum, "aceh", "TERRORIST");
	if(pnum < 1) return PLUGIN_HANDLED;
	
	g_iDuelPlayers[DUELIST_T] = players[0];
	
	new menu = menu_create("Choose duel type:", "DuelType_Handler");
	for(new i; i < sizeof(g_eDuelMenuItems); i++)
	{
		menu_additem(menu, g_eDuelMenuItems[i]);
	}
	
	menu_display(id, menu);
	
	return PLUGIN_HANDLED;
}
public DuelType_Handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	dr_set_mode(g_iModeDuel, 1);
	
	DuelStartForward(item);
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}
DuelStartForward(type)
{
	g_bDuelStarted = true;
	
	switch(type)
	{
		case DUELTYPE_KNIFE:
		{
			PrepareWeaponDuel();
			give_item(g_iDuelPlayers[DUELIST_CT], "weapon_knife");
			give_item(g_iDuelPlayers[DUELIST_T], "weapon_knife");
		}
		case DUELTYPE_DEAGLE:
		{
			PrepareWeaponDuel();
			StartTurnDuel(TURNDUEL_DEAGLE);
		}
		case DUELTYPE_AWP:
		{
			PrepareWeaponDuel();
			StartTurnDuel(TURNDUEL_AWP);
		}
	}
}
PrepareWeaponDuel()
{
	strip_user_weapons(g_iDuelPlayers[DUELIST_CT]);
	strip_user_weapons(g_iDuelPlayers[DUELIST_T]);
	set_user_health(g_iDuelPlayers[DUELIST_CT], 100);
	set_user_health(g_iDuelPlayers[DUELIST_T], 100);
	set_user_gravity(g_iDuelPlayers[DUELIST_CT], 1.0);
	set_user_gravity(g_iDuelPlayers[DUELIST_T], 1.0);
}
StartTurnDuel(type)
{
	g_iDuelWeapon[DUELIST_CT] = give_item(g_iDuelPlayers[DUELIST_CT], g_eDuelWeaponWithTurn[type]);
	g_iDuelWeapon[DUELIST_T] = give_item(g_iDuelPlayers[DUELIST_T], g_eDuelWeaponWithTurn[type]);
	cs_set_weapon_ammo(g_iDuelWeapon[DUELIST_CT], 1);
	cs_set_weapon_ammo(g_iDuelWeapon[DUELIST_T], 0);
	
	g_iTimer = FIRE_TIME;
	g_iCurTurn = 0;
	Task_ChangeTurn();
}
public Task_ChangeTurn()
{
	if(g_iTimer > 0)
	{
		client_print(g_iDuelPlayers[g_iCurTurn], print_center, "You have %d seconds.", g_iTimer);
	}
	else
	{
		ExecuteHamB(Ham_Weapon_PrimaryAttack, g_iDuelWeapon[g_iCurTurn]);
	}

	g_iTimer--;
	set_task(1.0, "Task_ChangeTurn", TASK_TURNCHANGER);
}
public Ham_WeaponPrimaryAttack_Post(weapon)
{
	if(!g_bDuelStarted || (weapon != g_iDuelWeapon[DUELIST_CT] && weapon != g_iDuelWeapon[DUELIST_T])) return HAM_IGNORED;
	
	new player = get_pdata_cbase(weapon, m_pPlayer, XO_CBASEPLAYERWEAPON);
	
	if(player == g_iDuelPlayers[g_iCurTurn])
	{
		g_iTimer = FIRE_TIME;
		g_iCurTurn ^= 1;
		cs_set_weapon_ammo(g_iDuelWeapon[g_iCurTurn], 1);
	}
	
	return HAM_IGNORED;
}
public Ham_PlayerTakeDamage_Pre(victim, idinflictor, attacker, Float:damage, damagebits)
{
	if(!g_bDuelStarted || victim == attacker || (victim != g_iDuelPlayers[DUELIST_CT] && victim != g_iDuelPlayers[DUELIST_T])) return HAM_IGNORED;
	
	if(attacker != g_iDuelPlayers[DUELIST_CT] && attacker != g_iDuelPlayers[DUELIST_T])
	{
		return HAM_SUPERCEDE;
	}
	
	return HAM_IGNORED;
}
public Ham_PlayerKilled_Post(victim, killer)
{
	if(g_bDuelStarted && (victim == g_iDuelPlayers[DUELIST_CT] || victim == g_iDuelPlayers[DUELIST_T]))
	{
		client_print(0, print_chat, "DUEL: over, died %d, winner %d", victim, killer);
		
		g_bDuelStarted = false;
		g_iDuelPlayers[DUELIST_CT] = 0;
		g_iDuelPlayers[DUELIST_T] = 0;
		
		remove_task(TASK_TURNCHANGER);
	}
}
