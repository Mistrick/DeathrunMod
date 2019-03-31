#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <deathrun_modes>

#define PLUGIN "Deathrun: Teleport Spot"
#define VERSION "1.0.3"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define RETURN_DAMAGE_TO_ATTACKER
#define TP_CHECK_DISTANCE 64.0

#define IsPlayer(%1) (%1 && %1 <= g_iMaxPlayers)
#define fm_get_user_team(%0) get_pdata_int(%0, 114)

new player_solid[33], g_bDuel, g_iDuelMode, g_iMaxPlayers;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    
    new ent = find_ent_by_class(-1, "info_teleport_destination");
    
    if(!pev_valid(ent)) {
        log_amx("Map doesn't have any teleports.");
        pause("a");
        return;
    }
    
    RegisterHam(Ham_TakeDamage, "player", "Ham_PlayerTakeDamage_Pre", false);
    g_iMaxPlayers = get_maxplayers();
}
public plugin_cfg()
{
    g_iDuelMode = dr_get_mode_by_mark("duel");
}
public dr_selected_mode(id, mode)
{
    g_bDuel = (g_iDuelMode == mode);
}
public Ham_PlayerTakeDamage_Pre(victim, idinflictor, attacker, Float:damage, damagebits)
{
    if(g_bDuel) {
        return HAM_IGNORED;
    }

    if(victim == attacker || !IsPlayer(attacker) || fm_get_user_team(victim) == fm_get_user_team(attacker)) {
        return HAM_IGNORED;
    }

    new Float:origin[3]; pev(victim, pev_origin, origin);
    new ent = -1;
    while((ent = find_ent_in_sphere(ent, origin, TP_CHECK_DISTANCE))) {
        new class_name[32]; pev(ent, pev_classname, class_name, charsmax(class_name));
        if(equal(class_name, "info_teleport_destination")) {
            #if defined RETURN_DAMAGE_TO_ATTACKER
            ExecuteHamB(Ham_TakeDamage, attacker, 0, attacker, damage, damagebits);
            #endif

            if(is_user_alive(attacker)) slap(attacker);
            if(is_user_alive(victim)) slap(victim);

            return HAM_SUPERCEDE;
        }
    }

    return HAM_IGNORED;
}
slap(id)
{
    new solid = pev(id, pev_solid);
    if(solid != SOLID_NOT) player_solid[id] = solid;
    
    set_pev(id, pev_solid, SOLID_NOT);
    
    user_slap(id, 0);
    user_slap(id, 0);
    
    remove_task(id);
    set_task(0.3, "restore_solid", id);
}
public restore_solid(id)
{
    if(is_user_alive(id)) set_pev(id, pev_solid, player_solid[id]);
}