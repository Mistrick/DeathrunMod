#include <amxmodx>
#include <engine>
#include <cstrike>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>
#include <deathrun_modes>

#define PLUGIN "Deathrun Mode: Snow"
#define VERSION "1.1.2"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define IsPlayer(%0) (%0 && %0 <= g_iMaxPlayers)

#define CAN_FLY_THROUGH_THE_WALLS
// #define STOP_BALL_AFTER_TOUCH
// #define AUTOTARGET

#define SNOWBALL_AMOUNT 200
#define SNOWBALL_DAMAGE 25.0
#define SNOWBALL_VELOCITY 1800.0
#define SNOWBALL_LIFETIME 5.0

#define AUTOTARGET_RANGE 128.0
#define AUTOTARGET_DELAY 1.0

new Float:HIT_MUL[9] = {
    0.0, // generic
    3.0, // head
    1.2, // chest
    1.1, // stomach
    0.9, // leftarm
    0.9, // rightarm
    0.75, // leftleg
    0.75, // rightleg
    0.0, // shield
};

const XO_CBASEPLAYERWEAPON = 4;
const XO_CBASEPLAYER = 5;
const m_pPlayer = 41;
const m_LastHitGroup = 75;

new const BALL_CLASSNAME[] = "snow_ball";
new const BALL_MODEL_W[] = "models/w_snowball.mdl";
new const BALL_MODEL_V[] = "models/v_snowball.mdl";
new const BALL_MODEL_P[] = "models/p_snowball.mdl";

new g_iModeSnow, g_iCurMode, g_iSprite, g_iMaxPlayers;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    
    RegisterHam(Ham_Spawn, "player", "Ham_PlayerSpawn_Post", true);
    RegisterHam(Ham_Item_Deploy, "weapon_smokegrenade", "Ham_SmokeGranade_Deploy_Post", true);
    
    register_forward(FM_SetModel, "FM_SetModel_Post", true);
    
    #if defined CAN_FLY_THROUGH_THE_WALLS
    register_forward(FM_ShouldCollide, "FM_ShouldCollide_Pre", false);
    #endif // CAN_FLY_THROUGH_THE_WALLS
    
    register_touch(BALL_CLASSNAME, "*", "Engine_TouchSnowBall");
    register_think(BALL_CLASSNAME, "Engine_ThinkSnowBall");
    
    register_message(get_user_msgid("TextMsg"), "Message_TextMsg");
    register_message(get_user_msgid("SendAudio"), "Message_SendAudio");
    
    g_iMaxPlayers = get_maxplayers();
    
    g_iModeSnow = dr_register_mode
    (
        .name = "DRM_MODE_SNOW",
        .mark = "snow",
        .round_delay = 3,
        .flags = DRM_BLOCK_CT_WEAPON | DRM_BLOCK_T_WEAPON | DRM_BLOCK_T_BUTTONS | DRM_ALLOW_BHOP
    );
}
public plugin_precache()
{
    precache_model(BALL_MODEL_V);
    precache_model(BALL_MODEL_P);
    precache_model(BALL_MODEL_W);
    g_iSprite = precache_model("sprites/zbeam3.spr");
}

public dr_selected_mode(id, mode)
{
    g_iCurMode = mode;
    if(g_iModeSnow == mode) {
        give_item(id, "weapon_smokegrenade");
        cs_set_user_bpammo(id, CSW_SMOKEGRENADE, SNOWBALL_AMOUNT);
    }
}

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

public Ham_PlayerSpawn_Post(id)
{
    if(g_iCurMode == g_iModeSnow) {
        if(is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_T) {
            give_item(id, "weapon_smokegrenade");
            cs_set_user_bpammo(id, CSW_SMOKEGRENADE, SNOWBALL_AMOUNT);
        }
    }
}

