public Action Command_SetArmor(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0)
	{
		SendPrint(client, "You must specify a target to set their armor.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0)
	{
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	char sArmor[12];
	GetCmdArg(2, sArmor, sizeof(sArmor));
	int armor = ClampCell(StringToInt(sArmor), 1, 999999);

	for (int i = 0; i < targets; i++)
	{
		CSGO_SetClientArmor(targets_list[i], armor);
		SendPrint(targets_list[i], "Your armor has been set to [H]%i [D]by [H]%N [D].", armor, client);
	}
	
	if (tn_is_ml)
		SendPrint(client, "You have set the armor of [H]%t [D]to [H]%i [D].", sTargetName, armor);
	else
		SendPrint(client, "You have set the armor of [H]%s [D]to [H]%i [D].", sTargetName, armor);

	return Plugin_Handled;
}

public Action Command_AddArmor(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0)
	{
		SendPrint(client, "You must specify a target to add to their armor.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0)
	{
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	char sArmor[12];
	GetCmdArg(2, sArmor, sizeof(sArmor));
	int armor = ClampCell(StringToInt(sArmor), 1, 999999);

	for (int i = 0; i < targets; i++)
	{
		CSGO_AddClientArmor(targets_list[i], armor);
		SendPrint(targets_list[i], "Your armor has been increased by [H]%i [D]by [H]%N [D].", armor, client);
	}
	
	if (tn_is_ml)
		SendPrint(client, "You have increased the armor of [H]%t [D]by [H]%i [D].", sTargetName, armor);
	else
		SendPrint(client, "You have increased the armor of [H]%s [D]by [H]%i [D].", sTargetName, armor);

	return Plugin_Handled;
}

public Action Command_RemoveArmor(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}
	
	if (args == 0)
	{
		SendPrint(client, "You must specify a target to deduct from their armor.");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0)
	{
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	char sArmor[12];
	GetCmdArg(2, sArmor, sizeof(sArmor));
	int armor = ClampCell(StringToInt(sArmor), 1, 999999);

	for (int i = 0; i < targets; i++)
	{
		CSGO_RemoveClientArmor(targets_list[i], armor);
		SendPrint(targets_list[i], "Your armor has been deducted by [H]%i [D]by [H]%N [D].", armor, client);
	}
	
	if (tn_is_ml)
		SendPrint(client, "You have deducted armor of [H]%t [D]by [H]%i [D].", sTargetName, armor);
	else
		SendPrint(client, "You have deducted armor of [H]%s [D]by [H]%i [D].", sTargetName, armor);

	return Plugin_Handled;
}