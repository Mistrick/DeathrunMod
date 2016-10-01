// Credits: Eriurias
#include <amxmodx>
#include <cstrike>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Mode: Rambo"
#define VERSION "0.2"
#define AUTHOR "Mistrick"

#define MIN_DIFF 8.0
#define MAX_OVERHEAT 200
#define BIG_HEAT 4
#define SMALL_HEAT 2

const XO_CBASEPLAYERWEAPON = 4;
const m_pPlayer = 41;
const m_iClip = 51;

enum (+=100)
{
	TASK_OVERHEAT_TICK = 150
};

enum _:Hooks
{
	Hook_AddToFullPack,
	Hook_CS_Item_CanDrop,
	Hook_Weapon_PrimaryAttack,
	Hook_Spawn,
	Hook_Player_PreThink
};

new HamHook:g_hHooks[Hooks];
new g_bEnabled, g_iModeRambo, g_iCurMode;
new g_iOverHeat[33], Float:g_fOldAngles[33][3];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	DisableHamForward(HamHook:g_hHooks[Hook_CS_Item_CanDrop] = RegisterHam(Ham_CS_Item_CanDrop, "weapon_m249", "Ham_Minigun_CanDrop_Pre", false));
	DisableHamForward(HamHook:g_hHooks[Hook_Weapon_PrimaryAttack] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_m249", "Ham_Minigun_PrimaryAttack_Pre", false));
	DisableHamForward(HamHook:g_hHooks[Hook_Spawn] = RegisterHam(Ham_Spawn, "player", "Ham_PlayerSpawn_Post", true));
	DisableHamForward(HamHook:g_hHooks[Hook_Player_PreThink] = RegisterHam(Ham_Player_PreThink, "player", "Ham_Player_PreThink_Pre", false));
	
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
	register_message(get_user_msgid("CurWeapon"), "Message_CurWeapon");
	
	g_iModeRambo = dr_register_mode
	(
		.Name = "DRM_MODE_RAMBO",
		.Mark = "rambo",
		.RoundDelay = 0,
		.CT_BlockWeapons = 0,
		.TT_BlockWeapons = 1,
		.CT_BlockButtons = 0,
		.TT_BlockButtons = 1,
		.Bhop = 1,
		.Usp = 1,
		.Hide = 0
	);
}
public client_disconnect(id)
{
	remove_task(id + TASK_OVERHEAT_TICK);
}
public Event_NewRound()
{
	DisableHooks();
}
public Ham_PlayerSpawn_Post(id)
{
	if(is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_T)
	{
		give_item(id, "weapon_m249");
		g_iOverHeat[id] = 0;
		set_task(0.1, "Task_OverHeat_Tick", id + TASK_OVERHEAT_TICK, .flags = "b");
	}
}
public Message_CurWeapon(msg, dest, id)
{
	if(g_iCurMode == g_iModeRambo && get_msg_arg_int(1) && get_msg_arg_int(2) == CSW_M249 && cs_get_user_team(id) == CS_TEAM_T)
	{
		set_msg_arg_int(2, ARG_BYTE, CSW_KNIFE);
		set_msg_arg_int(3, ARG_BYTE, -1);
	}
}
public Ham_Minigun_CanDrop_Pre(weapon)
{
	new player = get_pdata_cbase(weapon, m_pPlayer, XO_CBASEPLAYERWEAPON);
	
	if(cs_get_user_team(player) == CS_TEAM_T)
	{
		SetHamReturnInteger(false);
		return HAM_SUPERCEDE;
	}
	return HAM_IGNORED;
}
public Ham_Minigun_PrimaryAttack_Pre(weapon)
{
	new player = get_pdata_cbase(weapon, m_pPlayer, XO_CBASEPLAYERWEAPON);
	
	if(cs_get_user_team(player) != CS_TEAM_T) return HAM_IGNORED;
	
	cs_set_weapon_ammo(weapon, 100);
	
	new Float:angles[3]; pev(player, pev_angles, angles);
	new Float:diff = get_distance_f(angles, g_fOldAngles[player]);
	g_fOldAngles[player] = angles;
	
	g_iOverHeat[player] += (diff < MIN_DIFF) ? BIG_HEAT : SMALL_HEAT;
	
	SendMessage_BarTime2(player, MAX_OVERHEAT / 10, 100 - g_iOverHeat[player] * 100 / MAX_OVERHEAT);
	
	return HAM_IGNORED;
}
public Task_OverHeat_Tick(id)
{
	id -= TASK_OVERHEAT_TICK;
	
	if(g_iOverHeat[id] > 0)
	{
		g_iOverHeat[id]--;
	}
}
public Ham_Player_PreThink_Pre(id)
{
	if(g_iOverHeat[id] > MAX_OVERHEAT)
	{
		set_pev(id, pev_button, pev(id,pev_button) & ~IN_ATTACK);
	}
}
public FM_AddToFullPack_Post(es, e, ent, host, flags, player, pSet)
{
	if(player && host != ent)
	{
		if(cs_get_user_team(host) == CS_TEAM_T && cs_get_user_team(ent) == CS_TEAM_CT)
		{
			set_es(es, ES_RenderAmt, false);
			set_es(es, ES_RenderMode, kRenderTransAlpha);
		}
	}
}
public dr_selected_mode(id, mode)
{
	if(g_iCurMode == g_iModeRambo)
	{
		for(new i = 1; i < 33; i++)
		{
			remove_task(i + TASK_OVERHEAT_TICK);
			if(is_user_alive(i)) SendMessage_BarTime2(i, 0, 100);
		}
		DisableHooks();
	}
	
	g_iCurMode = mode;
	
	if(mode == g_iModeRambo)
	{
		EnableHooks();
		
		give_item(id, "weapon_m249");
		g_iOverHeat[id] = 0;
		set_task(0.1, "Task_OverHeat_Tick", id + TASK_OVERHEAT_TICK, .flags = "b");
	}
}
EnableHooks()
{
	g_bEnabled = true;
	
	g_hHooks[Hook_AddToFullPack] = HamHook:register_forward(FM_AddToFullPack, "FM_AddToFullPack_Post", true);
	for(new i = Hook_CS_Item_CanDrop; i < Hooks; i++)
	{
		EnableHamForward(g_hHooks[i]);
	}
}
DisableHooks()
{
	if(g_bEnabled)
	{
		g_bEnabled = false;
		
		unregister_forward(FM_AddToFullPack, _:g_hHooks[Hook_AddToFullPack], true);
		for(new i = Hook_CS_Item_CanDrop; i < Hooks; i++)
		{
			DisableHamForward(g_hHooks[i]);
		}
	}
}
stock SendMessage_BarTime2(id, duration, startpercent)
{
	static BarTime2; if(!BarTime2) BarTime2 = get_user_msgid("BarTime2");
	
	message_begin(MSG_ONE, BarTime2, .player = id);
	write_short(duration);
	write_short(startpercent);
	message_end();
}
