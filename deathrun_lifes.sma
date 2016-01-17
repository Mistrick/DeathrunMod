#include <amxmodx>
#include <hamsandwich>
#include <colorchat>

#define PLUGIN "Deathrun: Lifes"
#define VERSION "0.1"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define ADDLIFES 1
#define ALIVECTTORESPAWN 3

new const PREFIX[] = "[DL]";
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
public plugin_natives()
{
	register_native("dr_set_lifes", "native_set_lifes");
	register_native("dr_get_lifes", "native_get_lifes");
}
public native_set_lifes(id, count)
{
	g_iLifes[id] = count;
}
public native_get_lifes(id)
{
	return g_iLifes[id];
}
public Comman_Lifes(id)
{
	Show_LifeMenu(id);
}
public Ham_PlayerKilled_Post(victim, killer)
{
	if(killer && killer <= g_iMaxPlayers && killer != victim)
	{
		g_iLifes[killer] += ADDLIFES;
	}
	if(g_iLifes[victim] && alive_ct() >= ALIVECTTORESPAWN && get_user_team(victim) == 2)
	{
		Show_LifeMenu(victim);
	}
}
public Show_LifeMenu(id)
{
	new szMenu[256], iLen;
	
	iLen = formatex(szMenu, charsmax(szMenu), "\yLife Menu\w[Lifes: \r%d\w]\y:^n^n", g_iLifes[id]);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1.\w Respawn^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2.\w Exit");
	
	show_menu(id, (1 << 0)|(1 << 1), szMenu, -1, "LifeMenu");
}
public LifeMenu_Handler(id, key)
{
	switch(key)
	{
		case 0:
		{
			if(g_iLifes[id] && alive_ct() >= ALIVECTTORESPAWN && get_user_team(id) == 2)
			{
				g_iLifes[id]--;
				ExecuteHamB(Ham_CS_RoundRespawn, id);
			}
			else
			{
				client_print_color(id, DontChange, "^4%s^1 You can't respawn.", PREFIX);
			}
		}
	}
	return PLUGIN_HANDLED;
}
alive_ct()
{
	new count;
	for(new i = 1; i <= g_iMaxPlayers; i++)
	{
		if(is_user_alive(i) && get_user_team(i) == 2)
			count++;
	}
	return count++;
}
