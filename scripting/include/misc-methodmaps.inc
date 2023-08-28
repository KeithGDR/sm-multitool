/**

*	▒█▀▀▀█ █▀▀█ █░░█ █▀▀█ █▀▀ █▀▀ █▀▄▀█ █▀▀█ █▀▀▄ ░░ ▒█▀▄▀█ █▀▀ ▀▀█▀▀ █░░█ █▀▀█ █▀▀▄ █▀▄▀█ █▀▀█ █▀▀█ █▀▀ 
*	░▀▀▀▄▄ █░░█ █░░█ █▄▄▀ █░░ █▀▀ █░▀░█ █░░█ █░░█ ▀▀ ▒█▒█▒█ █▀▀ ░░█░░ █▀▀█ █░░█ █░░█ █░▀░█ █▄▄█ █░░█ ▀▀█ 
*	▒█▄▄▄█ ▀▀▀▀ ░▀▀▀ ▀░▀▀ ▀▀▀ ▀▀▀ ▀░░░▀ ▀▀▀▀ ▀▀▀░ ░░ ▒█░░▒█ ▀▀▀ ░░▀░░ ▀░░▀ ▀▀▀▀ ▀▀▀░ ▀░░░▀ ▀░░▀ █▀▀▀ ▀▀▀                                                                
*	This include contains a couple of methodmaps for use.
*	Author: Keith Warren (Drixevel)
*	https://github.com/drixevel-dev
*
*	NOTE: The best way to use this include is to copy and paste into your projects manually.
*	Credits: TheXeon
**/

#if defined _misc_methodmaps_included
#endinput
#endif
#define _misc_methodmaps_included

#tryinclude <sdktools>

/*--------------------------------------------------------->*/
//Entity methodmaps.

methodmap Entity {
	public Entity(const char[] classname) {
		return view_as<Entity>(CreateEntityByName(classname));
	}
	
	property int index  {
		public get() {
			return view_as<int>(this);
		} 
	}
	
	public bool Valid() {
		return IsValidEntity(this.index);
	}
	
	public bool SendInput(const char[] input, int activator = -1, int caller = -1, int outputid = 0) {
		return AcceptEntityInput(this.index, input, activator, caller, outputid);
	}
	
	public void Teleport(float origin[3], float angles[3], float velocity[3]) {
		TeleportEntity(this.index, origin, angles, velocity);
	}
	
	//Dispatches
	public bool Dispatch(const char[] keyName, const char[] value) {
		return DispatchKeyValue(this.index, keyName, value);
	}
	
	public bool DispatchFloat(const char[] keyName, const float value) {
		return DispatchKeyValueFloat(this.index, keyName, value);
	}
	
	public bool DispatchVector(const char[] keyName, const float value[3]) {
		return DispatchKeyValueVector(this.index, keyName, value);
	}
	
	public bool Spawn() {
		return DispatchSpawn(this.index);
	}
	
	//EntProp
	public bool SetProp(PropType type, const char[] prop, any value, int size = 4, int element = 0) {
		if (!HasEntProp(this.index, type, prop)) {
			return false;
		}
		
		SetEntProp(this.index, type, prop, value, size, element);
		return true;
	}
	
	public int GetProp(PropType type, const char[] prop, int size = 4, int element = 0) {
		if (!HasEntProp(this.index, type, prop)) {
			return 0;
		}
		
		return GetEntProp(this.index, type, prop, size, element);
	}
	
	//EntPropEnt
	public bool SetPropEnt(PropType type, const char[] prop, any value, int element = 0) {
		if (!HasEntProp(this.index, type, prop)) {
			return false;
		}
		
		SetEntPropEnt(this.index, type, prop, value, element);
		return true;
	}
	
	public int GetPropEnt(PropType type, const char[] prop, int element = 0) {
		if (!HasEntProp(this.index, type, prop)) {
			return 0;
		}
		
		return GetEntPropEnt(this.index, type, prop, element);
	}
	
	//EntPropFloat
	public bool SetPropFloat(PropType type, const char[] prop, float value, int element = 0) {
		if (!HasEntProp(this.index, type, prop)) {
			return false;
		}
		
		SetEntPropFloat(this.index, type, prop, value, element);
		return true;
	}
	
	public float GetPropFloat(PropType type, const char[] prop, int element = 0) {
		if (!HasEntProp(this.index, type, prop)) {	
			return 0.0;
		}
		
		return GetEntPropFloat(this.index, type, prop, element);
	}
	
	//EntPropString
	public bool SetPropString(PropType type, const char[] prop, const char[] buffer, int element = 0) {
		if (!HasEntProp(this.index, type, prop)) {
			return false;
		}
		
		SetEntPropString(this.index, type, prop, buffer, element);
		return true;
	}
	
	public int GetPropString(PropType type, const char[] prop, char[] buffer, int maxlen, int element = 0) {
		if (!HasEntProp(this.index, type, prop)) {
			return 0;
		}
		
		return GetEntPropString(this.index, type, prop, buffer, maxlen, element);
	}
	
	//EntPropVector
	public bool SetPropVector(PropType type, const char[] prop, const float vec[3], int element = 0) {
		if (!HasEntProp(this.index, type, prop))
			return false;
		
		SetEntPropVector(this.index, type, prop, vec, element);
		return true;
	}
	
	public bool GetPropVector(PropType type, const char[] prop, float vec[3], int element = 0) {
		if (!HasEntProp(this.index, type, prop)) {
			return false;
		}
		
		GetEntPropVector(this.index, type, prop, vec, element);
		return true;
	}
	
	//Misc
	public bool HasProp(PropType type, const char[] prop) {
		return HasEntProp(this.index, type, prop);
	}
	
	public int GetSize(PropType type, const char[] prop) {
		return GetEntPropArraySize(this.index, type, prop);
	}
	
	//Variants
	//This section isn't as needed but it's still nice to have.
	public void VariantBool(bool val) {
		SetVariantBool(val);
	}
	
	public void VariantColor(const int color[4]) {
		SetVariantColor(color);
	}
	
	public void VariantEntity(int entity) {
		SetVariantEntity(entity);
	}
	
	public void VariantFloat(float val) {
		SetVariantFloat(val);
	}
	
	public void VariantInt(int val) {
		SetVariantInt(val);
	}	
	
	public void VariantPosVector3D(const float vec[3]) {
		SetVariantPosVector3D(vec);
	}	
	
	public void VariantString(const char[] str) {
		SetVariantString(str);
	}	
	
	public void VariantVector3D(const float vec[3]) {
		SetVariantVector3D(vec);
	}
}

