public Action Command_CreateEntity(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0)
	{
		SendPrint(client, "You must specify a classname.");
		return Plugin_Handled;
	}

	char sClassname[64];
	GetCmdArg(1, sClassname, sizeof(sClassname));

	if (args == 1)
	{
		SendPrint(client, "You must specify an entity name for reference.");
		return Plugin_Handled;
	}

	char sName[64];
	GetCmdArg(2, sName, sizeof(sName));

	int entity = CreateEntityByName(sClassname);

	if (!IsValidEntity(entity))
	{
		SendPrint(client, "Unknown error while creating entity.");
		return Plugin_Handled;
	}

	if (!DispatchKeyValue(entity, "targetname", sName))
	{
		SendPrint(client, "Error while setting entity classname to '[H]%s [D]'.", sName);
		AcceptEntityInput(entity, "Kill");
		return Plugin_Handled;
	}

	SendPrint(client, "'[H]%s [D]' entity created with the index '[H]%i [D]'.", sClassname, entity);

	g_OwnedEntities[client].Push(EntIndexToEntRef(entity));
	SendPrint(client, "Entity '[H]%i [D]' is now under ownership of you.", entity);

	g_iTarget[client] = EntIndexToEntRef(entity);
	SendPrint(client, "Entity '[H]%s [D]' is now targetted by you.", sName);

	return Plugin_Handled;
}

public Action Command_DispatchKeyValue(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args < 2)
	{
		SendPrint(client, "You must input at least 2 arguments for the key and the value.");
		return Plugin_Handled;
	}

	if (g_iTarget[client] == INVALID_ENT_REFERENCE)
	{
		SendPrint(client, "You aren't currently targeting an entity.");
		return Plugin_Handled;
	}

	int entity = EntRefToEntIndex(g_iTarget[client]);

	if (!IsValidEntity(entity) || entity < 1)
	{
		SendPrint(client, "Entity is no longer valid.");
		g_iTarget[client] = INVALID_ENT_REFERENCE;
		return Plugin_Handled;
	}

	char sKeyName[64];
	GetCmdArg(1, sKeyName, sizeof(sKeyName));

	char sValue[PLATFORM_MAX_PATH];
	GetCmdArg(2, sValue, sizeof(sValue));

	char sName[64];
	GetEntityName(entity, sName, sizeof(sName));

	DispatchKeyValue(entity, sKeyName, sValue);
	SendPrint(client, "Targetted entity '[H]%s [D]' is now dispatch keyvalue '[H]%s [D]' for '[H]%s [D]'.", strlen(sName) > 0 ? sName : "N/A", sKeyName, sValue);

	return Plugin_Handled;
}

public Action Command_DispatchKeyValueFloat(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args < 2)
	{
		SendPrint(client, "You must input at least 2 arguments for the key and the value.");
		return Plugin_Handled;
	}

	if (g_iTarget[client] == INVALID_ENT_REFERENCE)
	{
		SendPrint(client, "You aren't currently targeting an entity.");
		return Plugin_Handled;
	}

	int entity = EntRefToEntIndex(g_iTarget[client]);

	if (!IsValidEntity(entity) || entity < 1)
	{
		SendPrint(client, "Entity is no longer valid.");
		g_iTarget[client] = INVALID_ENT_REFERENCE;
		return Plugin_Handled;
	}

	char sKeyName[64];
	GetCmdArg(1, sKeyName, sizeof(sKeyName));

	char sValue[PLATFORM_MAX_PATH];
	GetCmdArg(2, sValue, sizeof(sValue));
	float fValue = StringToFloat(sValue);

	char sName[64];
	GetEntityName(entity, sName, sizeof(sName));

	DispatchKeyValueFloat(entity, sKeyName, fValue);
	SendPrint(client, "Targetted entity '[H]%s [D]' is now dispatch keyvalue '[H]%s [D]' for '%.2f'.", strlen(sName) > 0 ? sName : "N/A", sKeyName, fValue);

	return Plugin_Handled;
}

