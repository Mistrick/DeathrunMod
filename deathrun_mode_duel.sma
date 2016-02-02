#include <amxmodx>
#include <cstrike>
#include <fun>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <deathrun_modes>
#include <xs>

#define PLUGIN "Deathrun Mode: Duel"
#define VERSION "0.2"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define FIRE_TIME 5

#define TASK_TURNCHANGER 100

new const SPAWNS_DIR[] = "deathrun_duel";

const XO_CBASEPLAYERWEAPON = 4;
const m_pPlayer = 41;

enum
{
	DUELIST_CT = 0,
	DUELIST_T
}

new g_iModeDuel;
new g_bDuelStarted;
new g_iDuelPlayers[2];
new g_iDuelWeapon[2];
new g_iTimer;
new g_iCurTurn;

new Float:g_fDuelSpawnOrigins[2][3];
new Float:g_fDuelSpawnAngles[2][3];
new g_bShowSpawns;
new g_bLoadedSpawns;
new g_szSpawnsFile[128];

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
	register_clcmd("duel_spawns", "Command_DuelSpawn", ADMIN_CFG);
	
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
public plugin_cfg()
{
	LoadSpawns();
}
LoadSpawns()
{
	new szConfigDir[128]; get_localinfo("amxx_configsdir", szConfigDir, charsmax(szConfigDir));
	new szDir[128]; formatex(szDir, charsmax(szDir), "%s/%s", szConfigDir, SPAWNS_DIR);
	
	if(dir_exists(szDir))
	{
		new szMap[32]; get_mapname(szMap, charsmax(szMap));
		formatex(g_szSpawnsFile, charsmax(g_szSpawnsFile), "%s/%s.ini", szDir, szMap);
		
		if(file_exists(g_szSpawnsFile))
		{
			new f = fopen(g_szSpawnsFile, "rt");
			
			if(f)
			{
				new szText[128], szTeam[3], szOrigins[3][16];
				while(!feof(f))
				{
					fgets(f, szText, charsmax(szText));
					parse(szText, szTeam, charsmax(szTeam), szOrigins[0], charsmax(szOrigins[]), szOrigins[1], charsmax(szOrigins[]), szOrigins[2], charsmax(szOrigins[]));
					new team = szTeam[0] == 'C' ? 0 : 1;
					g_fDuelSpawnOrigins[team][0] = str_to_float(szOrigins[0]);
					g_fDuelSpawnOrigins[team][1] = str_to_float(szOrigins[1]);
					g_fDuelSpawnOrigins[team][2] = str_to_float(szOrigins[2]);
				}
				fclose(f);
				if(g_fDuelSpawnOrigins[DUELIST_CT][0] != 0.0 && g_fDuelSpawnOrigins[DUELIST_T][0] != 0.0)
				{
					g_bLoadedSpawns = true;
					GetSpawnAngles();
				}
			}
		}
		else
		{
			FindSpawns();
		}
	}
	else
	{
		mkdir(szDir);
		FindSpawns();
	}
}
FindSpawns()
{
	new first_ent = find_ent_by_class(-1, "info_player_start");
	pev(first_ent, pev_origin, g_fDuelSpawnOrigins[DUELIST_CT]);
	new ent = first_ent, bFind;
	while((ent = find_ent_by_class(ent, "info_player_start")))
	{
		if(get_entity_distance(ent, first_ent) > 150.0)
		{
			bFind = true;
			pev(ent, pev_origin, g_fDuelSpawnOrigins[DUELIST_T]);
			break;
		}
	}
	if(bFind)
	{
		g_bLoadedSpawns = true;
		GetSpawnAngles();
	}
}
GetSpawnAngles()
{
	new Float:fVector[3]; xs_vec_sub(g_fDuelSpawnOrigins[DUELIST_T], g_fDuelSpawnOrigins[DUELIST_CT], fVector);
	xs_vec_normalize(fVector, fVector);
	vector_to_angle(fVector, g_fDuelSpawnAngles[DUELIST_CT]);
	xs_vec_mul_scalar(fVector, -1.0, fVector);
	vector_to_angle(fVector, g_fDuelSpawnAngles[DUELIST_T]);
}
public client_disconnect(id)
{
	if(g_bDuelStarted && (id == g_iDuelPlayers[DUELIST_CT] || id == g_iDuelPlayers[DUELIST_T]))
	{
		g_bDuelStarted = false;
		g_iDuelPlayers[DUELIST_CT] = 0;
		g_iDuelPlayers[DUELIST_T] = 0;
		remove_task(TASK_TURNCHANGER);
	}
}
public Command_DuelSpawn(id, flag)
{
	if(~get_user_flags(id) & flag) return PLUGIN_HANDLED;
	
	new menu = menu_create("Duel Spawn Control", "DuelSpawnControl_Handler");
	menu_additem(menu, "Set \rCT\w spawn");
	menu_additem(menu, "Set \rT\w spawn");
	menu_additem(menu, "Show spawns");
	menu_additem(menu, "Save spawns^n");
	menu_additem(menu, "Noclip");
	menu_display(id, menu);
	
	return PLUGIN_HANDLED;
}
public DuelSpawnControl_Handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	switch(item)
	{
		case 0, 1:
		{
			pev(id, pev_origin, g_fDuelSpawnOrigins[item]);
			if(g_bShowSpawns)
			{
				UpdateSpawnEnt(item);
			}
		}
		case 2:
		{
			if(!g_bShowSpawns)
			{
				g_bShowSpawns = true;
				CreateSpawnEnt();
			}
			else
			{
				g_bShowSpawns = false;
				RemoveSpawnEnt();
			}
		}
		case 3:
		{
			SaveSpawns();
		}
		case 4:
		{
			set_user_noclip(id, !get_user_noclip(id));
		}
	}
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}
CreateSpawnEnt()
{
	
}
RemoveSpawnEnt()
{
	
}
UpdateSpawnEnt(type)
{
	
}
SaveSpawns()
{
	
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
	
	new menu = menu_create("Choose duel type:", "DuelType_Handler");//make perm menu
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
			PreparePlayerForWeaponDuel(DUELIST_CT);
			PreparePlayerForWeaponDuel(DUELIST_T);
			give_item(g_iDuelPlayers[DUELIST_CT], "weapon_knife");
			give_item(g_iDuelPlayers[DUELIST_T], "weapon_knife");
		}
		case DUELTYPE_DEAGLE:
		{
			PreparePlayerForWeaponDuel(DUELIST_CT);
			PreparePlayerForWeaponDuel(DUELIST_T);
			StartTurnDuel(TURNDUEL_DEAGLE);
		}
		case DUELTYPE_AWP:
		{
			PreparePlayerForWeaponDuel(DUELIST_CT);
			PreparePlayerForWeaponDuel(DUELIST_T);
			StartTurnDuel(TURNDUEL_AWP);
		}
	}
	if(g_bLoadedSpawns)
	{
		MovePlayerToSpawn(DUELIST_CT);
		MovePlayerToSpawn(DUELIST_T);
	}
}
PreparePlayerForWeaponDuel(player)
{
	strip_user_weapons(g_iDuelPlayers[player]);
	set_user_health(g_iDuelPlayers[player], 100);
	set_user_gravity(g_iDuelPlayers[player], 1.0);
	set_user_rendering(g_iDuelPlayers[player]);
}
MovePlayerToSpawn(player)
{
	set_pev(g_iDuelPlayers[player], pev_origin, g_fDuelSpawnOrigins[player]);
	set_pev(g_iDuelPlayers[player], pev_v_angle, g_fDuelSpawnAngles[player]);
	set_pev(g_iDuelPlayers[player], pev_angles, g_fDuelSpawnAngles[player]);
	set_pev(g_iDuelPlayers[player], pev_fixangle, 1);
}
StartTurnDuel(type)
{
	g_iDuelWeapon[DUELIST_CT] = give_item(g_iDuelPlayers[DUELIST_CT], g_eDuelWeaponWithTurn[type]);
	g_iDuelWeapon[DUELIST_T] = give_item(g_iDuelPlayers[DUELIST_T], g_eDuelWeaponWithTurn[type]);
	cs_set_weapon_ammo(g_iDuelWeapon[DUELIST_CT], 1);
	cs_set_weapon_ammo(g_iDuelWeapon[DUELIST_T], 0);
	
	g_iTimer = FIRE_TIME;
	g_iCurTurn = DUELIST_CT;
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
		remove_task(TASK_TURNCHANGER);
		Task_ChangeTurn();
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
