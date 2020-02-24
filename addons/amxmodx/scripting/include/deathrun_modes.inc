#if defined _deathrun_modes_included
  #endinput
#endif
#define _deathrun_modes_included

#if AMXX_VERSION_NUM >= 175
    #pragma reqlib deathrun_modes
    #if !defined AMXMODX_NOAUTOLOAD
        #pragma loadlib deathrun_modes
    #endif
#else
    #pragma library deathrun_modes
#endif

enum _:ModeData {
    m_Name[32],
    m_Mark[16],
    m_RoundDelay,
    m_CurDelay,
    ModeFlags:m_Flags
};

enum ModeFlags (<<=1) {
    /* Block ct pick up weapons */
    DRM_BLOCK_CT_WEAPON = 1,
    /* Block t pick up weapons */
    DRM_BLOCK_T_WEAPON,
    /* Block ct use buttons */
    DRM_BLOCK_CT_BUTTONS,
    /* Block t use buttons */
    DRM_BLOCK_T_BUTTONS,
    /* Allow autobhop */
    DRM_ALLOW_BHOP,
    /* Give usp to ct at round start */
    DRM_GIVE_USP,
    /* Hide mode in menu */
    DRM_HIDE
};

/**
 * Mode registration.
 *
 * @param name                  Mode name, use ML key.
 * @param mark                  Mode mark, use this to get mode index in other plugins.
 * @param round_delay           Mode blocking in rounds.
 * @param flags                 Mode flags, see ModeFlags.
 *
 * @return                      Mode index.
 */
native dr_register_mode(name[32], mark[16], round_delay, ModeFlags:flags);

/**
 * Get current mode.
 *
 * @param name                  Mode name, here will be copied the current mode ML key.
 * @param size                  Name size.
 * 
 * @return                      Mode index.
 */
native dr_get_mode(name[] = "", size = 0);

/**
 * Set new mode.
 *
 * @param mode                  Mode index.
 * @param fwd                   Call forward(dr_selected_mode).
 * @param id                    Player index in forward.
 */
native dr_set_mode(mode, fwd = 0, id = 0);

/**
 * Get mode by mark.
 *
 * @param mark                  Mode mark.
 *
 * @return                      Mode index.
 */
native dr_get_mode_by_mark(mark[]);

/**
 * Get full mode info.
 * 
 * @param mode                  Mode index.
 * @param modeinfo              Info array.
 */
native dr_get_mode_info(mode, modeinfo[ModeData]);

/**
 * Set mode autobhop.
 * 
 * @param bhop                  0 - OFF, 1 - ON.
 */
native dr_set_mode_bhop(bhop);

/**
 * Get mode autobhop.
 * 
 * @return                      0 - OFF, 1 - ON.
 */
native dr_get_mode_bhop();

/**
 * Set player autobhop.
 * 
 * @note The value for a mode bhop more important than for the player.
 * 
 * @param id                    Player index.
 * @param bhop                  false - OFF, true - ON.
 */
native dr_set_user_bhop(id, bool:bhop);

/**
 * Get player autobhop.
 * 
 * @param id                    Player index.
 */
native bool:dr_get_user_bhop(id);

/**
 * Forward which called when mode selected.
 * 
 * @param id                    Terrorist index.
 * @param mode                  Mode index.
 */
forward dr_selected_mode(id, mode);

/**
 * Forward which called when player changed bhop.
 * 
 * @param id                    Player index.
 * @param value                 Enabled or disabled bhop.
 */
forward dr_changed_bhop(id, value);
