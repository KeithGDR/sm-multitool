public Action Command_CreateProp(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0)
	{
		SendPrint(client, "Must specify a model path.");
		return Plugin_Handled;
	}
	
	float vecOrigin[3];
	GetClientLookOrigin(client, vecOrigin);
	
	char sModel[PLATFORM_MAX_PATH];
	GetCmdArgString(sModel, sizeof(sModel));
	
	if (strlen(sModel) > 0 && GetEngineVersion() == Engine_TF2)
		PrecacheModel(sModel);
	
	CreateProp(sModel, vecOrigin);
	SendPrint(client, "Prop has been spawned with model '[H]%s [D]'.", sModel);
	
	return Plugin_Handled;
}

public Action Command_AnimateProp(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	int target = GetNearestEntity(client, "prop_dynamic");
	
	if (!IsValidEntity(target))
	{
		SendPrint(client, "No target has been found.");
		return Plugin_Handled;
	}
	
	char sClassname[32];
	GetEntityClassname(target, sClassname, sizeof(sClassname));
	
	if (StrContains(sClassname, "prop_dynamic") != 0)
	{
		SendPrint(client, "Target is not a dynamic prop entity.");
		return Plugin_Handled;
	}
	
	char sAnimation[32];
	GetCmdArgString(sAnimation, sizeof(sAnimation));
	
	if (strlen(sAnimation) == 0)
	{
		SendPrint(client, "Invalid animation input, please specify one.");
		return Plugin_Handled;
	}
	
	bool success = AnimateEntity(target, sAnimation);
	SendPrint(client, "Animation '[H]%s [D]' has been sent to the target [H]%s [D].", sAnimation, success ? "successfully" : "unsuccessfully");
	
	return Plugin_Handled;
}

public Action Command_DeleteProp(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}
	
	int target = GetNearestEntity(client, "prop_dynamic");
	
	if (!IsValidEntity(target))
	{
		SendPrint(client, "No target has been found.");
		return Plugin_Handled;
	}
	
	char sClassname[32];
	GetEntityClassname(target, sClassname, sizeof(sClassname));
	
	if (StrContains(sClassname, "prop_dynamic") != 0)
	{
		SendPrint(client, "Target is not a dynamic prop entity.");
		return Plugin_Handled;
	}
	
	bool success = DeleteEntity(target);
	SendPrint(client, "Prop has been deleted [H]%s [D].", success ? "successfully" : "unsuccessfully");
	
	return Plugin_Handled;
}