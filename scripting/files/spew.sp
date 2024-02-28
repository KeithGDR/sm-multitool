public Action Command_SpewSounds(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	g_SpewSounds = !g_SpewSounds;
	SendPrint(client, "Spew Sounds: [H]%s [D]", g_SpewSounds ? "ON" : "OFF");
	
	if (g_SpewSounds)
		AddNormalSoundHook(SpewSounds);
	else
		RemoveNormalSoundHook(SpewSounds);
	
	return Plugin_Handled;
}

public Action Command_SpewAmbients(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	g_SpewAmbients = !g_SpewAmbients;
	SendPrint(client, "Spew Ambients: [H]%s [D]", g_SpewAmbients ? "ON" : "OFF");
	
	if (g_SpewAmbients)
		AddAmbientSoundHook(SpewAmbients);
	else
		RemoveAmbientSoundHook(SpewAmbients);
	
	return Plugin_Handled;
}

public Action Command_SpewEntities(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	g_SpewEntities = !g_SpewEntities;
	SendPrint(client, "Spew Entities: [H]%s [D]", g_SpewEntities ? "ON" : "OFF");
	
	return Plugin_Handled;
}

public Action Command_SpewTriggers(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	g_SpewTriggers = !g_SpewTriggers;
	SendPrint(client, "Spew Triggers Touched: [H]%s [D]", g_SpewTriggers ? "ON" : "OFF");
	
	return Plugin_Handled;
}

public Action Command_SpewCommands(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}
	
	g_SpewCommands = !g_SpewCommands;
	SendPrint(client, "Spew Commands Received: [H]%s [D]", g_SpewCommands ? "ON" : "OFF");
	
	return Plugin_Handled;
}