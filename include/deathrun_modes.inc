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

enum _:ModeData
{
	m_Name[32],
	m_Mark[16],
	m_RoundDelay,
	m_CurDelay,
	m_CT_BlockWeapon,
	m_TT_BlockWeapon,
	m_CT_BlockButtons,
	m_TT_BlockButtons,
	m_Bhop,
	m_Usp,
	m_Hide
};

/**
 * Mode registration.
 *
 * @param Name				Mode name, use ML key.
 * @param Mark				Mode mark, use this to get mode index in other plugins.
 * @param RoundDelay		Mode blocking in rounds.
 * @param CT_BlockWeapons	Allow CT pick up weapons.
 * @param TT_BlockWeapons	Allow TT pick up weapons.
 * @param CT_BlockButtons	Allow CT use buttons.
 * @param TT_BlockButtons	Allow TT use buttons.
 * @param Bhop				Enable autobhop.
 * @param Usp				Enable start with USP for CT.
 * @param Hide				Allow hide mode in menu.
 *
 * @return					Mode index.
 */
native dr_register_mode(Name[32], Mark[16], RoundDelay, CT_BlockWeapons, TT_BlockWeapons, CT_BlockButtons, TT_BlockButtons, Bhop, Usp, Hide = 0);

/**
 * Get current mode.
 * 
 * @param name				Mode name, here will be copied the current mode ML key.
 * @param size				Name size.
 * 
 * @return					Mode index.
 */
native dr_get_mode(name[] = "", size = 0);

/**
 * Set new mode.
 * 
 * @param mode				Mode index.
 * @param fwd				Call forward(dr_selected_mode).
 * @param id				Player index in forward.
 */
native dr_set_mode(mode, fwd = 0, id = 0);

/**
 * Get mode by mark.
 * 
 * @param mark				Mode mark.
 *
 * @return					Mode index.
 */
native dr_get_mode_by_mark(mark[]);

/**
 * Get full mode info.
 * 
 * @param mode				Mode index.
 * @param modeinfo			Info array.
 */
native dr_get_mode_info(mode, modeinfo[ModeData]);

/**
 * Set mode autobhop.
 * 
 * @param bhop				0 - OFF, 1 - ON.
 */
native dr_set_mode_bhop(bhop);

/**
 * Get mode autobhop.
 * 
 * @return					0 - OFF, 1 - ON.
 */
native dr_get_mode_bhop();

/**
 * Set player autobhop.
 * 
 * @note The value for a mode bhop more important than for the player.
 * 
 * @param id				Player index.
 * @param bhop				false - OFF, true - ON.
 */
native dr_set_user_bhop(id, bool:bhop);

/**
 * Get player autobhop.
 * 
 * @param id				Player index.
 */
native bool:dr_get_user_bhop(id);

/**
 * Forward which called when the selection mode.
 * 
 * @param id				Terrorist index.
 * @param mode				Mode index.
 */
forward dr_selected_mode(id, mode);
