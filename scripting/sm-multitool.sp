//Pragma
#pragma semicolon 1
#pragma newdecls required

//Includes
#include <sourcemod>
#include <adminmenu>

#include <misc-colors>
#include <misc-csgo>
#include <misc-l4d>
#include <misc-methodmaps>
#include <misc-sm>
#include <misc-tf>

#undef REQUIRE_PLUGIN
#include <tf2attributes>
#include <tf_econ_data>
#include <left4dhooks>
#define REQUIRE_PLUGIN

//Defines
#define PLUGIN_NAME "[SM] Multitool"
#define PLUGIN_AUTHOR "KeithGDR"
#define PLUGIN_DESCRIPTION "A very large and bloated plugin that consists of tools via commands and code to make managing servers and developing plugins easy."
#define PLUGIN_VERSION "1.1.6"
#define PLUGIN_URL "https://github.com/KeithGDR/sm-multitool"

#define TAG "[Tools]"

//Globals
ConVar convar_Enabled;
ConVar convar_Autoreload;
ConVar convar_DisableWaitingForPlayers;

EngineVersion game;
char g_Tag[64];
char g_ChatColor[32];
char g_UniqueIdent[32];

ArrayList g_Commands;
StringMap g_CommandFlags;
StringMap g_CachedTimes;

int g_iAmmo[MAX_ENTITY_LIMIT + 1];
int g_iClip[MAX_ENTITY_LIMIT + 1];

bool g_Bunnyhopping[MAXPLAYERS + 1];

TopMenu hTopMenu;
bool g_SpewConditions;
bool g_SpewSounds;
bool g_SpewAmbients;
bool g_SpewEntities;
bool g_SpewTriggers;
bool g_SpewCommands;

