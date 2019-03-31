#if defined _deathrun_shop_included
  #endinput
#endif
#define _deathrun_shop_included

#if AMXX_VERSION_NUM >= 175
    #pragma reqlib deathrun_shop
    #if !defined AMXMODX_NOAUTOLOAD
        #pragma loadlib deathrun_shop
    #endif
#else
    #pragma library deathrun_shop
#endif

const ITEM_TEAM_T = (1 << 1);
const ITEM_TEAM_CT = (1 << 2);

/**
 * Item registration in shop
 * 
 * @param name                  Item name in menu
 * @param cost                  Item cost
 * @param team                  Team access, bitsum, use ITEM_TEAM_T, ITEM_TEAM_CT
 * @param access                Admin access, admin flags
 * @param on_buy                OnBuy function(id)
 * @param can_buy               CanBuy function(id), should return ITEM_ENABLED or ITEM_DISABLED
 * 
 * @return                      Item index, use with changing cost
 */
native dr_shop_add_item(name[], cost, team = (ITEM_TEAM_T|ITEM_TEAM_CT), access = 0, on_buy[], can_buy[] = "");

/**
 * Use this in CanBuy function
 * 
 * @param addition              Additional string in menu
 */
native dr_shop_item_addition(addition[]);

/**
 * @param item                  Item index
 * @param cost                  New item cost
 */
native dr_shop_set_item_cost(item, cost);
