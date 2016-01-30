#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <deathrun_modes>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#include <dhudmessage>
#endif

#define PLUGIN "Deathrun: Informer"
#define VERSION "0.4"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define UPDATE_INTERVAL 1.0

new const PREFIX[] = "[DRI]";

new g_szCurMode[32], g_iConnectedCount, g_iMaxPlayers, g_iHudInformer, g_iHudSpecList, g_iHudSpeed;
new bool:g_bAlive[33], bool:g_bInformer[33], bool:g_bSpeed[33], bool:g_bSpecList[33];
new g_iHealth[33], g_iMoney[33], g_iFrames[33], g_iPlayerFps[33];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_clcmd("say /informer", "Command_Informer");
	register_clcmd("say /speclist", "Command_SpecList");
	register_clcmd("say /speed", "Command_Speed");
	
	register_event("Money", "Event_Money", "b");
	register_event("Health", "Event_Health", "b");	
	register_logevent("Event_RoundStart", 2, "1=Round_Start");
	
	RegisterHam(Ham_Spawn, "player", "Ham_PlayerAlive_Post", 1);
	RegisterHam(Ham_Killed, "player", "Ham_PlayerAlive_Post", 1);
	register_forward(FM_PlayerPreThink, "FM_PlayerPreThink_Pre", 0);
	
	g_iHudInformer = CreateHudSyncObj();
	g_iHudSpeed = CreateHudSyncObj();
	g_iHudSpecList = CreateHudSyncObj();
	
	g_iMaxPlayers = get_maxplayers();
	
	set_task(1.0, "Task_FramesCount", .flags = "b");
	set_task(UPDATE_INTERVAL, "Task_ShowInfo", .flags = "b");
	set_task(0.1, "Task_ShowSpeed", .flags = "b");
}
public client_putinserver(id)
{
	g_bInformer[id] = true;
	g_bSpecList[id] = true;
	g_bSpeed[id] = true;
	g_iConnectedCount++;
}
public client_disconnect(id)
{
	g_bAlive[id] = false;
	g_iConnectedCount--;
}
//***** Commands *****//
public Command_Informer(id)
{
	g_bInformer[id] = !g_bInformer[id];
	client_print_color(id, print_team_default, "^4%s^1 Informer is^3 %s^1.", PREFIX, g_bInformer[id] ? "enabled" : "disabled");
}
public Command_SpecList(id)
{
	g_bSpecList[id] = !g_bSpecList[id];
	client_print_color(id, print_team_default, "^4%s^1 Speclist is^3 %s^1.", PREFIX, g_bSpecList[id] ? "enabled" : "disabled");
}
public Command_Speed(id)
{
	g_bSpeed[id] = !g_bSpeed[id];
	client_print_color(id, print_team_default, "^4%s^1 Speedometer is^3 %s^1.", PREFIX, g_bSpeed[id] ? "enabled" : "disabled");
}
//***** Events *****//
public Event_RoundStart()
{
	dr_get_mode(g_szCurMode, charsmax(g_szCurMode));
}
public Event_Money(id)
{
	g_iMoney[id] = read_data(1);
}
public Event_Health(id)
{
	g_iHealth[id] = get_user_health(id);
}
//***** Ham *****//
public Ham_PlayerAlive_Post(id)
{
	g_bAlive[id] = bool:is_user_alive(id);
}
//***** Fakemeta *****//
public FM_PlayerPreThink_Pre(id)
{
	g_iFrames[id]++;
}
//***** Frames *****//
public Task_FramesCount()
{
	for(new id = 1; id <= g_iMaxPlayers; id++)
	{
		g_iPlayerFps[id] = g_iFrames[id];
		g_iFrames[id] = 0;
	}
}
//***** Informer and SpecList *****//
/*
 * Mode: <mode>
 * Timeleft: <time>
 * ??Terrorist: <name>??
 * Alive CT: <alive>/<ct count>
 * All Players: <connected count>/<maxplayers>
 */
