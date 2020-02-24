#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <deathrun_modes>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#include <dhudmessage>
#define client_disconnected client_disconnect
#endif

#define PLUGIN "Deathrun: Informer"
#define VERSION "1.0.1"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define UPDATE_INTERVAL 1.0
//#define DONT_SHOW_FOR_ALIVE

#define fm_get_user_team(%0) get_pdata_int(%0, 114)

new const PREFIX[] = "^4[DRI]";

enum (+=100) {
    TASK_FPSCOUNT = 100,
    TASK_INFORMER,
    TASK_SPEEDOMETER
};

new g_szCurMode[32], g_iConnectedCount, g_iMaxPlayers, g_iHudInformer, g_iHudSpecList, g_iHudSpeed;
new bool:g_bConnected[33], bool:g_bAlive[33], bool:g_bInformer[33], bool:g_bSpeed[33], bool:g_bSpecList[33];
new g_iHealth[33], g_iMoney[33], g_iFrames[33], g_iPlayerFps[33];
new bool:g_bLangMode;

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
    
    set_task(1.0, "Task_FramesCount", TASK_FPSCOUNT, .flags = "b");
    set_task(UPDATE_INTERVAL, "Task_ShowInfo", TASK_INFORMER, .flags = "b");
    set_task(0.1, "Task_ShowSpeed", TASK_SPEEDOMETER, .flags = "b");
}
public plugin_cfg()
{
    register_dictionary("deathrun_informer.txt");
}
public client_putinserver(id)
{
    g_bConnected[id] = true;
    g_bInformer[id] = true;
    g_bSpecList[id] = true;
    g_bSpeed[id] = true;
    g_iConnectedCount++;
}
public client_disconnected(id)
{
    g_bConnected[id] = false;
    g_bAlive[id] = false;
    g_bSpeed[id] = false;
    g_iConnectedCount--;
}
//***** Commands *****//
public Command_Informer(id)
{
    g_bInformer[id] = !g_bInformer[id];
    client_print_color(id, print_team_default, "%s^1 %L", PREFIX, id, "DRI_INFORMER_MSG", id, g_bInformer[id] ? "DRI_ENABLED" : "DRI_DISABLED");
}
public Command_SpecList(id)
{
    g_bSpecList[id] = !g_bSpecList[id];
    client_print_color(id, print_team_default, "%s^1 %L", PREFIX, id, "DRI_SPECLIST_MSG", id, g_bSpecList[id] ? "DRI_ENABLED" : "DRI_DISABLED");
}
public Command_Speed(id)
{
    g_bSpeed[id] = !g_bSpeed[id];
    client_print_color(id, print_team_default, "%s^1 %L", PREFIX, id, "DRI_SPEEDOMETER_MSG", id, g_bSpeed[id] ? "DRI_ENABLED" : "DRI_DISABLED");
}
//***** Events *****//
public Event_RoundStart()
{
    dr_get_mode(g_szCurMode, charsmax(g_szCurMode));
    g_bLangMode = GetLangTransKey(g_szCurMode) != TransKey_Bad;
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
    for(new id = 1; id <= g_iMaxPlayers; id++) {
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
    new iAlive, iCount; get_ct(iAlive, iCount);

    static szSpecInfo[256], szSpecList[1024];
    for(new id = 1; id <= g_iMaxPlayers; id++) {
        if(!g_bConnected[id]) continue;
        
        if(g_bInformer[id]) {
            if(g_bLangMode) {
                iLen = formatex(szInformer, charsmax(szInformer), "%L: %L^n", id, "DRI_MODE", id, g_szCurMode);
            } else {
                iLen = formatex(szInformer, charsmax(szInformer), "%L: %s^n", id, "DRI_MODE", g_szCurMode);
            }
            iLen += formatex(szInformer[iLen], charsmax(szInformer) - iLen, "%L^n", id, "DRI_TIMELEFT", iTimeLeft / 60, iTimeLeft % 60);
            iLen += formatex(szInformer[iLen], charsmax(szInformer) - iLen, "%L^n", id, "DRI_ALIVECT", iAlive, iCount);
            iLen += formatex(szInformer[iLen], charsmax(szInformer) - iLen, "%L", id, "DRI_ALL_PLAYERS", g_iConnectedCount, g_iMaxPlayers);
            
            set_hudmessage(55, 245, 55, 0.02, 0.18, 0, _, UPDATE_INTERVAL, _, _, 3);
            ShowSyncHudMsg(id, g_iHudInformer, szInformer);
        }
        
        if(!g_bAlive[id]) continue;
        
        if(g_iHealth[id] >= 255) {
            set_dhudmessage(55, 245, 55, 0.02, 0.90, 0, _, UPDATE_INTERVAL - 0.05);
            show_dhudmessage(id, "%L", id, "DRI_HEALTH", g_iHealth[id]);
        }
        
        new bool:bShowInfo[33];
        
        iLen = 0;
        
        for(new dead = 1; dead <= g_iMaxPlayers; dead++) {
            if(!g_bConnected[dead] || g_bAlive[dead]) continue;
            
            if(pev(dead, pev_iuser2) == id) {
                get_user_name(dead, szName, charsmax(szName));
                iLen += formatex(szSpecList[iLen], charsmax(szSpecList) - iLen, "^n%s", szName);
                
                bShowInfo[dead] = true;
                bShowInfo[id] = true;
            }
        }
        if(bShowInfo[id]) {
            #if defined DONT_SHOW_FOR_ALIVE
            bShowInfo[id] = false;
            #endif
            
            get_user_name(id, szName, charsmax(szName));
            for(new player = 1; player < g_iMaxPlayers; player++) {
                if(g_bSpecList[player] && bShowInfo[player]) {
                    formatex(szSpecInfo, charsmax(szSpecInfo), "%L^n", player, "DRI_SPECLIST", szName, g_iHealth[id], g_iMoney[id], g_iPlayerFps[id]);
                    
                    set_hudmessage(245, 245, 245, 0.70, 0.15, 0, _, UPDATE_INTERVAL, _, _, 3);
                    ShowSyncHudMsg(player, g_iHudSpecList, "%s%s", szSpecInfo, szSpecList);
                }
            }
        }
    }
}
//***** Speedometer *****//
public Task_ShowSpeed()
{
    new Float:fSpeed, Float:fVelocity[3], iSpecmode;
    for(new id = 1, target; id <= g_iMaxPlayers; id++) {
        if(!g_bSpeed[id]) continue;
        
        iSpecmode = pev(id, pev_iuser1);
        target = (iSpecmode == 1  || iSpecmode == 2 || iSpecmode == 4) ? pev(id, pev_iuser2) : id;
        pev(target, pev_velocity, fVelocity);
        
        fSpeed = vector_length(fVelocity);
        
        set_hudmessage(0, 55, 255, -1.0, 0.7, 0, _, 0.1, _, _, 2);
        ShowSyncHudMsg(id, g_iHudSpeed, "%L", id, "DRI_SPEEDOMETER", fSpeed);
    }
}
public dr_selected_mode(id, mode)
{
    dr_get_mode(g_szCurMode, charsmax(g_szCurMode));
    g_bLangMode = GetLangTransKey(g_szCurMode) != TransKey_Bad;
}
stock get_ct(&alive, &count)
{
    count = 0; alive = 0;
    for(new id = 1; id <= g_iMaxPlayers; id++)
    {
        if(g_bConnected[id] && fm_get_user_team(id) == 2)
        {
            count++;
            if(g_bAlive[id]) alive++;
        }
    }
}