public Action Command_DispatchKeyValueVector(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args < 2)
	{
		SendPrint(client, "You must input at least 2 arguments for the key and the value.");
		return Plugin_Handled;
	}

	if (g_iTarget[client] == INVALID_ENT_REFERENCE)
	{
		SendPrint(client, "You aren't currently targeting an entity.");
		return Plugin_Handled;
	}

	int entity = EntRefToEntIndex(g_iTarget[client]);

	if (!IsValidEntity(entity) || entity < 1)
	{
		SendPrint(client, "Entity is no longer valid.");
		g_iTarget[client] = INVALID_ENT_REFERENCE;
		return Plugin_Handled;
	}

	char sKeyName[64];
	GetCmdArg(1, sKeyName, sizeof(sKeyName));

	char sValue[PLATFORM_MAX_PATH];
	GetCmdArg(2, sValue, sizeof(sValue));

	float vecValue[3];
	StringToVector(sValue, vecValue);

	char sName[64];
	GetEntityName(entity, sName, sizeof(sName));

	DispatchKeyValueVector(entity, sKeyName, vecValue);
	SendPrint(client, "Targetted entity '[H]%s [D]' is now dispatch keyvalue '[H]%s [D]' for '%.2f/%.2f/%.2f'.", strlen(sName) > 0 ? sName : "N/A", sKeyName, vecValue[0], vecValue[1], vecValue[2]);

	return Plugin_Handled;
}

public Action Command_DispatchSpawn(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (g_iTarget[client] == INVALID_ENT_REFERENCE)
	{
		SendPrint(client, "You aren't currently targeting an entity.");
		return Plugin_Handled;
	}

	int entity = EntRefToEntIndex(g_iTarget[client]);

	if (!IsValidEntity(entity) || entity < 1)
	{
		SendPrint(client, "Entity is no longer valid.");
		g_iTarget[client] = INVALID_ENT_REFERENCE;
		return Plugin_Handled;
	}

	char sName[64];
	GetEntityName(entity, sName, sizeof(sName));

	DispatchSpawn(entity);
	SendPrint(client, "Targetted entity '[H]%s [D]' is now dispatch spawned.", strlen(sName) > 0 ? sName : "N/A");

	return Plugin_Handled;
}

public Action Command_AcceptEntityInput(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (g_iTarget[client] == INVALID_ENT_REFERENCE)
	{
		SendPrint(client, "You aren't currently targeting an entity.");
		return Plugin_Handled;
	}

	int entity = EntRefToEntIndex(g_iTarget[client]);

	if (!IsValidEntity(entity) || entity < 1)
	{
		SendPrint(client, "Entity is no longer valid.");
		g_iTarget[client] = INVALID_ENT_REFERENCE;
		return Plugin_Handled;
	}
	
	char sInput[64];
	GetCmdArg(1, sInput, sizeof(sInput));
	
	char sVariantType[64];
	GetCmdArg(2, sVariantType, sizeof(sVariantType));
	
	char sVariant[64];
	GetCmdArg(3, sVariant, sizeof(sVariant));
	
	if (strlen(sVariantType) > 0 && strlen(sVariant) > 0)
	{
		if (StrEqual(sVariantType, "string", false))
			SetVariantString(sVariant);
	}
	
	char sName[64];
	GetEntityName(entity, sName, sizeof(sName));

	AcceptEntityInput(entity, sInput);
	SendPrint(client, "Targetted entity '[H]%s [D]' input '[H]%s [D]' sent.", strlen(sName) > 0 ? sName : "N/A", sInput);

	return Plugin_Handled;
}

