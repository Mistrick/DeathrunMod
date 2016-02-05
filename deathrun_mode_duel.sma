#include <amxmodx>
#include <cstrike>
#include <fun>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <deathrun_modes>
#include <xs>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif

#define PLUGIN "Deathrun Mode: Duel"
#define VERSION "0.5"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define FIRE_TIME 5
#define DUEL_TIME 60
#define MAX_DISTANCE 1000.0

enum (+=100)
{
	TASK_TURNCHANGER = 100,
	TASK_DUELTIMER
}

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
new g_iDuelTurnTimer;
new g_iDuelTimer;
new g_iCurTurn;

new Float:g_fDuelSpawnOrigins[2][3];
new Float:g_fDuelSpawnAngles[2][3];
new g_bShowSpawns;
new g_bLoadedSpawns;
new g_szSpawnsFile[128];
new g_bSetSpawn[2];

new g_iColors[2][3] = 
{
	{ 0, 0, 250 },
	{ 250, 0, 0 }
};

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
	register_clcmd("drop", "Command_Drop");
	
	for(new i; i < sizeof(g_eDuelWeaponWithTurn); i++)
	{
		RegisterHam(Ham_Weapon_PrimaryAttack, g_eDuelWeaponWithTurn[i], "Ham_WeaponPrimaryAttack_Post", true);
	}
	
	RegisterHam(Ham_TakeDamage, "player", "Ham_PlayerTakeDamage_Pre", false);
	RegisterHam(Ham_Killed, "player", "Ham_PlayerKilled_Post", true);
	register_touch("trigger_teleport", "player", "Engine_DuelTouch");
	register_touch("trigger_push", "player", "Engine_DuelTouch");
	
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
	
	new szMap[32]; get_mapname(szMap, charsmax(szMap));
	formatex(g_szSpawnsFile, charsmax(g_szSpawnsFile), "%s/%s.ini", szDir, szMap);
	
	if(dir_exists(szDir))
	{
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
					new team = (szTeam[0] == 'C' ? 0 : 1);
					g_fDuelSpawnOrigins[team][0] = str_to_float(szOrigins[0]);
					g_fDuelSpawnOrigins[team][1] = str_to_float(szOrigins[1]);
					g_fDuelSpawnOrigins[team][2] = str_to_float(szOrigins[2]);
					g_bSetSpawn[team] = true;
				}
				fclose(f);
				if(g_bSetSpawn[DUELIST_CT] && g_bSetSpawn[DUELIST_T])
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
		ResetDuel();
	}
}
public Command_Drop(id)
{
	return g_bDuelStarted ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
}
public Command_DuelSpawn(id, flag)
{
	if(~get_user_flags(id) & flag) return PLUGIN_HANDLED;
	
	Show_DuelSpawnControlMenu(id);
	
	return PLUGIN_HANDLED;
}
public Show_DuelSpawnControlMenu(id)
{
	new szText[64], menu = menu_create("Duel Spawn Control", "DuelSpawnControl_Handler");
	menu_additem(menu, "Set \rCT\w spawn");
	menu_additem(menu, "Set \rT\w spawn");
	formatex(szText, charsmax(szText), "%s spawns", g_bShowSpawns ? "Hide" : "Show");
	menu_additem(menu, szText);
	menu_additem(menu, "Save spawns^n");
	formatex(szText, charsmax(szText), "Noclip \r[%s]", get_user_noclip(id) ? "ON" : "OFF");
	menu_additem(menu, szText);
	menu_display(id, menu);
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
			g_bSetSpawn[item] = true;
			pev(id, pev_origin, g_fDuelSpawnOrigins[item]);
			if(g_bShowSpawns)
			{
				UpdateSpawnEnt();
			}
		}
		case 2:
		{
			if(!g_bShowSpawns)
			{
				g_bShowSpawns = true;
				CreateSpawnEnt(DUELIST_CT);
				CreateSpawnEnt(DUELIST_T);
			}
			else
			{
				g_bShowSpawns = false;
				RemoveSpawnEnt();
			}
		}
		case 3:
		{
			SaveSpawns(id);
		}
		case 4:
		{
			set_user_noclip(id, !get_user_noclip(id));
		}
	}
	
	Show_DuelSpawnControlMenu(id);
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}
CreateSpawnEnt(type)
{
	static szModels[][] = {"models/player/urban/urban.mdl", "models/player/arctic/arctic.mdl"};
	new ent = create_entity("info_target");
	DispatchSpawn(ent);
	
	entity_set_model(ent, szModels[type]);
	entity_set_string(ent, EV_SZ_classname, "duel_spawn_ent");
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_NOCLIP);
	entity_set_int(ent, EV_INT_solid, SOLID_NOT);
	entity_set_int(ent, EV_INT_iuser1, type);
	entity_set_int(ent, EV_INT_sequence, 1);
	
	entity_set_vector(ent, EV_VEC_origin, g_fDuelSpawnOrigins[type]);
	entity_set_vector(ent, EV_VEC_angles, g_fDuelSpawnAngles[type]);
}
RemoveSpawnEnt()
{
	new ent = -1;
	while((ent = find_ent_by_class(ent, "duel_spawn_ent")))
	{
		remove_entity(ent);
	}
}
UpdateSpawnEnt()
{
	GetSpawnAngles();
	new ent = -1;
	while((ent = find_ent_by_class(ent, "duel_spawn_ent")))
	{
		new type = entity_get_int(ent, EV_INT_iuser1);
		entity_set_vector(ent, EV_VEC_origin, g_fDuelSpawnOrigins[type]);
		entity_set_vector(ent, EV_VEC_angles, g_fDuelSpawnAngles[type]);
	}
}
SaveSpawns(id)
{
	if(!g_bSetSpawn[DUELIST_CT] || !g_bSetSpawn[DUELIST_T])
	{
		client_print_color(id, print_team_default, "^4[Duel]^1 You must set two spawns.");
		return;
	}
	if(file_exists(g_szSpawnsFile))
	{
		delete_file(g_szSpawnsFile);
	}
	new file = fopen(g_szSpawnsFile, "wt");
	if(file)
	{
		fprintf(file, "CT %f %f %f^n", g_fDuelSpawnOrigins[DUELIST_CT][0], g_fDuelSpawnOrigins[DUELIST_CT][1], g_fDuelSpawnOrigins[DUELIST_CT][2]);
		fprintf(file, "T %f %f %f^n", g_fDuelSpawnOrigins[DUELIST_T][0], g_fDuelSpawnOrigins[DUELIST_T][1], g_fDuelSpawnOrigins[DUELIST_T][2]);
		fclose(file);
		g_bLoadedSpawns = true;
		GetSpawnAngles();
		client_print_color(id, print_team_default, "^4[Duel]^1 Spawns saved.");
	}
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
	
	new players[32], pnum; get_players(players, pnum, "aceh", "CT");
	if(pnum > 1) return PLUGIN_HANDLED;
	
	get_players(players, pnum, "aceh", "TERRORIST");
	if(pnum < 1) return PLUGIN_HANDLED;
	
	if(!is_user_alive(id) || cs_get_user_team(id) != CS_TEAM_CT) return PLUGIN_HANDLED;
	
	dr_set_mode(g_iModeDuel, 1);
	
	DuelStartForward(item);
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}
DuelStartForward(type)
{
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
	
	StartDuelTimer();
}
StartDuelTimer()
{
	g_bDuelStarted = true;
	g_iDuelTimer = DUEL_TIME + 1;
	Task_DuelTimer();
}
public Task_DuelTimer()
{
	if(!g_bDuelStarted) return;
	
	if(--g_iDuelTimer <= 0)
	{
		g_bDuelStarted = false;
		
		ExecuteHamB(Ham_Killed, g_iDuelPlayers[DUELIST_CT], 0, 0);
		ExecuteHamB(Ham_Killed, g_iDuelPlayers[DUELIST_T], 0, 0);

		g_iDuelPlayers[DUELIST_CT] = 0;
		g_iDuelPlayers[DUELIST_T] = 0;
		
		remove_task(TASK_TURNCHANGER);
		client_print_color(0, print_team_default, "^4[Duel]^1 Duel time is over.");
	}
	else
	{
		set_task(1.0, "Task_DuelTimer", TASK_DUELTIMER);
	}
}
PreparePlayerForWeaponDuel(player)
{
	strip_user_weapons(g_iDuelPlayers[player]);
	set_user_health(g_iDuelPlayers[player], 100);
	set_user_gravity(g_iDuelPlayers[player], 1.0);
	set_user_rendering(g_iDuelPlayers[player], kRenderFxGlowShell, g_iColors[player][0], g_iColors[player][1], g_iColors[player][2], kRenderNormal, 20);
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
	if(pev_valid(g_iDuelWeapon[DUELIST_CT])) cs_set_weapon_ammo(g_iDuelWeapon[DUELIST_CT], 1);
	if(pev_valid(g_iDuelWeapon[DUELIST_T])) cs_set_weapon_ammo(g_iDuelWeapon[DUELIST_T], 0);
	
	g_iDuelTurnTimer = FIRE_TIME;
	g_iCurTurn = DUELIST_CT;
	Task_ChangeTurn();
}
public Task_ChangeTurn()
{
	if(!g_bDuelStarted) return;
	
	if(g_iDuelTurnTimer > 0)
	{
		client_print(g_iDuelPlayers[g_iCurTurn], print_center, "You have %d seconds.", g_iDuelTurnTimer);
	}
	else
	{
		ExecuteHamB(Ham_Weapon_PrimaryAttack, g_iDuelWeapon[g_iCurTurn]);
	}
	
	if(g_bLoadedSpawns)
	{
		CheckPlayersDistance();
	}
	
	g_iDuelTurnTimer--;
	set_task(1.0, "Task_ChangeTurn", TASK_TURNCHANGER);
}
CheckPlayersDistance()
{
	if(get_entity_distance(g_iDuelPlayers[DUELIST_CT], g_iDuelPlayers[DUELIST_T]) > MAX_DISTANCE)
	{
		MovePlayerToSpawn(DUELIST_CT);
		MovePlayerToSpawn(DUELIST_T);
	}
}
public Ham_WeaponPrimaryAttack_Post(weapon)
{
	if(!g_bDuelStarted || (weapon != g_iDuelWeapon[DUELIST_CT] && weapon != g_iDuelWeapon[DUELIST_T])) return HAM_IGNORED;
	
	new player = get_pdata_cbase(weapon, m_pPlayer, XO_CBASEPLAYERWEAPON);
	
	if(player == g_iDuelPlayers[g_iCurTurn])
	{
		g_iDuelTurnTimer = FIRE_TIME;
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
public Engine_DuelTouch(ent, toucher)
{
	return g_bDuelStarted ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
}
public Ham_PlayerKilled_Post(victim, killer)
{
	if(g_bDuelStarted && (victim == g_iDuelPlayers[DUELIST_CT] || victim == g_iDuelPlayers[DUELIST_T]))
	{
		new szName[32]; get_user_name(killer, szName, charsmax(szName));
		client_print_color(0, killer, "^4[Duel]^1 Duel winner is^3 %s^1.", szName);
		
		ResetDuel();
	}
}
public dr_selected_mode(id, mode)
{
	if(g_bDuelStarted && mode != g_iModeDuel)
	{
		ResetDuel();
	}
}
ResetDuel()
{
	g_bDuelStarted = false;
	g_iDuelPlayers[DUELIST_CT] = 0;
	g_iDuelPlayers[DUELIST_T] = 0;
	remove_task(TASK_TURNCHANGER);
	remove_task(TASK_DUELTIMER);
}
