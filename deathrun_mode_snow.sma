#include <amxmodx>
#include <engine>
#include <cstrike>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>
#include <deathrun_modes>

#define PLUGIN "Deathrun Mode: Snow"
#define VERSION "0.4.1"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define IsPlayer(%0) (%0 && %0 <= 32)

//#define STOP_BALL_AFTER_TOUCH

#define SNOWBALL_AMOUNT 200
#define SNOWBALL_DAMAGE 25.0
#define SNOWBALL_VELOCITY 2000.0
#define SNOWBALL_LIFETIME 5.0

const XO_CBASEPLAYERWEAPON = 4;
const XO_CBASEPLAYER = 5;
const m_pPlayer = 41;

new const BALL_CLASSNAME[] = "snow_ball";
new const BALL_MODEL_W[] = "models/w_snowball.mdl";
new const BALL_MODEL_V[] = "models/v_snowball.mdl";
new const BALL_MODEL_P[] = "models/p_snowball.mdl";

new g_iModeSnow, g_iCurMode, g_iSprite;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
	
	RegisterHam(Ham_Item_Deploy, "weapon_smokegrenade", "Ham_SmokeGranade_Deploy_Post", true);
	
	register_forward(FM_SetModel, "FM_SetModel_Post", true);
	register_forward(FM_ShouldCollide, "FM_ShouldCollide_Pre", false);
	
	register_touch(BALL_CLASSNAME, "*", "Engine_TouchSnowBall");
	register_think(BALL_CLASSNAME, "Engine_ThinkSnowBall");
	
	register_message(get_user_msgid("TextMsg"), "Message_TextMsg");
	register_message(get_user_msgid("SendAudio"), "Message_SendAudio");
	
	g_iModeSnow = dr_register_mode
	(
		.Name = "DRM_MODE_SNOW",
		.Mark = "snow",
		.RoundDelay = 3,
		.CT_BlockWeapons = 1,
		.TT_BlockWeapons = 1,
		.CT_BlockButtons = 0,
		.TT_BlockButtons = 1,
		.Bhop = 1,
		.Usp = 0,
		.Hide = 0
	);
}
public plugin_precache()
{
	precache_model(BALL_MODEL_V);
	precache_model(BALL_MODEL_P);
	precache_model(BALL_MODEL_W);
	g_iSprite = precache_model("sprites/zbeam3.spr");
}
//***** Events *****//
public Event_NewRound()
{
	g_iCurMode = -1;
}
//***** *****//
public dr_selected_mode(id, mode)
{
	g_iCurMode = mode;
	if(g_iModeSnow == mode)
	{
		give_item(id, "weapon_smokegrenade");
		cs_set_user_bpammo(id, CSW_SMOKEGRENADE, SNOWBALL_AMOUNT);
	}
}
//****************************//
public Message_TextMsg(msgid, dest, reciver)
{
	if(g_iCurMode != g_iModeSnow) return PLUGIN_CONTINUE;
	
	if(get_msg_args() != 5 || get_msg_argtype(5) != ARG_STRING) return PLUGIN_CONTINUE;

	new arg5[20]; get_msg_arg_string(5, arg5, charsmax(arg5));
	
	if(equal(arg5, "#Fire_in_the_hole")) return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}
public Message_SendAudio(msgid, dest, reciver)
{
	if(g_iCurMode != g_iModeSnow) return PLUGIN_CONTINUE;
	
	if(get_msg_args() != 3 || get_msg_argtype(2) != ARG_STRING) return PLUGIN_CONTINUE;

	new arg2[20]; get_msg_arg_string(2, arg2, charsmax(arg2));
	
	if(equal(arg2[1], "!MRAD_FIREINHOLE")) return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}