public Ham_SmokeGranade_Deploy_Post(weapon)
{
    if(g_iCurMode != g_iModeSnow) return HAM_IGNORED;
    
    new id = get_pdata_cbase(weapon, m_pPlayer, XO_CBASEPLAYERWEAPON);
    
    if(cs_get_user_team(id) == CS_TEAM_T) {
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
    if(is_user_alive(owner) && cs_get_user_team(owner) == CS_TEAM_T) {
        CreateSnowBall(owner);
        if(is_valid_ent(ent)) set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME);
    }
    
    return FMRES_IGNORED;
}
public CreateSnowBall(id)
{
    new Float:vec_start[3]; pev(id, pev_origin, vec_start);
    new Float:view_ofs[3]; pev(id, pev_view_ofs, view_ofs);
    xs_vec_add(vec_start, view_ofs, vec_start);
    
    new end_of_view[3]; get_user_origin(id, end_of_view, 3);
    new Float:vec_end[3]; IVecFVec(end_of_view, vec_end);
    
    new Float:velocity[3]; xs_vec_sub(vec_end, vec_start, velocity);
    new Float:normal[3]; xs_vec_normalize(velocity, normal);
    xs_vec_mul_scalar(normal, SNOWBALL_VELOCITY, velocity);
    
    new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
    
    set_pev(ent, pev_classname, BALL_CLASSNAME);
    set_pev(ent, pev_owner, id);
    set_pev(ent, pev_movetype, MOVETYPE_BOUNCE);
    set_pev(ent, pev_solid, SOLID_BBOX);
    set_pev(ent, pev_fuser1, get_gametime() + SNOWBALL_LIFETIME);
    set_pev(ent, pev_nextthink, get_gametime() + 0.1);
    
    engfunc(EngFunc_SetModel, ent, BALL_MODEL_W);
    engfunc(EngFunc_SetOrigin, ent, vec_start);
    engfunc(EngFunc_SetSize, ent, Float:{-3.0, -3.0, -3.0}, Float:{3.0, 3.0, 3.0});

    set_pev(ent, pev_velocity, velocity);
    
    set_task(0.1, "Task_SetTrail", ent);
    //trail_msg(ent, g_iSprite, 5, 8, 55, 55, 255, 150);
}
public Task_SetTrail(ent)
{
    if(is_valid_ent(ent)) {
        trail_msg(ent, g_iSprite, 5, 8, 55, 55, 255, 150);
    }
}
public Engine_TouchSnowBall(ent, toucher)
{
    if(!is_valid_ent(ent)) {
        return PLUGIN_CONTINUE;
    }
    if(IsPlayer(toucher) && SnowBallTakeDamage(ent, toucher)) {
        return PLUGIN_CONTINUE;
    }

    #if defined STOP_BALL_AFTER_TOUCH
    set_pev(ent, pev_movetype, MOVETYPE_FLY);
    set_pev(ent, pev_velocity, Float:{0.0, 0.0, 0.0});
    #else
    new Float:velocity[3]; pev(ent, pev_velocity, velocity);
    xs_vec_mul_scalar(velocity, 0.7, velocity);
    set_pev(ent, pev_velocity, velocity);
    #endif // STOP_BALL_AFTER_TOUCH

    return PLUGIN_CONTINUE;
}
SnowBallTakeDamage(snowball, player)
{
    new owner = pev(snowball, pev_owner);
    if(is_user_connected(owner)) {
        new hit_zone = get_hit_zone(player, snowball);
        if(hit_zone && is_user_alive(player) && cs_get_user_team(player) != cs_get_user_team(owner)) {
            set_pdata_int(player, m_LastHitGroup, hit_zone);

            ExecuteHamB(Ham_TakeDamage, player, snowball, owner, SNOWBALL_DAMAGE * HIT_MUL[hit_zone], 0);
            engfunc(EngFunc_RemoveEntity, snowball);
            return 1;
        }
    }
    return 0;
}
public Engine_ThinkSnowBall(ent)
{
    new Float:gametime = get_gametime();

    if(gametime >= pev(ent, pev_fuser1)) {
        set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME);
        return;
    }

    set_pev(ent, pev_nextthink, gametime + 0.1);

    #if defined AUTOTARGET
    if(pev(ent, pev_fuser2) > gametime) {
        return;
    }

    new p = -1;
    new target = 0;
    new Float:dist = -1.0;
    new Float:origin[3], Float:porigin[3];
    pev(ent, pev_origin, origin);

    new owner = pev(ent, pev_owner);

    while((p = engfunc(EngFunc_FindEntityInSphere, p, origin, AUTOTARGET_RANGE))) {
        if(p > 32) {
            break;
        }

        if(!is_user_alive(p)) {
            continue;
        }

        if(cs_get_user_team(p) == cs_get_user_team(owner)) {
            continue;
        }

        pev(p, pev_origin, porigin);
        new Float:d = vector_distance(origin, porigin);
        if(dist == -1.0 || dist > d) {
            dist = d;
            target = p;
        }
    }

    if(target) {
        new Float:velocity[3];
        pev(ent, pev_velocity, velocity);

        entity_set_follow(ent, target, vector_length(velocity), !random_num(0, 5));
        set_pev(ent, pev_fuser2, gametime + AUTOTARGET_DELAY);
    }
    #endif
}

