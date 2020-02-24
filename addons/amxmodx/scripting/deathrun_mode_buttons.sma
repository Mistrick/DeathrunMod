#include <amxmodx>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <deathrun_modes>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif

#pragma semicolon 1

#define PLUGIN "Deathrun Mode: Buttons"
#define VERSION "1.0.1"
#define AUTHOR "Mistrick"

#define IsPlayer(%1) (%1 && %1 <= g_iMaxPlayers)

enum { NONE_MODE = 0 };

new const PREFIX[] = "^4[DRM]";

new g_iModeButtons, g_iCurMode, g_iMaxPlayers;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    RegisterHam(Ham_Use, "func_button", "Ham_UseButtons_Pre", 0);
    
    g_iMaxPlayers = get_maxplayers();
    
    g_iModeButtons = dr_register_mode
    (
        .name = "DRM_MODE_BUTTONS",
        .mark = "buttons",
        .round_delay = 0,
        .flags = DRM_ALLOW_BHOP | DRM_GIVE_USP
    );
}
public dr_selected_mode(id, mode)
{
    g_iCurMode = mode;
}
public Ham_UseButtons_Pre(ent, caller, activator, use_type)
{
    if(g_iCurMode != NONE_MODE || !IsPlayer(activator)) return HAM_IGNORED;
    
    new CsTeams:team = cs_get_user_team(activator);
    
    if(team != CS_TEAM_T) return HAM_IGNORED;

    dr_set_mode(g_iModeButtons, 1, activator);
    show_menu(activator, 0, "^n");
    client_print_color(0, print_team_red, "%s %L", PREFIX, LANG_PLAYER, "DRM_USED_BUTTON", LANG_PLAYER, "DRM_MODE_BUTTONS");
    
    return HAM_IGNORED;
}