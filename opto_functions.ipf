#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include <Waves Average>



Function getNextSweep() //return next sweep to be associated with photostim
	controlinfo/W=ITC18USB_Dev_0 setvar_sweep
	variable nextsweep=v_value
	return nextsweep
end

Function isDAQhappening() //return 0 if acquisition is not taking place
	NVAR runmode = $GetDataAcqRunMode("ITC18USB_Dev_0")
	return runmode
end


Function startDAQ()
	variable runmode=isDAQhappening()
	if (runmode==0)
		PGC_SetAndActivateControl("ITC18USB_Dev_0","DataAcquireButton")
		return 1
	else
		print "DAQ already running, sweep not started"
		return 0
	endif
end

Function run_mapping_sweep_short(stimpoint_id, stim_num)
	variable stimPoint_ID, stim_num
	startDAQ()
end


Function run_mapping_sweep(stimPoint_ID, stim_num)
	variable stimPoint_ID, stim_num
	wave mapInfo_wv=root:opto_df:mapInfo
	wave sP_ID_wv=root:opto_df:photoStim_ID
	wave stim_num_wv=root:opto_df:stim_num
	wave round_count=root:opto_df:round_count
	variable round_num=round_count[0]
	variable LastSweep = AFH_GetLastSweepAcquired("ITC18USB_Dev_0")
	
	
	controlinfo/W=ITC18USB_Dev_0 setvar_sweep
	
	variable sweep_num=v_value
	
	startDAQ()
	string dim_name="sweep_"+num2str(sweep_num)
	variable dimLabel=FindDimLabel(mapInfo_wv,0,dim_name)
	if(dimLabel==-2) //if there's not a row for this sweep yet - could be cleaned up when other variables are settled on
		InsertPoints/M=0 0, 1, mapInfo_wv
		SetDimLabel 0, 0, $dim_name, mapInfo_wv
		dimLabel=0
	endif
	
	mapInfo_wv[dimLabel][0]=sweep_num
	mapInfo_wv[dimLabel][1]=stimPoint_ID
	mapInfo_wv[dimLabel][2]=stim_num
	mapInfo_wv[dimLabel][6]=round_num
	sp_ID_wv[8]=stimPoint_ID
	stim_num_wv[8]=stim_num
	pockel_times_for_sweep(LastSweep)

end

Function mapping_prep(duration, stimPoints, reps) //get ready for mapping experiment
	variable duration, stimPoints, reps
	wave round_count=root:opto_df:round_count
	round_count+=1	
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq_Indexing", val=0) //no indexing
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq1_DistribDaq", val=0) //no distribution
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_Settings_InsertTP", val=0) //no test pulse
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_01", val=0) //turn off ttl outputs to LED's
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_02", val=0)
	string all_TTLs=ReturnListofAllStimSets(CHANNEL_TYPE_TTL,"*TTL*")
	variable TTL_num=whichListItem("mappingShort_TTL_0", all_TTLs)+1 // +1 due to 'none'
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Wave_TTL_00", val=TTL_num) //select 'connmapping_ttl' as stim.
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_00", val=1)
	variable i
	string all_dacs = ReturnListofAllStimSets(0,"*DA*")
	variable stim_set_num
	if (duration<=0.5)
		stim_set_num = whichListItem("mapping_500ms_DA_0", all_dacs)+1 //+1 to comp for 'none'
	elseif (duration<=1)
		stim_set_num = whichListItem("mapping_1s_DA_0", all_dacs)+1 
	elseif (duration<=2)
		stim_set_num = whichListItem("mapping_2s_DA_0", all_dacs)+1
	elseif (duration<=5)
		stim_set_num = whichListItem("mapping_5s_DA_0", all_dacs)+1
	else
		stim_set_num = whichListItem("mapping_10s_DA_0", all_dacs)+1 
	endif
	 
	variable count_headstages=0
	for (i=0;i<=3;i+=1) //for each headstage
		string CB_name = "Check_DA_0"+num2str(i)
		controlinfo/W=ITC18USB_Dev_0 $CB_name
		variable DA_check = V_Value
		if (DA_check == 1) //if it's in use, update the protocol
			string first_da_drop = "Wave_DA_0"+num2str(i)
			PGC_setandactivatecontrol("ITC18USB_Dev_0", first_da_drop, val=stim_set_num)
			count_headstages+=1
		endif
	endfor
	
	if (count_headstages==1) //set sampling rate to avoid filling memory
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=2) //if only one headstage record at 25 kHz (interval = 4)
	elseif(count_headstages==4)
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=0) //if all 4 active, don't downsample (already 25 Khz)
	else
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=1) //sample multiplier = 2		
	endif
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "SetVar_DataAcq_SetRepeats", val=1)
	PGC_setAndActivateControl("ITC18USB_Dev_0", "Check_AD_06",val=1)
	PGC_setAndActivateControl("ITC18USB_Dev_0", "check_DataAcq_AutoBias", val=1)
	controlinfo/W=ITC18USB_Dev_0 setvar_sweep
	variable nextsweep=v_value
	print "mapping started at sweep "+num2str(nextsweep)+". "+num2str(stimPoints)+" stim IDs for "+num2str(reps)+". Over at sweep "+num2str(nextsweep+stimPoints*reps)+"."
	write_map_settings(nextsweep, stimPoints, reps, 0)
	make_photoStim_graph()
end




Function makeStimPointWave(stim_id, start, reps, interval) //make a wave containing each sweep # associated with a StimPoint
	string stim_id
	variable start, reps, interval
	DFREF saveDFR = GetDataFolderDFR()		// Save
	SetDataFolder root:opto_df
	string PS_wave_name="PhotoStimulation_"+stim_id
	Make/o/n=(reps) $PS_wave_name
	wave PS_wave=$PS_wave_name
	PS_wave=start+x*interval
	SetDataFolder saveDFR
	
end


Function appendStimPointWave(stim_id,start,reps,interval)
	string stim_id
	variable start, reps, interval
	variable i
	DFREF saveDFR = GetDataFolderDFR()		// Save
	SetDataFolder root:opto_df
	string PS_wave_name="PhotoStimulation_"+stim_id
	wave PS_wave=$PS_wave_name
	variable size=DimSize(PS_wave,0)
	Redimension/N=(size+reps) PS_wave
	for(i=0;i<reps;i+=1)
		PS_wave[size+i]=start+i*interval
	endfor
	SetDataFolder saveDFR
	
end


Function my_function(paneltitle, s)
	string paneltitle
	STRUCT AnalysisFunction_V3 &s
	
	switch(s.eventType)
		case PRE_DAQ_EVENT:
			print "this pre-daq!"
			
		case PRE_SET_EVENT:
			print "now it's pre-set-event?"

			break
		case POST_SWEEP_EVENT:
			print "sweep is over"

			break
		case POST_SET_EVENT:
			print "set is over"
			break
	endswitch
	
	//print "I am a function"
end



//////EXPERIMENT CONTROL GUI AND FUNCTIONS HERE///////
Function Exp_con_gui()
	if (wintype("experiment_control") == 0)
		newpanel/W=(1750,50,1950,700)/n=experiment_control
		Button button_intrinsic, pos={10,10}, fsize = 20, title = "Intrinsic", proc=ButtonProc_Intrinsic, size={100,100}
		Button button_extra, pos={120,10}, title="more steps", fsize=14, size={75,35}, proc=ButtonProc_bigsteps
		Button button_multi, title="multi check", fsize=14, size={100,100}, pos={10,120}, proc=ButtonProc_multi
		Button button_mapping, pos={10,230}, fsize = 20, title = "Mapping", proc=ButtonProc_Mapping, size={100,100}
		Button button_1P, pos={10, 340}, fsize = 20, title = "1P", proc=ButtonProc_1P, size={100,100}
		Button button_save, pos={10,510}, fsize=14, title = "save & export", proc=ButtonProc_save, size={100,50}
		Button button_TPcheck, pos={10,450}, fsize=14, title="TP check", proc=ButtonProc_testP, size={100,50}
		SetVariable setvarInterval, pos={150,235}, title="# cells", bodyWidth=45, value= _NUM:10
		SetVariable setvarReps, pos={150,265}, title="# reps", bodyWidth=45, value= _NUM:10, limits={1,1000,5}
		Button button_Append, title="append", fsize=14, pos={120, 290}, size={75, 35}, proc=ButtonProc_Append
		Checkbox checkTTL1, title="LED 1", value=0, pos={120, 380}
		Checkbox checkTTL2, title="LED 2", value=1, pos={120, 400}
	endif
	
	
end