//entity tools
ArrayList g_OwnedEntities[MAXPLAYERS + 1];
int g_iTarget[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

bool g_Locked;
ArrayList g_HookEvents;

//L4D/2 Respawning
Handle hRoundRespawn;
Handle hBecomeGhost;
Handle hState_Transition;

//Timers
Handle g_Timer[MAXPLAYERS + 1];
float g_TimerVal[MAXPLAYERS + 1];

#define EDITING_NAME 1
#define EDITING_MIN 2
#define EDITING_MAX 3

enum struct Trigger {
	char name[64];
	float origin[3];
	float minbounds[3];
	float maxbounds[3];

	int editing;

	void Clear() {
		this.name[0] = '\0';
		for (int i = 0; i < 3; i++) {
			this.origin[i] = 0.0;
			this.minbounds[i] = 0.0;
			this.maxbounds[i] = 0.0;
		}

		this.DefaultsBounds();
	}

	void DefaultsBounds() {
		this.minbounds[0] = -150.0;
		this.minbounds[1] = -150.0;
		this.minbounds[2] = 0.0;

		this.maxbounds[0] = 150.0;
		this.maxbounds[1] = 150.0;
		this.maxbounds[2] = 150.0;
	}

	void SetOrigin(float vec[3]) {
		for (int i = 0; i < 3; i++) {
			this.origin[i] = vec[i];
		}
	}

	void SetMin(float vec[3]) {
		for (int i = 0; i < 3; i++) {
			this.minbounds[i] = vec[i];
		}
	}

	void SetMax(float vec[3]) {
		for (int i = 0; i < 3; i++) {
			this.maxbounds[i] = vec[i];
		}
	}

	int Create(){
		int entity = CreateEntityByName("trigger_multiple");

		if (!IsValidEntity(entity)) {
			return entity;
		}
		
		float origin[3];
		for (int i = 0; i < 3; i++) {
			origin[i] = this.origin[i];
		}
		TeleportEntity(entity, origin, NULL_VECTOR, NULL_VECTOR);
		
		DispatchKeyValue(entity, "spawnflags", "64");
		DispatchKeyValue(entity, "targetname", this.name);

		DispatchSpawn(entity);
		ActivateEntity(entity);

		AcceptEntityInput(entity, "Enable");

		SetEntityModel(entity, "models/error.mdl");

		float min[3]; float max[3];
		for (int i = 0; i < 3; i++) {
			min[i] = this.minbounds[i];
			max[i] = this.maxbounds[i];
		}
		
		SetEntPropVector(entity, Prop_Send, "m_vecMins", min);
		SetEntPropVector(entity, Prop_Send, "m_vecMaxs", max);

		SetEntProp(entity, Prop_Send, "m_nSolidType", 2);	

		int iEffects = GetEntProp(entity, Prop_Send, "m_fEffects");	
		iEffects |= 32;	
		SetEntProp(entity, Prop_Send, "m_fEffects", iEffects);

		return entity;
	}
}

Trigger g_Trigger[MAXPLAYERS + 1];
ArrayList g_Triggers;
int g_Laser;

#include "files/entities.sp"
#include "files/plugins.sp"
#include "files/props.sp"
#include "files/spew.sp"
#include "files/timers.sp"
#include "files/triggers.sp"
#include "files/games/csgo.sp"
#include "files/games/left4dead2.sp"
#include "files/games/tf.sp"

public Plugin myinfo = {
	name = PLUGIN_NAME, 
	author = PLUGIN_AUTHOR, 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	game = GetEngineVersion();

	#if defined _tf2_included
	if (game != Engine_TF2) {
		MarkNativeAsOptional("TF2Econ_GetItemClassName");
		MarkNativeAsOptional("TF2Econ_GetItemSlot");
		MarkNativeAsOptional("TF2Items_CreateItem");
		MarkNativeAsOptional("TF2Items_SetClassname");
		MarkNativeAsOptional("TF2Items_SetItemIndex");
		MarkNativeAsOptional("TF2Items_SetQuality");
		MarkNativeAsOptional("TF2Items_SetLevel");
		MarkNativeAsOptional("TF2Items_GiveNamedItem");
		MarkNativeAsOptional("TF2Items_SetNumAttributes");
		MarkNativeAsOptional("TF2Items_SetAttribute");
	}
	#endif

	return APLRes_Success;
}

public void OnPluginStart() {
	LoadTranslations("common.phrases");

	CreateConVar("sm_multitool_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_DONTRECORD);
	convar_Enabled = CreateConVar("sm_multitool_enabled", "1", "Should this plugin be enabled or disabled?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Autoreload = CreateConVar("sm_multitool_autoreload", "1");
	convar_DisableWaitingForPlayers = CreateConVar("sm_multitool_disable_waitingforplayers", "1");
	//AutoExecConfig();
	
	if (IsSource2009()) {
		g_Tag = "{darkorchid}[{honeydew}Tools{darkorchid}]{whitesmoke}";
		g_ChatColor = "{beige}";
		g_UniqueIdent = "{ancient}";
	} else if (game == Engine_Left4Dead2) {
		g_Tag = "\x03[\x04Tools\x03]\x01";
		g_ChatColor = "\x03";
		g_UniqueIdent = "\x04";
	} else {
		g_Tag = "{yellow}[{lightred}Tools{yellow}]{default}";
		g_ChatColor = "{yellow}";
		g_UniqueIdent = "{lightred}";
	}

	//ArrayLists
	g_Commands = new ArrayList(ByteCountToCells(128));
	g_HookEvents = new ArrayList(ByteCountToCells(256));
	g_Triggers = new ArrayList();

	//StringMaps
	g_CommandFlags = new StringMap();
	g_CachedTimes = new StringMap();

	//Misc
	RegAdminCmd("sm_snoclip", Command_SilentNoclip, ADMFLAG_SLAY, "Noclip but without any indicators.");
	RegAdminCmd("sm_tools", Command_Tools, ADMFLAG_SLAY, "List available commands under server tools.");
	RegAdminCmd2("sm_restart", Command_Restart, ADMFLAG_ROOT, "Restart the server.");
	RegAdminCmd2("sm_quit", Command_Quit, ADMFLAG_ROOT, "Quit the server.");
	RegAdminCmd2("sm_goto", Command_Teleport, ADMFLAG_SLAY, "Teleports yourself to other clients.");
	RegAdminCmd("sm_tele", Command_Teleport, ADMFLAG_SLAY, "Teleports yourself to other clients.");
	RegAdminCmd("sm_teleport", Command_Teleport, ADMFLAG_SLAY, "Teleports yourself to other clients.");
	RegAdminCmd("sm_telecoords", Command_TeleportCoords, ADMFLAG_SLAY, "Teleports yourself to certain coordinates.");
	RegAdminCmd("sm_teleportcoords", Command_TeleportCoords, ADMFLAG_SLAY, "Teleports yourself to certain coordinates.");
	RegAdminCmd2("sm_bring", Command_Bring, ADMFLAG_SLAY, "Teleports clients to yourself.");
	RegAdminCmd("sm_bringhere", Command_Bring, ADMFLAG_SLAY, "Teleports clients to yourself.");
	RegAdminCmd2("sm_move", Command_Port, ADMFLAG_SLAY, "Teleports clients to your crosshair.");
	RegAdminCmd("sm_port", Command_Port, ADMFLAG_SLAY, "Teleports clients to your crosshair.");
	RegAdminCmd2("sm_health", Command_SetHealth, ADMFLAG_SLAY, "Sets health on yourself or other clients.");
	RegAdminCmd("sm_sethealth", Command_SetHealth, ADMFLAG_SLAY, "Sets health on yourself or other clients.");
	RegAdminCmd2("sm_addhealth", Command_AddHealth, ADMFLAG_SLAY, "Add health on yourself or other clients.");
	RegAdminCmd2("sm_removehealth", Command_RemoveHealth, ADMFLAG_SLAY, "Remove health from yourself or other clients.");
	RegAdminCmd2("sm_team", Command_Team, ADMFLAG_SLAY, "Sets the team of yourself or other clients and respawns them.");
	RegAdminCmd("sm_setteam", Command_SetTeam, ADMFLAG_SLAY, "Sets the team of yourself or other clients.");
	RegAdminCmd("sm_switchteams", Command_SwitchTeams, ADMFLAG_SLAY, "Switches all players on both teams in the same round.");
	RegAdminCmd2("sm_respawn", Command_Respawn, ADMFLAG_SLAY, "Respawn yourself or clients.");
	RegAdminCmd2("sm_refill", Command_RefillWeapon, ADMFLAG_SLAY, "Refill magazine/clip and ammunition for all of the clients weapons.");
	RegAdminCmd("sm_refillweapons", Command_RefillWeapon, ADMFLAG_SLAY, "Refill magazine/clip and ammunition for all of the clients weapons.");
	RegAdminCmd2("sm_ammo", Command_RefillAmunition, ADMFLAG_SLAY, "Refill your ammunition.");
	RegAdminCmd("sm_ammunition", Command_RefillAmunition, ADMFLAG_SLAY, "Refill your ammunition.");
	RegAdminCmd("sm_refillammunition", Command_RefillAmunition, ADMFLAG_SLAY, "Refill your ammunition.");
	RegAdminCmd2("sm_clip", Command_RefillClip, ADMFLAG_SLAY, "Refill your clip.");
	RegAdminCmd("sm_refillclip", Command_RefillClip, ADMFLAG_SLAY, "Refill your clip.");
	RegAdminCmd("sm_mag", Command_RefillClip, ADMFLAG_SLAY, "Refill your clip.");
	RegAdminCmd("sm_refillmag", Command_RefillClip, ADMFLAG_SLAY, "Refill your clip.");
	RegAdminCmd("sm_refillmagazine", Command_RefillClip, ADMFLAG_SLAY, "Refill your clip.");
	RegAdminCmd2("sm_bots", Command_ManageBots, ADMFLAG_GENERIC, "Manage bots on the server.");
	RegAdminCmd("sm_managebots", Command_ManageBots, ADMFLAG_GENERIC, "Manage bots on the server.");
	RegAdminCmd2("sm_password", Command_Password, ADMFLAG_ROOT, "Set a password on the server or remove it.");
	RegAdminCmd("sm_setpassword", Command_Password, ADMFLAG_ROOT, "Set a password on the server or remove it.");
	RegAdminCmd2("sm_endround", Command_EndRound, ADMFLAG_ROOT, "Ends the current round.");
	RegAdminCmd2("sm_settime", Command_SetTime, ADMFLAG_SLAY, "Sets time on the server.");
	RegAdminCmd2("sm_addtime", Command_AddTime, ADMFLAG_SLAY, "Adds time on the server.");
	RegAdminCmd2("sm_removetime", Command_RemoveTime, ADMFLAG_SLAY, "Remove time on the server.");
	RegAdminCmd2("sm_setgod", Command_SetGod, ADMFLAG_SLAY, "Sets godmode on yourself or other clients.");
	RegAdminCmd2("sm_god", Command_SetGod, ADMFLAG_SLAY, "Sets godmode on yourself or other clients.");
	RegAdminCmd2("sm_setbuddha", Command_SetBuddha, ADMFLAG_SLAY, "Sets buddhamode on yourself or other clients.");
	RegAdminCmd2("sm_buddha", Command_SetBuddha, ADMFLAG_SLAY, "Sets buddhamode on yourself or other clients.");
	RegAdminCmd2("sm_setmortal", Command_SetMortal, ADMFLAG_SLAY, "Sets mortality on yourself or other clients.");
	RegAdminCmd2("sm_mortal", Command_SetMortal, ADMFLAG_SLAY, "Sets mortality on yourself or other clients.");
	RegAdminCmd2("sm_stunplayer", Command_StunPlayer, ADMFLAG_SLAY, "Stuns either yourself or other clients.");
	RegAdminCmd2("sm_bleedplayer", Command_BleedPlayer, ADMFLAG_SLAY, "Bleeds either yourself or other clients.");
	RegAdminCmd2("sm_igniteplayer", Command_IgnitePlayer, ADMFLAG_SLAY, "Ignite either yourself or other clients.");
	RegAdminCmd2("sm_reloadmap", Command_ReloadMap, ADMFLAG_ROOT, "Reloads the current map.");
	RegAdminCmd2("sm_mapname", Command_MapName, ADMFLAG_SLAY, "Retrieves the name of the current map.");
	RegAdminCmd2("sm_spawnsentry", Command_SpawnSentry, ADMFLAG_SLAY, "Spawn a sentry where you're looking.");
	RegAdminCmd2("sm_spawndispenser", Command_SpawnDispenser, ADMFLAG_SLAY, "Spawn a dispenser where you're looking.");
	RegAdminCmd("sm_particle", Command_Particle, ADMFLAG_ROOT, "Spawn a particle where you're looking.");
	RegAdminCmd("sm_spawnparticle", Command_Particle, ADMFLAG_ROOT, "Spawn a particle where you're looking.");
	RegAdminCmd2("sm_p", Command_Particle, ADMFLAG_ROOT, "Spawn a particle where you're looking.");
	RegAdminCmd("sm_listparticles", Command_ListParticles, ADMFLAG_ROOT, "List particles by name and click on them to test them.");
	RegAdminCmd2("sm_lp", Command_ListParticles, ADMFLAG_ROOT, "List particles by name and click on them to test them.");
	RegAdminCmd2("sm_plist", Command_ListParticles, ADMFLAG_ROOT, "List particles by name and click on them to test them.");
	RegAdminCmd("sm_generateparticles", Command_GenerateParticles, ADMFLAG_ROOT, "Generates a list of particles under the addons/sourcemod/data/particles folder.");
	RegAdminCmd2("sm_gp", Command_GenerateParticles, ADMFLAG_ROOT, "Generates a list of particles under the addons/sourcemod/data/particles folder.");
	RegAdminCmd2("sm_getentname", Command_GetEntName, ADMFLAG_ROOT, "Gets the entity name of a certain entity.");
	RegAdminCmd2("sm_getentmodel", Command_GetEntModel, ADMFLAG_ROOT, "Gets the model of a certain entity if it has a model.");
	RegAdminCmd2("sm_setkillstreak", Command_SetKillstreak, ADMFLAG_SLAY, "Sets your current killstreak.");
	RegAdminCmd2("sm_giveweapon", Command_GiveWeapon, ADMFLAG_SLAY, "Give yourself a certain weapon based on index.");
	RegAdminCmd2("sm_spawnkit", Command_SpawnHealthkit, ADMFLAG_SLAY, "Spawns a healthkit where you're looking.");
	RegAdminCmd("sm_spawnhealth", Command_SpawnHealthkit, ADMFLAG_SLAY, "Spawns a healthkit where you're looking.");
	RegAdminCmd("sm_spawnhealthkit", Command_SpawnHealthkit, ADMFLAG_SLAY, "Spawns a healthkit where you're looking.");
	RegAdminCmd2("sm_lock", Command_Lock, ADMFLAG_ROOT, "Lock the server to admins only.");
	RegAdminCmd("sm_lockserver", Command_Lock, ADMFLAG_ROOT, "Lock the server to admins only.");
	RegAdminCmd2("sm_bhop", Command_Bhop, ADMFLAG_SLAY, "Toggles bunnyhopping for one or more players.");
	RegAdminCmd("sm_bhopping", Command_Bhop, ADMFLAG_SLAY, "Toggles bunnyhopping for one or more players.");
	RegAdminCmd("sm_bhophopping", Command_Bhop, ADMFLAG_SLAY, "Toggles bunnyhopping for one or more players.");
	RegAdminCmd2("sm_dummy", Command_SpawnDummy, ADMFLAG_SLAY, "Spawns a target dummy for easy damage testing.");
	RegAdminCmd("sm_spawndummy", Command_SpawnDummy, ADMFLAG_SLAY, "Spawns a target dummy for easy damage testing.");
	RegAdminCmd2("sm_debugevents", Command_DebugEvents, ADMFLAG_ROOT, "Easily debug events as they fire.");
	RegAdminCmd2("sm_setrendercolor", Command_SetRenderColor, ADMFLAG_ROOT, "Sets you current render color.");
	RegAdminCmd2("sm_setrenderfx", Command_SetRenderFx, ADMFLAG_ROOT, "Sets you current render fx.");
	RegAdminCmd2("sm_setrendermode", Command_SetRenderMode, ADMFLAG_ROOT, "Sets you current render mode.");
	RegAdminCmd2("sm_applyattribute", Command_ApplyAttribute, ADMFLAG_ROOT, "Apply an attribute to you or your weapons.");
	RegAdminCmd2("sm_removeattribute", Command_RemoveAttribute, ADMFLAG_ROOT, "Remove an attribute from you or your weapons.");
	RegAdminCmd2("sm_getentprop", Command_GetEntProp, ADMFLAG_ROOT, "Get an entity int property for entities.");
	RegAdminCmd2("sm_setentprop", Command_SetEntProp, ADMFLAG_ROOT, "Set an entity int property for entities.");
	RegAdminCmd2("sm_getentpropfloat", Command_GetEntPropFloat, ADMFLAG_ROOT, "Get an entity float property for entities.");
	RegAdminCmd2("sm_setentpropfloat", Command_SetEntPropFloat, ADMFLAG_ROOT, "Set an entity float property for entities.");
	RegAdminCmd2("sm_getentclass", Command_GetEntClass, ADMFLAG_ROOT, "Gets an entities classname based on crosshair and displays it.");
	RegAdminCmd2("sm_getentcount", Command_GetEntCount, ADMFLAG_ROOT, "Displays the current entity count.");
	RegAdminCmd2("sm_killentity", Command_KillEntity, ADMFLAG_ROOT, "Kills the entity in your crosshair.");

	//cs
	RegAdminCmd2("sm_armor", Command_SetArmor, ADMFLAG_SLAY, "Sets armor on yourself or other clients.");
	RegAdminCmd("sm_setarmor", Command_SetArmor, ADMFLAG_SLAY, "Sets armor on yourself or other clients.");
	RegAdminCmd2("sm_addarmor", Command_AddArmor, ADMFLAG_SLAY, "Add armor on yourself or other clients.");
	RegAdminCmd2("sm_removearmor", Command_RemoveArmor, ADMFLAG_SLAY, "Remove armor from yourself or other clients.");

	//tf
	RegAdminCmd2("sm_class", Command_SetClass, ADMFLAG_SLAY, "Sets the class of yourself or other clients.");
	RegAdminCmd("sm_setclass", Command_SetClass, ADMFLAG_SLAY, "Sets the class of yourself or other clients.");
	RegAdminCmd2("sm_regen", Command_Regenerate, ADMFLAG_SLAY, "Regenerate yourself or clients.");
	RegAdminCmd("sm_regenerate", Command_Regenerate, ADMFLAG_SLAY, "Regenerate yourself or clients.");
	RegAdminCmd2("sm_setcondition", Command_SetCondition, ADMFLAG_ROOT, "Sets a condition on yourself or other clients.");
	RegAdminCmd("sm_addcondition", Command_SetCondition, ADMFLAG_ROOT, "Adds a condition on yourself or other clients.");
	RegAdminCmd2("sm_removecondition", Command_RemoveCondition, ADMFLAG_ROOT, "Removes a condition from yourself or other clients.");
	RegAdminCmd("sm_stripcondition", Command_RemoveCondition, ADMFLAG_ROOT, "Removes a condition from yourself or other clients.");
	RegAdminCmd2("sm_spewconditions", Command_SpewConditions, ADMFLAG_ROOT, "Logs all conditions applied into chat.");
	RegAdminCmd2("sm_uber", Command_SetUbercharge, ADMFLAG_SLAY, "Sets ubercharge on yourself or other clients.");
	RegAdminCmd("sm_ubercharge", Command_SetUbercharge, ADMFLAG_SLAY, "Sets ubercharge on yourself or other clients.");
	RegAdminCmd("sm_setubercharge", Command_SetUbercharge, ADMFLAG_SLAY, "Sets ubercharge on yourself or other clients.");
	RegAdminCmd2("sm_adduber", Command_AddUbercharge, ADMFLAG_SLAY, "Adds ubercharge to yourself or other clients.");
	RegAdminCmd("sm_addubercharge", Command_AddUbercharge, ADMFLAG_SLAY, "Adds ubercharge to yourself or other clients.");
	RegAdminCmd2("sm_removeuber", Command_RemoveUbercharge, ADMFLAG_SLAY, "Adds ubercharge to yourself or other clients.");
	RegAdminCmd("sm_removeubercharge", Command_RemoveUbercharge, ADMFLAG_SLAY, "Adds ubercharge to yourself or other clients.");
	RegAdminCmd("sm_stripubercharge", Command_RemoveUbercharge, ADMFLAG_SLAY, "Adds ubercharge to yourself or other clients.");
	RegAdminCmd2("sm_metal", Command_SetMetal, ADMFLAG_SLAY, "Sets metal on yourself or other clients.");
	RegAdminCmd("sm_setmetal", Command_SetMetal, ADMFLAG_SLAY, "Sets metal on yourself or other clients.");
	RegAdminCmd2("sm_addmetal", Command_AddMetal, ADMFLAG_SLAY, "Adds metal to yourself or other clients.");
	RegAdminCmd2("sm_removemetal", Command_RemoveMetal, ADMFLAG_SLAY, "Remove metal from yourself or other clients.");
	RegAdminCmd("sm_stripmetal", Command_RemoveMetal, ADMFLAG_SLAY, "Remove metal from yourself or other clients.");
	RegAdminCmd2("sm_getmetal", Command_GetMetal, ADMFLAG_SLAY, "Displays the metal for yourself or other clients.");
	RegAdminCmd2("sm_crits", Command_SetCrits, ADMFLAG_SLAY, "Sets crits on yourself or other clients.");
	RegAdminCmd("sm_setcrits", Command_SetCrits, ADMFLAG_SLAY, "Sets crits on yourself or other clients.");
	RegAdminCmd("sm_addcrits", Command_SetCrits, ADMFLAG_SLAY, "Adds crits on yourself or other clients.");
	RegAdminCmd2("sm_removecrits", Command_RemoveCrits, ADMFLAG_SLAY, "Removes crits from yourself or other clients.");
	RegAdminCmd("sm_stripcrits", Command_RemoveCrits, ADMFLAG_SLAY, "Removes crits from yourself or other clients.");

	//left4dead2
	RegAdminCmd2("sm_common", Command_SpawnCommon, ADMFLAG_SLAY, "Spawns a common infected where you're looking.");
	RegAdminCmd2("sm_zombie", Command_SpawnCommon, ADMFLAG_SLAY, "Spawns a common infected where you're looking.");
	RegAdminCmd2("sm_spawncommon", Command_SpawnCommon, ADMFLAG_SLAY, "Spawns a common infected where you're looking.");
	RegAdminCmd2("sm_clear", Command_ClearZombies, ADMFLAG_SLAY, "Clears out all Common Infected nearby.");
	RegAdminCmd2("sm_cull", Command_ClearZombies, ADMFLAG_SLAY, "Clears out all Common Infected nearby.");
	RegAdminCmd2("sm_clearcommons", Command_ClearZombies, ADMFLAG_SLAY, "Clears out all Common Infected nearby.");
	RegAdminCmd2("sm_cullcommons", Command_ClearZombies, ADMFLAG_SLAY, "Clears out all Common Infected nearby.");
	RegAdminCmd2("sm_panic", Command_ForcePanic, ADMFLAG_SLAY, "Forces a Panic Event to occur.");
	RegAdminCmd2("sm_panicevent", Command_ForcePanic, ADMFLAG_SLAY, "Forces a Panic Event to occur.");
	RegAdminCmd2("sm_forcepanic", Command_ForcePanic, ADMFLAG_SLAY, "Forces a Panic Event to occur.");
	RegAdminCmd2("sm_forcepanicevent", Command_ForcePanic, ADMFLAG_SLAY, "Forces a Panic Event to occur.");
	RegAdminCmd2("sm_ledge", Command_LedgeGrab, ADMFLAG_SLAY, "Toggles the ability for player to grab a ledge on or off.");
	RegAdminCmd2("sm_ledgegrab", Command_LedgeGrab, ADMFLAG_SLAY, "Toggles the ability for player to grab a ledge on or off.");

	//Props
	RegAdminCmd2("sm_createprop", Command_CreateProp, ADMFLAG_ROOT, "Create a dynamic prop entity.");
	RegAdminCmd2("sm_animateprop", Command_AnimateProp, ADMFLAG_ROOT, "Animate a dynamic prop entity.");
	RegAdminCmd2("sm_deleteprop", Command_DeleteProp, ADMFLAG_ROOT, "Delete a dynamic prop entity.");
	
	//Timer
	RegAdminCmd("sm_starttimer", Command_StartTimer, ADMFLAG_SLAY, "Start a timer for either yourself or the server to see.");
	RegAdminCmd("sm_stoptimer", Command_Stoptimer, ADMFLAG_SLAY, "Stops a currently active timer on the server.");
	
	//Spew
	RegAdminCmd2("sm_spewsounds", Command_SpewSounds, ADMFLAG_ROOT, "Logs all sounds played live into chat.");
	RegAdminCmd2("sm_spewambients", Command_SpewAmbients, ADMFLAG_ROOT, "Logs all ambient sounds played live into chat.");
	RegAdminCmd2("sm_spewentities", Command_SpewEntities, ADMFLAG_ROOT, "Logs all entities created live into chat.");
	RegAdminCmd2("sm_spewtriggers", Command_SpewTriggers, ADMFLAG_SLAY, "Logs all triggers being touched by the player.");
	RegAdminCmd2("sm_spewcommands", Command_SpewCommands, ADMFLAG_SLAY, "Logs all commands being sent by the player.");
	
	//Plugins
	RegAdminCmd("sm_load", Command_LoadPlugin, ADMFLAG_SLAY);
	RegAdminCmd("sm_loadplugin", Command_LoadPlugin, ADMFLAG_SLAY);
	RegAdminCmd("sm_reload", Command_ReloadPlugin, ADMFLAG_SLAY);
	RegAdminCmd("sm_reloadplugin", Command_ReloadPlugin, ADMFLAG_SLAY);
	RegAdminCmd("sm_unload", Command_UnloadPlugin, ADMFLAG_SLAY);
	RegAdminCmd("sm_unloadplugin", Command_UnloadPlugin, ADMFLAG_SLAY);
	
	//entity tools
	RegAdminCmd("sm_createentity", Command_CreateEntity, ADMFLAG_ROOT, "Create an entity.");
	RegAdminCmd("sm_dispatchkeyvalue", Command_DispatchKeyValue, ADMFLAG_ROOT, "Dispatch keyvalue on an entity.");
	RegAdminCmd("sm_dispatchkeyvaluefloat", Command_DispatchKeyValueFloat, ADMFLAG_ROOT, "Dispatch keyvalue float on an entity.");
	RegAdminCmd("sm_dispatchkeyvaluevector", Command_DispatchKeyValueVector, ADMFLAG_ROOT, "Dispatch keyvalue vector on an entity.");
	RegAdminCmd("sm_dispatchspawn", Command_DispatchSpawn, ADMFLAG_ROOT, "Dispatch spawn an entity.");
	RegAdminCmd("sm_acceptentityinput", Command_AcceptEntityInput, ADMFLAG_ROOT, "Send an input to an entity.");
	RegAdminCmd("sm_animate", Command_Animate, ADMFLAG_ROOT, "Send an animation input to an entity.");
	RegAdminCmd("sm_targetentity", Command_TargetEntity, ADMFLAG_ROOT, "Target an entity.");
	RegAdminCmd("sm_deleteentity", Command_DeleteEntity, ADMFLAG_ROOT, "Delete an entity.");
	RegAdminCmd("sm_listownedentities", Command_ListOwnedEntities, ADMFLAG_ROOT, "List all entities owned by you.");

	//Triggers
	RegAdminCmd("sm_createtrigger", Command_CreateTrigger, ADMFLAG_ROOT);
	RegAdminCmd("sm_deletetriggers", Command_DeleteTriggers, ADMFLAG_ROOT);
	
	//Admin Menu
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
	
	//Gamedata
	if (game == Engine_Left4Dead || game == Engine_Left4Dead2) {
		GameData hGameConf = new GameData("multitool.gamedata");
		
		if (hGameConf != null) {
			StartPrepSDKCall(SDKCall_Player);
			PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "RoundRespawn");
			hRoundRespawn = EndPrepSDKCall();
			
			StartPrepSDKCall(SDKCall_Player);
			PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "BecomeGhost");
			PrepSDKCall_AddParameter(SDKType_PlainOldData , SDKPass_Plain);
			hBecomeGhost = EndPrepSDKCall();

			StartPrepSDKCall(SDKCall_Player);
			PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "State_Transition");
			PrepSDKCall_AddParameter(SDKType_PlainOldData , SDKPass_Plain);
			hState_Transition = EndPrepSDKCall();
		}

		delete hGameConf;
	}
	
	//Entities Live Loading
	int entity = -1; char classname[64];
	while ((entity = FindEntityByClassname(entity, "*")) != -1) {
		if (GetEntityClassname(entity, classname, sizeof(classname))) {
			OnEntityCreated(entity, classname);
		}
	}

	//Timers
	CreateTimer(2.0, Timer_CheckForUpdates, _, TIMER_REPEAT);
}

