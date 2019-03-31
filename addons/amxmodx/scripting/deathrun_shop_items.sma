#include <amxmodx>
#include <fun>
#include <deathrun_shop>
#include <deathrun_modes>

#define PLUGIN "Deathrun Shop: Items"
#define VERSION "0.1"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define MAX_USE 3

new g_iGrenadeUsed[33];
new g_iModeDuel;
new g_bDuel;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    
    register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
    
    dr_shop_add_item("Health", 100, ITEM_TEAM_T|ITEM_TEAM_CT, 0, "ShopItem_Health", "ShopItem_CanBuy_Health");
    dr_shop_add_item("Gravity", 100, ITEM_TEAM_T|ITEM_TEAM_CT, 0, "ShopItem_Gravity");
    dr_shop_add_item("Grenade HE", 100, ITEM_TEAM_CT, 0, "ShopItem_GrenadeHE", "ShopItem_CanBuy_GrenadeHE");
}
public plugin_cfg()
{
    g_iModeDuel = dr_get_mode_by_mark("duel");
}
public client_putinserver(id)
{
    g_iGrenadeUsed[id] = MAX_USE;
}
public Event_NewRound()
{
    arrayset(g_iGrenadeUsed, MAX_USE, sizeof(g_iGrenadeUsed));
}
public dr_selected_mode(id, mode)
{
    g_bDuel = (g_iModeDuel == mode) ? true : false;
}
public ShopItem_Health(id)
{
    set_user_health(id, get_user_health(id) + 150);
    client_print(id, print_chat, "You bougth 150HP.");
}
public ShopItem_Gravity(id)
{
    set_user_gravity(id, 0.5);
}
public ShopItem_GrenadeHE(id)
{
    g_iGrenadeUsed[id]--;
    give_item(id, "weapon_hegrenade");
}
public ShopItem_CanBuy_Health(id)
{
    return g_bDuel ? ITEM_DISABLED : ITEM_ENABLED;
}
public ShopItem_CanBuy_GrenadeHE(id)
{
    if(g_iGrenadeUsed[id] <= 0)
    {
        dr_shop_item_addition("\r[ALL USED]");
        return ITEM_DISABLED;
    }
    new szAddition[32]; formatex(szAddition, charsmax(szAddition), "\y[Have %d]", g_iGrenadeUsed[id]);
    dr_shop_item_addition(szAddition);
    return ITEM_ENABLED;
}
