#include <amxmodx>
#include <fun>
#include <hamsandwich>
#include <deathrun_modes>

#define PLUGIN "Deathrun Mode: Free"
#define VERSION "1.0.2"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define MAX_HEALTH 100

new g_iModeFree, g_iCurMode, g_iMaxPlayers;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_event("Health", "Event_Health", "b");
    
    new CSW_IGNORED = (1 << CSW_KNIFE);
    for(new i = CSW_P228, szWeaponName[32]; i <= CSW_P90; i++) {
        if(~CSW_IGNORED & 1<<i && get_weaponname(i, szWeaponName, charsmax(szWeaponName))) {
            RegisterHam(Ham_Item_AddToPlayer, szWeaponName, "Ham_Item_AddToPlayer_Pre", 0);
        }
    }
    
    g_iModeFree = dr_register_mode
    (
        .name = "DRM_MODE_FREE",
        .mark = "free",
        .round_delay = 0,
        .flags = DRM_BLOCK_CT_WEAPON | DRM_BLOCK_T_WEAPON | DRM_BLOCK_T_BUTTONS | DRM_ALLOW_BHOP
    );
    
    g_iMaxPlayers = get_maxplayers();
}
public Event_Health(id)
{
    if(g_iCurMode == g_iModeFree && (get_user_health(id) > MAX_HEALTH)) {
        set_user_health(id, MAX_HEALTH);
        client_print(id, print_center, "You can't have more than %d hp.", MAX_HEALTH);
    }
}
public Ham_Item_AddToPlayer_Pre(ent, id)
{
    return (g_iCurMode == g_iModeFree) ? HAM_SUPERCEDE : HAM_IGNORED;
}
public dr_selected_mode(id, mode)
{
    g_iCurMode = mode;
    
    if(g_iModeFree == mode) {
        for(new i = 1; i <= g_iMaxPlayers; i++) {
            if(is_user_alive(i)) {
                strip_user_weapons(i);
                give_item(i, "weapon_knife");
            }
        }
    }
}
