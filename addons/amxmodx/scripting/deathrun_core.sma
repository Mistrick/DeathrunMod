#include <amxmodx>
#include <cstrike>
#include <engine>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#define client_disconnected client_disconnect
#endif

#define PLUGIN "Deathrun: Core"
#define VERSION "1.1.6"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define IsPlayer(%1) (%1 && %1 <= g_iMaxPlayers)

#define get_num(%0) get_pcvar_num(g_pCvars[%0])
#define set_num(%0,%1) set_pcvar_num(g_pCvars[%0],%1)
#define get_float(%0) get_pcvar_float(g_pCvars[%0])
#define set_float(%0,%1) set_pcvar_float(g_pCvars[%0],%1)

enum (+=100) {
    TASK_RESPAWN = 100
};

enum _:Cvars {
    BLOCK_KILL,
    BLOCK_FALLDMG,
    LIMIT_HEALTH,
    WARMUP_TIME,
    AUTOTEAMBALANCE,
    LIMITTEAMS,
    RESTART
};

enum Forwards {
    NEW_TERRORIST
};

new const PREFIX[] = "^4[DRM]";

new g_pCvars[Cvars], g_iForwards[Forwards], g_iReturn, g_bWarmUp = true;
new g_iForwardSpawn, HamHook:g_iHamPreThink, Trie:g_tRemoveEntities;
new g_msgShowMenu, g_msgVGUIMenu, g_msgAmmoPickup, g_msgWeapPickup;
new g_iOldAmmoPickupBlock, g_iOldWeapPickupBlock, g_iTerrorist, g_iNextTerrorist, g_iMaxPlayers;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    
    register_cvar("deathrun_core_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
    
    g_pCvars[BLOCK_KILL] = register_cvar("deathrun_block_kill", "1");
    g_pCvars[BLOCK_FALLDMG] = register_cvar("deathrun_block_falldmg", "1");
    g_pCvars[LIMIT_HEALTH] = register_cvar("deathrun_limit_health", "150"); // 0 - disable
    g_pCvars[WARMUP_TIME] = register_cvar("deathrun_warmup_time", "15.0");
    
    g_pCvars[AUTOTEAMBALANCE] = get_cvar_pointer("mp_autoteambalance");
    g_pCvars[LIMITTEAMS]  = get_cvar_pointer("mp_limitteams");
    g_pCvars[RESTART] = get_cvar_pointer("sv_restart");
    
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
    
    g_iForwards[NEW_TERRORIST] = CreateMultiForward("dr_chosen_new_terrorist", ET_IGNORE, FP_CELL);
    
    g_msgVGUIMenu = get_user_msgid("VGUIMenu");
    g_msgShowMenu = get_user_msgid("ShowMenu");
    g_msgAmmoPickup = get_user_msgid("AmmoPickup");
    g_msgWeapPickup = get_user_msgid("WeapPickup");
    
    register_message(g_msgVGUIMenu, "Message_Menu");
    register_message(g_msgShowMenu, "Message_Menu");
    register_message(get_user_msgid("TextMsg"), "Message_TextMsg");
    
    DisableHamForward(g_iHamPreThink = RegisterHam(Ham_Player_PreThink, "player", "Ham_PlayerPreThink_Post", true));
    unregister_forward(FM_Spawn, g_iForwardSpawn, 0);
    TrieDestroy(g_tRemoveEntities);
    
    set_task(get_float(WARMUP_TIME), "Task_WarmupOff");
    
    Block_Commands();
    CheckMap();
    
    g_iMaxPlayers = get_maxplayers();
}
public Task_WarmupOff()
{
    g_bWarmUp = false;
    set_num(RESTART, 1);
}
CheckMap()
{
    new ent = find_ent_by_class(-1, "info_player_deathmatch");
    
    if(is_valid_ent(ent)) {
        register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
        register_logevent("Event_RoundStart", 2, "1=Round_Start");
    }
    
    ent = -1;
    while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "func_door"))) {
        new spawnflags = pev(ent, pev_spawnflags);
        if ((spawnflags & SF_DOOR_USE_ONLY) && UTIL_IsTargetActivate(ent)) {
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
    for(new i = 0; i < sizeof(szRemoveEntities); i++) {
        TrieSetCell(g_tRemoveEntities, szRemoveEntities[i], i);
    }
    g_iForwardSpawn = register_forward(FM_Spawn, "FakeMeta_Spawn_Pre", 0);
    engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_buyzone"));
}
public FakeMeta_Spawn_Pre(ent)
{
    if(!pev_valid(ent)) {
        return FMRES_IGNORED;
    }

    new classname[32];
    pev(ent, pev_classname, classname, charsmax(classname));
    
    if(TrieKeyExists(g_tRemoveEntities, classname)) {
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
    register_native("dr_get_terrorist", "native_get_terrorist");
    register_native("dr_set_next_terrorist", "native_set_next_terrorist");
    register_native("dr_get_next_terrorist", "native_get_next_terrorist");
}
public native_get_terrorist(plugin, params)
{
    return g_iTerrorist;
}
public native_set_next_terrorist(plugin, params)
{
    enum { arg_index = 1 };
    g_iNextTerrorist = get_param(arg_index);
}
public native_get_next_terrorist(plugin, params)
{
    return g_iNextTerrorist;
}
public client_putinserver(id)
{
    if(!g_bWarmUp && _get_alive_players()) {
        block_user_spawn(id);
    }
}
public client_disconnected(id)
{
    if(id != g_iTerrorist) {
        return;
    }
    
    new players[32], pnum;
    pnum = _get_players(players, true);
    
    if(pnum >= 2) {
        new Float:fOrigin[3]; pev(id, pev_origin, fOrigin);
        g_iTerrorist = players[random(pnum)];
        cs_set_user_team(g_iTerrorist, CS_TEAM_T);
        ExecuteHamB(Ham_CS_RoundRespawn, g_iTerrorist);
        engfunc(EngFunc_SetOrigin, g_iTerrorist, fOrigin);
        
        ExecuteForward(g_iForwards[NEW_TERRORIST], g_iReturn, g_iTerrorist);
        
        new name[32]; get_user_name(g_iTerrorist, name, charsmax(name));
        new leaver[32]; get_user_name(id, leaver, charsmax(leaver));
        client_print_color(0, print_team_red, "%s %L", PREFIX, LANG_PLAYER, "DRC_TERRORIST_LEFT", leaver, name);
    } else {
        set_num(RESTART, 5);
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
    new blocked_commands[][] = {"jointeam", "joinclass", "radio1", "radio2", "radio3"};
    for(new i = 0; i < sizeof(blocked_commands); i++) {
        register_clcmd(blocked_commands[i], "Command_BlockCmds");
    }
}
public Command_BlockCmds(id)
{
    return PLUGIN_HANDLED;
}
//******** Events ********//
public Event_NewRound()
{
    set_num(AUTOTEAMBALANCE, 0);
    set_num(LIMITTEAMS, 0);
    TeamBalance();	
}
TeamBalance()
{
    if(g_bWarmUp) {
        return;
    }

    new players[32], pnum, player;
    pnum = _get_players(players, false);
    
    if(pnum < 1 || pnum == 1 && !is_user_connected(g_iTerrorist)) {
        return;
    }

    if(is_user_connected(g_iTerrorist)) {
        cs_set_user_team(g_iTerrorist, CS_TEAM_CT);
    }

    if(!is_user_connected(g_iNextTerrorist)) {
        g_iTerrorist = players[random(pnum)];
    } else {
        g_iTerrorist = g_iNextTerrorist;
        g_iNextTerrorist = 0;
    }
    
    cs_set_user_team(g_iTerrorist, CS_TEAM_T);
    for(new i = 0; i < pnum; i++) {
        player = players[i];
        if(player != g_iTerrorist) {
            cs_set_user_team(player, CS_TEAM_CT);
        }
    }
    new name[32];
    get_user_name(g_iTerrorist, name, charsmax(name));
    client_print_color(0, print_team_red, "%s %L", PREFIX, LANG_PLAYER, "DRC_BECAME_TERRORIST", name);
}
public Event_RoundStart()
{
    TerroristCheck();
}
TerroristCheck()
{
    if(!is_user_connected(g_iTerrorist)) {
        new players[32], pnum;
        get_players(players, pnum, "ae", "TERRORIST");
        g_iTerrorist = pnum ? players[0] : 0;
    }
    ExecuteForward(g_iForwards[NEW_TERRORIST], g_iReturn, g_iTerrorist);
}
public Message_TextMsg(const msg, const dest, const id)
{
    enum {
        arg_destination_type = 1,
        arg_message
    }
    new dt = get_msg_arg_int(arg_destination_type);

    if(dt != print_console) {
        return PLUGIN_CONTINUE;
    }

    new message[16];
    get_msg_arg_string(arg_message, message, charsmax(message));

    if(equal(message, "#Game_scoring")) {
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}
//******** Messages Credits: PRoSToTeM@ ********//
public Message_Menu(const msg, const dest, const id)
{
    const MENU_TEAM = 2;
    const SHOWTEAMSELECT = 3;
    const Menu_ChooseTeam = 1;
    const m_iMenu = 205;
    const m_iJoiningState = 121;
    
    if (msg == g_msgShowMenu) {
        new szMsg[13]; get_msg_arg_string(4, szMsg, charsmax(szMsg));
        if (!equal(szMsg, "#Team_Select")) {
            return PLUGIN_CONTINUE;
        }
    } else if (get_msg_arg_int(1) != MENU_TEAM || get_msg_arg_int(2) & MENU_KEY_0) {
        return PLUGIN_CONTINUE;
    }

    if (get_pdata_int(id, m_iMenu) == Menu_ChooseTeam || get_pdata_int(id, m_iJoiningState) != SHOWTEAMSELECT) {
        return PLUGIN_CONTINUE;
    }
    
    EnableHamForward(g_iHamPreThink);

    return PLUGIN_HANDLED;
}
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
    
    if(!is_user_alive(id)) {
        return HAM_IGNORED;
    }

    block_user_radio(id);
    
    strip_user_weapons(id); //bug with m_bHasPrimary
    give_item(id, "weapon_knife");
    
    return HAM_IGNORED;
}
public Ham_PlayerKilled_Post(id)
{
    if(g_bWarmUp && cs_get_user_team(id) == CS_TEAM_CT && _get_alive_players()) {
        set_task(0.1, "Task_Respawn", id + TASK_RESPAWN);
    }
}
public Task_Respawn(id)
{
    id -= TASK_RESPAWN;
    if(is_user_connected(id)) {
        ExecuteHamB(Ham_CS_RoundRespawn, id);
    }
}
public Ham_UseButton_Pre(ent, caller, activator, use_type)
{
    if(!IsPlayer(activator) || !is_user_alive(activator) || cs_get_user_team(activator) == CS_TEAM_T) {
        return HAM_IGNORED;
    }

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
    // fix health abuse
    new Float:max_health = get_float(LIMIT_HEALTH);
    if(damage < 0.0 && max_health) {
        new Float:health;
        pev(victim, pev_health, health);
        if(health - damage > max_health) {
            return HAM_SUPERCEDE;
        }
    }
    if(damage_bits & DMG_FALL && get_num(BLOCK_FALLDMG) && cs_get_user_team(victim) == CS_TEAM_T) {
        return HAM_SUPERCEDE;
    }
    return HAM_IGNORED;
}
public Ham_TraceAttack_Pre(victim, idattacker, Float:damage, Float:direction[3], trace_result, damagebits)
{
    // fix health abuse
    new Float:max_health = get_float(LIMIT_HEALTH);
    if(damage < 0.0 && max_health) {
        new Float:health;
        pev(victim, pev_health, health);
        if(health - damage > max_health) {
            return HAM_SUPERCEDE;
        }
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
public FM_ClientKill_Pre(id)
{
    if(get_num(BLOCK_KILL) || is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_T) {
        return FMRES_SUPERCEDE;
    }
    return FMRES_IGNORED;
}
public FM_GetGameDescription_Pre()
{
    static game_name[32];
    if(!game_name[0]) {
        formatex(game_name, charsmax(game_name), "Deathrun v%s", VERSION);
    }
    forward_return(FMV_STRING, game_name);
    return FMRES_SUPERCEDE;
}
public Engine_TouchFuncDoor(ent, toucher)
{
    if(is_valid_ent(toucher)) {
        remove_entity(toucher);
    }
}
stock _get_players(players[32], bool:alive = false)
{
    new CsTeams:team, count;
    for(new i = 1; i <= g_iMaxPlayers; i++) {
        if(i == g_iTerrorist || !is_user_connected(i) || alive && !is_user_alive(i)) {
            continue;
        }
        team = cs_get_user_team(i);
        if(team == CS_TEAM_UNASSIGNED || team == CS_TEAM_SPECTATOR) {
            continue;
        }
        players[count++] = i;
    }
    return count;
}
stock _get_alive_players()
{
    new players[32], pnum;
    get_players(players, pnum, "a");
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
    engfunc(EngFunc_TraceLine, start, end, (ignore_players ? IGNORE_MONSTERS : DONT_IGNORE_MONSTERS), ent, 0);
    new Float:fraction; get_tr2(0, TR_flFraction, fraction);
    
    if(fraction == 1.0) {
        return true;
    }
    
    new hit_ent = get_tr2(0, TR_pHit);
    
    if(!pev_valid(hit_ent)) {
        return false;
    }
    
    new Float:absmin[3], Float:absmax[3], Float:volume[3]; 
    pev(hit_ent, pev_absmin, absmin);
    pev(hit_ent, pev_absmax, absmax);
    xs_vec_sub(absmax, absmin, volume);
    
    if(volume[0] < 48.0 && volume[1] < 48.0 && volume[2] < 48.0) {
        return true;
    }
    
    return false;
}
stock bool:UTIL_IsTargetActivate(const ent)
{
    new target_name[32];
    pev(ent, pev_targetname, target_name, charsmax(target_name));
    new temp = find_ent_by_tname(-1, target_name);
    return !pev_valid(temp);
}
