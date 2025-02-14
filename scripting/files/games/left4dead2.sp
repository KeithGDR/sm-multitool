public Action Command_SpawnCommon(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	float origin[3];
	GetClientCrosshairOrigin(client, origin);

	L4D_SpawnCommonInfected(origin);

	SendPrint(client, "You have spawned a common infected.");

	return Plugin_Handled;
}

public Action Command_ClearZombies(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	float origin[3];
	GetClientAbsOrigin(client, origin);

	int entity = -1; float origin2[3];
	while ((entity = FindEntityByClassname(entity, "infected")) != -1) {
		GetEntityOrigin(entity, origin2);

		if (GetVectorDistance(origin, origin2) <= 1000.0) {
			SDKHooks_TakeDamage(entity, 0, client, 999.0);
		}
	}

	SendPrint(client, "The Infected nearby have been cleared.");

	return Plugin_Handled;
}

public Action Command_ForcePanic(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	L4D_ForcePanicEvent();

	SendPrint(client, "You have forced a panic event.");

	return Plugin_Handled;
}

public Action Command_LedgeGrab(int client, int args) {
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		SendPrint(client, "You must specify a target to set ledge grab on.");
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

	char sStatus[MAX_TARGET_LENGTH];
	GetCmdArg(2, sStatus, sizeof(sStatus));

	bool status = StringToBool(sStatus);

	for (int i = 0; i < targets; i++) {
		AcceptEntityInput(targets_list[i], status ? "EnableLedgeHang" : "DisableLedgeHang");
		SendPrint(targets_list[i], "Your ledge grab ability has been turned [H]%s [D]by [H]%N [D].", (status ? "ON" : "OFF"), client);
	}
	
	if (tn_is_ml) {
		SendPrint(client, "You have set the ledge grab ability on [H]%t [D]to [H]%s[D].", sTargetName, (status ? "ON" : "OFF"));
	} else {
		SendPrint(client, "You have set the ledge grab ability on [H]%s [D]to [H]%s[D].", sTargetName, (status ? "ON" : "OFF"));
	}

	return Plugin_Handled;
}