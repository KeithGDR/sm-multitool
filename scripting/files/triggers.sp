public Action Command_CreateTrigger(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	if (client == 0 || !IsPlayerAlive(client) || g_Trigger[client].editing != 0)
		return Plugin_Handled;
	
	g_Trigger[client].Clear();

	float origin[3];
	GetClientAbsOrigin(client, origin);

	g_Trigger[client].SetOrigin(origin);
	
	OpenCreateTriggerMenu(client);

	return Plugin_Handled;
}

void OpenCreateTriggerMenu(int client)
{
	Menu menu = new Menu(MenuHandler_CreateTrigger);
	menu.SetTitle("Create a trigger entity:");

	char sDisplay[256];

	FormatEx(sDisplay, sizeof(sDisplay), "Name: %s", g_Trigger[client].name);
	menu.AddItem("name", sDisplay);

	FormatEx(sDisplay, sizeof(sDisplay), "Origin: %.0f/%.0f/%.0f", g_Trigger[client].origin[0], g_Trigger[client].origin[1], g_Trigger[client].origin[2]);
	menu.AddItem("origin", sDisplay);

	FormatEx(sDisplay, sizeof(sDisplay), "Minbounds: %.0f/%.0f/%.0f", g_Trigger[client].minbounds[0], g_Trigger[client].minbounds[1], g_Trigger[client].minbounds[2]);
	menu.AddItem("minbounds", sDisplay);

	FormatEx(sDisplay, sizeof(sDisplay), "Maxbounds: %.0f/%.0f/%.0f", g_Trigger[client].minbounds[0], g_Trigger[client].minbounds[1], g_Trigger[client].minbounds[2]);
	menu.AddItem("maxbounds", sDisplay);

	menu.AddItem("create", "Create Zone");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_CreateTrigger(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "name"))
			{
				PrintToChat(param1, "Please type in chat the name of this trigger:");
				g_Trigger[param1].editing = EDITING_NAME;
			}
			else if (StrEqual(sInfo, "origin"))
			{
				float origin[3];
				GetClientAbsOrigin(param1, origin);

				g_Trigger[param1].SetOrigin(origin);

				OpenCreateTriggerMenu(param1);
			}
			else if (StrEqual(sInfo, "minbounds"))
			{
				PrintToChat(param1, "Please type in chat the minimum bounds of this trigger:");
				g_Trigger[param1].editing = EDITING_MIN;
			}
			else if (StrEqual(sInfo, "maxbounds"))
			{
				PrintToChat(param1, "Please type in chat the maximum bounds of this trigger:");
				g_Trigger[param1].editing = EDITING_MAX;
			}
			else if (StrEqual(sInfo, "create"))
			{
				if (strlen(g_Trigger[param1].name) == 0)
				{
					PrintToChat(param1, "You must specify a name in order to create a zone.");
					OpenCreateTriggerMenu(param1);
					return 0;
				}

				int entity = g_Trigger[param1].Create();

				if (IsValidEntity(entity))
				{
					DrawTrigger(entity, param1);
					g_Triggers.Push(EntIndexToEntRef(entity));
				}
				
				PrintToChat(param1, "Trigger '%s' has been created successfully.", g_Trigger[param1].name);
				g_Trigger[param1].Clear();
			}
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void DrawTrigger(int entity, int client = 0, float time = 99999.0)
{
	char sClassname[32];
	GetEntityClassname(entity, sClassname, sizeof(sClassname));

	if (StrContains(sClassname, "trigger_", false) != 0)
		return;
	
	float posMin[4][3];
	GetEntPropVector(entity, Prop_Send, "m_vecMins", posMin[0]);

	float posMax[4][3];
	GetEntPropVector(entity, Prop_Send, "m_vecMaxs", posMax[0]);

	posMin[1][0] = posMax[0][0];
	posMin[1][1] = posMin[0][1];
	posMin[1][2] = posMin[0][2];
	posMax[1][0] = posMin[0][0];
	posMax[1][1] = posMax[0][1];
	posMax[1][2] = posMax[0][2];
	posMin[2][0] = posMin[0][0];
	posMin[2][1] = posMax[0][1];
	posMin[2][2] = posMin[0][2];
	posMax[2][0] = posMax[0][0];
	posMax[2][1] = posMin[0][1];
	posMax[2][2] = posMax[0][2];
	posMin[3][0] = posMax[0][0];
	posMin[3][1] = posMax[0][1];
	posMin[3][2] = posMin[0][2];
	posMax[3][0] = posMin[0][0];
	posMax[3][1] = posMin[0][1];
	posMax[3][2] = posMax[0][2];

	float orig[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", orig);

	AddVectors(posMin[0], orig, posMin[0]);
	AddVectors(posMax[0], orig, posMax[0]);
	AddVectors(posMin[1], orig, posMin[1]);
	AddVectors(posMax[1], orig, posMax[1]);
	AddVectors(posMin[2], orig, posMin[2]);
	AddVectors(posMax[2], orig, posMax[2]);
	AddVectors(posMin[3], orig, posMin[3]);
	AddVectors(posMax[3], orig, posMax[3]);

	/////////
	//UP & DOWN

	//BORDER
	DrawLine(posMin[0], posMax[3], client, time);
	DrawLine(posMin[1], posMax[2], client, time);
	DrawLine(posMin[3], posMax[0], client, time);
	DrawLine(posMin[2], posMax[1], client, time);
	//CROSS
	DrawLine(posMin[3], posMax[2], client, time);
	DrawLine(posMin[1], posMax[0], client, time);
	DrawLine(posMin[2], posMax[3], client, time);
	DrawLine(posMin[3], posMax[1], client, time);
	DrawLine(posMin[2], posMax[0], client, time);
	DrawLine(posMin[0], posMax[1], client, time);
	DrawLine(posMin[0], posMax[2], client, time);
	DrawLine(posMin[1], posMax[3], client, time);

	/////////
	//TOP

	//BORDER
	DrawLine(posMax[0], posMax[1], client, time);
	DrawLine(posMax[1], posMax[3], client, time);
	DrawLine(posMax[3], posMax[2], client, time);
	DrawLine(posMax[2], posMax[0], client, time);
	//CROSS
	DrawLine(posMax[0], posMax[3], client, time);
	DrawLine(posMax[2], posMax[1], client, time);

	/////////
	//BOTTOM

	//BORDER
	DrawLine(posMin[0], posMin[1], client, time);
	DrawLine(posMin[1], posMin[3], client, time);
	DrawLine(posMin[3], posMin[2], client, time);
	DrawLine(posMin[2], posMin[0], client, time);
	//CROSS
	DrawLine(posMin[0], posMin[3], client, time);
	DrawLine(posMin[2], posMin[1], client, time);
}

void DrawLine(float start[3], float end[3], int client = 0, float time = 10.0)
{
	TE_SetupBeamPoints(start, end, g_Laser, 0, 0, 0, time, 3.0, 3.0, 7, 0.0, {150, 255, 150, 255}, 0);

	if (client)
		TE_SendToClient(client);
	else
		TE_SendToAll();
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (g_Trigger[client].editing != 0)
	{
		char sOutput[64];
		strcopy(sOutput, sizeof(sOutput), sArgs);

		TrimString(sOutput);

		switch (g_Trigger[client].editing)
		{
			case EDITING_NAME:
				strcopy(g_Trigger[client].name, sizeof(Trigger::name), sOutput);

			case EDITING_MIN:
			{
				char sPart[3][16];
				int parts = ExplodeString(sOutput, " ", sPart, 3, 16);

				float vec[3];
				for (int i = 0; i < parts; i++)
					vec[i] = StringToFloat(sPart[i]);
				
				g_Trigger[client].SetMin(vec);
			}

			case EDITING_MAX:
			{
				char sPart[3][16];
				int parts = ExplodeString(sOutput, " ", sPart, 3, 16);

				float vec[3];
				for (int i = 0; i < parts; i++)
					vec[i] = StringToFloat(sPart[i]);
				
				g_Trigger[client].SetMax(vec);
			}
		}

		g_Trigger[client].editing = 0;
		OpenCreateTriggerMenu(client);
	}
}

public void OnGameFrame()
{
	int entity = -1;
	for (int i = 0; i < g_Triggers.Length; i++)
	{
		if ((entity = EntRefToEntIndex(g_Triggers.Get(i))) == -1)
		{
			g_Triggers.Erase(i);
			continue;
		}

		for (int client = 1; client <= MaxClients; client++)
			if (IsClientInGame(client) && !IsFakeClient(client))
				DrawTrigger(entity, client, 0.3);
	}
}

public Action Command_DeleteTriggers(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}
	
	int length = g_Triggers.Length;

	if (length < 1)
	{
		ReplyToCommand(client, "There's no spawned triggers owned by the plugin currently to delete.");
		return Plugin_Handled;
	}

	int entity = -1;
	for (int i = 0; i < length; i++)
		if ((entity = EntRefToEntIndex(g_Triggers.Get(i))) != -1)
			AcceptEntityInputSafe(entity, "Kill");
	
	g_Triggers.Clear();
	ReplyToCommand(client, "All triggers owned by the plugin have been deleted.");

	return Plugin_Handled;
}