public void OnPluginEnd() {
	int entity = -1;
	for (int i = 0; i < g_Triggers.Length; i++) {
		if ((entity = EntRefToEntIndex(g_Triggers.Get(i))) != -1) {
			AcceptEntityInputSafe(entity, "Kill");
		}
	}
}

void RegAdminCmd2(const char[] cmd, ConCmd callback, int adminflags, const char[] description = "", const char[] group = "", int flags = 0) {
	RegAdminCmd(cmd, callback, adminflags, description, group, flags);
	g_Commands.PushString(cmd);
	g_CommandFlags.SetValue(cmd, adminflags);
}

public void TF2_OnWaitingForPlayersStart() {
	if (convar_DisableWaitingForPlayers.BoolValue) {
		ServerCommand("mp_waitingforplayers_cancel 1");
	}
}

public Action Timer_CheckForUpdates(Handle timer) {
	OnAllPluginsLoaded();
	return Plugin_Continue;
}

public void OnAllPluginsLoaded() {
	if (!convar_Autoreload.BoolValue) {
		return;
	}
	
	char sPath[256];
	BuildPath(Path_SM, sPath, sizeof(sPath), "plugins/");

	if (g_CachedTimes.Size > 0) {
		StringMapSnapshot map = g_CachedTimes.Snapshot();
		
		int size; char sUnload[256];
		for (int i = 0; i < map.Length; i++){
			size = map.KeyBufferSize(i);
			
			char[] sFile = new char[size + 1];
			map.GetKey(i, sFile, size + 1);
			
			strcopy(sUnload, sizeof(sUnload), sFile);
			ReplaceString(sUnload, size + 1, sPath, "");

			Handle plugin = FindPluginByFile(sUnload);

			if (plugin == null) {
				g_CachedTimes.Remove(sFile);
			}
		}

		delete map;
	}

	Handle iter = GetPluginIterator();
	while (MorePlugins(iter)) {
		Handle plugin = ReadPlugin(iter);
		
		char sName[128];
		GetPluginInfo(plugin, PlInfo_Name, sName, sizeof(sName));
		
		char sFile[256];
		GetPluginFilename(plugin, sFile, sizeof(sFile));

		Format(sFile, sizeof(sFile), "%s%s", sPath, sFile);
		
		int current = GetFileTime(sFile, FileTime_LastChange);
		int iTime;

		if (g_CachedTimes.GetValue(sFile, iTime) && current > iTime) {
			char sReload[256];
			strcopy(sReload, sizeof(sReload), sFile);

			ReplaceString(sReload, sizeof(sReload), sPath, "", true);
			ReplaceString(sReload, sizeof(sReload), ".smx", "", true);
			
			EmitSoundToAll("ui/cyoa_map_open.wav");
			ServerCommand("sm plugins reload %s", sReload);
			
			SendPrintToAll("Plugin '[H]%s[D]' has been reloaded.", sName);
			PrintToServer("Plugin '%s' has been reloaded.", sName);
			
			ServerCommand("sm_reload_translations %s", sReload); //Automatically reloads translations.

			DataPack pack;
			CreateDataTimer(0.5, Timer_CheckLoad, pack, TIMER_FLAG_NO_MAPCHANGE);
			pack.WriteCell(plugin);
			pack.WriteString(sReload);
		}

		g_CachedTimes.SetValue(sFile, current);
	}

	delete iter;
}

public Action Timer_CheckLoad(Handle timer, DataPack pack) {
	pack.Reset();

	Handle plugin = pack.ReadCell();

	char sReload[256];
	pack.ReadString(sReload, sizeof(sReload));

	if (plugin == null) {
		ServerCommand("sm plugins load %s", sReload);
	}

	return Plugin_Continue;
}

public void OnMapStart() {
	PrecacheSound("ui/cyoa_map_open.wav");
	
	delete g_OwnedEntities[0];
	g_OwnedEntities[0] = new ArrayList();
	g_iTarget[0] = INVALID_ENT_REFERENCE;

	PrecacheModel("models/error.mdl");
	g_Laser = PrecacheModel("materials/sprites/laser.vmt");
}

public void OnMapEnd() {
	delete g_OwnedEntities[0];
	g_iTarget[0] = INVALID_ENT_REFERENCE;
	g_Locked = false;
	
	g_SpewConditions = false;
	g_SpewSounds = false;
	g_SpewAmbients = false;
	g_SpewEntities = false;
	g_SpewTriggers = false;
	g_SpewCommands = false;
}

public void OnAdminMenuReady(Handle aTopMenu) {
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	if (topmenu == hTopMenu) {
		return;
	}

	hTopMenu = topmenu;

	hTopMenu.AddCategory("sm_managebots", AdminMenu_BotCommands);
}

public void AdminMenu_BotCommands(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength) {
	if (action == TopMenuAction_DisplayOption) {
		FormatEx(buffer, maxlength, "Bot Commands");
	} else if (action == TopMenuAction_SelectOption) {
		OpenManageBotsMenu(param);
	}
}

public void OnClientConnected(int client) {
	delete g_OwnedEntities[client];
	g_OwnedEntities[client] = new ArrayList();
	g_iTarget[client] = INVALID_ENT_REFERENCE;
}

public void OnClientDisconnect(int client) {
	delete g_OwnedEntities[client];
	g_iTarget[client] = INVALID_ENT_REFERENCE;
	
	StopTimer(g_Timer[client]);
	g_TimerVal[client] = 0.0;
}