Function ButtonProc_save(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
        	NVAR runmode = $GetDataAcqRunMode("ITC18USB_Dev_0")
        	
        	if (runmode!=0)
        		print "Data is being acquired. I'm not doing anything for your own good."
        		break
        	else
				saveit()
				break
			endif
	case -1: // control being killed
            break
    endswitch

    return 0
End	

Function ButtonProc_Intrinsic(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
        	NVAR runmode = $GetDataAcqRunMode("ITC18USB_Dev_0")
        	
        	if (runmode!=0)
        		print "Data is being acquired. I'm not doing anything for your own good."
        		break
        	else
				intrinsic()
				break
			endif
	case -1: // control being killed
            break
    endswitch

    return 0
End	


Function ButtonProc_bigsteps(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
        	NVAR runmode = $GetDataAcqRunMode("ITC18USB_Dev_0")
        	
        	if (runmode!=0)
        		print "Data is being acquired. I'm not doing anything for your own good."
        		break
        	else
				bigsteps()
				break
			endif
	case -1: // control being killed
            break
    endswitch

    return 0
End	


Function ButtonProc_multi(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
        	NVAR runmode = $GetDataAcqRunMode("ITC18USB_Dev_0")
        	
        	if (runmode!=0)
        		print "Data is being acquired. I'm not doing anything for your own good."
        		break
        	else
				paircheck()
				break
			endif
	case -1: // control being killed
            break
    endswitch

    return 0
End	

Function ButtonProc_Mapping(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
    	case 2: // mouse up
    	   NVAR runmode = $GetDataAcqRunMode("ITC18USB_Dev_0")
        	
        	if (runmode!=0)
        		print "Data is being acquired. I'm not doing anything for your own good."
        		break
        	else
				controlinfo/W=experiment_control setvarInterval
				variable param0=v_value
				controlinfo/W=experiment_control setvarReps
				variable param1=v_value
				//mapping(cells=param0,reps=param1)
				mapping_short(param0,param1,0)
				break
			endif

	case -1: // control being killed
            break
    endswitch

    return 0
End	
	

Function ButtonProc_append(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
    	case 2: // mouse up
    	   NVAR runmode = $GetDataAcqRunMode("ITC18USB_Dev_0")
        	
        	if (runmode!=0)
        		print "Data is being acquired. I'm not doing anything for your own good."
        		break
        	else
				controlinfo/W=experiment_control setvarInterval
				variable param0=v_value
				controlinfo/W=experiment_control setvarReps
				variable param1=v_value
				//mapping(cells=param0,reps=param1)
				mapping_short(param0,param1, 1)
				break
			endif

	case -1: // control being killed
            break
    endswitch

    return 0
End	

	
Function ButtonProc_1P(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
        NVAR runmode = $GetDataAcqRunMode("ITC18USB_Dev_0")
        	
        	if (runmode!=0)
        		print "Data is being acquired. I'm not doing anything for your own good."
        		break
        	else
				controlinfo/W=experiment_control checkTTL1
				variable param1=v_value
				controlinfo/W=experiment_control checkTTL2
				variable param2=v_value
				oneP(param1, param2)
				break
			endif


	case -1: // control being killed
            break
    endswitch

    return 0
End	


Function ButtonProc_testP(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
        NVAR runmode = $GetDataAcqRunMode("ITC18USB_Dev_0")
        	
        	if (runmode!=0)
        		print "Data is being acquired. I'm not doing anything for your own good."
        		break
        	else
				tp_check()
				break
			endif


	case -1: // control being killed
            break
    endswitch

    return 0
End	

Function pairCheck()
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq_Indexing", val=0) //indexing to run multiple stim
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq1_DistribDaq", val=1) //distribute 
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq_Get_Set_ITI", val=0) //don;t use ITI's from protocols
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "SetVar_DataAcq_ITI", val=10)
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_00", val=0) //turn off the lights
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_01", val=0)
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_02", val=0)
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "SetVar_DataAcq_SetRepeats", val=10)
	variable i
	string all_dacs = ReturnListofAllStimSets(0,"*DA*")
	variable stim_set_num = whichListItem("pulsetrain_50hz_DA_0", all_dacs)+1 //+1 to comp for 'none'
	variable count_headstages=0
	for (i=0;i<=3;i+=1) //for each headstage
		string CB_name = "Check_DA_0"+num2str(i)
		controlinfo/W=ITC18USB_Dev_0 $CB_name
		variable DA_check = V_Value
		if (DA_check == 1) //if it's in use, update the protocol
			string first_da_drop = "Wave_DA_0"+num2str(i)
			PGC_setandactivatecontrol("ITC18USB_Dev_0", first_da_drop, val=stim_set_num)
			count_headstages+=1
		endif
	endfor
	
	if (count_headstages==1) //set sampling rate to avoid filling memory
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=2) //if only one headstage record at 25 kHz (interval = 4)
	elseif(count_headstages==4)
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=0) //if all 4 active, don't downsample (already 25 Khz)
	else
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=1) //sample multiplier = 2		
		
	endif
	PGC_setAndActivateControl("ITC18USB_Dev_0", "Check_AD_06",val=0)
	PGC_setAndActivateControl("ITC18USB_Dev_0", "check_DataAcq_AutoBias", val=1)

end	

Function bigsteps()
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq_Indexing", val=0) //indexing to run multiple stim
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq1_DistribDaq", val=1) //distribute in case there are synapses
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq_Get_Set_ITI", val=1) //use ITI's from protocols
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_00", val=0) //turn off the lights
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_01", val=0)
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_02", val=0)
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "SetVar_DataAcq_SetRepeats", val=1)
	
	variable i
	string all_dacs = ReturnListofAllStimSets(0,"*DA*")
	variable stim_set_num = whichListItem("big_steps_DA_0", all_dacs)+1 //+1 to comp for 'none'
	variable count_headstages=0
	for (i=0;i<=3;i+=1) //for each headstage
		string CB_name = "Check_DA_0"+num2str(i)
		controlinfo/W=ITC18USB_Dev_0 $CB_name
		variable DA_check = V_Value
		if (DA_check == 1) //if it's in use, update the protocol
			string first_da_drop = "Wave_DA_0"+num2str(i)
			PGC_setandactivatecontrol("ITC18USB_Dev_0", first_da_drop, val=stim_set_num)
			count_headstages+=1
		endif
	endfor
	
	if (count_headstages==1) //set sampling rate to avoid filling memory
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=2) //if only one headstage record at 25 kHz (interval = 4)
	elseif(count_headstages==4)
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=0) //if all 4 active, don't downsample (already 25 Khz)
	else
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=1) //sample multiplier = 2		
		
	endif
	PGC_setAndActivateControl("ITC18USB_Dev_0", "Check_AD_06",val=0)
	PGC_setAndActivateControl("ITC18USB_Dev_0", "check_DataAcq_AutoBias", val=1)
	
end



Function intrinsic()
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq_Indexing", val=1) //indexing to run multiple stim
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq1_DistribDaq", val=1) //distribute in case there are synapses
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq_Get_Set_ITI", val=1) //use ITI's from protocols
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_00", val=0) //turn off the lights
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_01", val=0)
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_02", val=0)
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "SetVar_DataAcq_SetRepeats", val=1)
	
	string intrins_list = ReturnListofAllStimSets(CHANNEL_TYPE_DAC,"*intrins*") //find all intrinsic protocols and corresponding #'s in popups
	string all_dacs = ReturnListofAllStimSets(0,"*DA*") 
	string first_intrins = stringfromlist(0,intrins_list)
	string last_intrins = stringfromlist(itemsinlist(intrins_list, ";")-1, intrins_list)
	variable first_num=whichListItem(first_intrins,all_dacs)+1 //+1 to compensate for "none" in popup
	variable last_num=whichListItem(last_intrins,all_dacs)+1
	variable i
	variable count_headstages=0
	for (i=0;i<=3;i+=1) //for each headstage
		string CB_name = "Check_DA_0"+num2str(i)
		controlinfo/W=ITC18USB_Dev_0 $CB_name
		variable DA_check = V_Value
		if (DA_check == 1) //if it's in use, update the protocol
			string first_da_drop = "Wave_DA_0"+num2str(i)
			string last_da_drop = "IndexEnd_DA_0"+num2str(i)
			PGC_setandactivatecontrol("ITC18USB_Dev_0", first_da_drop, val=first_num)
			PGC_setandactivatecontrol("ITC18USB_Dev_0", last_da_drop, val=last_num)
			count_headstages+=1
		endif
	endfor
	if (count_headstages==1) //set sampling rate to avoid filling memory
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=2) //if only one headstage record at 25 kHz (interval = 4)
	elseif(count_headstages==4)
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=0) //if all 4 active, don't downsample (already 25 Khz)
	else
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=1) //sample multiplier = 2		
		
	endif
	PGC_setAndActivateControl("ITC18USB_Dev_0", "Check_AD_06",val=0)
	make_stim_monitor()
	Setvariable setvarInterval win=stim_monitor_ops, value= _NUM:1
	Setvariable setvarReps win=stim_monitor_ops, value= _NUM:1
	controlinfo/W=ITC18USB_Dev_0 setvar_sweep
	variable nextsweep=v_value
	SetVariable setvarsweep win=stim_monitor_ops, value=_NUM:nextsweep
	SetVariable setvarMPT win=stim_monitor_ops, value=_NUM:1
	CheckBox checkscale win=stim_monitor_ops, value=1
	Print "Ready to acquire!"
	
	
end





Function mapping([cells, reps, checkAppend])
	variable cells, reps, checkAppend
	variable sweeps = cells*reps
	variable sweep_ITI=(10/cells)
	if (sweep_ITI<2) //inter-trial interval will be set to be at least 2 seconds, or if few cells, set so that 'cell 1' to 'cell 1' is 10 s.
		sweep_ITI=2
	endif
	
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq_Indexing", val=0) //no indexing
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq1_DistribDaq", val=0) //no distribution
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq_Get_Set_ITI", val=0) 
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "SetVar_DataAcq_ITI", val=sweep_ITI)  //ITI = see above
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_Settings_InsertTP", val=0) //no test pulse
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "SetVar_DataAcq_SetRepeats", val=sweeps)
	string all_TTLs=ReturnListofAllStimSets(CHANNEL_TYPE_TTL,"*TTL*")
	variable TTL_num=whichListItem("ConnMapping_TTL_0", all_TTLs)+1 // +1 due to 'none'
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Wave_TTL_00", val=TTL_num) //select 'connmapping_ttl' as stim.
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_00", val=1)
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_01", val=0) //turn off other ttl outputs
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_02", val=0)
	variable i
	string all_dacs = ReturnListofAllStimSets(0,"*DA*")
	variable stim_set_num = whichListItem("ConnMapping_DA_0", all_dacs)+1 //+1 to comp for 'none'
	variable count_headstages=0
	for (i=0;i<=3;i+=1) //for each headstage
		string CB_name = "Check_DA_0"+num2str(i)
		controlinfo/W=ITC18USB_Dev_0 $CB_name
		variable DA_check = V_Value
		if (DA_check == 1) //if it's in use, update the protocol
			string first_da_drop = "Wave_DA_0"+num2str(i)
			PGC_setandactivatecontrol("ITC18USB_Dev_0", first_da_drop, val=stim_set_num)
			count_headstages+=1
		endif
	endfor
	
	if (count_headstages==1) //set sampling rate to avoid filling memory
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=2) //if only one headstage record at 25 kHz (interval = 4)
	elseif(count_headstages==4)
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=0) //if all 4 active, don't downsample (already 25 Khz)
	else
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=1) //sample multiplier = 2		
		
	endif
	PGC_setAndActivateControl("ITC18USB_Dev_0", "Check_AD_06",val=1)
	PGC_setAndActivateControl("ITC18USB_Dev_0", "check_DataAcq_AutoBias", val=1)
	make_stim_monitor()
	Setvariable setvarInterval win=stim_monitor_ops, value= _NUM:cells
	Setvariable setvarReps win=stim_monitor_ops, value= _NUM:reps
	controlinfo/W=ITC18USB_Dev_0 setvar_sweep
	variable nextsweep=v_value
	SetVariable setvarsweep win=stim_monitor_ops, value=_NUM:nextsweep
	SetVariable setvarMPT win=stim_monitor_ops, value=_NUM:1
	CheckBox checkscale win=stim_monitor_ops, value=0

	write_map_settings(nextsweep, cells, reps, checkAppend)
	Print "Ready to acquire!"
