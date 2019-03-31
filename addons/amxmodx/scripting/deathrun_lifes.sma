#include <amxmodx>
#include <cstrike>
#include <hamsandwich>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif

#define PLUGIN "Deathrun: Lifes"
#define VERSION "1.0.1"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define ADD_LIFES 1
#define ALIVE_CT_TO_RESPAWN 3

new const PREFIX[] = "^4[DRL]";
new g_iLifes[33], g_iMaxPlayers;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    
    register_clcmd("say /life", "Comman_Lifes");
    register_clcmd("say /lifemenu", "Comman_Lifes");
    
    RegisterHam(Ham_Killed, "player", "Ham_PlayerKilled_Post", 1);
    
    register_menucmd(register_menuid("LifeMenu"), 1023, "LifeMenu_Handler");
    
    g_iMaxPlayers = get_maxplayers();
}
public plugin_cfg()
{
    register_dictionary("deathrun_lifes.txt");
}
public plugin_natives()
{
    register_native("dr_set_lifes", "native_set_lifes");
    register_native("dr_get_lifes", "native_get_lifes");
}
public native_set_lifes(plugin, params)
{
    enum {
        arg_player = 1,
        arg_lifes
    };
    new id = get_param(arg_player);
    
    if(id < 1 || id >= sizeof(g_iLifes)) {
        log_error(AMX_ERR_NATIVE, "[DRL] Set lifes: wrong player index! index %d", id);
        return 0;
    }
    
    g_iLifes[id] = get_param(arg_lifes);
    return 1;
}
public native_get_lifes(plugin, params)
{
    enum { arg_player = 1 };
    new id = get_param(arg_player);
    if(id < 1 || id >= sizeof(g_iLifes)) {
        log_error(AMX_ERR_NATIVE, "[DRL] Get lifes: wrong player index! index %d", id);
        return 0;
    }
    return g_iLifes[id];
}
public Comman_Lifes(id)
{
    Show_LifeMenu(id);
}
public Ham_PlayerKilled_Post(victim, killer)
{
    if(killer && killer <= g_iMaxPlayers && killer != victim && cs_get_user_team(victim) != cs_get_user_team(killer)) {
        g_iLifes[killer] += ADD_LIFES;
    }
    if(g_iLifes[victim] && alive_ct() >= ALIVE_CT_TO_RESPAWN && cs_get_user_team(victim) == CS_TEAM_CT) {
        Show_LifeMenu(victim);
    }
}
public Show_LifeMenu(id)
{
    new menu[256], iLen;
    
    iLen = formatex(menu, charsmax(menu), "%L^n^n", id, "DRL_LIFE_MENU", g_iLifes[id]);
    iLen += formatex(menu[iLen], charsmax(menu) - iLen, "\r1.\w %L^n", id, "DRL_RESPAWN");
    iLen += formatex(menu[iLen], charsmax(menu) - iLen, "\r2.\w %L", id, "DRL_EXIT");
    
    show_menu(id, (1 << 0)|(1 << 1), menu, -1, "LifeMenu");
}
public LifeMenu_Handler(id, key)
{
    switch(key) {
        case 0: {
            if(!is_user_alive(id) && g_iLifes[id] && alive_ct() >= ALIVE_CT_TO_RESPAWN && cs_get_user_team(id) == CS_TEAM_CT) {
                g_iLifes[id]--;
                ExecuteHamB(Ham_CS_RoundRespawn, id);
            } else {
                client_print_color(id, print_team_default, "%s^1 %L", PREFIX, id, "DRL_CANT_RESPAWN");
            }
        }
    }
    return PLUGIN_HANDLED;
}
alive_ct()
{
    new players[32], pnum; get_players(players, pnum, "ae", "CT");
    return pnum;
}