public Task_ShowInfo()
{
	new szName[32], szInformer[256], iLen = 0, iTimeLeft = get_timeleft();
	iLen = formatex(szInformer, charsmax(szInformer), "Mode: %s^n", g_szCurMode);
	iLen += formatex(szInformer[iLen], charsmax(szInformer) - iLen, "Timeleft: %02d:%02d^n", iTimeLeft / 60, iTimeLeft % 60);
		
	new iAlive, iCount; get_ct(iAlive, iCount);
	iLen += formatex(szInformer[iLen], charsmax(szInformer) - iLen, "Alive CT: %d/%d^n", iAlive, iCount);
	iLen += formatex(szInformer[iLen], charsmax(szInformer) - iLen, "All Players: %d/%d", g_iConnectedCount, g_iMaxPlayers);	

	static szSpecInfo[1152];
	new iAllPlayers[32], iAllNum; get_players(iAllPlayers, iAllNum, "ch");
	for(new id, i; i < iAllNum; i++)
	{
		id = iAllPlayers[i];
		
		if(g_iHealth[id] >= 255)
		{
			set_dhudmessage(55, 245, 55, 0.02, 0.90, 0, _, UPDATE_INTERVAL - 0.05, _, _, false);
			show_dhudmessage(id, "Health: %d", g_iHealth[id]);
		}
		if(g_bInformer[id])
		{
			set_hudmessage(55, 245, 55, 0.02, 0.18, 0, _, UPDATE_INTERVAL, _, _, 3);
			ShowSyncHudMsg(id, g_iHudInformer, szInformer);
		}

		
		if(!g_bAlive[id]) continue;
		
		new iDeadPlayers[32], iDeadNum; get_players(iDeadPlayers, iDeadNum, "bch");
		
		if(iDeadNum == 0) continue;
		
		new bool:bShowInfo[33];
		get_user_name(id, szName, charsmax(szName));
		iLen = formatex(szSpecInfo, charsmax(szSpecInfo), "Player: %s^nHealth: %dHP, Money: $%d, FPS: %d^n", szName, g_iHealth[id], g_iMoney[id], g_iPlayerFps[id]);
		
		for(new dead, j; j < iDeadNum; j++)
		{
			dead = iDeadPlayers[j];
			if(pev(dead, pev_iuser2) == id)
			{
				get_user_name(dead, szName, charsmax(szName));				
				iLen += formatex(szSpecInfo[iLen], charsmax(szSpecInfo) - iLen, "^n%s", szName);
				
				bShowInfo[dead] = true;
				bShowInfo[id] = true;
			}
		}
		if(bShowInfo[id])
		{
			for(new player, j; j < iAllNum; j++)
			{
				player = iAllPlayers[j];
				if(g_bSpecList[player] && bShowInfo[player])
				{
					set_hudmessage(245, 245, 245, 0.70, 0.15, 0, _, UPDATE_INTERVAL, _, _, 3);
					ShowSyncHudMsg(player, g_iHudSpecList, szSpecInfo);
				}
			}
		}
	}
}
//***** Speedometer *****//
public Task_ShowSpeed()
{
	new Float:fSpeed, Float:fVelocity[3], iSpecmode;
	new players[32], pnum; get_players(players, pnum, "ch");
	for(new id, i, target; id < pnum; i++)
	{
		id = players[i];
		if(!g_bSpeed[id]) continue;
		
		iSpecmode = pev(id, pev_iuser1);
		target = (iSpecmode == 1  || iSpecmode == 2 || iSpecmode == 4) ? pev(id, pev_iuser2) : id;
		pev(target, pev_velocity, fVelocity);
		
		fSpeed = vector_length(fVelocity);
		
		set_hudmessage(0, 55, 255, -1.0, 0.7, 0, _, 0.1, _, _, 2);
		ShowSyncHudMsg(id, g_iHudSpeed, "Speed: %3.2f", fSpeed);
	}
}
//********
public dr_selected_mode(id, mode)
{
	dr_get_mode(g_szCurMode, charsmax(g_szCurMode));
}
stock get_ct(&alive, &count)
{
	new players[32];
	get_players(players, count, "ceh", "CT");
	get_players(players, alive, "aceh", "CT");
}