end

Function TP_check()
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq_Indexing", val=0) //no indexing
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_Settings_InsertTP", val=1) //test pulse on
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_00", val=0) //turn off the lights
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_01", val=0)
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_02", val=0)
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "SetVar_DataAcq_SetRepeats", val=1)
	
	variable i
	string all_dacs = ReturnListofAllStimSets(0,"*DA*")
	variable stim_set_num = whichListItem("TP_blank_DA_0", all_dacs)+1 //+1 to comp for 'none'
	variable count_headstages=0
	for (i=0;i<=3;i+=1) //for each headstage
		string CB_name = "Check_DA_0"+num2str(i)
		controlinfo/W=ITC18USB_Dev_0 $CB_name
		variable DA_check = V_Value
		if (DA_check == 1) //if it's in use, update the protocol
			string first_da_drop = "Wave_DA_0"+num2str(i)
			PGC_setandactivatecontrol("ITC18USB_Dev_0", first_da_drop, val=stim_set_num)
			PGC_setAndActivateControl("ITC18USB_Dev_0", "SetVar_DataAcq_Hold_VC",val=-70)
			PGC_setAndActivateControl("ITC18USB_Dev_0", "check_DatAcq_HoldEnableVC",val=1)
			
			count_headstages+=1
		endif
	endfor
	setVClampMode()
End


Function mapping_short(cells, reps, checkAppend)
	variable cells, reps, checkAppend
	variable sweeps = cells*reps
	variable sweep_ITI=2
	
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq_Indexing", val=0) //no indexing
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq1_DistribDaq", val=0) //no distribution
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq_Get_Set_ITI", val=0) 
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "SetVar_DataAcq_ITI", val=sweep_ITI)  //ITI = see above
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_Settings_InsertTP", val=0) //no test pulse
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "SetVar_DataAcq_SetRepeats", val=sweeps)
	string all_TTLs=ReturnListofAllStimSets(CHANNEL_TYPE_TTL,"*TTL*")
	variable TTL_num=whichListItem("mappingShort_TTL_0", all_TTLs)+1 // +1 due to 'none'
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Wave_TTL_00", val=TTL_num) //select 'connmapping_ttl' as stim.
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_00", val=1)
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_01", val=0) //turn off other ttl outputs
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_02", val=0)
	variable i
	string all_dacs = ReturnListofAllStimSets(0,"*DA*")
	variable stim_set_num = whichListItem("mappingShort_DA_0", all_dacs)+1 //+1 to comp for 'none'
	variable count_headstages=0
	for (i=0;i<=3;i+=1) //for each headstage
		string CB_name = "Check_DA_0"+num2str(i)
		controlinfo/W=ITC18USB_Dev_0 $CB_name
		variable DA_check = V_Value
		if (DA_check == 1) //if it's in use, update the protocol
			string first_da_drop = "Wave_DA_0"+num2str(i)
			PGC_setandactivatecontrol("ITC18USB_Dev_0", first_da_drop, val=stim_set_num)
			count_headstages+=1
		endif
	endfor
	
	if (count_headstages==1) //set sampling rate to avoid filling memory
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=2) //if only one headstage record at 25 kHz (interval = 4)
	elseif(count_headstages==4)
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=0) //if all 4 active, don't downsample (already 25 Khz)
	else
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=1) //sample multiplier = 2		
		
	endif
	PGC_setAndActivateControl("ITC18USB_Dev_0", "Check_AD_06",val=1)
	PGC_setAndActivateControl("ITC18USB_Dev_0", "check_DataAcq_AutoBias", val=1)
	make_stim_monitor()
	Setvariable setvarInterval win=stim_monitor_ops, value= _NUM:cells
	Setvariable setvarReps win=stim_monitor_ops, value= _NUM:reps
	controlinfo/W=ITC18USB_Dev_0 setvar_sweep
	variable nextsweep=v_value
	SetVariable setvarsweep win=stim_monitor_ops, value=_NUM:nextsweep
	SetVariable setvarMPT win=stim_monitor_ops, value=_NUM:1
	CheckBox checkscale win=stim_monitor_ops, value=0

	write_map_settings(nextsweep, cells, reps, checkAppend)
	Print "Ready to acquire!"
end



Function make_opto_folder()
	if(DataFolderExists("root:opto_df:")==0)
		newdatafolder root:opto_df
	
		make/o/n=0 root:opto_df:T_start
		make/o/n=0 root:opto_df:roi
		make/o/n=0 root:opto_df:reps
		make/o/t/n=0 root:opto_df:cnxs
		make/o/t/n=0 root:opto_df:supps
		make_mapInfo_wave()
		make/o/n=9 root:opto_df:photoStim_ID ={NaN, NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN} //make wave to store photoStim_ID and pass on to labnotebook
		make/o/n=9 root:opto_df:stim_num ={NaN, NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN}
		make/o/n=4 root:opto_df:HS_selection={1,1,1,1,0,0,1} //make wave to store user-selected headstages to display
		make/o/n=1 root:opto_df:round_count
		wave round_count=root:opto_df:round_count
		round_count=0
	endif
end

Function make_mapInfo_wave()
	DFREF saveDFR = GetDataFolderDFR()		// Save
	SetDataFolder root:opto_df
	make/o/N=(1,7)/D mapInfo
		SetDimLabel 1, 0, sweep, mapInfo
		SetDimLabel 1, 1, stimPoint_ID, mapInfo
		SetDimLabel 1, 2, stim_num, mapInfo
		SetDimLabel 1, 3, pockel_start, mapInfo
		SetDimLabel 1, 4, pockel_power, mapInfo
		SetDimLabel 1, 5, sweep_length, mapInfo
		SetDimLabel 1, 6, round_ID, mapinfo
		SetDimLabel 0, 0, sweep_0, mapInfo
	mapInfo=NaN
	SetDataFolder saveDFR
end


Function write_map_settings(first_sweep, cells, num_reps, checkAppend)
	variable first_sweep, cells, num_reps, checkAppend
	DFREF saveDFR = GetDataFolderDFR()		// Save
	
	SetDataFolder root:opto_df
	wave T_start, roi, reps
	variable size=DimSize(T_start,0)
	if(checkAppend==1)
		reps[size-1]=reps[size-1]+num_reps
	
	
	elseif(size!=0)

		variable lastT_Start=T_start[size-1]
		if(lastT_Start==first_sweep) //if there is already mapInfo for this starting sweep, overwrite it. Here to handle user corrections.
			T_start[size-1]=first_sweep
			reps[size-1]=num_reps
			roi[size-1]=cells
		else
			Redimension/N=(size+1) T_start, roi, reps
			T_start[size]=first_sweep
			reps[size]=num_reps
			roi[size]=cells	
			
		endif	
	else
		Redimension/N=(size+1) T_start, roi, reps
		T_start[size]=first_sweep
		reps[size]=num_reps
		roi[size]=cells
	
	endif
	//if(append_check==0)
	//	Redimension/N=(size+1) T_start, roi, reps
	//	T_start[size]=first_sweep
	//	reps[size]=num_reps
	//	roi[size]=cells
	//endif
	SetDataFolder saveDFR
	
end

Function write_cnx(first_sweep,MP_target)
	variable first_sweep, MP_target
	string cnx_note="TSeries_"+num2str(first_sweep)+"_MP_"+num2str(MP_target)
	DFREF saveDFR = GetDataFolderDFR()		// Save
	
	SetDataFolder root:opto_df
	wave/t cnxs
	variable size=DimSize(cnxs,0)
	Redimension/N=(size+1) cnxs
	cnxs[size]=cnx_note
	
end


Function write_supp(first_sweep,MP_target)
	variable first_sweep, MP_target
	string supp_note="TSeries_"+num2str(first_sweep)+"_MP_"+num2str(MP_target)
	DFREF saveDFR = GetDataFolderDFR()		// Save
	
	SetDataFolder root:opto_df
	wave/t supp
	variable size=DimSize(supp,0)
	Redimension/N=(size+1) supp
	supp[size]=supp_note
	
end


