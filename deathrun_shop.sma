#include <amxmodx>
#include <cstrike>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif

#define PLUGIN "Deathrun: Shop"
#define VERSION "0.1.1"
#define AUTHOR "Mistrick"

#pragma semicolon 1

enum _:ShopItem
{
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
	enum
	{
		arg_name = 1,
		arg_cost,
		arg_team,
		arg_access,
		arg_onbuy,
		arg_canbuy
	};
	
	new eItemInfo[ShopItem];
	
	get_string(arg_name, eItemInfo[ItemName], charsmax(eItemInfo[ItemName]));
	eItemInfo[ItemCost] = get_param(arg_cost);
	eItemInfo[ItemTeam] = get_param(arg_team);
	eItemInfo[ItemAccess] = get_param(arg_access);
	eItemInfo[ItemPlugin] = plugin;
	
	new function[32]; get_string(arg_onbuy, function, charsmax(function));
	eItemInfo[ItemOnBuy] = get_func_id(function, plugin);
	
	
	get_string(arg_canbuy, function, charsmax(function));
	
	if(function[0])
	{
		// public CanBuyItem(id);
		eItemInfo[ItemCanBuy] = CreateMultiForward(function, ET_CONTINUE, FP_CELL);
	}
	
	ArrayPushArray(g_aShopItems, eItemInfo);
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
	enum
	{
		arg_item = 1,
		arg_cost
	};
	
	new item = get_param(arg_item);
	
	if(item < 0 || item >= g_iShopTotalItems)
	{
		log_error(AMX_ERR_NATIVE, "[DRS] Set item cost: wrong item index! index %d", item);
		return 0;
	}
	
	new eItemInfo[ShopItem]; ArrayGetArray(g_aShopItems, item, eItemInfo);
	eItemInfo[ItemCost] = get_param(arg_cost);
	ArraySetArray(g_aShopItems, item, eItemInfo);
	
	return 1;
}
public Command_Shop(id)
{
	Show_ShopMenu(id, 0);
}
Show_ShopMenu(id, page)
{
	if(!g_iShopTotalItems) return;
	
	new szText[64]; formatex(szText, charsmax(szText), "%L", id, "DRS_MENU_TITLE");
	new menu = menu_create(szText, "ShopMenu_Handler");
	
	new hCallback, szNum[2], eItemInfo[ShopItem];
	new team = (1 << _:cs_get_user_team(id));
	
	for(new i = 0; i < g_iShopTotalItems; i++)
	{
		g_szItemAddition = "";
		ArrayGetArray(g_aShopItems, i, eItemInfo);
		
		if(~eItemInfo[ItemTeam] & team) continue;
		
		szNum[0] = i;
		hCallback = (GetCanBuyAnswer(id, eItemInfo[ItemCanBuy]) == ITEM_ENABLED) ? -1 : g_hCallbackDisabled;
		formatex(szText, charsmax(szText), "%s %s \R\y$%d", eItemInfo[ItemName], g_szItemAddition, eItemInfo[ItemCost]);
		
		menu_additem(menu, szText, szNum, eItemInfo[ItemAccess], hCallback);
	}
	
	formatex(szText, charsmax(szText), "%L", id, "DRS_MENU_BACK");
	menu_setprop(menu, MPROP_BACKNAME, szText);
	formatex(szText, charsmax(szText), "%L", id, "DRS_MENU_NEXT");
	menu_setprop(menu, MPROP_NEXTNAME, szText);
	formatex(szText, charsmax(szText), "%L", id, "DRS_MENU_EXIT");
	menu_setprop(menu, MPROP_EXITNAME, szText);
	
	menu_display(id, menu, page);
}
public ShopMenu_Handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu); return;
	}
	
	new iAccess, szInfo[2], hCallback;
	menu_item_getinfo(menu, item, iAccess, szInfo, charsmax(szInfo), _, _, hCallback);
	menu_destroy(menu);
	
	new item_index = szInfo[0];
	new eItemInfo[ShopItem]; ArrayGetArray(g_aShopItems, item_index, eItemInfo);
	
	new team = (1 << _:cs_get_user_team(id));
	
	if((~eItemInfo[ItemTeam] & team) || GetCanBuyAnswer(id, eItemInfo[ItemCanBuy]) != ITEM_ENABLED)
	{
		client_print_color(id, print_team_default, "%s^1 %L", PREFIX, id, "DRS_CANT_BUY");
		return;
	}
	
	new money = cs_get_user_money(id) - eItemInfo[ItemCost];
	
	if(money < 0)
	{
		client_print_color(id, print_team_default, "%s^1 %L", PREFIX, id, "DRS_NEED_MORE_MONEY", -money);
	}
	else
	{
		cs_set_user_money(id, money);
		
		// public OnBuyItem(id);
		callfunc_begin_i(eItemInfo[ItemOnBuy], eItemInfo[ItemPlugin]);
		callfunc_push_int(id);
		callfunc_end();
	}
	
	Show_ShopMenu(id, item / 7);
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
