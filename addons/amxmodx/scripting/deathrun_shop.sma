#include <amxmodx>
#include <cstrike>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif

#define PLUGIN "Deathrun: Shop"
#define VERSION "0.1.2"
#define AUTHOR "Mistrick"

#pragma semicolon 1

enum _:ShopItem {
    ItemName[32],
    ItemCost,
    ItemTeam,
    ItemAccess,
    ItemPlugin,
    ItemOnBuy,
    ItemCanBuy
};

new const PREFIX[] = "^4[DRS]";

new Array:g_aShopItems;
new g_iShopTotalItems;
new g_hCallbackDisabled;
new g_szItemAddition[32];

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    register_clcmd("say /shop", "Command_Shop");
    register_clcmd("say_team /shop", "Command_Shop");
}
public plugin_cfg()
{
    register_dictionary("deathrun_shop.txt");
}
public plugin_natives()
{
    g_aShopItems = ArrayCreate(ShopItem);
    g_hCallbackDisabled = menu_makecallback("ShopDisableItem");
    
    register_library("deathrun_shop");
    register_native("dr_shop_add_item", "native_add_item");
    register_native("dr_shop_item_addition", "native_item_addition");
    register_native("dr_shop_set_item_cost", "native_set_item_cost");
}
/**
 *  native dr_shop_add_item(name[], cost, team = (ITEM_TEAM_T|ITEM_TEAM_CT), access = 0, on_buy[], can_buy[] = "");
 */
public native_add_item(plugin, params)
{
    enum {
        arg_name = 1,
        arg_cost,
        arg_team,
        arg_access,
        arg_onbuy,
        arg_canbuy
    };
    
    new item_info[ShopItem];
    
    get_string(arg_name, item_info[ItemName], charsmax(item_info[ItemName]));
    item_info[ItemCost] = get_param(arg_cost);
    item_info[ItemTeam] = get_param(arg_team);
    item_info[ItemAccess] = get_param(arg_access);
    item_info[ItemPlugin] = plugin;
    
    new function[32]; get_string(arg_onbuy, function, charsmax(function));
    item_info[ItemOnBuy] = get_func_id(function, plugin);
    
    
    get_string(arg_canbuy, function, charsmax(function));
    
    if(function[0]) {
        // public CanBuyItem(id);
        item_info[ItemCanBuy] = CreateOneForward(plugin, function, FP_CELL);
    }
    
    ArrayPushArray(g_aShopItems, item_info);
    g_iShopTotalItems++;
    
    return g_iShopTotalItems - 1;
}
/**
 *  native dr_shop_item_addition(addition[]);
 */
public native_item_addition(plugin, params)
{
    enum { arg_addition = 1 };
    get_string(arg_addition, g_szItemAddition, charsmax(g_szItemAddition));
}
/**
 *  native dr_shop_set_item_cost(item, cost);
 */
public native_set_item_cost(plugin, params)
{
    enum {
        arg_item = 1,
        arg_cost
    };
    
    new item = get_param(arg_item);
    
    if(item < 0 || item >= g_iShopTotalItems) {
        log_error(AMX_ERR_NATIVE, "[DRS] Set item cost: wrong item index! index %d", item);
        return 0;
    }
    
    new item_info[ShopItem]; ArrayGetArray(g_aShopItems, item, item_info);
    item_info[ItemCost] = get_param(arg_cost);
    ArraySetArray(g_aShopItems, item, item_info);
    
    return 1;
}
public Command_Shop(id)
{
    Show_ShopMenu(id, 0);
}
Show_ShopMenu(id, page)
{
    if(!g_iShopTotalItems) {
        client_print_color(id, print_team_default, "%s^1 %L", PREFIX, id, "DRS_SHOP_WITHOUT_ITEMS");
        return;
    }
    
    new text[64]; formatex(text, charsmax(text), "%L", id, "DRS_MENU_TITLE");
    new menu = menu_create(text, "ShopMenu_Handler");
    
    new hCallback, num[2], item_info[ShopItem];
    new team = (1 << _:cs_get_user_team(id));
    
    for(new i = 0; i < g_iShopTotalItems; i++) {
        g_szItemAddition = "";
        ArrayGetArray(g_aShopItems, i, item_info);
        
        if(~item_info[ItemTeam] & team) continue;
        
        num[0] = i;
        hCallback = (GetCanBuyAnswer(id, item_info[ItemCanBuy]) == ITEM_ENABLED) ? -1 : g_hCallbackDisabled;
        formatex(text, charsmax(text), "%s %s \R\y$%d", item_info[ItemName], g_szItemAddition, item_info[ItemCost]);
        
        menu_additem(menu, text, num, item_info[ItemAccess], hCallback);
    }
    
    formatex(text, charsmax(text), "%L", id, "DRS_MENU_BACK");
    menu_setprop(menu, MPROP_BACKNAME, text);
    formatex(text, charsmax(text), "%L", id, "DRS_MENU_NEXT");
    menu_setprop(menu, MPROP_NEXTNAME, text);
    formatex(text, charsmax(text), "%L", id, "DRS_MENU_EXIT");
    menu_setprop(menu, MPROP_EXITNAME, text);
    
    menu_display(id, menu, page);
}
public ShopMenu_Handler(id, menu, item)
{
    if(item == MENU_EXIT) {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }
    
    new access, info[2], callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);
    menu_destroy(menu);
    
    new item_index = info[0];
    new item_info[ShopItem]; ArrayGetArray(g_aShopItems, item_index, item_info);
    
    new team = (1 << _:cs_get_user_team(id));
    
    if((~item_info[ItemTeam] & team) || GetCanBuyAnswer(id, item_info[ItemCanBuy]) != ITEM_ENABLED) {
        client_print_color(id, print_team_default, "%s^1 %L", PREFIX, id, "DRS_CANT_BUY");
        return PLUGIN_HANDLED;
    }
    
    new money = cs_get_user_money(id) - item_info[ItemCost];
    
    if(money < 0) {
        client_print_color(id, print_team_default, "%s^1 %L", PREFIX, id, "DRS_NEED_MORE_MONEY", -money);
    } else {
        cs_set_user_money(id, money);
        
        // public OnBuyItem(id);
        callfunc_begin_i(item_info[ItemOnBuy], item_info[ItemPlugin]);
        callfunc_push_int(id);
        callfunc_end();
    }
    
    Show_ShopMenu(id, item / 7);
    return PLUGIN_HANDLED;
}
GetCanBuyAnswer(id, callback)
{
    if(!callback) return ITEM_ENABLED;
    new return_value; ExecuteForward(callback, return_value, id);
    return return_value;
}
public ShopDisableItem()
{
    return ITEM_DISABLED;
}