Function oneP(TTL1, TTL2)
	variable TTL1, TTL2
	if(TTL1==0 && TTL2==0)
		print "no TTL active"
	endif
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq_Indexing", val=0) //no indexing
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq1_DistribDaq", val=0) //no distribution
	variable i
	string all_dacs = ReturnListofAllStimSets(0,"*DA*")
	string all_TTLs = ReturnListofAllStimSets(CHANNEL_TYPE_TTL,"*TTL*")
	variable stim_set_num = whichListItem("TargetCell_DA_0", all_dacs)+1 //+1 to comp for 'none'
	variable TTL_num=whichListItem("TargetCell_TTL_0", all_TTLs)+1
	//variable TTL_num=whichListItem("PWM_100ms_TTL_0", all_TTLs)+1
	
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_00", val=0)
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "SetVar_DataAcq_SetRepeats", val=1)
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "SetVar_DataAcq_ITI", val=10)
	if(TTL1==1)
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_01", val=1)
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Wave_TTL_01", val=TTL_num)
	else
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_01", val=0)
	endif
	
	if(TTL2==1)
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_02", val=1)
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Wave_TTL_02", val=TTL_num)
	else
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_02", val=0)
	endif
	variable count_headstages=0
	for (i=0;i<=3;i+=1) //for each headstage
		string CB_name = "Check_DA_0"+num2str(i)
		controlinfo/W=ITC18USB_Dev_0 $CB_name
		variable DA_check = V_Value
		
		if (DA_check == 1) //if it's in use, update the protocol
			string first_da_drop = "Wave_DA_0"+num2str(i)
			PGC_setandactivatecontrol("ITC18USB_Dev_0", first_da_drop, val=stim_set_num)
			count_headstages+=1
		endif
	endfor	
	if (count_headstages==1) //set sampling rate to avoid filling memory
		//PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=2) //if only one headstage record at 25 kHz (interval = 4)
	elseif(count_headstages==4)
		//PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=0) //if all 4 active, don't downsample (already 25 Khz)
	else
		//PGC_setandactivatecontrol("ITC18USB_Dev_0", "Popup_Settings_SampIntMult", val=1) //sample multiplier = 2		
		
	endif
	PGC_setAndActivateControl("ITC18USB_Dev_0", "Check_AD_06",val=0)
	Print "Choose a TTL StimSet and then Ready to aquire!"


end



///missed pockel response///
Function make_missed_pockel(missed_sweep)
	variable missed_sweep
	if(wintype("no_pockel")==0)
		NewPanel/N=no_pockel/W=(800,50,1000,200)
		TitleBox tb1, title="No Pockel pulse was detected", frame=5, pos={5,5}
		Button abort_button title="stop DAC and\rreset sweep", proc = ButtonStop, size={100,50}, pos={50, 30}
		SetVariable setvarSweepReset title="missed sweep", bodyWidth=45, value= _NUM:missed_sweep, pos={100,85}
		Button ignore_button title="ignore", proc = ButtonIgnore, pos={75, 110}, help={"ignore this, best to wait for DAQ to complete or window may return"}
		
		
	endif
end 