//****************************//
public Ham_SmokeGranade_Deploy_Post(weapon)
{
	if(g_iCurMode != g_iModeSnow) return HAM_IGNORED;
	
	new id = get_pdata_cbase(weapon, m_pPlayer, XO_CBASEPLAYERWEAPON);
	
	if(cs_get_user_team(id) == CS_TEAM_T)
	{
		set_pev(id, pev_viewmodel2, BALL_MODEL_V);
		set_pev(id, pev_weaponmodel2, BALL_MODEL_P);
	}
	
	return HAM_IGNORED;
}
public FM_SetModel_Post(ent, const model[])
{
	if(g_iCurMode != g_iModeSnow) return FMRES_IGNORED;
	
	if(!equali(model, "models/w_smokegrenade.mdl")) return FMRES_IGNORED;
	
	new owner = pev(ent, pev_owner);
	if(is_user_alive(owner) && cs_get_user_team(owner) == CS_TEAM_T)
	{
		CreateSnowBall(owner);
		if(is_valid_ent(ent)) set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME);
	}
	
	return FMRES_IGNORED;
}
public CreateSnowBall(id)
{
	new iVectorStart[3]; get_user_origin(id, iVectorStart, 1);
	new iVectorEnd[3]; get_user_origin(id, iVectorEnd, 3);
	new Float:fVectorStart[3]; IVecFVec(iVectorStart, fVectorStart);
	new Float:fVectorEnd[3]; IVecFVec(iVectorEnd, fVectorEnd);
	new Float:fVelocity[3]; xs_vec_sub(fVectorEnd, fVectorStart, fVelocity);
	new Float:fNormal[3]; xs_vec_normalize(fVelocity, fNormal);
	xs_vec_mul_scalar(fNormal, SNOWBALL_VELOCITY, fVelocity);
	xs_vec_mul_scalar(fNormal, 32.0, fNormal);
	xs_vec_add(fVectorStart, fNormal, fVectorStart);
	
	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
		
	set_pev(ent, pev_classname, BALL_CLASSNAME);
	set_pev(ent, pev_owner, id);
	set_pev(ent, pev_movetype, MOVETYPE_BOUNCE);
	set_pev(ent, pev_solid, SOLID_TRIGGER);
	set_pev(ent, pev_nextthink, get_gametime() + SNOWBALL_LIFETIME);
	
	engfunc(EngFunc_SetModel, ent, BALL_MODEL_W);
	engfunc(EngFunc_SetOrigin, ent, fVectorStart);
	engfunc(EngFunc_SetSize, ent, Float:{-3.0, -3.0, -3.0}, Float:{3.0, 3.0, 3.0});

	set_pev(ent, pev_velocity, fVelocity);
	
	set_task(0.1, "Task_SetTrail", ent);
	//trail_msg(ent, g_iSprite, 5, 8, 55, 55, 255, 150);
}
public Task_SetTrail(ent)
{
	trail_msg(ent, g_iSprite, 5, 8, 55, 55, 255, 150);
}
public Engine_TouchSnowBall(ent, toucher)
{
	if(!is_valid_ent(ent))
	{
		return PLUGIN_CONTINUE;
	}
	if(IsPlayer(toucher) && SnowBallTakeDamage(ent, toucher))
	{
		return PLUGIN_CONTINUE;
	}
	#if defined STOP_BALL_AFTER_TOUCH
	set_pev(ent, pev_movetype, MOVETYPE_FLY);
	set_pev(ent, pev_velocity, Float:{0.0, 0.0, 0.0});
	#else
	new Float:fVelocity[3]; pev(ent, pev_velocity, fVelocity);
	xs_vec_mul_scalar(fVelocity, 0.7, fVelocity);
	set_pev(ent, pev_velocity, fVelocity);
	#endif
	return PLUGIN_CONTINUE;
}
SnowBallTakeDamage(snowball, player)
{
	new owner = pev(snowball, pev_owner);
	if(is_user_connected(owner))
	{
		if(is_user_alive(player) && cs_get_user_team(player) != cs_get_user_team(owner))
		{
			ExecuteHamB(Ham_TakeDamage, player, snowball, owner, SNOWBALL_DAMAGE, 0);
			engfunc(EngFunc_RemoveEntity, snowball);
			return 1;
		}
	}
	return 0;
}
public Engine_ThinkSnowBall(ent)
{
	set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME);
}
public FM_ShouldCollide_Pre(ent, toucher)
{
	if(g_iCurMode != g_iModeSnow) return FMRES_IGNORED;
	
	if(IsPlayer(toucher)) return FMRES_IGNORED;
	
	new szToucherClassName[32]; pev(toucher, pev_classname , szToucherClassName, charsmax(szToucherClassName));
	if(equal(szToucherClassName, BALL_CLASSNAME))
	{
		new szClassName[32]; pev(ent, pev_classname , szClassName, charsmax(szClassName));
		if(equal(szClassName, "func_wall"))
		{
			new Float:FXAmount = Float:pev(ent, pev_renderamt);			
			if(FXAmount < 200.0)
			{
				forward_return(FMV_CELL, 0); 
				return FMRES_SUPERCEDE;
			}
		}
	}
	return FMRES_IGNORED;
}

trail_msg(ent, sprite, lifetime, size, r, g, b, alpha)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMFOLLOW);	// TE_BEAMFOLLOW
	write_short(ent);
	write_short(sprite);//sprite
	write_byte(lifetime * 10);//lifetime
	write_byte(size);//size
	write_byte(r);//r
	write_byte(g);//g
	write_byte(b);//b
	write_byte(alpha);//alpha
	message_end();
}
