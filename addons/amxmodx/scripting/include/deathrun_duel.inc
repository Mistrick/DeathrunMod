#if defined _deathrun_duel_included
  #endinput
#endif
#define _deathrun_duel_included

#if AMXX_VERSION_NUM >= 175
    #pragma reqlib deathrun_duel
    #if !defined AMXMODX_NOAUTOLOAD
        #pragma loadlib deathrun_duel
    #endif
#else
    #pragma library deathrun_duel
#endif

enum CancelType
{
    CType_TimeOver,
    CType_PlayerDisconneced,
    CType_PlayerDied,
    CType_ModeChanged
}

 /**
 * Forward which called before duel start, warm up time
 * 
 * @param duelist_ct            Player index.
 * @param duelist_t             Player index.
 */
forward dr_duel_prestart(duelist_ct, duelist_t);

 /**
 * Forward which called when duel started
 * 
 * @param duelist_ct            Player index.
 * @param duelist_t             Player index.
 */
forward dr_duel_start(duelist_ct, duelist_t);

 /**
 * Forward which called when duel overed
 * 
 * @param winner                Player index.
 * @param looser                Player index.
 */
forward dr_duel_finish(winner, looser);

 /**
 * Forward which called when duel canceled
 * 
 * @param type                  Cancel type
 */
forward dr_duel_canceled(CancelType:type);