Function ButtonStop(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
          NVAR runmode = $GetDataAcqRunMode("ITC18USB_Dev_0")
        	
        	if (runmode!=0)
            	PGC_SetAndActivateControl("ITC18USB_Dev_0","DataAcquireButton")// click code here
          endif
          controlinfo/W=no_pockel setVarSweepReset
          variable missed_sweep=V_value
          SetVariable setvar_sweep win=ITC18USB_Dev_0, value=_NUM:missed_sweep
          KillWindow/Z no_pockel
         break
        case -1: // control being killed
            break
    endswitch

    return 0
End

Function ButtonIgnore(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
          
          KillWindow/Z no_pockel
         break
        case -1: // control being killed
            break
    endswitch

    return 0
End

///////STIM MONITOR GUI AND FUNCTIONS HERE///////


Function make_stim_monitor()
	if (wintype("stim_monitor") == 0)
		Display/n=stim_monitor/W=(800,50,1200,500)
		stim_gui()
	endif

End


Function stim_gui()
	newpanel/W=(0,200,100,0)/n=stim_monitor_ops/HOST=stim_monitor/EXT=0
	SetVariable setvarSweep title="1st sweep",bodyWidth=45, value= _NUM:10, limits={0,10000,1}
	SetVariable setvarInterval title="# cells", bodyWidth=45, value= _NUM:10, limits={1,10000,1}
	SetVariable setvarReps title="# reps", bodyWidth=45, value= _NUM:10, limits={1,10000,5}
	SetVariable setvarMPT title="MP target", bodyWidth=45, value= _NUM:1
	Button button0 title="Party On!",proc=ButtonProc_plot,size={70,20}, help={"plot sweeps"}
	Button button4 title="<", proc=ButtonProc_plot_prev, size={35,20}, help={"plot previous"}
	Button button1 title=">",proc=ButtonProc_plot_next, size={35,20}, help={"plot next"}
	Button cnx_button title="cnx", proc=ButtonProc_cnx, size={35,20}, help={"note current mark point as a putative connection"}
	Button ignore_button title="supp.", proc=ButtonProc_supp, size={35,20}, help={"note current mark point as unconventional"} 
	Checkbox checkAverage, title="average", value=0, help={"plot the average and S.D., other options may be ignored"}, proc=Checkbox_proc
	Checkbox checkXoffset, title="offset X", value=1, help={"offset traces to start of pockel cell output"}, proc=Checkbox_proc
	Checkbox checkYoffset, title="offset Y", value=1, help={"crude baseline offset"}, proc=Checkbox_proc
	Checkbox checkScale, title="full scale?", value=0, help={"display entire wave, ignore settings below"}, proc=Checkbox_proc
	Checkbox checkDistOn, title="distribute", value=0, help={"keep distribute on"},  proc=Checkbox_proc
	Checkbox checkColorOn, title="color", value=0, help={"keep color on"},  proc=Checkbox_proc
	SetVariable setvarXmin title="X min", bodyWidth=45, value= _NUM:-50
	SetVariable setvarXmax title="X max", bodyWidth=45, value= _NUM:150
	Button button2 title="highlighter", proc=ButtonProc_highlighter, size={70,20}, help={"highlight single trace, cycles through"}
	//Button button3 title="multi-plot", proc=ButtonProc_multiplot, size={70,20}, help={"not that useful"}
	//Button button5 title="start auto", proc=ButtonProc_startupdate, size={70,20}, help={"cycles through MP targets every 2 s, make sure to turn off"}
	//Button button6 title="stop auto", proc=ButtonProc_stopupdate, size={70,20}, help={"stop cycling"}
	PopupMenu popupHS, title="headstage", value="all;0;1;2;3", proc=single_hs_click
	PopupMenu popupT_starts, title="Load T series", value=t_series_list(), proc=populate_t_series_values
 
end

Function/S t_series_list()
	wave t_series_w=root:opto_df:t_start
	string list=""
	variable size=DimSize(T_series_w,0)
	variable i
	for (i=0;i<size;i+=1)
		list=list+num2str(T_series_w[i])+";"
	endfor
	return list
end

Function populate_t_series_values(PU_Struct) : PopupMenuControl
	STRUCT WMPopupAction &PU_Struct
	controlinfo/W=stim_monitor_ops popupT_starts
	variable popup_value=v_value-1
	wave T_wave=root:opto_df:T_start
	wave cell_wave=root:opto_df:roi
	wave reps_wave=root:opto_df:reps
	variable first_sweep=T_wave[popup_value]
	variable cells=cell_wave[popup_value]
	variable reps=reps_wave[popup_value]
	Setvariable setvarInterval win=stim_monitor_ops, value= _NUM:cells
	Setvariable setvarReps win=stim_monitor_ops, value= _NUM:reps
	
	SetVariable setvarsweep win=stim_monitor_ops, value=_NUM:first_sweep
	SetVariable setvarMPT win=stim_monitor_ops, value=_NUM:1
	

	return 0
end

Function single_hs_click(PU_Struct) : PopupMenuControl
	STRUCT WMPopupAction &PU_Struct
	controlinfo/W=stim_monitor_ops popupHS
	single_hs(v_value-2)
	return 0

end

Function Checkbox_proc(CB_Struct) : CheckBoxControl
	STRUCT WMCheckboxAction &CB_Struct
		     //print "box was clicked"
		     controlinfo/W=stim_monitor_ops setvarSweep
            variable param0=v_value
            controlinfo/W=stim_monitor_ops setvarInterval
            variable param1=v_value
            controlinfo/W=stim_monitor_ops setvarReps
            variable param2=v_value
            controlinfo/W=stim_monitor_ops checkXoffset
            variable param3=v_value
            controlinfo/W=stim_monitor_ops checkYoffset
            variable param4=v_value
            controlinfo/W=stim_monitor_ops setvarXmin
            variable param5=v_value
            controlinfo/W=stim_monitor_ops setvarXmax
            variable param6=v_value
            controlinfo/W=stim_monitor_ops setvarMPT
            variable param7=v_value
            controlinfo/W=stim_monitor_ops checkScale
            variable param8=v_value
            controlinfo/W=stim_monitor_ops checkColorOn
            variable param9=V_value
            controlinfo/W=stim_monitor_ops checkDistOn
            variable param10=v_value
            controlinfo/W=stim_monitor_ops checkAverage
            variable param12=v_value
            
            if(param12==1)
            		plot_avg(param0,param1,param2,param4, param5, param6, param7, param8)
            		
            		
            else
            		map_plot(param0,param1,param2, param3, param4, param5, param6, param7, param8, param9, param10)// click code here
            endif
            
            

	return 0
End
	





Function ButtonProc_plot(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
            controlinfo/W=stim_monitor_ops setvarSweep
            variable param0=v_value
            controlinfo/W=stim_monitor_ops setvarInterval
            variable param1=v_value
            controlinfo/W=stim_monitor_ops setvarReps
            variable param2=v_value
            controlinfo/W=stim_monitor_ops checkXoffset
            variable param3=v_value
            controlinfo/W=stim_monitor_ops checkYoffset
            variable param4=v_value
            controlinfo/W=stim_monitor_ops setvarXmin
            variable param5=v_value
            controlinfo/W=stim_monitor_ops setvarXmax
            variable param6=v_value
            controlinfo/W=stim_monitor_ops setvarMPT
            variable param7=v_value
            controlinfo/W=stim_monitor_ops checkScale
            variable param8=v_value
            controlinfo/W=stim_monitor_ops checkColorOn
            variable param9=V_value
            controlinfo/W=stim_monitor_ops checkDistOn
            variable param10=v_value
            controlinfo/W=stim_monitor_ops popupHS
            variable param11=v_value
            controlinfo/W=stim_monitor_ops checkAverage
            variable param12=v_value
            
            if(param12==1)
            		plot_avg(param0,param1,param2,param4, param5, param6, param7, param8)
            		
            		
            else
            		map_plot(param0,param1,param2, param3, param4, param5, param6, param7, param8, param9, param10)// click code here
            endif
            break
        case -1: // control being killed
            break
    endswitch

    return 0
End

Function ButtonProc_plot_next(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
            controlinfo/W=stim_monitor_ops setvarsweep
            variable param0=v_value
            controlinfo/W=stim_monitor_ops setvarInterval
            variable param1=v_value
            controlinfo/W=stim_monitor_ops setvarReps
            variable param2=v_value
            controlinfo/W=stim_monitor_ops checkXoffset
            variable param3=v_value
            controlinfo/W=stim_monitor_ops checkYoffset
            variable param4=v_value
            controlinfo/W=stim_monitor_ops setvarXmin
            variable param5=v_value
            controlinfo/W=stim_monitor_ops setvarXmax
            variable param6=v_value
            controlinfo/W=stim_monitor_ops setvarMPT
            variable old_MPT=v_value
            variable new_MPT
            if (param1==1)
            		new_MPT=1
            		param0=param0+1
            		SetVariable setvarsweep win=stim_monitor_ops, value=_NUM:param0
            elseif (old_MPT>=param1)
            		new_MPT=1
            else
            		new_MPT=V_value+1
            endif
            Setvariable setvarMPT win=stim_monitor_ops, value= _NUM:new_MPT
            controlinfo/W=stim_monitor_ops setvarMPT
            variable param7=v_value
            controlinfo/W=stim_monitor_ops checkScale
            variable param8=v_value
            controlinfo/W=stim_monitor_ops checkColorOn
            variable param9=v_value
            controlinfo/W=stim_monitor_ops checkDistOn
            variable param10=v_value
            
            controlinfo/W=stim_monitor_ops checkAverage
            variable param12=v_value
            
            if(param12==1)
            		plot_avg(param0,param1,param2,param4, param5, param6, param7, param8)
            else
            
            		map_plot(param0,param1,param2, param3, param4, param5, param6, param7, param8, param9, param10)// click code here
            endif
            break
        case -1: // control being killed
            break
    endswitch

    return 0
End


Function ButtonProc_plot_prev(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
            controlinfo/W=stim_monitor_ops setvarsweep
            variable param0=v_value
            controlinfo/W=stim_monitor_ops setvarInterval
            variable param1=v_value
            controlinfo/W=stim_monitor_ops setvarReps
            variable param2=v_value
            controlinfo/W=stim_monitor_ops checkXoffset
            variable param3=v_value
            controlinfo/W=stim_monitor_ops checkYoffset
            variable param4=v_value
            controlinfo/W=stim_monitor_ops setvarXmin
            variable param5=v_value
            controlinfo/W=stim_monitor_ops setvarXmax
            variable param6=v_value
            controlinfo/W=stim_monitor_ops setvarMPT
            variable old_MPT=v_value
            variable new_MPT
            if (param1==1)
            		new_MPT=1
            		param0=param0-1
            		SetVariable setvarsweep win=stim_monitor_ops, value=_NUM:param0
            elseif (old_MPT==1)
            		new_MPT=param1
            else
            		new_MPT=old_MPT-1
            endif
            Setvariable setvarMPT win=stim_monitor_ops, value= _NUM:new_MPT
            controlinfo/W=stim_monitor_ops setvarMPT
            variable param7=v_value
            controlinfo/W=stim_monitor_ops checkScale
            variable param8=v_value
            controlinfo/W=stim_monitor_ops checkColorOn
            variable param9=v_value
            controlinfo/W=stim_monitor_ops checkDistOn
            variable param10=v_value
            
            
            controlinfo/W=stim_monitor_ops checkAverage
            variable param12=v_value
            
            if(param12==1)
            		plot_avg(param0,param1,param2,param4, param5, param6, param7, param8)
            else
            
            		map_plot(param0,param1,param2, param3, param4, param5, param6, param7, param8, param9, param10)// click code here
            endif
            
            
            break
        case -1: // control being killed
            break
    endswitch

    return 0
End


Function ButtonProc_cnx(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
            controlinfo/W=stim_monitor_ops setvarSweep
            variable param0=v_value
            controlinfo/W=stim_monitor_ops setvarMPT
            variable param1=v_value
            print "TSeries_"+num2str(param0)+"_MP_"+num2str(param1)+" putative cnx"

            break
        case -1: // control being killed
            break
    endswitch

    return 0
End


Function ButtonProc_supp(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
            controlinfo/W=stim_monitor_ops setvarSweep
            variable param0=v_value
            controlinfo/W=stim_monitor_ops setvarMPT
            variable param1=v_value
            print "TSeries_"+num2str(param0)+"_MP_"+num2str(param1)+" skip analysis"

            break
        case -1: // control being killed
            break
    endswitch

    return 0
End


Function ButtonProc_highlighter(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
        	highlighter()//click code here
        	break
        case -1: // control being killed
        	break
     endswitch
     
     return 0
End

Function ButtonProc_startupdate(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
        	startSMupdate()//click code here
        	break
        case -1: // control being killed
        	break
     endswitch
     
     return 0
End

Function ButtonProc_stopupdate(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
        	stopSMupdate()//click code here
        	break
        case -1: // control being killed
        	break
     endswitch
     
     return 0
End



Function ButtonProc_multiplot(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
            controlinfo/W=stim_monitor_ops setvarSweep
            variable param0=v_value
            controlinfo/W=stim_monitor_ops setvarInterval
            variable param1=v_value
            controlinfo/W=stim_monitor_ops setvarReps
            variable param2=v_value
            controlinfo/W=stim_monitor_ops checkXoffset
            variable param3=v_value
            controlinfo/W=stim_monitor_ops checkYoffset
            variable param4=v_value
            controlinfo/W=stim_monitor_ops setvarXmin
            variable param5=v_value
            controlinfo/W=stim_monitor_ops setvarXmax
            variable param6=v_value
            controlinfo/W=stim_monitor_ops setvarMPT
            variable param7=v_value
            multiplot(param0,param1,param2, param3, param4, param5, param6, param7)// click code here
            break
        case -1: // control being killed
            break
    endswitch

    return 0
End




Function distribute_sweeps()

    string sweeplist=tracenamelist("",";",1)

    variable total_traces=itemsinlist(sweeplist,";")

    string axes=axislist("")

    axes=listmatch(axes,"L*")

    variable numaxes=itemsinlist(axes,";")

    variable i, axes_i

    string sweepname, info

    variable column_number

    variable trace_range

    

    variable trace_offset

    for (axes_i=0; axes_i<numaxes-1; axes_i+=1)

        string single_axis=stringfromlist(axes_i,axes)

        variable total_offset=0

        for (i=0;i<total_traces;i+=1)

            sweepname=stringfromlist(i,sweeplist)

            wave w_trace=tracenametowaveref("",sweepname)

            info=traceinfo("",sweepname,0)

            string yaxisname=stringbykey("YAXIS",info)

            if (cmpstr(yaxisname,single_axis)==0)

                String offsets = StringByKey("offset(x)",info,"=",";") // "{xOffset,yOffset}"

                Variable xOffset,yOffset

                sscanf offsets, "{%g,%g}",xOffset,yOffset

                string yrange=stringbykey("YRANGE",info,":",";")

                sscanf yrange, "[*][%g]", column_number

                string xrange=stringbykey("XRANGE",info,":",";")

                

                duplicate/o/r=[][column_number] w_trace temp_wave

                wavestats/q/r=(-1*xOffset-50,-1*xOffset+150) temp_wave

                trace_range=(V_max-V_min)///1.5

                

                if (trace_range>3)

                    trace_range=1

                    

                endif

                wavestats/q/r=(-1*xOffset-50,-1*xOffset+150) temp_wave

                trace_offset=abs(V_avg)+total_offset

                total_offset+=trace_range

                ModifyGraph offset($sweepname)={xOffset,trace_offset}

                

            endif

        endfor

    endfor

end


Function multiplot(first_sweep, interval, reps, xoffset_check, yoffset_check, x_start, x_end, MPT)
	variable first_sweep, interval, reps, xoffset_check, yoffset_check, x_start, x_end, MPT
	//print "multiplot doesn't exist yet!"
	variable i,j, trace, total_traces, count2four
	string sweeplist=tracenamelist("",";",1)
	for (i=itemsinlist(sweeplist,";")-1; i>=0;i-=1) //remove all existing sweeps, this may be made optional later
		string sweepname=stringfromlist(i,sweeplist)
		RemoveFromGraph/W=stim_monitor/Z $sweepname
	endfor

	setdatafolder root:MIES:ITCDevices:ITC18USB:Device0:Data:
	
	for (count2four=1; count2four<=4; count2four+=1)
		string bottom_name="B_"+num2str(count2four)
		if (MPT+count2four>interval+1)
			variable starter = first_sweep + MPT + count2four - interval - 2
		else
			starter=first_sweep + MPT + count2four - 2
		endif
		for (i=0; i<reps; i+=1) //for each sweep...
			variable sweepnumber=starter+interval*i
			string config_name="Config_Sweep_"+num2str(sweepnumber)
			string sweep_name="Sweep_"+num2str(sweepnumber)
			wave W_config=$config_name
			wave W_sweep=$sweep_name
			variable trace_count=0
			variable xoffset_value=0
			for (j=0;j<dimsize(W_config,0);j+=1) //for each channel...
				if (W_config[j][0] == 0) //if this is an AD_trace...
					string axis_name="L_AD"+num2str(W_config[j][1])
					appendtograph/L=$axis_name/B=$bottom_name W_sweep[][j] //append it to the correct axis				
					trace_count+=1
				endif
			
				if (xoffset_check==1 && W_config[j][1]==6) //if this is AD6 (pockel output)
					Duplicate/o/R=[][j] W_sweep, tempAD6
					Findlevel/q tempAD6 0.05
					if(V_flag == 0) //if there was a Pockel pulse
						xoffset_value=V_LevelX*-1 //we'll offset the traces from this sweep by the crossing point
						sweeplist=tracenamelist("",";",1)
						total_traces=itemsinlist(sweeplist,";")
						for (trace=total_traces-1; trace>=total_traces-trace_count;trace-=1) 
							sweepname=stringfromlist(trace,sweeplist)
							ModifyGraph/W=stim_monitor offset($sweepname)={xoffset_value,0}
						endfor
						Killwaves/Z tempAD6
					endif
				endif
			endfor
		endfor
	endfor	
	string axes=axislist("stim_monitor")
	string L_axes=listmatch(axes,"L*")
	string B_axes=listmatch(axes,"B*")
	variable numaxes=itemsinlist(L_axes,";")
	variable numBaxes=itemsinlist(B_axes,";")
	Make/o/n=(numaxes) axeslimits
	axeslimits=1-x/(numaxes-1)
	Make/o/n=(numBaxes+1) Baxeslimits
	Baxeslimits=x/(numBaxes)
	for (i=0;i<(numBaxes);i+=1)
		axis_name=stringfromlist(i,B_axes)
		variable Baxisleft = Baxeslimits[i]+.01
		variable Baxisright = Baxeslimits[i+1]-.01
		Setaxis $axis_name x_start, x_end
		ModifyGraph freePos($axis_name)=0
		if(MPT+i<=interval)
			Label $axis_name "MarkPoints "+num2str(MPT+i)
		else
			Label $axis_name "MarkPoints "+num2str(MPT+i-interval)
		endif
		ModifyGraph lblPos($axis_name)=50
		ModifyGraph axisEnab($axis_name)={Baxisleft,Baxisright}
		ModifyGraph tkLblRot($axis_name)=45
	endfor	
	for (i=0;i<(numaxes-1);i+=1)
		axis_name=stringfromlist(i,L_axes)
		variable axisbottom = axeslimits[i+1]+.01
		variable axistop = axeslimits[i]-.01
		ModifyGraph freePos($axis_name)=0
		ModifyGraph axisEnab($axis_name)={axisbottom,axistop}
		Label $axis_name axis_name
		ModifyGraph lblPos($axis_name)=50
		SetAxis/A=2 $axis_name
	endfor
	ModifyGraph freePos(L_AD6)=0
	ModifyGraph axisEnab(L_AD6)={0,1}
	ModifyGraph noLabel(L_AD6)=2,axThick(L_AD6)=0
	ModifyGraph rgb=(0,0,0)
	
	
	total_traces=itemsinlist(sweeplist,";")
	for(i=0;i<total_traces;i+=1)
		sweepname=stringfromlist(i,sweeplist)
		string info=traceinfo("",sweepname,0)
		string yaxisname=stringbykey("YAXIS",info)
		if (cmpstr(yaxisname,"L_AD6")==0)
			ModifyGraph mode($sweepname)=7,hbFill($sweepname)=2,rgb($sweepname)=(65535,49151,49151)
			ReorderTraces _back_, {$sweepname}
		endif
		
		
	endfor	
	if (yoffset_check == 1)
		for (i=0;i<total_traces;i+=1)
			sweepname=stringfromlist(i,sweeplist)
			wave w_trace=tracenametowaveref("stim_monitor",sweepname)
			info=traceinfo("",sweepname,0)
			variable column_number
			String offsets = StringByKey("offset(x)",info,"=",";") // "{xOffset,yOffset}"
 			Variable xOffset,yOffset
			sscanf offsets, "{%g,%g}",xOffset,yOffset
			string yrange=stringbykey("YRANGE",info,":",";")
			sscanf yrange, "[*][%g]", column_number
			duplicate/o/r=[][column_number] w_trace temp_wave
			
			if (yOffset_check==1 && xoffset_check==0)
				print "made it to y on x off"
				wavestats/q/r=[0,10] temp_wave
				yOffset=V_avg*-1
				ModifyGraph offset($sweepname)={xOffset, yOffset}
			elseif (yoffset_check==1 && xoffset_check==1)
				variable x_range=xOffset*-1
				wavestats/q/r=(x_range-10,x_range) temp_wave
				yOffset=V_avg*-1
				ModifyGraph offset($sweepname)={xOffset, yOffset}
			
			endif

			
		endfor
	endif
		Killwaves/z temp_wave, axeslimits, Baxeslimits
	ModifyGraph tickUnit=1

	
end
        
Function map_plot(first_sweep, interval, reps, xoffset_check, yoffset_check, x_start, x_end, MPT, scale, color, dist)
	variable first_sweep, interval, reps, xoffset_check, yoffset_check, x_start, x_end, MPT, scale, color, dist
	variable i,j, trace, total_traces
	string sweeplist=tracenamelist("",";",1)
	for (i=itemsinlist(sweeplist,";")-1; i>=0;i-=1) //remove all existing sweeps, this may be made optional later
		string sweepname=stringfromlist(i,sweeplist)
		RemoveFromGraph/W=stim_monitor/Z $sweepname
	endfor

	setdatafolder root:MIES:ITCDevices:ITC18USB:Device0:Data:
	for (i=0; i<reps; i+=1) //for each sweep...
		variable sweepnumber=(first_sweep + MPT - 1)+interval*i
		string config_name="Config_Sweep_"+num2str(sweepnumber)
		string sweep_name="Sweep_"+num2str(sweepnumber)
		wave W_config=$config_name
		wave W_sweep=$sweep_name
		variable trace_count=0
		variable xoffset_value=0
		for (j=0;j<dimsize(W_config,0);j+=1) //for each channel...
			if (W_config[j][0] == 0) //if this is an AD_trace...
				string axis_name="L_AD"+num2str(W_config[j][1])
				appendtograph/L=$axis_name W_sweep[][j] //append it to the correct axis				
				trace_count+=1
			endif
			sweeplist=tracenamelist("",";",1)
			total_traces=itemsinlist(sweeplist,";")
			if (xoffset_check==1 && W_config[j][1]==6) //if this is AD6 (pockel output)
				Duplicate/o/R=[][j] W_sweep, tempAD6
				Findlevel/q tempAD6 0.05
				if(V_flag == 0) //if there was a Pockel pulse
					xoffset_value=V_LevelX*-1 //we'll offset the traces from this sweep by the crossing point
					
					
					for (trace=total_traces-1; trace>=total_traces-trace_count;trace-=1) 
						sweepname=stringfromlist(trace,sweeplist)
						ModifyGraph/W=stim_monitor offset($sweepname)={xoffset_value,0}
					endfor
					Killwaves/Z tempAD6
				endif
			endif
		endfor
	endfor	
	string axes=axislist("stim_monitor")
	axes=listmatch(axes,"L*")
	variable numaxes=itemsinlist(axes,";")
	Make/o/n=(numaxes) axeslimits
	axeslimits=1-0.9*x/(numaxes-1)
	if (scale==0)
		Setaxis bottom x_start, x_end
	endif
	for (i=0;i<(numaxes-1);i+=1)
		axis_name=stringfromlist(i,axes)
		variable axisbottom = axeslimits[i+1]+.01
		variable axistop = axeslimits[i]-.01
		ModifyGraph freePos($axis_name)=0
		ModifyGraph axisEnab($axis_name)={axisbottom,axistop}
		Label $axis_name axis_name
		ModifyGraph lblPos($axis_name)=50
		SetAxis/A=2 $axis_name
	endfor
	ModifyGraph freePos(L_AD6)=0
	ModifyGraph axisEnab(L_AD6)={0,0.09}
	Label L_AD6 "L_AD6"
	ModifyGraph lblPos(L_AD6)=50
	ModifyGraph rgb=(0,0,0)

	total_traces=itemsinlist(sweeplist,";")
	
	if (yoffset_check == 1)
		for (i=0;i<total_traces;i+=1)
			sweepname=stringfromlist(i,sweeplist)
			wave w_trace=tracenametowaveref("stim_monitor",sweepname)
			string info=traceinfo("",sweepname,0)
			variable column_number
			String offsets = StringByKey("offset(x)",info,"=",";") // "{xOffset,yOffset}"
 			Variable xOffset,yOffset
			sscanf offsets, "{%g,%g}",xOffset,yOffset
			string yrange=stringbykey("YRANGE",info,":",";")
			sscanf yrange, "[*][%g]", column_number
			duplicate/o/r=[][column_number] w_trace temp_wave
			
			if (yOffset_check==1 && xoffset_check==0)
				//print "made it to y on x off"
				wavestats/q/r=[0,10] temp_wave
				yOffset=V_avg*-1
				ModifyGraph offset($sweepname)={xOffset, yOffset}
			elseif (yoffset_check==1 && xoffset_check==1)
				variable x_range=xOffset*-1
				wavestats/q/r=(x_range-10,x_range) temp_wave
				yOffset=V_avg*-1
				ModifyGraph offset($sweepname)={xOffset, yOffset}
			
			endif

			
		endfor
	endif
		Killwaves/z temp_wave, axeslimits
	if (color == 1)
		Execute "ColorWaves()"
	
	endif
	
	if (Dist == 1)
		distribute_sweeps()
		
	endif
end


Function highlighter()
	ModifyGraph/W=photostim_graph lsize=1, rgb=(43690,43690,43690)
	string axes=axislist("photostim_graph")
	axes=listmatch(axes,"L*")
	variable numaxes=itemsinlist(axes,";")
	string sweeplist=tracenamelist("",";",1)
	variable axis
	variable sweep
	variable count = 0
	Do
		string sweepname=stringfromlist(count,sweeplist)
		ModifyGraph/W=photostim_graph lsize($sweepname)=1.2,rgb($sweepname)=(65535,21845,0)
		ReorderTraces _front_, {$sweepname}
		count+=1
	while (count<numaxes)
end



Function Auto_update_sm(s)		// This is the function that will be called periodically
	STRUCT WMBackgroundStruct &s
				controlinfo/W=stim_monitor_ops setvarsweep
            variable param0=v_value
            controlinfo/W=stim_monitor_ops setvarInterval
            variable param1=v_value
            controlinfo/W=stim_monitor_ops setvarReps
            variable param2=v_value
            controlinfo/W=stim_monitor_ops checkXoffset
            variable param3=v_value
            controlinfo/W=stim_monitor_ops checkYoffset
            variable param4=v_value
            controlinfo/W=stim_monitor_ops setvarXmin
            variable param5=v_value
            controlinfo/W=stim_monitor_ops setvarXmax
            variable param6=v_value
            controlinfo/W=stim_monitor_ops setvarMPT

            variable param7=v_value
            controlinfo/W=stim_monitor_ops checkScale
            variable param8=v_value
            controlinfo/W=stim_monitor_ops checkColorOn
            variable param9=v_value
            controlinfo/W=stim_monitor_ops checkDistOn
            variable param10=v_value
            
            
            map_plot(param0,param1,param2, param3, param4, param5, param6, param7, param8, param9, param10)

			return 0
End

Function StartSMupdate()
	Variable numTicks = 2 * 60		// Run every two seconds (120 ticks)
	CtrlNamedBackground Test, period=numTicks, proc=auto_update_sm
	CtrlNamedBackground Test, start
End

Function StopSMupdate()
	CtrlNamedBackground Test, stop
End

Macro ColorWaves() ///pulled from Igor code snippets, credit should be assigned if ever shared
	Variable rev = 1
	String colorTable = "RainbowCycle"
	ColorTraces(rev, colorTable)
End
 
Function ColorTraces( rev, colorTable )
//% V1.5
	Variable rev 
	String colorTable 
 
	String list = TraceNameList( "", ";", 1 )
	Variable numItems = ItemsInList( list )
	if ( numItems == 0 )
		return 0
	endif
 
	ColorTab2Wave $colorTable
	Wave M_colors	
 
	Variable index, traceindex
	for( index = 0; index < numItems; index += 1 )			
		Variable row = ( index/numItems )*DimSize( M_Colors, 0 )
		traceindex = ( rev == 0 ? index : numItems - index )
		Variable red = M_Colors[ row ][ 0 ], green = M_Colors[ row ][ 1 ], blue = M_Colors[ row ][ 2 ]
		ModifyGraph/Z rgb[ traceindex ] = ( red, green, blue )
	endfor
 
	KillWaves/Z M_colors
End



////UN-USED OR STALLED PROJECTS
Function get_units(W_sweep)
	wave W_sweep
	string notestring=note(W_sweep)
	//string AD0units=stringbykey("HS#0:AD unit", notestring, ":", ",")
	string AD0units=stringbykey("HS#0:AD unit", notestring, ": ", ",")
	string AD1units=stringbykey(notestring,"HS#1:AD unit: ")
	print "AD0:" + AD0units
	print "AD1:" + AD1units
	Print StringByKey("kz", "KZ:1st,kz:2nd,", ":", ",")
	Print StringByKey("HS#0:AD unit", "HS#0:AD unit: pA", ": ", ",")
end




Function oneP_full()
	variable i
	string all_dacs = ReturnListofAllStimSets(0,"*DA*")
	string all_TTLs = ReturnListofAllStimSets(CHANNEL_TYPE_TTL,"*TTL*")
	variable stim_set_num = whichListItem("TargetCell_DA_0", all_dacs)+1 //+1 to comp for 'none'
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_00", val=0)
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_TTL_02", val=1)
	
	string oneP_list = ReturnListofAllStimSets(CHANNEL_TYPE_TTL,"**") //find all oneP protocols and corresponding #'s in popups 
	string first_oneP = stringfromlist(0,oneP_list)
	string last_oneP = stringfromlist(itemsinlist(oneP_list, ";")-1, oneP_list)
	variable first_num=whichListItem(first_oneP,all_TTLs)+1 //+1 to compensate for "none" in popup
	variable last_num=whichListItem(last_oneP,all_TTLs)+1
	print "first_num="+num2str(first_num)
	print "last_num="+num2str(last_num)
	PGC_setandactivatecontrol("ITC18USB_Dev_0", "Check_DataAcq_Indexing", val=0) //no indexing
	for (i=0;i<=3;i+=1) //for each headstage
		string CB_name = "Check_DA_0"+num2str(i)
		controlinfo/W=ITC18USB_Dev_0 $CB_name
		variable DA_check = V_Value
		
		if (DA_check == 1) //if it's in use, update the protocol
			string first_da_drop = "Wave_DA_0"+num2str(i)
			PGC_setandactivatecontrol("ITC18USB_Dev_0", first_da_drop, val=6)
			
		endif
	endfor	
	for (i=first_num;i<=first_num;i+=1)
		PGC_setandactivatecontrol("ITC18USB_Dev_0", "Wave_TTL_02", val=i)
		print i
		PGC_SetAndActivateControl("ITC18USB_Dev_0","DataAcquireButton")
		Do
			NVAR dataAcqRunmode = $GetDataAcqRunMode("ITC18USB_Dev_0")
		//print "run mode = " +num2str(dataAcqRunmode)
		//start_run_check()
		while(dataAcqRunmode==1)
		
		

	endfor
	
end

Function check_runmode(s)
	STRUCT WMBackgroundStruct &s
	NVAR dataAcqRunmode = $GetDataAcqRunMode("ITC18USB_Dev_0")
	print "run mode = " +num2str(dataAcqRunmode)
	if (dataAcqRunmode==0)
		stop_run_check()
		return 1
	endif
	return 0

	
end

Function start_run_check()
	variable numticks=60
	CtrlNamedBackground run_ctrl, period=numTicks, proc=check_runmode
	CtrlNamedBackground run_ctrl, start
end

Function stop_run_check()
	CtrlNamedBackground run_ctrl, stop
	
	print "DAQisOver"
end







Function test_crossing(s)
	STRUCT WMBackgroundStruct &s
	variable crossing = 20
	Wave OscilloscopeData
	
	Duplicate/o/r=[*][1] oscilloscopedata temp_data_wave
	Findlevel/q temp_data_wave, crossing
	if(V_flag==0)
		print "it happened at "+num2str(V_levelX)
		stop_testupdate()
	endif
	return 0
End


	

Function start_testupdate()
	variable numticks = 6
	CtrlNamedBackground crossing_ctrl, period=numTicks, proc=test_crossing
	CtrlNamedBackground crossing_ctrl, start
end

Function stop_testupdate()
	CtrlNamedBackground crossing_ctrl, stop
end




Function ButtonProc_dist(ba) : ButtonControl //old

   STRUCT WMButtonAction &ba



   switch( ba.eventCode )

       case 2: // mouse up

           distribute_sweeps()//click code here

           break

       case -1: // control being killed

           break

    endswitch

   

    return 0

End


Function ButtonProc_color(ba) : ButtonControl //old
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
        	Execute "ColorWaves()"//click code here
        	break
        case -1: // control being killed
        	break
     endswitch
     
     return 0
End


Function map_plot_new(first_sweep, interval, reps, xoffset_check, yoffset_check, x_start, x_end, MPT, scale, color, dist, headstage)
	variable first_sweep, interval, reps, xoffset_check, yoffset_check, x_start, x_end, MPT, scale, color, dist, headstage
	variable i,j, trace, total_traces
	headstage -=2 //subtract 2 so that "all" headstage option = -1, single headstage options will now = actual #
	print headstage
	string sweeplist=tracenamelist("",";",1)
	
	for (i=itemsinlist(sweeplist,";")-1; i>=0;i-=1) //remove all existing sweeps, this may be made optional later
		string sweepname=stringfromlist(i,sweeplist)
		RemoveFromGraph/W=stim_monitor/Z $sweepname
	endfor
	
	setdatafolder root:MIES:ITCDevices:ITC18USB:Device0:Data:
	for (i=0; i<reps; i+=1) //for each sweep...
		variable sweepnumber=(first_sweep + MPT - 1)+interval*i
		string config_name="Config_Sweep_"+num2str(sweepnumber)
		string sweep_name="Sweep_"+num2str(sweepnumber)
		wave W_config=$config_name
		wave W_sweep=$sweep_name
		variable trace_count=0
		variable xoffset_value=0
		if (headstage>0) //if we are to plot everything
			for (j=0;j<dimsize(W_config,0);j+=1) //for each channel...
				if (W_config[j][0] == 0) //if this is an AD_trace...
					string axis_name="L_AD"+num2str(W_config[j][1])
					appendtograph/L=$axis_name W_sweep[][j] //append it to the correct axis				
					trace_count+=1
				endif
			endfor
		else
			for (j=0;j<dimsize(W_config,0);j+=1) //for each channel...
				if (W_config[j][0] == 0 && (W_config[j][1] == headstage || W_config[j][1]==6)) //if this is an AD_trace and it's the specified headstage or pockel output
					axis_name="L_AD"+num2str(W_config[j][1])
					appendtograph/L=$axis_name W_sweep[][j] //append it to the correct axis				
					trace_count+=1
				endif
			endfor
		endif
		
	endfor		
end

//note to travis, above works to append only selected headstage, need to think about how to do x-offset for both multiple and single headstage cases


//for (j=0;j<dimsize(W_config,0);j+=1) //for each channel...
//			if (W_config[j][0] == 0) //if this is an AD_trace...
//				string axis_name="L_AD"+num2str(W_config[j][1])
//				appendtograph/L=$axis_name W_sweep[][j] //append it to the correct axis				
//				trace_count+=1
//			endif
//			sweeplist=tracenamelist("",";",1)
//			total_traces=itemsinlist(sweeplist,";")
//			if (xoffset_check==1 && W_config[j][1]==6) //if this is AD6 (pockel output)
//				Duplicate/o/R=[][j] W_sweep, tempAD6
//				Findlevel/q tempAD6 0.05
//				if(V_flag == 0) //if there was a Pockel pulse
//					xoffset_value=V_LevelX*-1 //we'll offset the traces from this sweep by the crossing point
//					
//					
//					for (trace=total_traces-1; trace>=total_traces-trace_count;trace-=1) 
//						sweepname=stringfromlist(trace,sweeplist)
//						ModifyGraph/W=stim_monitor offset($sweepname)={xoffset_value,0}
//					endfor
//					Killwaves/Z tempAD6
//				endif
//			endif
//		endfor

	
Function make_temp_wave(sweep_number, channel_number)
	variable sweep_number, channel_number
	setdatafolder root:MIES:ITCDevices:ITC18USB:Device0:Data:
	string config_name="Config_Sweep_"+num2str(sweep_number)
	string sweep_name="Sweep_"+num2str(sweep_number)
	wave W_config_source=$config_name
	wave W_sweep_source=$sweep_name
	//data folder stuff ...make reference to MIES source, make my own folder to store dup. waves in, refresh on folder reference comamnds
End
	


	
Function plot_avg(first_sweep, interval, reps,yoffset_check,  x_start, x_end, MPT, scale)
	variable first_sweep, interval, reps, MPT, yoffset_check, x_start, x_end, scale
	variable i, j, trace, total_traces
	string sweeplist=tracenamelist("",";",1)
	for (i=itemsinlist(sweeplist,";")-1; i>=0;i-=1) //remove all existing sweeps, this may be made optional later
		string sweepname=stringfromlist(i,sweeplist)
		RemoveFromGraph/W=stim_monitor/Z $sweepname
	endfor
	setdatafolder root:opto_df:
	
	string kill_list=wavelist("Sweep_*", ";","")  //sounds dark, unfortunately
	KillWaves/z kill_list
	for (i=0; i<itemsinlist(kill_list,";"); i+=1)
		KillWaves/Z $(StringFromList(i, kill_list))
	endfor
	
	setdatafolder root:MIES:ITCDevices:ITC18USB:Device0:Data:
	//Display
	for (i=0; i<reps; i+=1) //for each sweep...
		setdatafolder root:MIES:ITCDevices:ITC18USB:Device0:Data:
		variable sweepnumber=(first_sweep + MPT - 1)+interval*i
		string config_name="Config_Sweep_"+num2str(sweepnumber)
		string sweep_name="Sweep_"+num2str(sweepnumber)
		wave W_config=$config_name
		wave W_sweep=$sweep_name
		variable trace_count=0
		for (j=0;j<dimsize(W_config,0);j+=1) //for each channel...
			if (W_config[j][0] == 0) //if this is an AD_trace...
				string temp_name=sweep_name+"_AD"+num2str(W_config[j][1])
				
				Duplicate/o/r=[][j] W_sweep root:opto_df:$temp_name
				wave temp_wave=root:opto_df:$temp_name
				string axis_name="L_AD"+num2str(W_config[j][1])
				appendtograph/L=$axis_name root:opto_df:$temp_name //append it to the correct axis				
				trace_count+=1
			endif
			sweeplist=tracenamelist("",";",1)
			total_traces=itemsinlist(sweeplist,";")
			SetDataFolder root:opto_df

			if (W_config[j][1]==6) //if this is pockel output
				 
				FindLevel/q/p temp_wave 0.05
				
				if (V_flag==0)
				
					variable x_offset_value=floor(V_LevelX)*deltax(temp_wave)*-1
					
					for (trace=total_traces-1; trace>=total_traces-trace_count; trace-=1)
						wave theWave=WaveRefIndexed("",trace,1)
						SetScale/P x x_offset_value, deltax(theWave), theWave
						if (yoffset_check==1)
							wavestats/q/r=(-200,0) theWave
							variable med=median(theWave, -50,0)
							theWave=theWave-med
						endif
					endfor
				
				endif
			endif

		endfor
		
	endfor
	SetDataFolder root:opto_df
	ModifyGraph rgb=(48059,48059,48059)
	string axes=axislist("")
	axes=listmatch(axes,"L*")
	variable numaxes=itemsinlist(axes,";")
	Make/o/n=(numaxes) axeslimits
	axeslimits=1-0.9*x/(numaxes-1)

	for (i=0;i<(numaxes-1);i+=1)
		axis_name=stringfromlist(i,axes)
		string wavematch="*"+axis_name[2,4]
		string average_name="T"+num2str(first_sweep)+"_"+num2str(MPT)+"_"+axis_name[2,4]+"_avg"
		string error_name="T"+num2str(first_sweep)+"_"+num2str(MPT)+"_"+axis_name[2,4]+"_err"
		variable axisbottom = axeslimits[i+1]+.01
		variable axistop = axeslimits[i]-.01
		ModifyGraph freePos($axis_name)=0
		ModifyGraph axisEnab($axis_name)={axisbottom,axistop}
		Label $axis_name axis_name
		ModifyGraph lblPos($axis_name)=50
		SetAxis/A=2 $axis_name
		string sweep_list_axis = waveList(wavematch,";","WIN:")
		//print sweep_list_axis
		fWaveAverage(sweep_list_axis,"",1,1,average_name,error_name)
		wave average_wave=$average_name
		wave error_wave=$error_name
		appendtograph/l=$axis_name average_wave
		ErrorBars $average_name SHADE= {0,4,(0,0,0,0),(0,0,0,0)},wave=(error_wave,error_wave)
	endfor
	ModifyGraph freePos(L_AD6)=0
	ModifyGraph axisEnab(L_AD6)={0,0.09}
	Label L_AD6 "L_AD6"
	ModifyGraph lblPos(L_AD6)=50
	if (scale==0)
		Setaxis bottom x_start, x_end
	endif
End

Function single_hs(headstage)
	variable headstage
	string axes=axislist("")
	axes=listmatch(axes,"L*")
	variable numaxes=itemsinlist(axes,";")
	variable i
	
	
	if (headstage<0)
		
		Make/o/n=(numaxes) axeslimits
		axeslimits=1-0.9*x/(numaxes-1)
		for (i=0;i<(numaxes-1);i+=1)
			string axis_name=stringfromlist(i,axes)
			variable axisbottom = axeslimits[i+1]+.01
			variable axistop = axeslimits[i]-.01
			ModifyGraph axisEnab($axis_name)={axisbottom,axistop}
		endfor
	else
		string hs_axis_name="L_AD"+num2str(headstage)
		ModifyGraph axisEnab($hs_axis_name)={0.1,1}

		for (i=0;i<(numaxes-1);i+=1)
			axis_name=stringfromlist(i,axes)
			if (CmpStr(hs_axis_name, axis_name)!=0)
			
				ModifyGraph axisEnab($axis_name)={0,0.0001}
			endif
			
		endfor
		
	endif
End


Function Opto_ReturnNextSweep()

	controlinfo/W=ITC18USB_Dev_0 setvar_sweep
	variable sw = v_value
	//print "here I am"
	return sw
	
End


Function check_pockel_times()
	variable min_buffer = 200
	//variable max_start = 1500
	wave mapInfo = root:opto_df:mapInfo
	variable row_count=DimSize(mapInfo,0)
	Make/o/n=(row_count) pockel_starts, time_remaining
	pockel_starts=mapInfo[p][3]
	time_remaining=mapInfo[p][5] //set wave to sweep length (temp)
	time_remaining=time_remaining-pockel_starts //subtract pockel onset to get remaining record
	variable i
	variable count = 0
	for (i=0;i<row_count;i+=1)
		if (pockel_starts[i]<min_buffer || time_remaining[i]<min_buffer)
			string bad_sweep=GetDimLabel(mapInfo,0,i)
			print bad_sweep+" had an out of range pockel onset"
			count +=1
		endif
	endfor
	print num2str(count)+" sweeps failed pockel QC"
end

Function pockel_times_for_sweep(sweep)
	variable sweep
	wave mapInfo_wv=root:opto_df:mapInfo

	setdatafolder root:MIES:ITCDevices:ITC18USB:Device0:Data:
	string config_name="Config_Sweep_"+num2str(sweep)
	string sweep_name="Sweep_"+num2str(sweep)
	wave W_config=$config_name
	wave W_sweep=$sweep_name
	variable col_num=AFH_GetITCDataColumn(W_config, 6, 0) //data column corresponding to AD_6, where we record PC output
	
	if (numtype(col_num)==2)
		print "no pockel"
		
		
	else
		Duplicate/o/r=[][col_num] W_sweep, tempAD6
		FindLevel/q tempAD6 0.05
		if (V_flag == 1)
    		print "No Pockel cell output detected when one was expected on "+sweep_name
    		variable time_crossing=NaN
    		variable power=NaN
    			
    	else
    		time_crossing=V_LevelX
    		//wavestats/q/r=(time_crossing+1,time_crossing+2) tempAD6
    		power=mean(tempAD6,time_crossing+1,time_crossing+2)
    		power=round(power*52.7)
		
    	endif
    	variable sweepEnd=rightx(tempAd6)
    	variable dimLabel=FindDimLabel(mapInfo_wv,0,sweep_name)
		if(dimLabel==-2) //if there's not a row for this sweep yet - could be cleaned up when other variables are settled on
			InsertPoints/M=0 0, 1, mapInfo_wv
			SetDimLabel 0, 0, $sweep_name, mapInfo_wv
			dimLabel=0
		endif	
		mapInfo_wv[dimLabel][0]=sweep
		mapInfo_wv[dimLabel][3]=time_crossing
		mapInfo_wv[dimLabel][4]=power
		mapInfo_wv[dimLabel][5]=sweepEnd
	endif

end