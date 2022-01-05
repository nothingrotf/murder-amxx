#include < amxmodx >
#include < screenfade_util >
#include < hamsandwich >
#include < reapi >

#define PLUGIN "Murder"
#define VERSION "1.0.0"
#define AUTHOR "Nothing"

#define UNUSED -5
#define HAND 2

#define DAMAGE_INSTAKILL 300

enum
{
    MURDERER = 0,
    DETECTIVE,
    BYSTANDER
}

public playersClass[ MAX_PLAYERS + 1 ] = { BYSTANDER, ... };
public minPlayers;

public bool:gameIsRunning;

public freezetimePointer;
public roundtimePointer;
public restartPointer;

public bool:canJoin;
public gameStarting;

public const MESSAGES[][] = {
    "Você é o Assassino",
    "Você é o Detetive",
    "Você é um Inocente"
}

enum _:WeaponInfoStruct
{
	WeaponName[15],
    WeaponId,
	WeaponIdType:weaponIdType,
	WeaponClip,
    WeaponAmmo,
    PModel[28],
    VModel[28],
    WModel[28]
}

public const WeaponsInfo[][WeaponInfoStruct] = {
    {
        /* WeaponName: */   "weapon_knife",
        /* WeaponId: */     UNUSED,
        /* weaponIdType: */ WEAPON_KNIFE,
        /* WeaponClip: */   UNUSED,
        /* WeaponAmmo: */   UNUSED,
        /* PModel: */       UNUSED,
        /* VModel: */       UNUSED,
        /* WModel: */       UNUSED
    },
    {
        /* WeaponName: */   "weapon_deagle",
        /* WeaponId: */     1,
        /* weaponIdType: */ WEAPON_DEAGLE,
        /* WeaponClip: */   1,
        /* WeaponAmmo: */   35,
        /* PModel: */       "models/murder/p_deagle.mdl",
        /* VModel: */       "models/murder/v_deagle.mdl",
        /* WModel: */       "models/murder/w_deagle.mdl"
    },
    {
        /* WeaponName: */   "weapon_p228",
        /* WeaponId: */     2,
        /* weaponIdType: */ WEAPON_P228,
        /* WeaponClip: */   0,
        /* WeaponAmmo: */   0,
        /* PModel: */       "models/murder/p_p228.mdl",
        /* VModel: */       "models/murder/v_p228.mdl",
        /* WModel: */       "models/murder/w_p228.mdl"
    }
}

public plugin_precache()
{
    for (new i = 0; i < sizeof WeaponsInfo; i++)
    {
        if (WeaponsInfo[i][PModel] != UNUSED)
        {
            precache_model(WeaponsInfo[i][PModel]);
            precache_model(WeaponsInfo[i][VModel]);
            precache_model(WeaponsInfo[i][WModel]);
        }
    }
}

public plugin_cfg()
{
    resetMurderCFG();
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    register_event("HLTV", "EventNewRound", "a", "1=0", "2=0");
    register_logevent("EventRoundStart", 2,  "1=Round_Start");

    bind_pcvar_num(register_cvar("murder_min_players", "4"), minPlayers);
    freezetimePointer = get_cvar_pointer("mp_freezetime");
    roundtimePointer = get_cvar_pointer("mp_roundtime");
    restartPointer = get_cvar_pointer("sv_restartround")

    for (new i = 0; i < sizeof WeaponsInfo; i++)
    {
        if (WeaponsInfo[i][WeaponClip] != UNUSED)
        {
            RegisterHam(Ham_Weapon_Reload, WeaponsInfo[i][WeaponName], "preWeaponReload", 0);
        }

        RegisterHam(Ham_Item_Deploy, WeaponsInfo[i][WeaponName], "postItemDeploy", 1);
        RegisterHam(Ham_Touch, "weaponbox", "preTouch", 0);
    }

    RegisterHookChain(RG_CWeaponBox_SetModel, "setModel", 0);
    RegisterHookChain(RG_CBasePlayer_TakeDamage, "takeDamage", 0);
}


/*
public client_disconnected(id)
{
    if (playersClass[id] == MURDERER)
    {

    }
}
*/

public postItemDeploy(weapon)
{
    new id = get_member(weapon, m_pPlayer);

    if (!is_user_connected(id))
    {
        return HAM_IGNORED;
    }

    new class = getWeaponClass(weapon);

    set_entvar(id, var_viewmodel, WeaponsInfo[class][VModel]);
    set_entvar(id, var_weaponmodel, WeaponsInfo[class][WModel]); 

    return HAM_IGNORED;
}

