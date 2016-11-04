#include <amxmodx>
#include <cstrike>
#include <engine>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif

#define PLUGIN "Deathrun: Core"
#define VERSION "1.1.4"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define IsPlayer(%1) (%1 && %1 <= g_iMaxPlayers)

#define WARMUP_TIME 15.0
#define HEALER_MAX_HEALTH 150.0

enum (+=100)
{
	TASK_RESPAWN = 100
};
enum _:Cvars
{
	BLOCK_KILL,
	BLOCK_FALLDMG,
	AUTOTEAMBALANCE,
	LIMITTEAMS,
	RESTART
};

enum Forwards
{
	FW_NEW_TERRORIST
};

new const PREFIX[] = "^4[DRM]";

new g_eCvars[Cvars], g_iForwards[Forwards], g_iReturn, g_bWarmUp = true;
new g_iForwardSpawn, HamHook:g_iHamPreThink, Trie:g_tRemoveEntities;
new g_msgShowMenu, g_msgVGUIMenu, g_msgAmmoPickup, g_msgWeapPickup;
new g_iOldAmmoPickupBlock, g_iOldWeapPickupBlock, g_iTerrorist, g_iNextTerrorist, g_iMaxPlayers;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_cvar("deathrun_core_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	
	g_eCvars[BLOCK_KILL] = register_cvar("deathrun_block_kill", "1");
	g_eCvars[BLOCK_FALLDMG] = register_cvar("deathrun_block_falldmg", "1");
	
	g_eCvars[AUTOTEAMBALANCE] = get_cvar_pointer("mp_autoteambalance");
	g_eCvars[LIMITTEAMS]  = get_cvar_pointer("mp_limitteams");
	g_eCvars[RESTART] = get_cvar_pointer("sv_restart");
	
	register_clcmd("chooseteam", "Command_ChooseTeam");
	
	RegisterHam(Ham_Spawn, "player", "Ham_PlayerSpawn_Pre", false);
	RegisterHam(Ham_Spawn, "player", "Ham_PlayerSpawn_Post", true);
	RegisterHam(Ham_Killed, "player", "Ham_PlayerKilled_Post", true);
	RegisterHam(Ham_Use, "func_button", "Ham_UseButton_Pre", false);
	RegisterHam(Ham_TakeDamage, "player", "Ham_TakeDamage_Pre", false);
	RegisterHam(Ham_TraceAttack, "player", "Ham_TraceAttack_Pre", false);
	
	register_forward(FM_ClientKill, "FM_ClientKill_Pre", false);
	register_forward(FM_GetGameDescription, "FM_GetGameDescription_Pre", false);
	
	register_touch("func_door", "weaponbox", "Engine_TouchFuncDoor");
	
	g_iForwards[FW_NEW_TERRORIST] = CreateMultiForward("dr_chosen_new_terrorist", ET_IGNORE, FP_CELL);
	
	g_msgVGUIMenu = get_user_msgid("VGUIMenu");
	g_msgShowMenu = get_user_msgid("ShowMenu");
	g_msgAmmoPickup = get_user_msgid("AmmoPickup");
	g_msgWeapPickup = get_user_msgid("WeapPickup");
	
	register_message(g_msgVGUIMenu, "Message_Menu");
	register_message(g_msgShowMenu, "Message_Menu");
	
	DisableHamForward(g_iHamPreThink = RegisterHam(Ham_Player_PreThink, "player", "Ham_PlayerPreThink_Post", true));
	unregister_forward(FM_Spawn, g_iForwardSpawn, 0);
	TrieDestroy(g_tRemoveEntities);
	
	set_task(WARMUP_TIME, "Task_WarmupOff");
	
	Block_Commands();
	CheckMap();
	
	g_iMaxPlayers = get_maxplayers();
}
public Task_WarmupOff()
{
	g_bWarmUp = false;
	set_pcvar_num(g_eCvars[RESTART], 1);
}
CheckMap()
{
	new ent = find_ent_by_class(-1, "info_player_deathmatch");
	
	if(is_valid_ent(ent))
	{
		register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
		register_logevent("Event_RoundStart", 2, "1=Round_Start");
	}
	
	ent = -1;
	while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "func_door")))
	{
		new spawnflags = pev(ent, pev_spawnflags);
		if ((spawnflags & SF_DOOR_USE_ONLY) && UTIL_IsTargetActivate(ent))
		{
			set_pev(ent, pev_spawnflags, spawnflags & ~SF_DOOR_USE_ONLY);
		}
	}
}
public plugin_precache()
{
	new const szRemoveEntities[][] = 
	{
		"func_bomb_target", "func_escapezone", "func_hostage_rescue", "func_vip_safetyzone", "info_vip_start",
		"hostage_entity", "info_bomb_target", "func_buyzone","info_hostage_rescue", "monster_scientist"
	};
	g_tRemoveEntities = TrieCreate();
	for(new i = 0; i < sizeof(szRemoveEntities); i++)
	{
		TrieSetCell(g_tRemoveEntities, szRemoveEntities[i], i);
	}
	g_iForwardSpawn = register_forward(FM_Spawn, "FakeMeta_Spawn_Pre", 0);
	engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_buyzone"));
}
public FakeMeta_Spawn_Pre(ent)
{
	if(!pev_valid(ent)) return FMRES_IGNORED;
	
	static szClassName[32]; pev(ent, pev_classname, szClassName, charsmax(szClassName));
	
	if(TrieKeyExists(g_tRemoveEntities, szClassName))
	{
		engfunc(EngFunc_RemoveEntity, ent);
		return FMRES_SUPERCEDE;
	}
	return FMRES_IGNORED;
}
public plugin_cfg()
{
	register_dictionary("deathrun_core.txt");
}
public plugin_natives()
{
	register_library("deathrun_core");
	register_native("dr_get_terrorist", "native_get_terrorist", 1);
	register_native("dr_set_next_terrorist", "native_set_next_terrorist", 1);
	register_native("dr_get_next_terrorist", "native_get_next_terrorist", 1);
}
public native_get_terrorist()
{
	return g_iTerrorist;
}
public native_set_next_terrorist(id)
{
	g_iNextTerrorist = id;
}
public native_get_next_terrorist()
{
	return g_iNextTerrorist;
}
public client_putinserver(id)
{
	if(!g_bWarmUp && _get_alive_players())
	{
		block_user_spawn(id);
	}
}
public client_disconnect(id)
{
	if(id == g_iTerrorist)
	{
		new iPlayers[32], iNum;	iNum = _get_players(iPlayers, true);
		
		if(iNum >= 2)
		{
			new Float:fOrigin[3]; pev(id, pev_origin, fOrigin);
			g_iTerrorist = iPlayers[random(iNum)];
			cs_set_user_team(g_iTerrorist, CS_TEAM_T);
			ExecuteHamB(Ham_CS_RoundRespawn, g_iTerrorist);
			engfunc(EngFunc_SetOrigin, g_iTerrorist, fOrigin);
			
			ExecuteForward(g_iForwards[FW_NEW_TERRORIST], g_iReturn, g_iTerrorist);
			
			new szName[32]; get_user_name(g_iTerrorist, szName, charsmax(szName));
			new szNameLeaver[32]; get_user_name(id, szNameLeaver, charsmax(szNameLeaver));
			client_print_color(0, print_team_red, "%s %L", PREFIX, LANG_PLAYER, "DRC_TERRORIST_LEFT", szNameLeaver, szName);
		}
		else
		{
			set_pcvar_num(g_eCvars[RESTART], 5);
		}
	}
}
//******** Commands ********//
public Command_ChooseTeam(id)
{
	//Add custom menu
	return PLUGIN_HANDLED;
}
//***** Block Commands *****//
Block_Commands()
{
	new szBlockedCommands[][] = {"jointeam", "joinclass", "radio1", "radio2", "radio3"};
	for(new i = 0; i < sizeof(szBlockedCommands); i++)
	{
		register_clcmd(szBlockedCommands[i], "Command_BlockCmds");
	}
}
public Command_BlockCmds(id)
{
	return PLUGIN_HANDLED;
}
//******** Events ********//
public Event_NewRound()
{
	set_pcvar_num(g_eCvars[AUTOTEAMBALANCE], 0);
	set_pcvar_num(g_eCvars[LIMITTEAMS], 0);
	TeamBalance();	
}
TeamBalance()
{
	if(g_bWarmUp) return;
	
	new iPlayers[32], iNum, iPlayer; iNum = _get_players(iPlayers, false);
	
	if(iNum < 1 || iNum == 1 && !is_user_connected(g_iTerrorist)) return;

	if(is_user_connected(g_iTerrorist)) cs_set_user_team(g_iTerrorist, CS_TEAM_CT);
	
	if(!is_user_connected(g_iNextTerrorist))
	{
		g_iTerrorist = iPlayers[random(iNum)];
	}
	else
	{
		g_iTerrorist = g_iNextTerrorist;
		g_iNextTerrorist = 0;
	}
	
	cs_set_user_team(g_iTerrorist, CS_TEAM_T);
	for(new i = 0; i < iNum; i++)
	{
		iPlayer = iPlayers[i];
		if(iPlayer != g_iTerrorist) cs_set_user_team(iPlayer, CS_TEAM_CT);
	}
	new szName[32]; get_user_name(g_iTerrorist, szName, charsmax(szName));
	client_print_color(0, print_team_red, "%s %L", PREFIX, LANG_PLAYER, "DRC_BECAME_TERRORIST", szName);
}
public Event_RoundStart()
{
	TerroristCheck();
}
TerroristCheck()
{
	if(!is_user_connected(g_iTerrorist))
	{
		new players[32], pnum; get_players(players, pnum, "ae", "TERRORIST");
		g_iTerrorist = pnum ? players[0] : 0;
	}
	ExecuteForward(g_iForwards[FW_NEW_TERRORIST], g_iReturn, g_iTerrorist);
}
//******** Messages Credits: PRoSToTeM@ ********//
public Message_Menu(const msg, const dest, const id)
{
	const MENU_TEAM = 2;
	const SHOWTEAMSELECT = 3;
	const Menu_ChooseTeam = 1;
	const m_iMenu = 205;
	const m_iJoiningState = 121;
	
	if (msg == g_msgShowMenu)
	{
		new szMsg[13]; get_msg_arg_string(4, szMsg, charsmax(szMsg));
		if (!equal(szMsg, "#Team_Select"))
		{
			return PLUGIN_CONTINUE;
		}
	}
	else if (get_msg_arg_int(1) != MENU_TEAM || get_msg_arg_int(2) & MENU_KEY_0)
	{
		return PLUGIN_CONTINUE;
	}

	if (get_pdata_int(id, m_iMenu) == Menu_ChooseTeam || get_pdata_int(id, m_iJoiningState) != SHOWTEAMSELECT)
	{
		return PLUGIN_CONTINUE;
	}
	
	EnableHamForward(g_iHamPreThink);

	return PLUGIN_HANDLED;
}
//*******
public Ham_PlayerSpawn_Pre(id)
{	
	g_iOldAmmoPickupBlock = get_msg_block(g_msgAmmoPickup);
	g_iOldWeapPickupBlock = get_msg_block(g_msgWeapPickup);
	set_msg_block(g_msgAmmoPickup, BLOCK_SET);
	set_msg_block(g_msgWeapPickup, BLOCK_SET);
}
public Ham_PlayerSpawn_Post(id)
{
	set_msg_block(g_msgAmmoPickup, g_iOldAmmoPickupBlock);
	set_msg_block(g_msgWeapPickup, g_iOldWeapPickupBlock);
	
	if(!is_user_alive(id)) return HAM_IGNORED;
	
	block_user_radio(id);
	
	strip_user_weapons(id);//bug with m_bHasPrimary
	give_item(id, "weapon_knife");
	
	return HAM_IGNORED;
}
public Ham_PlayerKilled_Post(id)
{
	if(g_bWarmUp && cs_get_user_team(id) == CS_TEAM_CT && _get_alive_players())
	{
		set_task(0.1, "Task_Respawn", id + TASK_RESPAWN);
	}
}
public Task_Respawn(id)
{
	id -= TASK_RESPAWN;
	if(is_user_connected(id))
	{
		ExecuteHamB(Ham_CS_RoundRespawn, id);
	}
}
public Ham_UseButton_Pre(ent, caller, activator, use_type)
{
	if(!IsPlayer(activator) || !is_user_alive(activator) || cs_get_user_team(activator) == CS_TEAM_T) return HAM_IGNORED;
	
	new Float:fEntOrigin[3], Float:fPlayerOrigin[3];
	fEntOrigin = get_ent_brash_origin(ent);
	fPlayerOrigin = get_player_eyes_origin(activator);
	
	new bool:bCanUse = allow_press_button(ent, fPlayerOrigin, fEntOrigin);
	
	return bCanUse ? HAM_IGNORED : HAM_SUPERCEDE;
}
Float:get_ent_brash_origin(ent)
{
	new Float:origin[3], Float:mins[3], Float:maxs[3];
	pev(ent, pev_absmin, mins);
	pev(ent, pev_absmax, maxs);
	xs_vec_add(mins, maxs, origin);
	xs_vec_mul_scalar(origin, 0.5, origin);
	return origin;
}
Float:get_player_eyes_origin(id)
{
	new Float:origin[3], eyes_origin[3];
	get_user_origin(id, eyes_origin, 1);
	IVecFVec(eyes_origin, origin);
	return origin;
}
public Ham_TakeDamage_Pre(victim, inflictor, attacker, Float:damage, damage_bits)
{
	if(damage < 0.0)
	{
		new Float:health; pev(victim, pev_health, health);
		if(health - damage > HEALER_MAX_HEALTH)
		return HAM_SUPERCEDE;
	}
	if(damage_bits & DMG_FALL && get_pcvar_num(g_eCvars[BLOCK_FALLDMG]) && cs_get_user_team(victim) == CS_TEAM_T)
	{
		return HAM_SUPERCEDE;
	}
	return HAM_IGNORED;
}
public Ham_TraceAttack_Pre(victim, idattacker, Float:damage, Float:direction[3], trace_result, damagebits)
{
	if(damage < 0.0)
	{
		new Float:health; pev(victim, pev_health, health);
		if(health - damage > HEALER_MAX_HEALTH)
			return HAM_SUPERCEDE;
	}
	return HAM_IGNORED;
}
public Ham_PlayerPreThink_Post(id)
{
	DisableHamForward(g_iHamPreThink);
	
	new iOldShowMenuBlock = get_msg_block(g_msgShowMenu);
	new iOldVGUIMenuBlock = get_msg_block(g_msgVGUIMenu);
	set_msg_block(g_msgShowMenu, BLOCK_SET);
	set_msg_block(g_msgVGUIMenu, BLOCK_SET);
	engclient_cmd(id, "jointeam", "2");
	engclient_cmd(id, "joinclass", "5");
	set_msg_block(g_msgVGUIMenu, iOldVGUIMenuBlock);
	set_msg_block(g_msgShowMenu, iOldShowMenuBlock);
}
//*******
public FM_ClientKill_Pre(id)
{
	return (get_pcvar_num(g_eCvars[BLOCK_KILL]) || is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_T) ? FMRES_SUPERCEDE : FMRES_IGNORED;
}
public FM_GetGameDescription_Pre()
{
	static szGameName[32]; if(!szGameName[0]) formatex(szGameName, charsmax(szGameName), "Deathrun v%s", VERSION);
	forward_return(FMV_STRING, szGameName);
	return FMRES_SUPERCEDE;
}
public Engine_TouchFuncDoor(ent, toucher)
{
	if(is_valid_ent(toucher))
	{
		remove_entity(toucher);
	}
}
//****************************************//
stock _get_players(players[32], bool:alive = false)
{
	new CsTeams:team, count;
	for(new i = 1; i <= g_iMaxPlayers; i++)
	{
		if(i == g_iTerrorist || !is_user_connected(i) || alive && !is_user_alive(i)) continue;
		team = cs_get_user_team(i);
		if(team == CS_TEAM_UNASSIGNED || team == CS_TEAM_SPECTATOR) continue;
		players[count++] = i;
	}
	return count;
}
stock _get_alive_players()
{
	new players[32], pnum; get_players(players, pnum, "a");
	return pnum;
}
stock block_user_radio(id)
{
	const m_iRadiosLeft = 192;
	set_pdata_int(id, m_iRadiosLeft, 0);
}
stock block_user_spawn(id)
{
	const m_iSpawnCount = 365;
	set_pdata_int(id, m_iSpawnCount, 1);
}
stock bool:allow_press_button(ent, Float:start[3], Float:end[3], bool:ignore_players = true)
{
	new trace = 0; engfunc(EngFunc_TraceLine, start, end, (ignore_players ? IGNORE_MONSTERS : DONT_IGNORE_MONSTERS), ent, trace);
	new Float:fraction; get_tr2(trace, TR_flFraction, fraction);
	
	if(fraction == 1.0) return true;
	
	new hit_ent = get_tr2(trace, TR_pHit);
	
	if(!pev_valid(hit_ent)) return false;
	
	new Float:fAbsMin[3]; pev(hit_ent, pev_absmin, fAbsMin);
	new Float:fAbsMax[3]; pev(hit_ent, pev_absmax, fAbsMax);
	new Float:fVolume[3]; xs_vec_sub(fAbsMax, fAbsMin, fVolume);
	
	if(fVolume[0] < 48.0 && fVolume[1] < 48.0 && fVolume[2] < 48.0) return true;
	
	return false;
}
stock bool:UTIL_IsTargetActivate(const ent)
{
	new target_name[32]; pev(ent, pev_targetname, target_name, charsmax(target_name));
	return (target_name[0]) ? false : true;
}