bool IsEnabled() {
	return convar_Enabled.BoolValue;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Commands

public Action Command_SilentNoclip(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (client == 0) {
		SendPrint(client, "You must be in-game to use this command.");
		return Plugin_Handled;
	}
	
	if (GetEntityMoveType(client) == MOVETYPE_NOCLIP) {
		SetEntityMoveType(client, MOVETYPE_WALK);
	} else {
		SetEntityMoveType(client, MOVETYPE_NOCLIP);
	}
	
	return Plugin_Handled;
}

public Action Command_Tools(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (client == 0) {
		SendPrint(client, "You must be in-game to use this command.");
		return Plugin_Handled;
	}

	ListCommands(client);
	return Plugin_Handled;
}

void ListCommands(int client) {
	Panel panel = new Panel();
	panel.SetTitle("Server Tools:");

	char sCommand[128]; int admflag;
	for (int i = 0; i < g_Commands.Length; i++) {
		g_Commands.GetString(i, sCommand, sizeof(sCommand));
		
		if (g_CommandFlags.GetValue(sCommand, admflag) && !CheckCommandAccess(client, "", admflag, true)) {
			continue;
		}
		
		ReplaceString(sCommand, sizeof(sCommand), "sm_", "!");
		panel.DrawText(sCommand);
	}

	panel.Send(client, PanelHandler_Commands, MENU_TIME_FOREVER);
	delete panel;
}

public int PanelHandler_Commands(Menu menu, MenuAction action, int param1, int param2) {
	delete menu;
	return 0;
}

public Action Command_Restart(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	SendConfirmationMenu(client, Confirm_Restart, "Are you sure you want to restart the server?", MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public void Confirm_Restart(int client, ConfirmationResponses response) {
	if (response == Confirm_Yes) {
		SendPrint(client, "Restarting the server in [H]5 [D]seconds...");
		CreateTimer(5.0, Timer_Restart);
	}
}

public Action Timer_Restart(Handle timer) {
	ServerCommand("_restart");
	return Plugin_Continue;
}

public Action Command_Quit(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	SendConfirmationMenu(client, Confirm_Quit, "Are you sure you want close the server?", MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public void Confirm_Quit(int client, ConfirmationResponses response) {
	if (response == Confirm_Yes) {
		SendPrint(client, "Shutting down the server in [H]5 [D]seconds...");
		CreateTimer(5.0, Timer_Quit);
	}
}

public Action Timer_Quit(Handle timer) {
	ServerCommand("quit");
	return Plugin_Continue;
}

public Action Command_Teleport(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (client == 0) {
		SendPrint(client, "You must be in-game to use this command.");
		return Plugin_Handled;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a target to teleport to.");
		return Plugin_Handled;
	}

	if (!IsPlayerAlive(client)) {
		SendPrint(client, "You must be alive to use this command.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int target = FindTarget(client, sTarget, false, true);

	if (!IsPlayerIndex(target) || !IsClientConnected(target) || !IsClientInGame(target)) {
		SendPrint(client, "Invalid target specified, please try again.");
		return Plugin_Handled;
	}

	if (!IsPlayerAlive(target)) {
		SendPrint(client, "[H]%N [D]isn't currently alive.", target);
		return Plugin_Handled;
	}

	float vecOrigin[3];
	GetClientAbsOrigin(target, vecOrigin);

	float vecAngles[3];
	GetClientAbsAngles(target, vecAngles);

	TeleportEntity(client, vecOrigin, vecAngles, NULL_VECTOR);

	SendPrint(target, "[H]%N [D]teleported themselves to you.", client);
	SendPrint(client, "You have teleported yourself to [H]%N [D].", target);

	return Plugin_Handled;
}

public Action Command_TeleportCoords(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	float vecOrigin[3];
	vecOrigin[0] = GetCmdArgFloat(1);
	vecOrigin[1] = GetCmdArgFloat(2);
	vecOrigin[2] = GetCmdArgFloat(3);
	
	TeleportEntity(client, vecOrigin, NULL_VECTOR, NULL_VECTOR);

	SendPrint(client, "You have teleported to coordinates: %.2f/%.2f/%.2f", vecOrigin[0], vecOrigin[1], vecOrigin[2]);
	return Plugin_Handled;
}

public Action Command_Bring(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (client == 0) {
		SendPrint(client, "You must be in-game to use this command.");
		return Plugin_Handled;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a target to bring.");
		return Plugin_Handled;
	}

	if (!IsPlayerAlive(client)) {
		SendPrint(client, "You must be alive to use this command.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0) {
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	float vecOrigin[3];
	GetClientAbsOrigin(client, vecOrigin);

	float vecAngles[3];
	GetClientAbsAngles(client, vecAngles);

	for (int i = 0; i < targets; i++) {
		TeleportEntity(targets_list[i], vecOrigin, vecAngles, NULL_VECTOR);
		SendPrint(targets_list[i], "You have been teleported to [H]%N [D].", client);
	}
	
	if (tn_is_ml) {
		SendPrint(client, "You have teleported [H]%t [D]to you.", sTargetName);
	} else {
		SendPrint(client, "You have teleported [H]%s [D]to you.", sTargetName);
	}

	return Plugin_Handled;
}

public Action Command_Port(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (client == 0) {
		SendPrint(client, "You must be in-game to use this command.");
		return Plugin_Handled;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a target to port.");
		return Plugin_Handled;
	}

	if (!IsPlayerAlive(client)) {
		SendPrint(client, "You must be alive to use this command.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), 0, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0) {
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	float vecOrigin[3];
	GetClientLookOrigin(client, vecOrigin);

	for (int i = 0; i < targets; i++) {
		if (!IsPlayerAlive(targets_list[i])) {
			TF2_RespawnPlayer(targets_list[i]);
		}
		
		TeleportEntity(targets_list[i], vecOrigin, NULL_VECTOR, NULL_VECTOR);
		SendPrint(targets_list[i], "You have been ported by [H]%N [D].", client);
	}
	
	if (tn_is_ml) {
		SendPrint(client, "You have ported [H]%t [D]to your look position.", sTargetName);
	} else {
		SendPrint(client, "You have ported [H]%s [D]to your look position.", sTargetName);
	}

	return Plugin_Handled;
}

public Action Command_SetHealth(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a target to set their health.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0) {
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	char sHealth[12];
	GetCmdArg(2, sHealth, sizeof(sHealth));
	int health = ClampCell(StringToInt(sHealth), 1, 999999);

	for (int i = 0; i < targets; i++) {
		if (game == Engine_TF2) {
			TF2_SetPlayerHealth(targets_list[i], health);
		} else {
			SetEntityHealth(targets_list[i], health);
		}
		
		SendPrint(targets_list[i], "Your health has been set to [H]%i [D]by [H]%N [D].", health, client);
	}
	
	if (tn_is_ml) {
		SendPrint(client, "You have set the health of [H]%t [D]to [H]%i [D].", sTargetName, health);
	} else {
		SendPrint(client, "You have set the health of [H]%s [D]to [H]%i [D].", sTargetName, health);
	}

	return Plugin_Handled;
}

public Action Command_AddHealth(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a target to add to their health.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0) {
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	char sHealth[12];
	GetCmdArg(2, sHealth, sizeof(sHealth));
	int health = ClampCell(StringToInt(sHealth), 1, 999999);

	for (int i = 0; i < targets; i++) {
		if (game == Engine_TF2) {
			TF2_AddPlayerHealth(targets_list[i], health);
		} else {
			SetEntityHealth(targets_list[i], (GetClientHealth(targets_list[i]) + health));
		}
		
		SendPrint(targets_list[i], "Your health has been increased by [H]%i [D]by [H]%N [D].", health, client);
	}
	
	if (tn_is_ml) {
		SendPrint(client, "You have increased the health of [H]%t [D]by [H]%i [D].", sTargetName, health);
	} else {
		SendPrint(client, "You have increased the health of [H]%s [D]by [H]%i [D].", sTargetName, health);
	}

	return Plugin_Handled;
}

public Action Command_RemoveHealth(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a target to deduct from their health.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0) {
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	char sHealth[12];
	GetCmdArg(2, sHealth, sizeof(sHealth));
	int health = ClampCell(StringToInt(sHealth), 1, 999999);

	for (int i = 0; i < targets; i++) {
		if (game == Engine_TF2) {
			TF2_RemovePlayerHealth(targets_list[i], health);
		} else {
			if ((GetClientHealth(targets_list[i]) - health) < 1) {
				ForcePlayerSuicide(targets_list[i]);
			} else {
				SetEntityHealth(targets_list[i], (GetClientHealth(targets_list[i]) - health));
			}
		}
		
		SendPrint(targets_list[i], "Your health has been deducted by [H]%i [D]by [H]%N [D].", health, client);
	}
	
	if (tn_is_ml) {
		SendPrint(client, "You have deducted health of [H]%t [D]by [H]%i [D].", sTargetName, health);
	} else {
		SendPrint(client, "You have deducted health of [H]%s [D]by [H]%i [D].", sTargetName, health);
	}

	return Plugin_Handled;
}

public Action Command_Team(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a target to set their team.");
		return Plugin_Handled;
	} else if (args == 1) {
		SendPrint(client, "You must specify a team to set.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_CONNECTED, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0) {
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	char sTeam[32];
	GetCmdArg(2, sTeam, sizeof(sTeam));
	
	int team;
	if (IsStringNumeric(sTeam)) {	
		team = StringToInt(sTeam);
	} else {
		if (StrEqual(sTeam, "red", false) || StrEqual(sTeam, "t", false) || StrEqual(sTeam, "terrorist", false)) {
			team = 2;
		} else if (StrEqual(sTeam, "blue", false) || StrEqual(sTeam, "ct", false) || StrEqual(sTeam, "counter-terrorist", false)) {
			team = 3;
		}
	}

	if (team < 1 || team > 3) {
		SendPrint(client, "You have specified an invalid team.");
		return Plugin_Handled;
	}

	char sTeamName[32];
	GetTeamName(team, sTeamName, sizeof(sTeamName));

	for (int i = 0; i < targets; i++) {
		switch (game) {
			case Engine_TF2: {
				TF2_ChangeClientTeam(targets_list[i], view_as<TFTeam>(team));
				TF2_RespawnPlayer(targets_list[i]);
			}
			
			case Engine_CSS, Engine_CSGO: {
				CS_SwitchTeam(targets_list[i], team);
				CS_RespawnPlayer(targets_list[i]);
			}

			default: {
				ChangeClientTeam(targets_list[i], team);
			}
		}
		
		SendPrint(targets_list[i], "Your team has been set to [H]%s [D]by [H]%N [D].", sTeamName, client);
	}
	
	if (tn_is_ml) {
		SendPrint(client, "You have set the team of [H]%t [D]to [H]%s [D].", sTargetName, sTeamName);
	} else {
		SendPrint(client, "You have set the team of [H]%s [D]to [H]%s [D].", sTargetName, sTeamName);
	}

	return Plugin_Handled;
}

public Action Command_SetTeam(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a target to set their team.");
		return Plugin_Handled;
	} else if (args == 1) {
		SendPrint(client, "You must specify a team to set.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_CONNECTED, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0) {
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	char sTeam[32];
	GetCmdArg(2, sTeam, sizeof(sTeam));
	
	int team;
	if (IsStringNumeric(sTeam)) {
		team = StringToInt(sTeam);
	} else {
		if (StrEqual(sTeam, "red", false) || StrEqual(sTeam, "t", false) || StrEqual(sTeam, "terrorist", false)) {
			team = 2;
		} else if (StrEqual(sTeam, "blue", false) || StrEqual(sTeam, "ct", false) || StrEqual(sTeam, "counter-terrorist", false)) {
			team = 3;
		}
	}

	if (team < 1 || team > 3) {
		SendPrint(client, "You have specified an invalid team.");
		return Plugin_Handled;
	}

	char sTeamName[32];
	GetTeamName(team, sTeamName, sizeof(sTeamName));

	for (int i = 0; i < targets; i++) {
		switch (game) {
			case Engine_TF2: {
				TF2_ChangeClientTeam(targets_list[i], view_as<TFTeam>(team));
			}
			
			case Engine_CSS, Engine_CSGO: {
				CS_SwitchTeam(targets_list[i], team);
			}

			default: {
				ChangeClientTeam(targets_list[i], team);
			}
		}
		
		SendPrint(targets_list[i], "Your team has been set to [H]%s [D]by [H]%N [D].", sTeamName, client);
	}
	
	if (tn_is_ml) {
		SendPrint(client, "You have set the team of [H]%t [D]to [H]%s [D].", sTargetName, sTeamName);
	} else {
		SendPrint(client, "You have set the team of [H]%s [D]to [H]%s [D].", sTargetName, sTeamName);
	}

	return Plugin_Handled;
}

public Action Command_SwitchTeams(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) < 2) {
			continue;
		}
		
		ChangeClientTeam_Alive(i, GetClientTeam(i) == 2 ? 3 : 2);
	}
	
	SendPrintToAll("[H]%N [D]has switched both teams.", client);
	return Plugin_Handled;
}

public Action Command_Respawn(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a target to respawn.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_CONNECTED, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0) {
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	for (int i = 0; i < targets; i++) {
		switch (game) {
			case Engine_TF2: {
				TF2_RespawnPlayer(targets_list[i]);
			}
			case Engine_CSS, Engine_CSGO: {
				CS_RespawnPlayer(targets_list[i]);
			}
			case Engine_Left4Dead, Engine_Left4Dead2: {
				switch(GetClientTeam(targets_list[i])) {
					case 2: {
						SDKCall(hRoundRespawn, targets_list[i]);
						CheatCommand(targets_list[i], "give", "first_aid_kit");
						CheatCommand(targets_list[i], "give", "smg");
					}
					
					case 3: {
						SDKCall(hState_Transition, targets_list[i], 8);
						SDKCall(hBecomeGhost, targets_list[i], 1);
						SDKCall(hState_Transition, targets_list[i], 6);
						SDKCall(hBecomeGhost, targets_list[i], 1);
					}
				}
			}
		}
		
		SendPrint(targets_list[i], "Your have been respawned by [H]%N [D].", client);
	}
	
	if (tn_is_ml) {
		SendPrint(client, "You have respawned [H]%t [D].", sTargetName);
	} else {
		SendPrint(client, "You have respawned [H]%s [D].", sTargetName);
	}

	return Plugin_Handled;
}

public Action Command_RefillWeapon(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a target to refill their ammunition.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0) {
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	int weapon2;
	for (int i = 0; i < targets; i++) {
		for (int x = 0; x < 8; x++) {
			if ((weapon2 = GetPlayerWeaponSlot(targets_list[i], i)) != INVALID_ENT_INDEX && IsValidEntity(weapon2)) {
				if (g_iClip[weapon2] > 0) {
					SetWeaponClip(weapon2, g_iClip[weapon2]);
				}
				
				if (g_iAmmo[weapon2] > 0) {
					SetWeaponAmmo(targets_list[i], weapon2, g_iAmmo[weapon2]);
				}
			}
		}

		SendPrint(targets_list[i], "Your weapons ammunitions have been refilled by [H]%N [D].", client);
	}
	
	if (tn_is_ml) {
		SendPrint(client, "You have refilled the ammunition ammo for [H]%t [D].", sTargetName);
	} else {
		SendPrint(client, "You have refilled the ammunition ammo for [H]%s [D].", sTargetName);
	}

	return Plugin_Handled;
}

public Action Command_RefillAmunition(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a target to refill their ammunition.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0) {
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	int weapon2;
	for (int i = 0; i < targets; i++) {
		for (int x = 0; x < 8; x++) {
			if ((weapon2 = GetPlayerWeaponSlot(targets_list[i], i)) != INVALID_ENT_INDEX && IsValidEntity(weapon2) && g_iAmmo[weapon2] > 0) {
				SetWeaponAmmo(targets_list[i], weapon2, g_iAmmo[weapon2]);
			}
		}

		SendPrint(targets_list[i], "Your weapons ammunitions have been refilled by [H]%N [D].", client);
	}
	
	if (tn_is_ml) {
		SendPrint(client, "You have refilled the ammunition ammo for [H]%t [D].", sTargetName);
	} else {
		SendPrint(client, "You have refilled the ammunition ammo for [H]%s [D].", sTargetName);
	}

	return Plugin_Handled;
}

public Action Command_RefillClip(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a target to refill their clip.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0) {
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	int weapon2;
	for (int i = 0; i < targets; i++) {
		for (int x = 0; x < 8; x++)	{
			if ((weapon2 = GetPlayerWeaponSlot(targets_list[i], i)) != INVALID_ENT_INDEX && IsValidEntity(weapon2) && g_iClip[weapon2] > 0) {
				SetWeaponClip(weapon2, g_iClip[weapon2]);
			}
		}

		SendPrint(targets_list[i], "Your weapons clips have been refilled by [H]%N [D].", client);
	}
	
	if (tn_is_ml) {
		SendPrint(client, "You have refilled the clip ammo for [H]%t [D].", sTargetName);
	} else {
		SendPrint(client, "You have refilled the clip ammo for [H]%s [D].", sTargetName);
	}

	return Plugin_Handled;
}

public void TF2Items_OnGiveNamedItem_Post(int client, char[] classname, int itemDefinitionIndex, int itemLevel, int itemQuality, int entityIndex) {
	if (StrContains(classname, "tf_weapon") != 0) {
		return;
	}

	DataPack pack;
	CreateDataTimer(0.2, Timer_CacheValues, pack, TIMER_FLAG_NO_MAPCHANGE);
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(EntIndexToEntRef(entityIndex));
}

public Action Timer_CacheValues(Handle timer, DataPack data) {
	data.Reset();

	int client = GetClientOfUserId(data.ReadCell());
	int entity = EntRefToEntIndex(data.ReadCell());

	if (IsPlayerIndex(client) && IsValidEntity(entity)) {
		g_iAmmo[entity] = GetWeaponAmmo(client, entity);
		g_iClip[entity] = GetWeaponClip(entity);
	}

	return Plugin_Continue;
}

public void OnEntityDestroyed(int entity) {
	if (!IsEntityIndex(entity)) {
		return;
	}

	g_iAmmo[entity] = 0;
	g_iClip[entity] = 0;
	
	if (g_SpewEntities) {
		char classname[64];
		GetEntityClassname(entity, classname, sizeof(classname));
		SendPrintToAll("[SpewEntities] -[H]%i [D]: [H]%s [D]([H]Destroyed[D])", entity, classname);
	}
}

public Action Command_ManageBots(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (client == 0) {
		SendPrint(client, "You must be in-game to use this command.");
		return Plugin_Handled;
	}

	OpenManageBotsMenu(client);
	return Plugin_Handled;
}

void OpenManageBotsMenu(int client) {
	Menu menu = new Menu(MenuHandler_ManageBots);
	menu.SetTitle(":[Tools] Manage Bots:");

	menu.AddItem("spawn", "Spawn a Bot");
	menu.AddItem("remove", "Remove a Bot");
	menu.AddItem("class", "Set Bot Class");
	menu.AddItem("team", "Switch Bot Team");
	menu.AddItem("move", "Toggle Bot Movement");
	menu.AddItem("quota", "Update Bot Quota");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ManageBots(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "spawn")) {
				SendPrintToAll("[H]%N [D]has spawned a bot.", param1);
				ServerCommand("tf_bot_add");

				OpenManageBotsMenu(param1);
			} else if (StrEqual(sInfo, "remove")) {
				int target = GetClientAimTarget(param1, true);

				if (!IsPlayerIndex(target) || !IsFakeClient(target)) {
					SendPrint(param1, "Please aim your crosshair at a valid bot.");
					OpenManageBotsMenu(param1);
					return 0;
				}

				SendPrintToAll("[H]%N [D]has kicked the bot [H]%N [D].", param1, target);
				ServerCommand("tf_bot_kick \"%N \"", target);

				OpenManageBotsMenu(param1);
			} else if (StrEqual(sInfo, "class")) {
				int target = GetClientAimTarget(param1, true);

				if (!IsPlayerIndex(target) || !IsFakeClient(target)) {
					SendPrint(param1, "Please aim your crosshair at a valid bot.");
					OpenManageBotsMenu(param1);
					return 0;
				}

				OpenSetBotClassMenu(param1, target);
			} else if (StrEqual(sInfo, "team")) {
				int target = GetClientAimTarget(param1, true);

				if (!IsPlayerIndex(target) || !IsFakeClient(target)) {
					SendPrint(param1, "Please aim your crosshair at a valid bot.");
					OpenManageBotsMenu(param1);
					return 0;
				}

				OpenSetBotTeamMenu(param1, target);
			} else if (StrEqual(sInfo, "move")) {
				ConVar blind = FindConVar("nb_blind");
				SetConVarFlag(blind, false, FCVAR_CHEAT);
				blind.SetBool(!blind.BoolValue);
				SetConVarFlag(blind, true, FCVAR_CHEAT);

				SendPrintToAll("[H]%N [D]has toggled bot movement [H]%s [D].", param1, !blind.BoolValue ? "on" : "off");

				OpenManageBotsMenu(param1);
			} else if (StrEqual(sInfo, "quota")) {
				OpenSetBotQuotaMenu(param1);
			}
		}

		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

void OpenSetBotClassMenu(int client, int target) {
	Menu menu = new Menu(MenuHandler_SetBotClass);
	menu.SetTitle("[Tools] Pick a class for [H]%N [D]:", target);

	menu.AddItem("1", "Scout");
	menu.AddItem("3", "Soldier");
	menu.AddItem("7", "Pyro");
	menu.AddItem("4", "DemoMan");
	menu.AddItem("6", "Heavy");
	menu.AddItem("9", "Engineer");
	menu.AddItem("5", "Medic");
	menu.AddItem("2", "Sniper");
	menu.AddItem("8", "Spy");

	PushMenuInt(menu, "target", target);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_SetBotClass(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			int target = GetMenuInt(menu, "target");
			TFClassType class = view_as<TFClassType>(StringToInt(sInfo));

			if (!IsPlayerIndex(target) || !IsFakeClient(target)) {
				SendPrint(param1, "Bot is no longer valid.");
				OpenManageBotsMenu(param1);
				return 0;
			}

			TF2_SetPlayerClass(target, class);
			TF2_RegeneratePlayer(target);

			OpenSetBotClassMenu(param1, target);
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				OpenManageBotsMenu(param1);
			}
		}

		case MenuAction_End: {
			delete menu;
		}
	}

	return 0;
}

void OpenSetBotTeamMenu(int client, int target) {
	Menu menu = new Menu(MenuHandler_SetBotTeam);
	menu.SetTitle("[Tools] Pick a team for [H]%N [D]:", target);

	menu.AddItem("2", "Red");
	menu.AddItem("3", "Blue");

	PushMenuInt(menu, "target", target);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_SetBotTeam(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			int target = GetMenuInt(menu, "target");
			TFTeam team = view_as<TFTeam>(StringToInt(sInfo));

			if (!IsPlayerIndex(target) || !IsFakeClient(target)) {
				SendPrint(param1, "Bot is no longer valid.");
				OpenManageBotsMenu(param1);
				return 0;
			}

			TF2_ChangeClientTeam(target, team);
			TF2_RespawnPlayer(target);

			OpenSetBotTeamMenu(param1, target);
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				OpenManageBotsMenu(param1);
			}
		}

		case MenuAction_End: {
			delete menu;
		}
	}

	return 0;
}

void OpenSetBotQuotaMenu(int client) {
	Menu menu = new Menu(MenuHandler_SetBotQuota);
	menu.SetTitle("[Tools] Set the curren bot quota:");

	menu.AddItem("0", "Zero");
	menu.AddItem("6", "Six");
	menu.AddItem("12", "Twelve");
	menu.AddItem("18", "Eighteen");
	menu.AddItem("24", "Twenty-Four");
	menu.AddItem("30", "Thirty");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_SetBotQuota(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char sInfo[12];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			ServerCommand("tf_bot_quota %i", StringToInt(sInfo));

			OpenSetBotQuotaMenu(param1);
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				OpenManageBotsMenu(param1);
			}
		}

		case MenuAction_End: {
			delete menu;
		}
	}

	return 0;
}

public Action Command_Password(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	ConVar password = FindConVar("sv_password");

	char sPassword[256];
	password.GetString(sPassword, sizeof(sPassword));

	if (args == 0) {
		if (strlen(sPassword) == 0) {
			SendPrint(client, "No password is currently set on the server, it's unlocked.");
			return Plugin_Handled;
		}

		password.SetString("");
		SendPrintToAll("[H]%N [D]has removed the password unlocking the server.", client);

		return Plugin_Handled;
	}

	char sNewPassword[256];
	GetCmdArgString(sNewPassword, sizeof(sNewPassword));

	if (strlen(sNewPassword) == 0) {
		SendPrint(client, "You must specify a password in order to set it.");
		return Plugin_Handled;
	}

	if (strlen(sNewPassword) < 6) {
		SendPrint(client, "The new password requires more than or equal to 6 characters.");
		return Plugin_Handled;
	}

	if (strlen(sNewPassword) > 256) {
		SendPrint(client, "The new password requires less than or equal to 256 characters.");
		return Plugin_Handled;
	}

	password.SetString(sPassword);

	SendPrintToAll("[H]%N [D]has set a password on the server locking it.", client);
	SendPrint(client, "You have set the server password locking it to [H]%s [D].", sNewPassword);

	return Plugin_Handled;
}

public Action Command_EndRound(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	switch (game) {
		case Engine_TF2: {
			TFTeam team = TFTeam_Unassigned;

			if (args > 0) {
				team = view_as<TFTeam>(GetCmdArgInt(1));
			}

			TF2_ForceRoundWin(team);
			TF2_ForceWin(team);
		}
		case Engine_CSGO, Engine_CSS: {
			float delay;
			CSRoundEndReason reason = CSRoundEnd_Draw;
			bool blockhook = true;
			
			if (args >= 1) {
				delay = GetCmdArgFloat(1);
			}
			if (args >= 2) {
				reason = view_as<CSRoundEndReason>(GetCmdArgInt(2));
			}
			if (args >= 3) {
				blockhook = GetCmdArgBool(3);
			}
			
			CS_TerminateRound(delay, reason, blockhook);
		}
	}
	
	SendPrintToAll("[H]%N [D]has ended the current round.", client);
	return Plugin_Handled;
}

public void TF2_OnConditionAdded(int client, TFCond condition) {
	if (g_SpewConditions) {
		char sCondition[32];
		TF2_GetConditionName(condition, sCondition, sizeof(sCondition));
		SendPrint(client, "[Condition Added] -: [H]%s [D]", sCondition);
	}
}

public void TF2_OnConditionRemoved(int client, TFCond condition) {
	if (g_SpewConditions) {
		char sCondition[32];
		TF2_GetConditionName(condition, sCondition, sizeof(sCondition));
		SendPrint(client, "[Condition Removed] -: [H]%s [D]", sCondition);
	}
}

public Action Command_SetTime(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a time to set.");
		return Plugin_Handled;
	}

	char sTime[12];
	GetCmdArg(1, sTime, sizeof(sTime));
	int time = StringToInt(sTime);

	int entity = FindEntityByClassname(-1, "team_round_timer");

	if (IsValidEntity(entity)) {
		SetVariantInt(time);
		AcceptEntityInput(entity, "SetTime");
	} else {
		ConVar timelimit = FindConVar("mp_timelimit");
		SetConVarFloat(timelimit, float(time) / 60);
		delete timelimit;
	}

	SendPrintToAll("[H]%N [D]has set the time to [H]%i [D].", client, time);

	return Plugin_Handled;
}

public Action Command_AddTime(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	int time = 999999;

	if (args > 0) {
		char sTime[12];
		GetCmdArg(1, sTime, sizeof(sTime));
		time = StringToInt(sTime);
	}

	int entity = FindEntityByClassname(-1, "team_round_timer");

	if (IsValidEntity(entity)) {
		char sMap[32];
		GetCurrentMap(sMap, sizeof(sMap));

		if (strncmp(sMap, "pl_", 3) == 0) {
			char sBuffer[32];
			Format(sBuffer, sizeof(sBuffer), "0 [H]%i [D]", time);

			SetVariantString(sBuffer);
			AcceptEntityInput(entity, "AddTeamTime");
		} else {
			SetVariantInt(time);
			AcceptEntityInput(entity, "AddTime");
		}
	} else {
		ConVar timelimit = FindConVar("mp_timelimit");
		SetConVarFloat(timelimit, timelimit.FloatValue + (float(time) / 60));
		delete timelimit;
	}

	SendPrintToAll("[H]%N [D]has added time to [H]%i [D].", client, time);

	return Plugin_Handled;
}

public Action Command_RemoveTime(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a time to removed from.");
		return Plugin_Handled;
	}

	char sTime[12];
	GetCmdArg(1, sTime, sizeof(sTime));
	int time = StringToInt(sTime);

	int entity = FindEntityByClassname(-1, "team_round_timer");

	if (IsValidEntity(entity)) {
		char sMap[32];
		GetCurrentMap(sMap, sizeof(sMap));

		if (strncmp(sMap, "pl_", 3) == 0) {
			char sBuffer[32];
			Format(sBuffer, sizeof(sBuffer), "0 [H]%i [D]", time);

			SetVariantString(sBuffer);
			AcceptEntityInput(entity, "RemoveTeamTime");
		} else {
			SetVariantInt(time);
			AcceptEntityInput(entity, "RemoveTime");
		}
	} else {
		ConVar timelimit = FindConVar("mp_timelimit");
		SetConVarFloat(timelimit, timelimit.FloatValue - (StringToFloat(sTime) / 60));
		delete timelimit;
	}

	SendPrintToAll("[H]%N [D]has removed time from [H]%i [D].", client, time);

	return Plugin_Handled;
}

public Action Command_SetGod(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a target to set godmode on.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0) {
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	for (int i = 0; i < targets; i++) {
		TF2_SetGodmode(targets_list[i], TFGod_God);
		SendPrint(targets_list[i], "Your have been set to godmode by [H]%N [D].", client);
	}
	
	if (tn_is_ml) {
		SendPrint(client, "You have set godmode on [H]%t [D].", sTargetName);
	} else {
		SendPrint(client, "You have set godmode on [H]%s [D].", sTargetName);
	}

	return Plugin_Handled;
}

public Action Command_SetBuddha(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a target to set buddhamode on.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0) {
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	for (int i = 0; i < targets; i++) {
		TF2_SetGodmode(targets_list[i], TFGod_Buddha);
		SendPrint(targets_list[i], "Your have been set to buddhamode by [H]%N [D].", client);
	}
	
	if (tn_is_ml) {
		SendPrint(client, "You have set buddhamode on [H]%t [D].", sTargetName);
	} else {
		SendPrint(client, "You have set buddhamode on [H]%s [D].", sTargetName);
	}

	return Plugin_Handled;
}

public Action Command_SetMortal(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a target to set mortalmode on.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0) {
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	for (int i = 0; i < targets; i++) {
		TF2_SetGodmode(targets_list[i], TFGod_Mortal);
		SendPrint(targets_list[i], "Your have been set to mortalmode by [H]%N [D].", client);
	}
	
	if (tn_is_ml) {
		SendPrint(client, "You have set mortalmode on [H]%t [D].", sTargetName);
	} else {
		SendPrint(client, "You have set mortalmode on [H]%s [D].", sTargetName);
	}

	return Plugin_Handled;
}

public Action Command_StunPlayer(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a target to stun.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0) {
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	float time = 7.0;

	if (args >= 2) {
		char sTime[12];
		GetCmdArg(2, sTime, sizeof(sTime));

		time = StringToFloat(sTime);

		if (time < 0.0) {
			SendPrint(client, "You have specified an invalid time.");
			return Plugin_Handled;
		}
	}

	float slowdown = 0.8;

	if (args >= 3) {
		char sSlowdown[12];
		GetCmdArg(3, sSlowdown, sizeof(sSlowdown));

		slowdown = StringToFloat(sSlowdown);

		if (slowdown < 0.0 || slowdown > 1.00) {
			SendPrint(client, "You have specified an invalid slowdown.");
			return Plugin_Handled;
		}
	}

	for (int i = 0; i < targets; i++) {
		TF2_StunPlayer(targets_list[i], time, slowdown, TF_STUNFLAGS_SMALLBONK, client);
		SendPrint(targets_list[i], "Your have been stunned by [H]%N [D] for %.2f seconds.", client, time);
	}
	
	if (tn_is_ml) {
		SendPrint(client, "You have stunned [H]%t [D] for %.2f seconds.", sTargetName, time);
	} else {
		SendPrint(client, "You have stunned [H]%s [D] for %.2f seconds.", sTargetName, time);
	}

	return Plugin_Handled;
}

public Action Command_BleedPlayer(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a target to bleed.");
		return Plugin_Handled;
	} else if (game != Engine_TF2) {
		SendPrint(client, "This command is for Team Fortress 2 only.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0) {
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	float time = 10.0;

	if (args >= 2) {
		char sTime[12];
		GetCmdArg(2, sTime, sizeof(sTime));

		time = StringToFloat(sTime);

		if (time < 0.0) {
			SendPrint(client, "You have specified an invalid time.");
			return Plugin_Handled;
		}
	}

	for (int i = 0; i < targets; i++) {
		TF2_MakeBleed(targets_list[i], client, time);
		SendPrint(targets_list[i], "Your have been cut by [H]%N [D] for %.2f seconds.", client, time);
	}
	
	if (tn_is_ml) {
		SendPrint(client, "You have cut [H]%t [D] for %.2f seconds.", sTargetName, time);
	} else {
		SendPrint(client, "You have cut [H]%s [D] for %.2f seconds.", sTargetName, time);
	}

	return Plugin_Handled;
}

public Action Command_IgnitePlayer(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a target to ignite.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0) {
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	for (int i = 0; i < targets; i++) {
		if (game == Engine_TF2) {
			TF2_IgnitePlayer(targets_list[i], client);
		} else {
			IgniteEntity(targets_list[i], 99999.0);
		}
		
		SendPrint(targets_list[i], "Your have been ignited by [H]%N [D].", client);
	}
	
	if (tn_is_ml) {
		SendPrint(client, "You have ignited [H]%t [D]", sTargetName);
	} else {
		SendPrint(client, "You have ignited [H]%s [D]", sTargetName);
	}

	return Plugin_Handled;
}

public Action Command_ReloadMap(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	char sCurrentMap[MAX_MAP_NAME_LENGTH];
	GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));
	ServerCommand("sm_map %s", sCurrentMap);

	char sMap[MAX_MAP_NAME_LENGTH];
	GetMapName(sMap, sizeof(sMap));
	SendPrintToAll("[H]%N [D]has initiated a map reload.", client);

	return Plugin_Handled;
}

