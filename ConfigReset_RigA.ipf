#pragma TextEncoding = "Windows-1252"

#pragma rtGlobals=3		// Use modern global access method and strict wave access.



Function Go()
	//***********VARIABLES TO MODIFY TO EACH RIG
	
	Variable numHeadStages = 4 //NEED TO CHANGE
	Make/O ampSequence = {1, 2, 3, 4} //hardwired amp connections, need to change for each rig
	String ampsList = "831400; 837041" //Serial numbers of connected amps w/o leading zeroes 
	
	//***********VARIABLES TO MODIFY TO EACH RIG
	
	
	//FIRST RESET ALL MC VALUES
	print "Starting..."
	

	AI_OpenMCCs(ampsList, maxAttempts = 10)
	MCC_FindServers
	
	Variable channelIDCol = 3
	Variable MCCol = 0

	Variable j //counter variable
	Wave W_MultiClamps 
	
	for(j=0; j < numHeadStages; j += 1 )
		MCC_FindServers
		Variable tempChannel = W_MultiClamps[j][channelIDCol]
		MCC_SelectMultiClamp700B(GetDimLabel(W_MultiClamps, 0, j), tempChannel)
	
		MCC_SetMode(0)//voltage clamp commands
		MCC_SetHolding(0)
		MCC_SetHoldingEnable(0)
		MCC_SetFastCompCap(0)
		MCC_SetSlowCompCap(0)
	
		MCC_SetMode(1) //current clamp commands
		MCC_SetHolding(0)
		MCC_SetHoldingEnable(0)
	
		MCC_SetBridgeBalEnable(0)
		MCC_SetBridgeBalResist(0)
	
		MCC_SetNeutralizationEnable(0)
		MCC_SetNeutralizationCap(0)
		MCC_SetSlowCurrentInjEnable(0)
	
		MCC_SetPrimarySignalGain(1) //gain to 1
	
		MCC_SetMode(0) // set back to V clamp to start
	endfor


	DAP_CreateDAEphysPanel() //open DA_Ephys
	string preDevicePanel = GetMainWindow(GetCurrentWindow())
	

	
	//hardware: select, open, lock device

	variable devNum = WhichListItem("ITC18USB",DEVICE_TYPES) //finds device ITC18USB
	PGC_setAndActivateControl(preDevicePanel, "popup_MoreSettings_DeviceType", val=devNum) //selects device
	
	PGC_setAndActivateControl(preDevicePanel, "button_SettingsPlus_LockDevice") //Locks selected device

	
	//query connected amps, assign, autofill

	variable i
	AI_FindConnectedAmps()
	
	string panelTitle = GetMainWindow(GetCurrentWindow())
	
	for(i = 0; i<j; i+=1)	
		PGC_setAndActivateControl(panelTitle, "Popup_Settings_HeadStage", val = i) 
		PGC_setAndActivateControl(panelTitle, "Popup_Settings_Amplifier", val = ampSequence[i])
	endfor 
	
	variable numConnAmplifiers = AI_QueryGainsFromMCC(panelTitle)
	
	print(numConnAmplifiers)
				
	PGC_setAndActivateControl(panelTitle, "button_Hardware_AutoGainAndUnit")
	PGC_setAndActivateControl(panelTitle, "Check_DataAcq_Get_Set_ITI",val=1) 

	PGC_setAndActivateControl(panelTitle, "Check_AD_06",val=1)
	PGC_setAndActivateControl(panelTitle, "Gain_AD_06",val=1)
	
	for(i = 0; i<numHeadStages; i+=1)

		PGC_setAndActivateControl(panelTitle, "slider_DataAcq_ActiveHeadstage",val=i)
		PGC_setAndActivateControl(panelTitle, "SetVar_DataAcq_Hold_VC",val=-70)
		PGC_setAndActivateControl(panelTitle, "check_DatAcq_HoldEnableVC",val=0)
	
		PGC_setAndActivateControl(panelTitle, "SetVar_DataAcq_Hold_IC",val=0)
		PGC_setAndActivateControl(panelTitle, "check_DatAcq_HoldEnable",val=0)
	
		PGC_setAndActivateControl(panelTitle, "SetVar_DataAcq_BB",val=0)
		PGC_setAndActivateControl(panelTitle, "SetVar_DataAcq_CN",val=0)
		PGC_setAndActivateControl(panelTitle, "check_DatAcq_CNEnable",val=0)
	
		PGC_setAndActivateControl(panelTitle, "SetVar_DataAcq_AutoBiasV",val=-70)
		PGC_setAndActivateControl(panelTitle, "SetVar_DataAcq_AutoBiasVrange",val=1)
		PGC_setAndActivateControl(panelTitle, "setvar_DataAcq_IbiasMax",val=200)
		PGC_setAndActivateControl(panelTitle, "check_DataAcq_AutoBias",val=0)
	endfor
	PGC_setAndActivateControl(panelTitle, "slider_DataAcq_ActiveHeadstage",val=0)
	
	
	// Unit_AD_06
	
