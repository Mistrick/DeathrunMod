#if defined _deathrun_modes_included
  #endinput
#endif
#define _deathrun_modes_included

/**
 * Регистрация режима.
 *
 * @param Name				Имя режима, будет отображено в меню.
 * @param RoundDelay		На сколько раундов будет заблокирован режим для выбора.
 * @param CT_BlockWeapons	Позволяет блокировать взятие лежащего оружия для CT.
 * @param TT_BlockWeapons	Позволяет блокировать взятие лежащего оружия для T.
 * @param CT_BlockButtons	Позволяет блокировать использование кнопок для CT.
 * @param TT_BlockButtons	Позволяет блокировать использование кнопок для T.
 * @param Bhop				Включить/выключить автобхоп.
 * @param Usp				Включить/выключить выдачу USP для CT.
 * @param Hide				Позволяет скрывать режим в меню.
 *
 * @return					Возвращает индекс режима.
 */
native dr_register_mode(Name[32], RoundDelay, CT_BlockWeapons, TT_BlockWeapons, CT_BlockButtons, TT_BlockButtons, Bhop, Usp, Hide = 0);

/**
 * Получение имени и индекса текущего режима.
 * 
 * @param name				Сюда будет скопировано имя режима.
 * @param size				Размер массива name.
 * 
 * @return					Возвращает индекс режима.
 */
native dr_get_mode(name[] = "", size = 0);

/**
 * Установка режима.
 * 
 * @param mode				Индекс режима, полученный при регистрации.
 * @param fwd				Вызывать ли форвард выбора режима(dr_selected_mode).
 * @param id				Индекс игрока от которого будет вызван форвард выбора режима.
 */
native dr_set_mode(mode, fwd = 0, id = 0);

/**
 * Установка автобхопа для текущего режима.
 * 
 * @param bhop				0 - выключение, 1 - включение.
 */
native dr_set_mode_bhop(bhop);

/**
 * Получение значения автобхопа для текущего режима.
 * 
 * @return					0 - выключен, 1 - включен.
 */
native dr_get_mode_bhop();

/**
 * Установка автобхопа для конкретного игрока.
 * 
 * @note Значение bhop для режима важнее, чем для игрока.
 * 
 * @param id				Индекс игрока.
 * @param bhop				0 - выключение, 1 - включение.
 */
native dr_set_user_bhop(id, bool:bhop);

/**
 * Получение значения автобхопа для конкретного игрока.
 * 
 * @param id				Индекс игрока.
 */
native bool:dr_get_user_bhop(id);

/**
 * Форвард, который вызывается после выбора режима.
 * 
 * @param id				Индекс игрока.
 * @param mode				Индекс режима.
 */
forward dr_selected_mode(id, mode);

/**
 * deathrun_core
 */

/**
 * Получение индекса текущего террориста.
 * 
 * @return					Индекс игрока.
 */
native dr_get_terrorist();

/**
 * Устанавливает игрока, который станет террористом в следующем раунде.
 * 
 * @param id				Индекс игрока.
 */
native dr_set_next_terrorist(id);

/**
 * deathrun_modes_duel
 */

 /**
 * Форвард, который вызывается до начала дуэли, во время разминки.
 * 
 * @param duelist_ct			Индекс игрока.
 * @param duelist_t				Индекс игрока.
 */
forward dr_duel_prestart(duelist_ct, duelist_t);

 /**
 * Форвард, который вызывается когда началась дуэль.
 * 
 * @param duelist_ct			Индекс игрока.
 * @param duelist_t				Индекс игрока.
 */
forward dr_duel_start(duelist_ct, duelist_t);

 /**
 * Форвард, который вызывается когда закончилась дуэль.
 * 
 * @param winner				Индекс победителя.
 * @param looser				Индекс проигравшего.
 */
forward dr_duel_finish(winner, looser);

 /**
 * Форвард, который вызывается когда отменили дуэль.
 */
forward dr_duel_canceled();
