#include <sdktools>
#include <simple_colors>

#pragma semicolon 1
#pragma newdecls required

int g_iCampTime;
int g_iSlapDamage;

float g_fRadius;
int g_iBeamSprite = -1;
int g_iHaloSprite = -1;
float g_fLastPos[MAXPLAYERS + 1][3];
float g_fSpawnEyeAng[MAXPLAYERS + 1][3];

Handle g_hTimerChecker[MAXPLAYERS + 1];

int g_iCampCount[MAXPLAYERS + 1];

#define			NAME 		"Simple Anti Camp"
#define			AUTHOR		"Master"
#define			VERSION		"1.0"
#define			URL			"https://cswild.pl/"

public Plugin myinfo =
{ 
	name	= NAME,
	author	= AUTHOR,
	version	= VERSION,
	url		= URL
};

public void OnPluginStart()
{
    HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerDeath);

    LoadSettings();

    LoadTranslations("Master_AntiCamp.phrases");
}

public void OnMapStart()
{
    g_iBeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt", true);
    g_iHaloSprite = PrecacheModel("materials/sprites/halo.vmt", true);
    PrecacheSound("buttons/blip1.wav", true);

    LoadSettings();
}

void LoadSettings()
{
	char sBuffer[256];
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "configs/Master/Master_AntiCamp.cfg");

	if(!FileExists(sBuffer))
	{
		SetFailState("File doesnt exist: %s", sBuffer);
		return;
	}

	KeyValues kv = new KeyValues("Configs");

	if(!kv.ImportFromFile(sBuffer))
	{
		delete kv;
		SetFailState("File not found %s!", sBuffer);
		return;
	}

	g_iCampTime = kv.GetNum("camp_time");
	g_iSlapDamage = kv.GetNum("slap_damage");
	g_fRadius = kv.GetFloat("radius");

	delete kv;
}

public void OnClientDisconnect(int iClient)
{
    DeleteTimer(iClient);
    g_iCampCount[iClient] = 0;
}

public Action Event_RoundEnd(Event hEvent, char[] sEvName, bool bDontBroadcast)
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i))
        {
            DeleteTimer(i);
            g_iCampCount[i] = 0;
        }
    }
}

public Action Event_PlayerDeath(Event hEvent, char[] sEvName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(hEvent.GetInt("userid"));

    DeleteTimer(iClient);
}

public Action Event_PlayerSpawn(Event hEvent, char[] sEvName, bool bDontBroadcast)
{
    if(IsWarmup()) return;

    int iClient = GetClientOfUserId(hEvent.GetInt("userid"));

    GetClientAbsOrigin(iClient, g_fLastPos[iClient]);
    GetClientAbsOrigin(iClient, g_fSpawnEyeAng[iClient]);

    DeleteTimer(iClient);
    g_hTimerChecker[iClient] = CreateTimer(2.0, Timer_Checker, GetClientUserId(iClient), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Checker(Handle hTimer, any iClientUserId)
{
    int iClient = GetClientOfUserId(iClientUserId);

    if(!iClient || !IsPlayerAlive(iClient))
    {
        g_hTimerChecker[iClient] = null;
        return Plugin_Stop;
    }

    if(g_hTimerChecker[iClient] == null) return Plugin_Stop;

    if(IsCamping(iClient)) g_iCampCount[iClient] += 2;
    else g_iCampCount[iClient] = 0;

    if(g_iCampCount[iClient] == g_iCampTime)
        for(int i = 1; i <= MaxClients; i++)
            S_PrintToChat(i, "%T", "Camp_Message", i, iClient);

    if(g_iCampCount[iClient] >= g_iCampTime)
    {
        float fVec[3];
        GetClientAbsOrigin(iClient, fVec);
        fVec[2] += 10;

        TE_SetupBeamRingPoint(fVec, 10.0, 375.0, g_iBeamSprite, g_iHaloSprite, 0, 10, 0.6, 10.0, 0.5, GetClientTeam(iClient) == 3 ? {0, 0, 150, 255} : {150, 0, 0, 255}, 10, 0);
        TE_SendToAll();

        EmitAmbientSound("buttons/blip1.wav", fVec, iClient, SNDLEVEL_RAIDSIREN);

        SlapPlayer(iClient, g_iSlapDamage, true);
    }

    return Plugin_Continue;
}

bool IsCamping(int iClient)
{
    float fCurrentPos[3];
    GetClientAbsOrigin(iClient, fCurrentPos);

    if(g_fRadius > GetVectorDistance(g_fSpawnEyeAng[iClient], fCurrentPos)) return false;

    if(g_fRadius > GetVectorDistance(g_fLastPos[iClient], fCurrentPos)) return true;

    g_fLastPos[iClient] = fCurrentPos;
    return false;
}

void DeleteTimer(int iClient)
{
    if(g_hTimerChecker[iClient] != null)
    {
        KillTimer(g_hTimerChecker[iClient]);
        g_hTimerChecker[iClient] = null;
    }
}

bool IsWarmup()
{
	return (GameRules_GetProp("m_bWarmupPeriod") == 1);
}