methodmap Hud < Handle {
	public Hud() {
		return view_as<Hud>(CreateHudSynchronizer());
	}
	
	property Handle index  {
		public get() {
			return view_as<Handle>(this);
		} 
	}
	
	public void Clear(int client) {
		ClearSyncHud(client, this.index);
	}
	
	public void ClearAll() {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && !IsFakeClient(i)) {
				ClearSyncHud(i, this.index);
			}
		}
	}
	
	public void SetParams(float x = -1.0, float y = -1.0, float holdTime = 2.0, int r = 255, int g = 255, int b = 255, int a = 255, int effect = 0, float fxTime = 6.0, float fadeIn = 0.1, float fadeOut = 0.2) {
		SetHudTextParams(x, y, holdTime, r, g, b, a, effect, fxTime, fadeIn, fadeOut);
	}
	
	public void SetParamsEx(float x = -1.0, float y = -1.0, float holdTime = 2.0, int color1[4] = {255, 255, 255, 255}, int color2[4] = {255, 255, 255, 255}, int effect = 0, float fxTime = 6.0, float fadeIn = 0.1, float fadeOut = 0.2) {
		SetHudTextParamsEx(x, y, holdTime, color1, color2, effect, fxTime, fadeIn, fadeOut);
	}
	
	public void Send(int client, const char[] format, any ...) {
		int size = strlen(format) + 255;
		char[] sBuffer = new char[size];
		VFormat(sBuffer, size, format, 4);
		ShowSyncHudText(client, this.index, sBuffer);
	}
	
	public void SendToAll(const char[] format, any ...) {
		int size = strlen(format) + 255;
		char[] sBuffer = new char[size];
		VFormat(sBuffer, size, format, 3);
		
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && !IsFakeClient(i)) {
				ShowSyncHudText(i, this.index, sBuffer);
			}
		}
	}
}