#if defined CAN_FLY_THROUGH_THE_WALLS
public FM_ShouldCollide_Pre(ent, toucher)
{
    if(g_iCurMode != g_iModeSnow) return FMRES_IGNORED;
    
    if(IsPlayer(toucher)) return FMRES_IGNORED;
    
    new toucher_classname[32]; pev(toucher, pev_classname , toucher_classname, charsmax(toucher_classname));
    if(equal(toucher_classname, BALL_CLASSNAME)) {
        new ent_classname[32]; pev(ent, pev_classname , ent_classname, charsmax(ent_classname));
        if(equal(ent_classname, "func_wall")) {
            new Float:FXAmount = Float:pev(ent, pev_renderamt);
            if(FXAmount < 200.0) {
                forward_return(FMV_CELL, 0); 
                return FMRES_SUPERCEDE;
            }
        }
    }
    return FMRES_IGNORED;
}
#endif // CAN_FLY_THROUGH_THE_WALLS

stock get_hit_zone(player, ent)
{
    new Float:porigin[3], Float:eorigin[3];
    pev(player, pev_origin, porigin);
    pev(ent, pev_origin, eorigin);

    new Float:point[3];
    pev(ent, pev_velocity, point);
    xs_vec_normalize(point, point);
    xs_vec_mul_scalar(point, 32.0, point);
    xs_vec_sub(eorigin, point, eorigin);
    xs_vec_mul_scalar(point, 4.0, point);
    xs_vec_add(eorigin, point, porigin);

    new trace = 0;
    engfunc(EngFunc_TraceLine, eorigin, porigin, DONT_IGNORE_MONSTERS, ent, trace);

    return get_tr2(trace, TR_iHitgroup);
}

trail_msg(ent, sprite, lifetime, size, r, g, b, alpha)
{
    message_begin(MSG_ALL, SVC_TEMPENTITY);
    write_byte(TE_BEAMFOLLOW);// TE_BEAMFOLLOW
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

stock entity_set_follow(entity, target, Float:speed, bool:head) {
    if (!is_valid_ent(entity) || !is_valid_ent(target)) return 0;

    new Float:entity_origin[3], Float:target_origin[3];
    entity_get_vector(entity, EV_VEC_origin, entity_origin);
    entity_get_vector(target, EV_VEC_origin, target_origin);

    if(head) {
        new Float:view_ofs[3];
        entity_get_vector(target, EV_VEC_view_ofs, view_ofs);
        xs_vec_add(target_origin, view_ofs, target_origin);
    }

    new Float:diff[3];
    diff[0] = target_origin[0] - entity_origin[0];
    diff[1] = target_origin[1] - entity_origin[1];
    diff[2] = target_origin[2] - entity_origin[2];

    new Float:length = floatsqroot(floatpower(diff[0], 2.0) + floatpower(diff[1], 2.0) + floatpower(diff[2], 2.0));

    new Float:Velocity[3];
    Velocity[0] = diff[0] * (speed / length);
    Velocity[1] = diff[1] * (speed / length);
    Velocity[2] = diff[2] * (speed / length);

    entity_set_vector(entity, EV_VEC_velocity, Velocity);

    return 1;
}
