public Action Command_LoadPlugin(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	char sName[128];
	GetCmdArgString(sName, sizeof(sName));
	
	ServerCommand("sm plugins load %s", sName);
	SendPrint(client, "[H]%s [D]has been loaded.", sName);
	
	return Plugin_Handled;
}

public Action Command_ReloadPlugin(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	char sName[128];
	GetCmdArgString(sName, sizeof(sName));
	
	ServerCommand("sm plugins reload %s", sName);
	SendPrint(client, "[H]%s [D]has been reloaded.", sName);
	
	return Plugin_Handled;
}

public Action Command_UnloadPlugin(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}
	
	char sName[128];
	GetCmdArgString(sName, sizeof(sName));
	
	ServerCommand("sm plugins unload %s", sName);
	SendPrint(client, "[H]%s [D]has been unloaded.", sName);
	
	return Plugin_Handled;
}