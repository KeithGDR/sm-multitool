public Action Command_StartTimer(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}

	g_TimerVal[client] = 0.0;
	
	StopTimer(g_Timer[client]);
	g_Timer[client] = CreateTimer(1.0, Timer_Start, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Handled;
}

public Action Command_Stoptimer(int client, int args)
{
	if (!IsEnabled()) {
		return Plugin_Continue;
	}
	
	StopTimer(g_Timer[client]);
	g_TimerVal[client] = 0.0;
	return Plugin_Handled;
}