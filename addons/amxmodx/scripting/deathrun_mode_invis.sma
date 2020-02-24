#include <amxmodx>
#include <cstrike>
#include <fun>
#include <hamsandwich>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Mode: Invis"
#define VERSION "1.0.2"
#define AUTHOR "Mistrick"

#define TERRORIST_HEALTH 150

new g_iModeInvis, g_iCurMode;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    RegisterHam(Ham_Spawn, "player", "Ham_PlayerSpawn_Post", 1);
    
    g_iModeInvis = dr_register_mode
    (
        .name = "DRM_MODE_INVIS",
        .mark = "invis",
        .round_delay = 2,
        .flags = DRM_BLOCK_T_WEAPON | DRM_BLOCK_T_BUTTONS | DRM_ALLOW_BHOP | DRM_GIVE_USP
    );
}
public Ham_PlayerSpawn_Post(id)
{
    if(is_user_alive(id)) {
        if(g_iCurMode == g_iModeInvis && cs_get_user_team(id) == CS_TEAM_T) {
            set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, 0);
            set_user_health(id, TERRORIST_HEALTH);
        }
    }
}
public dr_selected_mode(id, mode)
{
    g_iCurMode = mode;
    
    if(mode == g_iModeInvis) {
        set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, 0);
        set_user_health(id, TERRORIST_HEALTH);
    }
}
