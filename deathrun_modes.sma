#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <colorchat>
#include <deathrun_modes>
#include <fun>

#define PLUGIN "Deathrun: Modes"
#define VERSION "0.4"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define DEFAULT_BHOP 1
#define DEFAULT_USP 1
#define TIMER 15

enum _:ModeData
{
	m_Name[32],
	m_RoundDelay,
	m_CurDelay,	
	m_CT_BlockWeapon,
	m_TT_BlockWeapon,
	m_CT_BlockButtons,
	m_TT_BlockButtons,
	m_Bhop,
	m_Usp,
	m_Hide//add min max players
};

#define NONE_MODE -1

new const PREFIX[] = "[DRM]";

new Array:g_aModes, g_iModesNum;

new g_eCurModeInfo[ModeData];
new g_iCurMode = NONE_MODE;
new g_iModeButtons;
new g_iMaxPlayers;

new g_iPage[33], g_iTimer[33], bool:g_bBhop[33];

new g_fwSelectedMode, g_fwReturn;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_cvar("deathrun_modes_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	
	register_clcmd("say /bhop", "Command_Bhop");
	
	RegisterHam(Ham_Spawn, "player", "Ham_PlayerSpawn_Post", 1);
	RegisterHam(Ham_Touch, "weaponbox", "Ham_TouchItems_Pre", 0);
	RegisterHam(Ham_Touch, "armoury_entity", "Ham_TouchItems_Pre", 0);
	RegisterHam(Ham_Touch, "weapon_shield", "Ham_TouchItems_Pre", 0);
	RegisterHam(Ham_Use, "func_button", "Ham_UseButtons_Pre", 0);
	RegisterHam(Ham_Player_Jump, "player", "Ham_PlayerJump_Pre", 0);
	
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
	register_event("TextMsg", "Event_Restart", "a", "2=#Game_Commencing", "2=#Game_will_restart_in");
	
	register_menucmd(register_menuid("ModesMenu"), 1023, "ModesMenu_Handler");
	
	g_aModes = ArrayCreate(ModeData);
	
	g_fwSelectedMode = CreateMultiForward("dr_selected_mode", ET_IGNORE, FP_CELL, FP_CELL);
	
	g_iMaxPlayers = get_maxplayers();
	
	g_iModeButtons = dr_register_mode
	(
		.Name = "Buttons",
		.RoundDelay = 0,
		.CT_BlockWeapons = 0,
		.TT_BlockWeapons = 0,
		.CT_BlockButtons = 0,
		.TT_BlockButtons = 0,
		.Bhop = 1,
		.Usp = 1,
		.Hide = 0
	);
	
	g_eCurModeInfo[m_Name] = "None";
	g_eCurModeInfo[m_Bhop] = DEFAULT_BHOP;
	g_eCurModeInfo[m_Usp] = DEFAULT_USP;
}

