// Credits: Eriurias
#include <amxmodx>
#include <cstrike>
#include <engine>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <deathrun_modes>

#if AMXX_VERSION_NUM < 183
#define client_disconnected client_disconnect
#endif

#pragma semicolon 1

#define PLUGIN "Deathrun Mode: Rambo"
#define VERSION "1.1.1"
#define AUTHOR "Mistrick"

#define MIN_DIFF 8.0
#define MAX_OVERHEAT 200
#define BIG_HEAT 4
#define SMALL_HEAT 2
#define ENLIGHTEN_COOLDOWN 5.0

const XO_CBASEPLAYERWEAPON = 4;
const m_pPlayer = 41;
const m_iClip = 51;

enum (+=100) {
    TASK_OVERHEAT_TICK = 150
};

enum _:Hooks {
    Hook_AddToFullPack,
    Hook_CS_Item_CanDrop,
    Hook_Weapon_PrimaryAttack,
    Hook_Spawn,
    Hook_Player_PreThink
};

new HamHook:g_hHooks[Hooks];
new g_bEnabled, g_iModeRambo, g_iCurMode;
new g_iOverHeat[33], Float:g_fOldAngles[33][3], Float:g_fAllowUse[33];


public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    
    DisableHamForward(HamHook:g_hHooks[Hook_CS_Item_CanDrop] = RegisterHam(Ham_CS_Item_CanDrop, "weapon_m249", "Ham_Minigun_CanDrop_Pre", false));
    DisableHamForward(HamHook:g_hHooks[Hook_Weapon_PrimaryAttack] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_m249", "Ham_Minigun_PrimaryAttack_Pre", false));
    DisableHamForward(HamHook:g_hHooks[Hook_Spawn] = RegisterHam(Ham_Spawn, "player", "Ham_PlayerSpawn_Post", true));
    DisableHamForward(HamHook:g_hHooks[Hook_Player_PreThink] = RegisterHam(Ham_Player_PreThink, "player", "Ham_Player_PreThink_Pre", false));
    
    register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
    register_message(get_user_msgid("CurWeapon"), "Message_CurWeapon");
    
    g_iModeRambo = dr_register_mode
    (
        .name = "DRM_MODE_RAMBO",
        .mark = "rambo",
        .round_delay = 0,
        .flags = DRM_BLOCK_T_WEAPON | DRM_BLOCK_T_BUTTONS | DRM_ALLOW_BHOP | DRM_GIVE_USP
    );
}
public client_disconnected(id)
{
    remove_task(id + TASK_OVERHEAT_TICK);
}
public Event_NewRound()
{
    DisableHooks();
}
public Ham_PlayerSpawn_Post(id)
{
    if(is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_T) {
        give_item(id, "weapon_m249");
        g_iOverHeat[id] = 0;
        set_task(0.1, "Task_OverHeat_Tick", id + TASK_OVERHEAT_TICK, .flags = "b");
    }
}
public Message_CurWeapon(msg, dest, id)
{
    enum {
        arg_is_active = 1,
        arg_weaponid
    };
    if(g_iCurMode == g_iModeRambo && get_msg_arg_int(arg_is_active) && get_msg_arg_int(arg_weaponid) == CSW_M249 && cs_get_user_team(id) == CS_TEAM_T) {
        set_msg_arg_int(2, ARG_BYTE, CSW_KNIFE);
        set_msg_arg_int(3, ARG_BYTE, -1);
    }
}
public Ham_Minigun_CanDrop_Pre(weapon)
{
    new player = get_pdata_cbase(weapon, m_pPlayer, XO_CBASEPLAYERWEAPON);
    
    if(cs_get_user_team(player) == CS_TEAM_T) {
        SetHamReturnInteger(false);
        return HAM_SUPERCEDE;
    }
    return HAM_IGNORED;
}
public Ham_Minigun_PrimaryAttack_Pre(weapon)
{
    new player = get_pdata_cbase(weapon, m_pPlayer, XO_CBASEPLAYERWEAPON);
    
    if(cs_get_user_team(player) != CS_TEAM_T) return HAM_IGNORED;
    
    cs_set_weapon_ammo(weapon, 100);
    
    new Float:angles[3]; pev(player, pev_angles, angles);
    new Float:diff = get_distance_f(angles, g_fOldAngles[player]);
    g_fOldAngles[player] = angles;
    
    g_iOverHeat[player] += (diff < MIN_DIFF) ? BIG_HEAT : SMALL_HEAT;
    
    SendMessage_BarTime2(player, MAX_OVERHEAT / 10, 100 - g_iOverHeat[player] * 100 / MAX_OVERHEAT);
    
    return HAM_IGNORED;
}
public Task_OverHeat_Tick(id)
{
    id -= TASK_OVERHEAT_TICK;
    
    if(g_iOverHeat[id] > 0) {
        g_iOverHeat[id]--;
    }
}
public Ham_Player_PreThink_Pre(id)
{
    if(!is_user_alive(id) || cs_get_user_team(id) != CS_TEAM_T) {
        return HAM_IGNORED;
    }

    new buttons = pev(id,pev_button);
    new old_buttons = pev(id, pev_oldbuttons);
    new Float:gametime = get_gametime();

    if(buttons & IN_USE && ~old_buttons & IN_USE && gametime >= g_fAllowUse[id]) {
        g_fAllowUse[id] = gametime + ENLIGHTEN_COOLDOWN;

        new players[32], pnum, target, origin[3];
        get_players(players, pnum, "ae", "CT");
        for(new i = 0; i < pnum; i++) {
            target = players[i];
            
            get_user_origin(target, origin);
            te_create_teleport_splash(origin, id, false);
        }
    }

    if(g_iOverHeat[id] > MAX_OVERHEAT) {
        set_pev(id, pev_button, buttons & ~IN_ATTACK);
    }

    return HAM_IGNORED;
}
public FM_AddToFullPack_Post(es, e, ent, host, flags, player, pSet)
{
    if(player && host != ent) {
        if(cs_get_user_team(host) == CS_TEAM_T && cs_get_user_team(ent) == CS_TEAM_CT) {
            set_es(es, ES_RenderAmt, false);
            set_es(es, ES_RenderMode, kRenderTransAlpha);
        }
    }
}
public dr_selected_mode(id, mode)
{
    if(g_iCurMode == g_iModeRambo) {
        for(new i = 1; i < 33; i++) {
            remove_task(i + TASK_OVERHEAT_TICK);
            if(is_user_alive(i)) SendMessage_BarTime2(i, 0, 100);
        }
        DisableHooks();
    }
    
    g_iCurMode = mode;
    
    if(mode == g_iModeRambo) {
        EnableHooks();
        
        give_item(id, "weapon_m249");
        g_iOverHeat[id] = 0;
        set_task(0.1, "Task_OverHeat_Tick", id + TASK_OVERHEAT_TICK, .flags = "b");
    }
}
EnableHooks()
{
    g_bEnabled = true;
    
    g_hHooks[Hook_AddToFullPack] = HamHook:register_forward(FM_AddToFullPack, "FM_AddToFullPack_Post", true);
    for(new i = Hook_CS_Item_CanDrop; i < Hooks; i++) {
        EnableHamForward(g_hHooks[i]);
    }
}
DisableHooks()
{
    if(g_bEnabled) {
        g_bEnabled = false;
        
        unregister_forward(FM_AddToFullPack, _:g_hHooks[Hook_AddToFullPack], true);
        for(new i = Hook_CS_Item_CanDrop; i < Hooks; i++) {
            DisableHamForward(g_hHooks[i]);
        }
    }
}
stock SendMessage_BarTime2(id, duration, startpercent)
{
    static BarTime2; if(!BarTime2) BarTime2 = get_user_msgid("BarTime2");
    
    message_begin(MSG_ONE, BarTime2, .player = id);
    write_short(duration);
    write_short(startpercent);
    message_end();
}

stock te_create_teleport_splash(position[3], receiver = 0, bool:reliable = true)
{
    if(receiver && !is_user_connected(receiver))
        return 0;

    message_begin(get_msg_destination(receiver, reliable), SVC_TEMPENTITY, .player = receiver);
    write_byte(TE_TELEPORT);
    write_coord(position[0]);
    write_coord(position[1]);
    write_coord(position[2]);
    message_end();

    return 1;
}

stock get_msg_destination(id, bool:reliable)
{
    if(id)
        return reliable ? MSG_ONE : MSG_ONE_UNRELIABLE;

    return reliable ? MSG_ALL : MSG_BROADCAST;
}