public Action Command_MapName(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	char sCurrentMap[MAX_MAP_NAME_LENGTH];
	GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));

	char sMap[MAX_MAP_NAME_LENGTH];
	GetMapDisplayName(sCurrentMap, sMap, sizeof(sMap));

	if (StrContains(sCurrentMap, "workshop/", false) == 0) {
		SendPrint(client, "Name: [H]%s [D][[H]%s [D]]", sMap, sCurrentMap);
	} else {
		SendPrint(client, "Name: [H]%s [D]", sCurrentMap);
	}

	return Plugin_Handled;
}

public Action Command_SpawnSentry(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		char sCommand[32];
		GetCommandName(sCommand, sizeof(sCommand));
		SendPrint(client, "Usage: [H]%s [D]<target> <team> <level> <mini> <disposable>", sCommand);
		return Plugin_Handled;
	} else if (game != Engine_TF2) {
		SendPrint(client, "This command is for Team Fortress 2 only.");
		return Plugin_Handled;
	}

	float vecOrigin[3];
	if (!GetClientLookOrigin(client, vecOrigin)) {
		SendPrint(client, "Invalid look position.");
		return Plugin_Handled;
	}

	float vecAngles[3];
	GetClientAbsAngles(client, vecAngles);

	int target = GetCmdArgTarget(client, 1, false, false);

	if (target == -1) {
		target = client;
	}

	TFTeam team = view_as<TFTeam>(GetCmdArgInt(2));
	int level = GetCmdArgInt(3);
	bool mini = GetCmdArgBool(4);
	bool disposable = GetCmdArgBool(5);

	TF2_SpawnSentry(target, vecOrigin, vecAngles, team, level, mini, disposable);
	return Plugin_Handled;
}