public preWeaponReload(weapon)
{
    new id = get_member(weapon, m_pPlayer);

    if (!is_user_connected(id))
    {
        return HAM_IGNORED;
    }

    new class = getWeaponClass(weapon);

    if (get_member(weapon, m_Weapon_iClip) < WeaponsInfo[class][WeaponClip])
    {
        return HAM_IGNORED;
    }

    new animation = 0

    set_entvar(id, var_weaponanim, animation);

    message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = id);
    write_byte(animation);
    write_byte(get_entvar(id, var_body));
    message_end();

    return HAM_SUPERCEDE;
}

public preTouch(weapon, id)
{
    if (getWeaponClass(weapon) != UNUSED)
    {
        return HAM_IGNORED;
    }

    return get_entvar(weapon, var_owner) == id ? HAM_IGNORED : HAM_SUPERCEDE;
}

public setModel(weapon)
{
    new class = getWeaponClass(weapon)
    if (class != UNUSED)
    {
        SetHookChainArg(2, ATYPE_STRING, WeaponsInfo[class][WModel]);
    }
    return HC_CONTINUE;
}

public takeDamage(id, inflictor, attacker)
{
    if (!is_user_connected(id) || id == attacker || attacker != inflictor)
    {
        return HC_CONTINUE;
    }

    SetHookChainArg(4, ATYPE_FLOAT, DAMAGE_INSTAKILL);

    return HC_CONTINUE;
}

public EventNewRound()
{
    arrayset(playersClass, BYSTANDER, sizeof(playersClass));
    new freezetime = get_pcvar_num(freezetimePointer);

    if (freezetime == 30)
    {
        set_pcvar_num(freezetimePointer, 10);
        canJoin = true;
    }
    else if (freezetime == 10)
    {
        startGame();
    }
}

public EventRoundStart()
{
    new freezetime = get_pcvar_num(freezetimePointer);
    if (freezetime == 10 && canJoin == true)
    {
        canJoin = false;
        gameStarting = true;
        set_pcvar_num(restartPointer, 1);
    }
    else if (canJoin == false)
    {
        resetMurderCFG();
        gameStarting = false;
    }
}

public client_putinserver(id)
{
    new players[32], playerCount;
    get_players(players, playerCount, "eh", "CT");

    if (playerCount >= minPlayers && !gameIsRunning)
    {
        preStartGame();
    }
}

public preStartGame()
{
    gameIsRunning = true;

    set_pcvar_num(freezetimePointer, 30);
    set_pcvar_num(restartPointer, 1);

}

public startGame()
{
    arrayset(playersClass, BYSTANDER, sizeof(playersClass));

    new detective, murderer, players[32], playerCount;

    get_players(players, playerCount, "eh", "CT");
    get_randomPlayers(players, playerCount, detective, murderer);

    playersClass[detective] = DETECTIVE;
    playersClass[murderer] = MURDERER;

    set_hudmessage(255, 255, 255, _, _, _, 10.0);

    for (new i = 0, id, msgId; i < playerCount; i++)
    {
        id = players[i];
        msgId = playersClass[id];

        UTIL_FadeToBlack(id, 10.0, true);
        show_hudmessage(id, MESSAGES[msgId]);

        rg_remove_all_items(id, false);
        getWeapons(id);
    }
}

public getWeapons(id)
{
    new class = HAND
    
    for (new i = 0; i < 2; i++)
    {
        new weapon = rg_give_custom_item(id, WeaponsInfo[class][WeaponName], GT_REPLACE, WeaponsInfo[class][WeaponId]);

        rg_set_iteminfo(weapon, ItemInfo_iMaxClip, WeaponsInfo[class][WeaponClip]);
        rg_set_user_ammo(id, WeaponsInfo[class][weaponIdType], WeaponsInfo[class][WeaponClip]);
        rg_set_user_bpammo(id, WeaponsInfo[class][weaponIdType], WeaponsInfo[class][WeaponAmmo]);
        
        class = playersClass[id]
        
        if (class == BYSTANDER)
        {
            break;
        }
    }

    return PLUGIN_HANDLED;
}

stock resetMurderCFG()
{
    set_pcvar_num(freezetimePointer, 0);
    set_pcvar_float(roundtimePointer, 99999.0);
}

stock get_randomPlayers(players[], playerCount, &detective, &murderer)
{
    detective = players[random(playerCount)];

    do
    {
        murderer = players[random(playerCount)];
    } while (detective == murderer);
}

stock getWeaponClass(weapon)
{
    new WeaponIdType:wId = get_member(weapon, m_iId)

    if (wId == WEAPON_KNIFE)
    {
        return MURDERER;
    }
    else if (wId == WEAPON_DEAGLE)
    {
        return DETECTIVE;
    } 
    else if (wId == WEAPON_P228)
    {
        return BYSTANDER;
    }
    else
    {
        return UNUSED;
    }
}