public plugin_natives()
{
	register_library("deathrun_modes");
	register_native("dr_register_mode", "native_register_mode", 1);
	register_native("dr_set_mode", "native_set_mode", 1);
	register_native("dr_get_mode", "native_get_mode", 1);
	register_native("dr_set_mode_bhop", "native_set_mode_bhop");
	register_native("dr_get_mode_bhop", "native_get_mode_bhop");
	register_native("dr_set_user_bhop", "native_set_user_bhop");
	register_native("dr_get_user_bhop", "native_get_user_bhop");
}
public native_register_mode(Name[32], RoundDelay, CT_BlockWeapons, TT_BlockWeapons, CT_BlockButtons, TT_BlockButtons, Bhop, Usp, Hide)
{
	param_convert(1);
	new ModeInfo[ModeData];
	
	copy(ModeInfo[m_Name], charsmax(ModeInfo[m_Name]), Name);
	ModeInfo[m_RoundDelay] = RoundDelay;
	ModeInfo[m_CT_BlockWeapon] = CT_BlockWeapons;
	ModeInfo[m_TT_BlockWeapon] = TT_BlockWeapons;
	ModeInfo[m_CT_BlockButtons] = CT_BlockButtons;
	ModeInfo[m_TT_BlockButtons] = TT_BlockButtons;
	ModeInfo[m_Bhop] = Bhop;
	ModeInfo[m_Usp] = Usp;
	ModeInfo[m_Hide] = Hide;
	
	ArrayPushArray(g_aModes, ModeInfo);
	g_iModesNum++;
	
	return g_iModesNum;
}
public native_set_mode(mode, fwd, id)
{
	if(mode && mode <= g_iModesNum)
	{
		g_iCurMode = mode - 1;
		ArrayGetArray(g_aModes, mode - 1, g_eCurModeInfo);
		g_eCurModeInfo[m_CurDelay] = g_eCurModeInfo[m_RoundDelay];
		ArraySetArray(g_aModes, mode - 1, g_eCurModeInfo);
		
		if(fwd) ExecuteForward(g_fwSelectedMode, g_fwReturn, id, mode);
	}
}
public native_get_mode(name[], size)
{
	param_convert(1);
	if(size) copy(name, size, g_eCurModeInfo[m_Name]);
	return g_iCurMode + 1;
}
public native_set_mode_bhop(bhop)
{
	g_eCurModeInfo[m_Bhop] = bhop;
}
public native_get_mode_bhop()
{
	return g_eCurModeInfo[m_Bhop];
}
public native_set_user_bhop(id, bool:bhop)
{
	g_bBhop[id] = bhop;
}
public bool:native_get_user_bhop(id)
{
	return g_bBhop[id];
}
public client_putinserver(id)
{
	g_bBhop[id] = true;
}
public Command_Bhop(id)
{
	if(!g_eCurModeInfo[m_Bhop]) return PLUGIN_CONTINUE;
	
	g_bBhop[id] = !g_bBhop[id];
	client_print_color(id, DontChange, "^4%s^1 Bhop is^3 %s^1.", PREFIX, g_bBhop[id] ? "enabled" : "disabled");
	
	return PLUGIN_CONTINUE;
}
//***** Events *****//
public Event_NewRound()
{
	g_iCurMode = NONE_MODE;
	g_eCurModeInfo[m_Name] = "None";
	g_eCurModeInfo[m_Bhop] = DEFAULT_BHOP;
	g_eCurModeInfo[m_Usp] = DEFAULT_USP;
	g_eCurModeInfo[m_CT_BlockWeapon] = 0;
	g_eCurModeInfo[m_TT_BlockWeapon] = 0;
	g_eCurModeInfo[m_CT_BlockButtons] = 0;
	g_eCurModeInfo[m_TT_BlockButtons] = 0;
	
	new ModeInfo[ModeData];
	for(new i = 0; i < g_iModesNum; i++)
	{
		ArrayGetArray(g_aModes, i, ModeInfo);
		if(ModeInfo[m_CurDelay])
		{
			ModeInfo[m_CurDelay]--;
			ArraySetArray(g_aModes, i, ModeInfo);
		}
	}
	for(new id = 1; id <= g_iMaxPlayers; id++)
	{
		remove_task(id);
	}
}
public Event_Restart()
{
	new ModeInfo[ModeData];
	for(new i = 0; i < g_iModesNum; i++)
	{
		ArrayGetArray(g_aModes, i, ModeInfo);
		ModeInfo[m_CurDelay] = 0;
		ArraySetArray(g_aModes, i, ModeInfo);
	}
}
//***** Ham *****//
public Ham_PlayerJump_Pre(id)
{	
	if(!g_eCurModeInfo[m_Bhop] || !g_bBhop[id]) return HAM_IGNORED;
	
	new flags = pev(id, pev_flags);
	
	if(flags & FL_WATERJUMP || pev(id, pev_waterlevel) >= 2 || !(flags & FL_ONGROUND))
		return HAM_IGNORED;

	new Float:fVelocity[3];
	
	pev(id, pev_velocity, fVelocity);
	
	fVelocity[2] = 250.0;
	
	set_pev(id, pev_velocity, fVelocity);
	set_pev(id, pev_gaitsequence, 6);
	
	return HAM_IGNORED;
}
public Ham_UseButtons_Pre(ent, caller, activator, use_type)
{
	if(activator == 0 || activator > 32) return HAM_IGNORED;
	
	new CsTeams:iTeam = cs_get_user_team(activator);
	
	if(g_iCurMode == NONE_MODE && iTeam == CS_TEAM_T)
	{
		dr_set_mode(g_iModeButtons, 1, activator);
		show_menu(activator, 0, "^n");
		client_print_color(0, DontChange, "^4%s^3 Terrorist^1 used button. Mode: ^4Buttons^1.", PREFIX);
		return HAM_IGNORED;
	}
	
	if(iTeam == CS_TEAM_T && g_eCurModeInfo[m_TT_BlockButtons] || iTeam == CS_TEAM_CT && g_eCurModeInfo[m_CT_BlockButtons])
	{
		return HAM_SUPERCEDE;
	}
	
	return HAM_IGNORED;
}
public Ham_TouchItems_Pre(ent, id)
{
	if(!(id && id <= g_iMaxPlayers) || g_iCurMode < 0) return HAM_IGNORED;
	
	new CsTeams:iTeam = cs_get_user_team(id);
	
	if(iTeam == CS_TEAM_T && g_eCurModeInfo[m_TT_BlockWeapon] || iTeam == CS_TEAM_CT && g_eCurModeInfo[m_CT_BlockWeapon])
	{
		return HAM_SUPERCEDE;
	}
	
	return HAM_IGNORED;
}
public Ham_PlayerSpawn_Post(id)
{
	if(!is_user_alive(id)) return HAM_IGNORED;
	
	set_user_rendering(id);
	
	new CsTeams:iTeam = cs_get_user_team(id);
	if(iTeam == CS_TEAM_CT && g_eCurModeInfo[m_Usp])
	{
		give_item(id, "weapon_usp");
		cs_set_user_bpammo(id, CSW_USP, 100);
	}
	
	if(g_iCurMode != NONE_MODE  || iTeam != CS_TEAM_T) return HAM_IGNORED;
	
	g_iTimer[id] = TIMER;
	Show_ModesMenu(id, g_iPage[id] = 0);
	set_task(1.0, "Task_MenuTimer", id, _, _, "a", TIMER);
	
	return HAM_IGNORED;
}
public Show_ModesMenu(id, iPage)
{
	if(iPage < 0) return PLUGIN_HANDLED;
	
	new iMax = g_iModesNum;
	new i = min(iPage * 8, iMax);
	new iStart = i - (i % 8);
	new iEnd = min(iStart + 8, iMax);
	
	iPage = iStart / 8;
	g_iPage[id] = iPage;
	
	new szMenu[512], iLen, Item, iKey, ModeInfo[ModeData];
	
	iLen = formatex(szMenu, charsmax(szMenu), "\ySelect mode:^n^n");
	
	for (i = iStart; i < iEnd; i++)
	{
		ArrayGetArray(g_aModes, i, ModeInfo);
		
		if(ModeInfo[m_Hide]) continue;
		
		if(ModeInfo[m_CurDelay] > 0)
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d%d. %s[\r%d\d]^n", ++Item, ModeInfo[m_Name], ModeInfo[m_CurDelay]);
		}
		else
		{
			iKey |= (1 << Item);
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d.\w %s^n", ++Item, ModeInfo[m_Name]);
		}
	}
	
	if(iMax > 8)
	{
		while(Item <= 8)
		{
			Item++;
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");
		}
		
		if (iEnd < iMax)
		{
			iKey |= (1 << 8);
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9.\w Next^n");
			if(iPage)
			{
				iKey |= (1 << 9);
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0.\w Back^n");
			}
		}
		else if(iPage)
		{
			iKey |= (1 << 9);
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^n\r0.\w Back^n");
		}
	}
	
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\dYou have \r%d \dseconds.", g_iTimer[id]);
	
	show_menu(id, iKey, szMenu, -1, "ModesMenu");
	
	return PLUGIN_HANDLED;
}
public ModesMenu_Handler(id, key)
{
	if(g_iCurMode != NONE_MODE || cs_get_user_team(id) != CS_TEAM_T) return PLUGIN_HANDLED;
	
	switch(key)
	{
		case 8: Show_ModesMenu(id, ++g_iPage[id]);
		case 9: Show_ModesMenu(id, --g_iPage[id]);
		default:
		{
			new iMode = key + g_iPage[id] * 8;
			
			g_iCurMode = iMode;
			
			ArrayGetArray(g_aModes, iMode, g_eCurModeInfo);
			g_eCurModeInfo[m_CurDelay] = g_eCurModeInfo[m_RoundDelay] + 1;
			ArraySetArray(g_aModes, iMode, g_eCurModeInfo);
			
			#if DEFAULT_USP < 1
			if(g_eCurModeInfo[m_Usp])
			{
			new id, players[32], pnum; get_players(players, pnum, "ae", "CT");
			for(new i = 0; i < pnum; i++)
			{
				new player, players[32], pnum; get_players(players, pnum, "ae", "CT");
				for(new i = 0; i < pnum; i++)
				{
					player = players[i];
					give_item(player, "weapon_usp");
					cs_set_user_bpammo(player, CSW_USP, 100);
				}
			}
			#else
			if(!g_eCurModeInfo[m_Usp])
			{
				new player, players[32], pnum; get_players(players, pnum, "ae", "CT");
				for(new i = 0; i < pnum; i++)
				{
					player = players[i];
					fm_strip_user_gun(player, CSW_USP);
				}
			}
			#endif
			
			ExecuteForward(g_fwSelectedMode, g_fwReturn, id, iMode + 1);
			
			client_print_color(0, Red, "^4%s^3 Terrorist^1 selected mode:^4 %s^1.", PREFIX, g_eCurModeInfo[m_Name]);
		}
	}
	
	return PLUGIN_HANDLED;
}
public Task_MenuTimer(id)
{
	if(g_iCurMode != NONE_MODE || !is_user_alive(id) || cs_get_user_team(id) != CS_TEAM_T)
	{
		if(task_exists(id)) remove_task(id);
		show_menu(id, 0, "^n");
		return;
	}
	if(--g_iTimer[id] <= 0)
	{
		show_menu(id, 0, "^n");
		
		new iMode;
		
		if(!is_all_modes_blocked())
		{
			do
			{
				iMode = random(g_iModesNum);
				ArrayGetArray(g_aModes, iMode, g_eCurModeInfo);
			} while(g_eCurModeInfo[m_CurDelay] && !g_eCurModeInfo[m_Hide]);
		}
		else
		{
			iMode = random(g_iModesNum);
			ArrayGetArray(g_aModes, iMode, g_eCurModeInfo);
		}
		
		g_iCurMode = iMode;
		
		g_eCurModeInfo[m_CurDelay] = g_eCurModeInfo[m_RoundDelay] + 1;
		ArraySetArray(g_aModes, iMode, g_eCurModeInfo);
		
		ExecuteForward(g_fwSelectedMode, g_fwReturn, id, iMode + 1);
		
		client_print_color(0, Red, "^4%s^3 Random^1 mode:^4 %s^1.", PREFIX, g_eCurModeInfo[m_Name]);
	}
	else
	{
		Show_ModesMenu(id, g_iPage[id]);
	}
}
//*****  *****//
bool:is_all_modes_blocked()
{
	new ModeInfo[ModeData];
	for(new i; i < g_iModesNum; i++)
	{
		ArrayGetArray(g_aModes, i, ModeInfo);
		if(!ModeInfo[m_CurDelay] && !ModeInfo[m_Hide]) return false;
	}
	return true;
}