public Action Command_SpawnDispenser(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		char sCommand[32];
		GetCommandName(sCommand, sizeof(sCommand));
		SendPrint(client, "Usage: [H]%s [D]<target> <team> <level>", sCommand);
		return Plugin_Handled;
	} else if (game != Engine_TF2) {
		SendPrint(client, "This command is for Team Fortress 2 only.");
		return Plugin_Handled;
	}

	float vecOrigin[3];
	if (!GetClientLookOrigin(client, vecOrigin)) {
		SendPrint(client, "Invalid look position.");
		return Plugin_Handled;
	}

	float vecAngles[3];
	GetClientAbsAngles(client, vecAngles);

	int target = GetCmdArgTarget(client, 1, false, false);

	if (target == -1) {
		target = client;
	}

	TFTeam team = view_as<TFTeam>(GetCmdArgInt(2));
	int level = GetCmdArgInt(3);

	TF2_SpawnDispenser(target, vecOrigin, vecAngles, team, level);
	return Plugin_Handled;
}

public Action Command_SpawnTeleporter(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		char sCommand[32];
		GetCommandName(sCommand, sizeof(sCommand));
		SendPrint(client, "Usage: [H]%s [D]<target> <team> <level> <mode>", sCommand);
		return Plugin_Handled;
	}

	float vecOrigin[3];
	if (!GetClientLookOrigin(client, vecOrigin)) {
		SendPrint(client, "Invalid look position.");
		return Plugin_Handled;
	}

	float vecAngles[3];
	GetClientAbsAngles(client, vecAngles);

	int target = GetCmdArgTarget(client, 1, false, false);

	if (target == -1) {
		target = client;
	}

	TFTeam team = view_as<TFTeam>(GetCmdArgInt(2));
	int level = GetCmdArgInt(3);
	TFObjectMode mode = view_as<TFObjectMode>(GetCmdArgInt(4));

	TF2_SpawnTeleporter(target, vecOrigin, vecAngles, team, level, mode);
	return Plugin_Handled;
}

