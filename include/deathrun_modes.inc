native dr_register_mode(Name[32], RoundDelay, CT_BlockWeapons, TT_BlockWeapons, CT_BlockButtons, TT_BlockButtons, Bhop, Usp, Hide = 0);
native dr_get_mode(name[] = "", size = 0);
native dr_get_mode_by_name(name[]);
native dr_set_mode(mode, fwd = 0, id = 0);
native dr_set_mode_bhop(bhop);
native dr_get_mode_bhop();

native dr_set_user_bhop(id, bool:bhop);
native bool:dr_get_user_bhop(id);

forward dr_selected_mode(id, mode);
