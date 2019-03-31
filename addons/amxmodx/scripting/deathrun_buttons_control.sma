// Credits: R3X
#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>

#define PLUGIN "Deathrun: Buttons Control"
#define VERSION "1.0.1"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define MAX_BUTTONS 128
#define BUTTON_MIN_DELAY 5.0
#define BUTTON_MAX_USE 1

#define PDATA_SAFE 2

#define get_button_index(%0) (pev(%0, pev_iuser4) - 1)
#define set_button_index(%0,%1) set_pev(%0, pev_iuser4, %1)
#define fm_get_user_team(%0) get_pdata_int(%0, 114)

const m_flWait = 44;
const XO_CBASETOGGLE1 = 4;

new const g_szButtons[][] = {"func_button", "func_rot_button"};

new g_iButtonsEnt[MAX_BUTTONS];
new g_iButtonsCount;

#if BUTTON_MAX_USE > 0
new g_iButtonsUsed[MAX_BUTTONS];
#endif

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
    register_dictionary("deathrun_core.txt");
    LoadButtons();
}
LoadButtons()
{
    for(new i; i < sizeof(g_szButtons); i++) {
        #if BUTTON_MAX_USE > 0
        new last_count = g_iButtonsCount;
        #endif
        
        new ent = FM_NULLENT;
        
        while(g_iButtonsCount < MAX_BUTTONS && (ent = find_ent_by_class(ent, g_szButtons[i]))) {
            g_iButtonsEnt[g_iButtonsCount++] = ent;
            set_button_index(ent, g_iButtonsCount);
            
            new Float:fButtonDelay = get_pdata_float(ent, m_flWait, XO_CBASETOGGLE1);
            if(fButtonDelay < BUTTON_MIN_DELAY) {
                set_pdata_float(ent, m_flWait, BUTTON_MIN_DELAY, XO_CBASETOGGLE1);
            }
        }
        #if BUTTON_MAX_USE > 0
        if(last_count < g_iButtonsCount) {
            RegisterHam(Ham_Use, g_szButtons[i], "Ham_ButtonUse_Pre", false);
        }
        #endif
    }
    if(!g_iButtonsCount) {
        log_amx("Map doesn't have any buttons.");
        pause("a");
    }
}
public Event_NewRound()
{
    RestoreButtons();
}
RestoreButtons()
{
    arrayset(g_iButtonsUsed, 0, g_iButtonsCount);
    for(new i, ent; i < g_iButtonsCount; i++) {
        ent = g_iButtonsEnt[i];
        if(pev(ent, pev_frame) > 0.0) {
            new Float:nextthink; pev(ent, pev_nextthink, nextthink);
            set_pev(ent, pev_ltime, nextthink - 0.1);
        }
    }
}
#if BUTTON_MAX_USE > 0
public Ham_ButtonUse_Pre(ent, caller, activator, use_type)
{
    if(caller != activator || pev_valid(caller) != PDATA_SAFE) return HAM_IGNORED;
    
    if(pev(ent, pev_frame) > 0.0) return HAM_IGNORED;
    
    if(fm_get_user_team(caller) != 1) return HAM_IGNORED;
    
    new index = get_button_index(ent);
    
    if(index == -1) return HAM_IGNORED;
    
    if(g_iButtonsUsed[index] >= BUTTON_MAX_USE) {
        client_print(caller, print_center, "%L", LANG_PLAYER, "DRBC_CANT_USE");
        return HAM_SUPERCEDE;
    }
    
    g_iButtonsUsed[index]++;
    
    return HAM_IGNORED;
}
#endif