public Action Command_Particle(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		char sCommand[64];
		GetCommandName(sCommand, sizeof(sCommand));
		SendPrint(client, "Usage: [H]%s [D]<particle> <time>", sCommand);
		return Plugin_Handled;
	}
	
	char sParticle[64];
	GetCmdArg(1, sParticle, sizeof(sParticle));
	
	float time = GetCmdArgFloat(2);
	
	if (time <= 0.0) {
		time = 2.0;
	}
	
	float vecOrigin[3];
	GetClientLookOrigin(client, vecOrigin);
	
	CreateParticle(sParticle, vecOrigin, time);
	SendPrint(client, "Particle [H]%s [D]has been spawned for %.2f second(s).", sParticle, time);
	
	return Plugin_Handled;
}

public Action Command_ListParticles(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	ListParticles(client);
	return Plugin_Handled;
}

void ListParticles(int client) {
	int tblidx = FindStringTable("ParticleEffectNames");
	
	if (tblidx == INVALID_STRING_TABLE) {
		SendPrint(client, "Could not find string table: ParticleEffectNames");
		return;
	}
	
	Menu menu = new Menu(MenuHandler_Particles);
	menu.SetTitle("Available particles:");
	
	char sParticle[256];
	for (int i = 0; i < GetStringTableNumStrings(tblidx); i++) {
		ReadStringTable(tblidx, i, sParticle, sizeof(sParticle));
		menu.AddItem(sParticle, sParticle);
	}
	
	if (menu.ItemCount == 0) {
		menu.AddItem("", "[Empty]", ITEMDRAW_DISABLED);
	}
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Particles(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char sParticle[256];
			menu.GetItem(param2, sParticle, sizeof(sParticle));
			
			float vecOrigin[3];
			GetClientLookOrigin(param1, vecOrigin);
			
			CreateParticle(sParticle, vecOrigin, 2.0);
			SendPrint(param1, "Particle [H]%s [D]has been spawned for 2.0 seconds.", sParticle);
			
			ListParticles(param1);
		}

		case MenuAction_End: {
			delete menu;
		}
	}

	return 0;
}

public Action Command_GenerateParticles(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/");
	
	if (!DirExists(sPath)) {
		CreateDirectory(sPath, 511);
		
		if (!DirExists(sPath)) {
			SendPrint(client, "Error finding and creating directory: [H]%s [D]", sPath);
			return Plugin_Handled;
		}
	}
	
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/particles.txt");
	
	File file = OpenFile(sPath, "w");
	
	if (file == null) {
		SendPrint(client, "Error opening up file for writing: [H]%s [D]", sPath);
		return Plugin_Handled;
	}
	
	int tblidx = FindStringTable("ParticleEffectNames");
	
	if (tblidx == INVALID_STRING_TABLE) {
		SendPrint(client, "Could not find string table: ParticleEffectNames");
		return Plugin_Handled;
	}
	
	char name[256];
	for (int i = 0; i < GetStringTableNumStrings(tblidx); i++) {
		ReadStringTable(tblidx, i, name, sizeof(name));
		file.WriteLine(name);
	}
	
	delete file;

	char sGame[32];
	GetGameFolderName(sGame, sizeof(sGame));

	SendPrint(client, "Particles file generated successfully for [H]%s [D]at: [H]%s [D]", sGame, sPath);
	
	return Plugin_Handled;
}

public Action SpewSounds(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed) {
	SendPrintToAll("[SpewSounds] -: [H]%s [D]", sample);
	return Plugin_Continue;
}

public Action SpewAmbients(char sample[PLATFORM_MAX_PATH], int &entity, float &volume, int &level, int &pitch, float pos[3], int &flags, float &delay) {
	SendPrintToAll("[SpewAmbients] -: [H]%s [D]", sample);
	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname) {
	if (g_SpewEntities) {
		SendPrintToAll("[SpewEntities] -[H]%i [D]: [H]%s [D]([H]Created[D])", entity, classname);
	}
	
	if (StrContains(classname, "trigger", false) == 0) {
		SDKHook(entity, SDKHook_StartTouch, OnTriggerTouch);
	}
}

public Action Command_GetEntName(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	int target = GetClientAimTarget(client, false);
	
	if (!IsValidEntity(target)) {
		SendPrint(client, "Target not found, please aim your crosshair at the entity.");
		return Plugin_Handled;
	}
	
	char sName[64];
	GetEntityName(target, sName, sizeof(sName));
	SendPrint(client, "Entity Name: [H]%s [D]", sName);
	
	return Plugin_Handled;
}