public Action Command_Animate(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (g_iTarget[client] == INVALID_ENT_REFERENCE)
	{
		SendPrint(client, "You aren't currently targeting an entity.");
		return Plugin_Handled;
	}

	int entity = EntRefToEntIndex(g_iTarget[client]);

	if (!IsValidEntity(entity) || entity < 1)
	{
		SendPrint(client, "Entity is no longer valid.");
		g_iTarget[client] = INVALID_ENT_REFERENCE;
		return Plugin_Handled;
	}
	
	char sAnimation[64];
	GetCmdArg(1, sAnimation, sizeof(sAnimation));
	
	char sName[64];
	GetEntityName(entity, sName, sizeof(sName));
	
	SetVariantString(sAnimation);
	AcceptEntityInput(entity, "SetAnimation");
	SendPrint(client, "Targetted entity '[H]%s [D]' animation '[H]%s [D]' set.", strlen(sName) > 0 ? sName : "N/A", sAnimation);

	return Plugin_Handled;
}

public Action Command_TargetEntity(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	int entity = GetClientAimTarget(client, false);

	if (!IsValidEntity(entity))
	{
		SendPrint(client, "You aren't aiming at a valid entity.");
		return Plugin_Handled;
	}

	char sName[64];
	GetEntityName(entity, sName, sizeof(sName));

	g_iTarget[client] = EntIndexToEntRef(entity);
	SendPrint(client, "Entity '[H]%s [D]' is now targetted by you.", sName);

	return Plugin_Handled;
}

public Action Command_DeleteEntity(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (g_iTarget[client] == INVALID_ENT_REFERENCE)
	{
		SendPrint(client, "You aren't currently targeting an entity.");
		return Plugin_Handled;
	}

	int entity = EntRefToEntIndex(g_iTarget[client]);

	if (!IsValidEntity(entity) || entity < 1)
	{
		SendPrint(client, "Entity is no longer valid.");
		g_iTarget[client] = INVALID_ENT_REFERENCE;
		return Plugin_Handled;
	}

	char sName[64];
	GetEntityName(entity, sName, sizeof(sName));

	AcceptEntityInput(entity, "Kill");
	g_iTarget[client] = INVALID_ENT_REFERENCE;
	SendPrint(client, "Targetted entity '[H]%s [D]' is now deleted.", strlen(sName) > 0 ? sName : "N/A");

	return Plugin_Handled;
}

public Action Command_ListOwnedEntities(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}
	
	int owned = g_OwnedEntities[client].Length;

	if (owned == 0)
	{
		SendPrint(client, "You currently don't own any entities.");
		return Plugin_Handled;
	}

	Menu menu = new Menu(MenuHandler_ListOwnedEntities);
	menu.SetTitle("Owned Entities:");

	int reference; int entity; char sName[64]; char sIndex[12];
	for (int i = 0; i < owned; i++)
	{
		reference = g_OwnedEntities[client].Get(i);
		entity = EntRefToEntIndex(reference);

		if (!IsValidEntity(entity))
		{
			g_OwnedEntities[client].Erase(i);
			continue;
		}

		IntToString(i, sIndex, sizeof(sIndex));
		GetEntityName(entity, sName, sizeof(sName));

		if (strlen(sName) == 0)
		{
			GetEntityClassname(entity, sName, sizeof(sName));
		}

		if (reference == g_iTarget[client])
		{
			Format(sName, sizeof(sName), "(T)%s", sName);
		}

		menu.AddItem(sIndex, sName, (reference == g_iTarget[client]) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	menu.Display(client, 20);

	return Plugin_Handled;
}

public int MenuHandler_ListOwnedEntities(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sIndex[12]; char sName[64];
			menu.GetItem(param2, sIndex, sizeof(sIndex), _, sName, sizeof(sName));
			int index = StringToInt(sIndex);

			int entity = EntRefToEntIndex(g_OwnedEntities[param1].Get(index));

			if (!IsValidEntity(entity))
			{
				g_OwnedEntities[param1].Erase(index);
				Command_ListOwnedEntities(param1, 0);
				return 0;
			}

			g_iTarget[param1] = EntIndexToEntRef(entity);
			SendPrint(param1, "[H]%s [D]Entity '[H]%s [D]' is now targetted by you.", sName);
			Command_ListOwnedEntities(param1, 0);
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}