//load stim set

	//HD_LoadAdditionalStimSet()  //TH comment out
	//ChangeTab(panelTitle, "ADC", 0)
	PGC_setAndActivateControl(panelTitle, "Check_DataAcqHS_00",val=1)
	PGC_setAndActivateControl(panelTitle, "StartTestPulseButton")
	
	PGC_setandActivateControl(panelTitle, "Check_settings_TPAfterDAQ", val=1)
	PGC_setandActivateControl(panelTitle, "check_Settings_TP_SaveTPRecord", val=1) //TH add
	PGC_setandActivateControl(panelTitle, "SetVar_DataAcq_TPDuration", val=10) //TH add
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq_Get_Set_ITI", val=0) 
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "setvar_DataAcq_OnsetDelayUser", val=20)
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "SetVar_DataAcq_ITI", val=10)  
	PGC_setandActivateControl(panelTitle, "Check_Settings_Append", val=1)
	PGC_setandActivateControl(panelTitle, "Unit_AsyncAD_07", str="C")
	PGC_setandActivateControl(panelTitle, "Title_AsyncAD_07", str="temperature")
	PGC_setandActivateControl(panelTitle, "Gain_AsyncAD_07", val=0.1)
	PGC_setandActivateControl(panelTitle, "Check_AsyncAD_07", val=1)
	NWB_LoadAllStimsets(fileName="C:Travis MIES:stimsets_0228.nwb") //TH add
	
	//NWB_LoadAllStimsets(fileName="C:Travis MIES:old Igor pxps:1P_stim_wPWM_2.nwb")
	Exp_con_gui() //TH add
	make_opto_folder()
	print "Done!"
	print "Set up Prairie Save folder and confirm appropriate objective setting and galvo calibration!"
	print "   ...or else"
	print "Run script and set Zseries to 'test'"
End


Function Reset4()
	Variable channelIDCol = 3
	Variable MCCol = 0
	
	
	//NEED TO CHANGE
	Variable numHeadStages = 2
	
	
	Variable i //counter variable
	Wave W_MultiClamps 



for(i = 0; i<numHeadStages; i+=1)
	string panelTitle = GetMainWindow(GetCurrentWindow())
	String tempStr
	sprintf tempStr, "Radio_ClampMode_%d", i*2
	PGC_setAndActivateControl(panelTitle, tempStr, val=0)
	PGC_setAndActivateControl(panelTitle, "slider_DataAcq_ActiveHeadstage",val=i)
	PGC_setAndActivateControl(panelTitle, "SetVar_DataAcq_Hold_VC",val=-70)
	PGC_setAndActivateControl(panelTitle, "check_DatAcq_HoldEnableVC",val=0)
	
	PGC_setAndActivateControl(panelTitle, "SetVar_DataAcq_Hold_IC",val=0)
	PGC_setAndActivateControl(panelTitle, "check_DatAcq_HoldEnable",val=0)
	
	PGC_setAndActivateControl(panelTitle, "SetVar_DataAcq_BB",val=0)
	PGC_setAndActivateControl(panelTitle, "SetVar_DataAcq_CN",val=0)
	PGC_setAndActivateControl(panelTitle, "check_DatAcq_CNEnable",val=0)
	
	PGC_setAndActivateControl(panelTitle, "SetVar_DataAcq_AutoBiasV",val=-70)
	PGC_setAndActivateControl(panelTitle, "SetVar_DataAcq_AutoBiasVrange",val=1)
	PGC_setAndActivateControl(panelTitle, "setvar_DataAcq_IbiasMax",val=200)
	PGC_setAndActivateControl(panelTitle, "check_DataAcq_AutoBias",val=0)
	
	MCC_FindServers
	Variable tempChannel = W_MultiClamps[i][channelIDCol]
	MCC_SelectMultiClamp700B(GetDimLabel(W_MultiClamps, 0, i), tempChannel)
	
	MCC_SetMode(0)//voltage clamp commands
	MCC_SetHoldingEnable(0)
	MCC_SetFastCompCap(0)
	MCC_SetSlowCompCap(0)
	
	MCC_SetMode(1) //current clamp commands
	MCC_SetHoldingEnable(0)
	
	MCC_SetBridgeBalEnable(0)
	MCC_SetBridgeBalResist(0)
	
	MCC_SetNeutralizationEnable(0)
	MCC_SetNeutralizationCap(0)
	MCC_SetSlowCurrentInjEnable(0)
	
	MCC_SetPrimarySignalGain(1) //gain to 1
	
	MCC_SetMode(0) // set back to V clamp to start
endfor

PGC_setAndActivateControl(panelTitle, "slider_DataAcq_ActiveHeadstage",val=0)
PGC_setAndActivateControl(panelTitle, "SetVar_Sweep",val=0)
//ChangeTab(panelTitle, "ADC", 0)
PGC_setAndActivateControl(panelTitle, "Check_DataAcqHS_00",val=1)
PGC_setAndActivateControl(panelTitle, "StartTestPulseButton")
print "Ready!"
End  



Function SaveIt()
	
	string user
	string userList = "AB;CB;LH;TH;guest"
	variable experiment_number
	Prompt user "Select user", popup userList
	Prompt experiment_number "experiment number:"
	DoPrompt "Set experiment ID", user, experiment_number
	
	string dateString=getTimeStamp()[0,10]
	string full_name=dateString+"exp"+num2str(experiment_number)+"_"+user+".pxp"
	if (cmpstr(user,"TH")==0)
		NewPath/o/C savePath, "C:Travis MIES:"+datestring[0,9]
	elseif (cmpstr(user,"LH")==0)
		print "hi Lawrence"
		NewPath/o/C savePath, "C:Lawrence:"+datestring[0,9]
	else
		print "you have no home here"
		NewPath/o/C savePath "C:"+datestring[0,9]
	endif
	
	SaveExperimentWrapper("savePath",full_name)
	NWB_ExportWithDialog(NWB_EXPORT_DATA)
	DFREF saveDFR = GetDataFolderDFR()		// Save
	
	SetDataFolder "root:opto_df"
	wave t_start, reps, roi
	Edit T_start, reps, roi
	SaveTableCopy/T=2/O/P=savePath as dateString+"exp"+num2str(experiment_number)+"_"+user+"mapInfo.csv"
	SaveExperiment
	SetDataFolder saveDFR
end