public Action Command_GetEntModel(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	int target = GetClientAimTarget(client, false);
	
	if (!IsValidEntity(target)) {
		SendPrint(client, "Target not found, please aim your crosshair at the entity.");
		return Plugin_Handled;
	}
	
	if (!HasEntProp(target, Prop_Data, "m_ModelName")) {
		SendPrint(client, "Target doesn't have a valid model.");
		return Plugin_Handled;
	}
	
	char sModel[PLATFORM_MAX_PATH];
	GetEntPropString(target, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	SendPrint(client, "Model Found: [H]%s [D]", sModel);
	
	return Plugin_Handled;
}

public Action Command_SetKillstreak(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (game != Engine_TF2) {
		SendPrint(client, "This command is for Team Fortress 2 only.");
		return Plugin_Handled;
	}
	
	int value = GetCmdArgInt(1);
	TF2_SetKillstreak(client, value);
	SendPrint(client, "Killstreak set to: [H]%i [D]", value);
	return Plugin_Handled;
}

public Action Command_GiveWeapon(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	int target = client;
			
	if (args > 1) {
		target = GetCmdArgTarget(client, 1);
	}
	
	if (target == -1) {
		SendPrint(client, "Invalid target specified: Not Found");
		return Plugin_Handled;
	}
	
	if (!IsPlayerAlive(target)) {
		SendPrint(client, "Invalid target specified: Not Alive");
		return Plugin_Handled;
	}
	
	char class[64];
	switch (game) {
		case Engine_TF2: {
			int index = GetCmdArgInt(1);
			
			if (index < 0) {
				SendPrint(client, "Invalid index specified, please specify an index.");
				return Plugin_Handled;
			}
			
			TF2Econ_GetItemClassName(index, class, sizeof(class));
			int slot = TF2Econ_GetItemSlot(index, TF2_GetPlayerClass(client));
			
			TF2_RemoveWeaponSlot(client, slot);
			int weapon = TF2_GiveItem(target, class, index);
			
			if (IsValidEntity(weapon)) {
				EquipWeapon(client, weapon);
				
				if (client == target) {
					SendPrint(client, "Weapon with index %i and class %s has been equipped.", index, class);
				} else {
					SendPrint(client, "Weapon with index %i and class %s has been given to %N.", index, class, target);
					SendPrint(target, "Weapon with index %i and class %s has been received by %N.", index, class, client);
				}
			} else {
				SendPrint(client, "Unknown error while creating weapon with index %i and class %s.", index, class);
			}
		}
		default: {
			GetCmdArg(1, class, sizeof(class));
			
			if (args < 1 || strlen(class) == 0) {
				SendPrint(client, "Invalid Item specified, please input one.");
				return Plugin_Handled;
			}
			
			if (StrContains(class, "weapon_", false) != 0) {
				Format(class, sizeof(class), "weapon_%s", class);
			}
			
			int weapon = GivePlayerItem(target, class);
			
			if (IsValidEntity(weapon)) {
				EquipWeapon(client, weapon);
				
				if (client == target) {
					SendPrint(client, "Weapon with class %s has been equipped.", class);
				} else {
					SendPrint(client, "Weapon with class %s has been given to %N.", class, target);
					SendPrint(target, "Weapon with class %s has been received by %N.", class, client);
				}
			} else {
				SendPrint(client, "Unknown error while creating weapon with class %s.", class);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action Command_SpawnHealthkit(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (client == 0) {
		return Plugin_Continue;
	}
	
	float vecOrigin[3];
	GetClientLookOrigin(client, vecOrigin);
	
	TF2_SpawnPickup(vecOrigin, PICKUP_TYPE_HEALTHKIT, PICKUP_FULL);
	SendPrintToAll("Health kit has been spawned where you're looking.");
	
	return Plugin_Handled;
}

public Action Command_Lock(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	g_Locked = !g_Locked;
	SendPrintToAll(g_Locked ? "Server is now locked to admins by [H]%N [D]." : "Server is now unlocked by [H]%N [D].", client);
	return Plugin_Handled;
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen) {
	if (g_Locked && !CheckCommandAccess(client, "", ADMFLAG_GENERIC, true)) {
		strcopy(rejectmsg, maxlen, "Server is currently locked, you cannot access it.");
		return false;
	}
	
	return true;
}

public Action Command_DebugEvents(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (g_HookEvents.Length > 0) {
		char sName[256];
		for (int i = 0; i < g_HookEvents.Length; i++) {
			g_HookEvents.GetString(i, sName, sizeof(sName));
			UnhookEvent(sName, Event_Debug);
		}
		
		g_HookEvents.Clear();
		SendPrint(client, "Event debugging: OFF");
		
		return Plugin_Handled;
	}
	
	char sPath[PLATFORM_MAX_PATH];
	FormatEx(sPath, sizeof(sPath), "resource/modevents.res");
	
	KeyValues kv = new KeyValues("ModEvents");
	
	if (!kv.ImportFromFile(sPath)) {
		delete kv;
		SendPrint(client, "Error finding file: [H]%s [D]", sPath);
		return Plugin_Handled;
	}
	
	if (!kv.GotoFirstSubKey()) {
		delete kv;
		SendPrint(client, "Error parsing file: [H]%s [D]", sPath);
		return Plugin_Handled;
	}
	
	char sName[256];
	do {
		kv.GetSectionName(sName, sizeof(sName));
		HookEventEx(sName, Event_Debug);
		g_HookEvents.PushString(sName);
	} while (kv.GotoNextKey());
	
	delete kv;
	SendPrint(client, "Event [H]%i [D]debugging: ON", g_HookEvents.Length);
	
	return Plugin_Handled;
}

public void Event_Debug(Event event, const char[] name, bool dontBroadcast) {
	PrintToConsoleAll("[EVENT DEBUGGING] FIRED: %s", name);
}

public Action Command_SetRenderColor(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	int red = GetCmdArgInt(1);
	int green = GetCmdArgInt(2);
	int blue = GetCmdArgInt(3);
	int alpha = GetCmdArgInt(4);
	
	SetEntityRenderColor(client, red, green, blue, alpha);
	SendPrint(client, "Render color set to '[H]%i [D]/[H]%i [D]/[H]%i [D]/[H]%i [D]'.", red, green, blue, alpha);
	
	return Plugin_Handled;
}

public Action Command_SetRenderFx(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	char sArg[64];
	GetCmdArgString(sArg, sizeof(sArg));
	
	SetEntityRenderFx(client, GetRenderFxByName(sArg));
	SendPrint(client, "Render fx set to '[H]%s [D]'.", sArg);
	
	return Plugin_Handled;
}

public Action Command_SetRenderMode(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	char sArg[64];
	GetCmdArgString(sArg, sizeof(sArg));
	
	SetEntityRenderMode(client, GetRenderModeByName(sArg));
	SendPrint(client, "Render mode set to '[H]%s [D]'.", sArg);
	
	return Plugin_Handled;
}

public Action Command_ApplyAttribute(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (client == 0) {
		return Plugin_Handled;
	}
	
	if (game != Engine_TF2) {
		SendPrint(client, "This command is for Team Fortress 2 only.");
		return Plugin_Handled;
	}
	
	if (!IsPlayerAlive(client)) {
		SendPrint(client, "You must be alive to apply attributes.");
		return Plugin_Handled;
	}
	
	if (args < 2) {
		char sCommand[64];
		GetCommandName(sCommand, sizeof(sCommand));
		SendPrint(client, "Usage: [H]%s [D]<attribute> <value> <0/1 weapons>", sCommand);
		return Plugin_Handled;
	}
	
	char sArg1[64];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	
	char sArg2[64];
	GetCmdArg(2, sArg2, sizeof(sArg2));
	float value = StringToFloat(sArg2);
	
	if (IsStringNumeric(sArg1)) {
		int index = StringToInt(sArg1);
		TF2Attrib_SetByDefIndex(client, index, value);
		SendPrint(client, "Applying attribute index '[H]%i [D]' to yourself with the value: %.2f", index, value);
		
		if (args >= 3) {
			TF2Attrib_SetByDefIndex_Weapons(client, -1, index, value, GetCmdArgBool(4));
			SendPrint(client, "Applying attribute index '[H]%i [D]' to your weapons with the value: %.2f", index, value);
		}
	} else {
		TF2Attrib_SetByName(client, sArg1, value);
		SendPrint(client, "Applying attribute '[H]%s [D]' to yourself with the value: %.2f", sArg1, value);
		
		if (args >= 3) {
			TF2Attrib_SetByName_Weapons(client, -1, sArg1, value);
			SendPrint(client, "Applying attribute '[H]%s [D]' to your weapons with the value: %.2f", sArg1, value);
		}
	}
	
	return Plugin_Handled;
}

public Action Command_RemoveAttribute(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (client == 0) {
		return Plugin_Handled;
	}
		
	if (game != Engine_TF2) {
		SendPrint(client, "This command is for Team Fortress 2 only.");
		return Plugin_Handled;
	}
	
	if (!IsPlayerAlive(client)) {
		SendPrint(client, "You must be alive to remove attributes.");
		return Plugin_Handled;
	}
	
	if (args < 2) {
		char sCommand[64];
		GetCommandName(sCommand, sizeof(sCommand));
		SendPrint(client, "Usage: [H]%s [D]<attribute> <0/1 weapons>", sCommand);
		return Plugin_Handled;
	}
	
	char sArg1[64];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	
	if (IsStringNumeric(sArg1)) {
		int index = StringToInt(sArg1);
		TF2Attrib_RemoveByDefIndex(client, index);
		SendPrint(client, "Removing attribute index '[H]%i [D]' from yourself.", index);
		
		if (args >= 2) {
			TF2Attrib_RemoveByDefIndex_Weapons(client, -1, index);
			SendPrint(client, "Removing attribute index '[H]%i [D]' from your weapons.", index);
		}
	} else {
		TF2Attrib_RemoveByName(client, sArg1);
		SendPrint(client, "Removing attribute '[H]%s [D]' from yourself.", sArg1);
		
		if (args >= 2) {
			TF2Attrib_RemoveByName_Weapons(client, -1, sArg1);
			SendPrint(client, "Removing attribute '[H]%s [D]' from your weapons.", sArg1);
		}
	}
	
	return Plugin_Handled;
}

public Action Command_GetEntProp(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	int target = GetClientAimTarget(client, false);
	
	if (!IsValidEntity(target)) {
		SendPrint(client, "Entity not found, please aim your crosshair at the entity.");
		return Plugin_Handled;
	}
	
	PropType type = view_as<PropType>(GetCmdArgInt(1));
	
	char prop[64];
	GetCmdArg(2, prop, sizeof(prop));
	
	if (!HasEntProp(target, type, prop)) {
		SendPrint(client, "Entity doesn't have netprop: %s", prop);
		return Plugin_Handled;
	}
	
	SendPrint(client, "SetEntProp Output: %i", GetEntProp(target, type, prop));
	return Plugin_Handled;
}

public Action Command_SetEntProp(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	int target = GetClientAimTarget(client, false);
	
	if (!IsValidEntity(target)) {
		SendPrint(client, "Entity not found, please aim your crosshair at the entity.");
		return Plugin_Handled;
	}
	
	PropType type = view_as<PropType>(GetCmdArgInt(1));
	
	char prop[64];
	GetCmdArg(2, prop, sizeof(prop));
	
	if (!HasEntProp(target, type, prop)) {
		SendPrint(client, "Entity doesn't have netprop: %s", prop);
		return Plugin_Handled;
	}
	
	int value = GetCmdArgInt(3);
	SetEntProp(target, type, prop, value);
	SendPrint(client, "SetEntProp on %i: %i", target, value);
	
	return Plugin_Handled;
}

public Action Command_GetEntPropFloat(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	int target = GetClientAimTarget(client, false);
	
	if (!IsValidEntity(target)) {
		SendPrint(client, "Entity not found, please aim your crosshair at the entity.");
		return Plugin_Handled;
	}
	
	PropType type = view_as<PropType>(GetCmdArgInt(1));
	
	char prop[64];
	GetCmdArg(2, prop, sizeof(prop));
	
	if (!HasEntProp(target, type, prop)) {
		SendPrint(client, "Entity doesn't have netprop: %s", prop);
		return Plugin_Handled;
	}
	
	SendPrint(client, "SetEntPropFloat Output: %.2f", GetEntPropFloat(target, type, prop));
	return Plugin_Handled;
}

public Action Command_SetEntPropFloat(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	int target = GetClientAimTarget(client, false);
	
	if (!IsValidEntity(target)) {
		SendPrint(client, "Entity not found, please aim your crosshair at the entity.");
		return Plugin_Handled;
	}
	
	PropType type = view_as<PropType>(GetCmdArgInt(1));
	
	char prop[64];
	GetCmdArg(2, prop, sizeof(prop));
	
	if (!HasEntProp(target, type, prop)) {
		SendPrint(client, "Entity doesn't have netprop: %s", prop);
		return Plugin_Handled;
	}
	
	float value = GetCmdArgFloat(3);
	SetEntPropFloat(target, type, prop, value);
	SendPrint(client, "SetEntPropFloat on %i: %.2f", target, value);
	
	return Plugin_Handled;
}

public Action Command_GetEntClass(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	int target = GetClientAimTarget(client, false);
	
	if (!IsValidEntity(target)) {
		SendPrint(client, "Entity not found, please aim your crosshair at the entity.");
		return Plugin_Handled;
	}
	
	char sClass[64];
	GetEntityClassname(target, sClass, sizeof(sClass));
	SendPrint(client, "Entity [H]%i[D]'s class: [H]%s", target, sClass);
	
	return Plugin_Handled;
}

public Action Timer_Start(Handle timer, any data) {
	int client = data;
	
	if (!IsClientInGame(client)) {
		return Plugin_Stop;
	}
	
	g_TimerVal[client] += 1.0;
	PrintHintText(client, "Timer :: %.2f", g_TimerVal[client]);
	
	return Plugin_Continue;
}

public void OnTriggerTouch(int entity, int other) {
	if (IsPlayerIndex(other) && g_SpewTriggers) {
		char classname[64];
		GetEntityClassname(entity, classname, sizeof(classname));
		SendPrintToAll("[SpewTriggers] -[H]%i [D]: [H]%s [D]([H]Touched [D]by [H]%N[D])", entity, classname, other);
	}
}

public Action OnClientCommand(int client, int args) {
	if (g_SpewCommands) {
		char sCommand[64];
		GetCmdArg(0, sCommand, sizeof(sCommand));
		
		char sArguments[64];
		GetCmdArgString(sArguments, sizeof(sArguments));
		
		SendPrintToAll("[SpewCommands] -[H]%N [D]: [H]%s [D][[H]%s[D]]", client, sCommand, sArguments);
	}

	return Plugin_Continue;
}

public Action Command_GetEntCount(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	SendPrint(client, "Total Networked Entities: [H]%i", GetEntityCount());
	return Plugin_Handled;
}

public Action Command_Bhop(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0) {
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	bool status = GetCmdArgBool(2);

	for (int i = 0; i < targets; i++) {
		g_Bunnyhopping[targets_list[i]] = status;
		SendPrint(targets_list[i], "[H]%N [D] has %s ability to bunnyhop.", client, status ? "given you the" : "took away your");
	}
	
	if (tn_is_ml) {
		SendPrint(client, "[H]%t [D]can %s bunnyhop.", sTargetName, status ? "now" : "no longer");
	} else {
		SendPrint(client, "[H]%s [D]can %s bunnyhop.", sTargetName, status ? "now" : "no longer");
	}
	
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
	if (g_Bunnyhopping[client] && (!(GetEntityFlags(client) & FL_FAKECLIENT) && buttons & IN_JUMP) && (GetEntityFlags(client) & FL_ONGROUND)) {
		buttons &= ~IN_JUMP;
	}

	return Plugin_Continue;
}

public Action Command_KillEntity(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	int target = GetClientAimTarget(client, false);
	
	if (!IsValidEntity(target)) {
		SendPrint(client, "Entity not found, please aim your crosshair at the entity.");
		return Plugin_Handled;
	}
	
	char sClass[64];
	GetEntityClassname(target, sClass, sizeof(sClass));

	SendPrint(client, "Entity [H]%i[D] with class class [H]%s[D] has been killed.", target, sClass);
	AcceptEntityInput(target, "Kill");

	return Plugin_Handled;
}

stock void SendPrint(int client, const char[] format, any ...) {
	char sBuffer[255];
	VFormat(sBuffer, sizeof(sBuffer), format, 3);

	if (client == 0) {
		Format(sBuffer, sizeof(sBuffer), "%s %s", TAG, sBuffer);
		ReplaceString(sBuffer, sizeof(sBuffer), "[D]", "");
		ReplaceString(sBuffer, sizeof(sBuffer), "[H]", "");
		PrintToServer(sBuffer);
		return;
	}
	
	Format(sBuffer, sizeof(sBuffer), "%s %s", g_Tag, sBuffer);
	
	ReplaceString(sBuffer, sizeof(sBuffer), "[D]", g_ChatColor);
	ReplaceString(sBuffer, sizeof(sBuffer), "[H]", g_UniqueIdent);
	
	CPrintToChat(client, sBuffer);
}

stock void SendPrintToAll(const char[] format, any ...) {
	char sBuffer[255];
	VFormat(sBuffer, sizeof(sBuffer), format, 2);
	
	Format(sBuffer, sizeof(sBuffer), "%s %s", g_Tag, sBuffer);
	
	ReplaceString(sBuffer, sizeof(sBuffer), "[D]", g_ChatColor);
	ReplaceString(sBuffer, sizeof(sBuffer), "[H]", g_UniqueIdent);
	
	CPrintToChatAll(sBuffer);
}

public Action Command_SpawnDummy(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}
	
	float eyePos[3], eyeAng[3], endPos[3];
	GetClientEyePosition(client, eyePos);
	GetClientEyeAngles(client, eyeAng);
	
	Handle hTrace = TR_TraceRayFilterEx(eyePos, eyeAng, MASK_NPCSOLID, RayType_Infinite, TraceRayDontHitEntity, client);
	bool hit = TR_DidHit();
	TR_GetEndPosition(endPos, hTrace);
	delete hTrace;

	if (!hit) {
		SendPrint(client, "Cannot spawn a bot in the position you're looking, please aim elsewhere.");
		return Plugin_Handled;
	}

	char sName[MAX_NAME_LENGTH];
	FormatEx(sName, sizeof(sName), "%N's Target Dummy", client);

	int dummy = CreateFakeClient(sName);

	if (dummy < 1) {
		SendPrint(client, "Unknown error while spawning a target dummy.");
		return Plugin_Handled;
	}

	int team = GetClientTeam(client) == 2 ? 3 : 2;
	ChangeClientTeam(dummy, team);
	TF2_SetPlayerClass(dummy, TFClass_Heavy);
	TF2_RespawnPlayer(dummy);

	endPos[2] += 5.0;
	TeleportEntity(dummy, endPos, NULL_VECTOR, NULL_VECTOR);

	SendPrint(client, "Target dummy has been spawned.");
	SDKHook(dummy, SDKHook_PreThink, OnDummyThink);

	return Plugin_Handled;
}

public Action OnDummyThink(int client) {
	SetEntityHealth(client, GetEntProp(client, Prop_Data, "m_iMaxHealth"));
	return Plugin_Continue;
}

public bool TraceRayDontHitEntity(int entity,int mask,any data) {
	if (entity == data || entity != 0) {
		return false;
	}

	return true;
}