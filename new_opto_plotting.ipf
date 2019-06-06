#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function make_photoStim_graph()
	if (wintype("photoStim_graph")==0)
		Display/n=photoStim_graph/W=(800,50,1200,500)
		photostim_gui()
	endif
end


Function photostim_gui()
	wave list=root:opto_df:textwave0
	newpanel/W=(0,250,100,0)/n=photostim_ops/HOST=photostim_graph/EXT=0
	PopupMenu popup_PSID, title="photostim ID", value=PSID_list(), proc=plot_ID_drop, help={"choose photostim ID to plot"}
	Button buttonPrev title="<", proc=PS_ButtonProc_plot_prev, size={35,20}, help={"plot previous"}
	Button buttonNext title=">",proc=PS_ButtonProc_plot_next, size={35,20}, help={"plot next"}
	Button buttonUpdate title="update", proc=PS_ButtonProc_update, help={"update plot"}
	PopupMenu popup_recent, title=" ", help={"display all data or only most recent round"}, value=round_list()
	Checkbox checkAverage, title="average", value=0, help={"plot the average and S.D., other options may be ignored"}, proc=avg_CB_proc
	Checkbox checkYoffset, title="offset Y", value=1, help={"crude baseline offset"}, proc=PS_Yoffset_proc
	Checkbox checkScale, title="full scale?", value=0, help={"display entire wave, ignore settings below"}, proc=fullscale_checkbox_proc
	Checkbox checkDistOn, title="distribute", value=0, help={"keep distribute on"},  proc=PS_CheckDist_proc
	Checkbox checkColorOn, title="color", value=0, help={"keep color on"},  proc=color_CB_proc
	Checkbox checkQC, title="QC", value=1, help={"only display sweeps meeting QC"}
	Button buttonFail title="FAIL", proc=ButtonProc_fail, help={"manually fail sweep under cursor A for QC"}
	SetVariable setvarXmin title="X min", bodyWidth=45, value= _NUM:-50, limits={-10000,10000,10}, proc=SV_setxscale
	SetVariable setvarXmax title="X max", bodyWidth=45, value= _NUM:150, limits={-10000,10000,10}, proc=SV_setxscale
	Button button2 title="highlighter", proc=ButtonProc_highlighter, size={70,20}, help={"highlight single trace, cycles through"}
	PopupMenu popup_power title="powers", value=power_list(), proc=plot_power_drop, help={"select power(s) to display"}
	
	Checkbox HS_all, title="all", value=1, help={"display all headstages with data"}, proc=HS_CB_proc
	Checkbox HS_0, title="HS 0", value=0, help={"toggle headstage display"}, proc=HS_CB_proc
	Checkbox HS_1, title="HS 1", value=0, help={"toggle headstage display"}, proc=HS_CB_proc
	Checkbox HS_2, title="HS 2", value=0, help={"toggle headstage display"}, proc=HS_CB_proc
	Checkbox HS_3, title="HS 3", value=0, help={"toggle headstage display"}, proc=HS_CB_proc
	GroupBox cnxbox, size={90,300}, title="connection", frame=0
	Button excitatory, title="excitatory", pos={5,520}, size={70,20}, proc=ButtonProc_excitatory
	Button inhibitory, title="inhibitory", pos={5,545}, size={70,20}, proc=ButtonProc_inhibitory
	Button refine_bl, title="fine offset", pos={5,570}, size={70,20}, proc=ButtonProc_fine_offset
	SetVariable refine_bl_start, title="", bodyWidth=45, value= _NUM:0
	SetVariable refine_bl_end, title="", bodyWidth=45, value=_NUM:10
	
end


Function ButtonProc_excitatory(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
			call_cnx(1)
        	break
       case -1: //control being killed
       	break
       endswitch
       
       return 0
 end


Function ButtonProc_inhibitory(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
			call_cnx(2)
        	break
       case -1: //control being killed
       	break
       endswitch
       
       return 0
 end



Function ButtonProc_fine_offset(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
        	controlinfo/W=photostim_ops refine_bl_start
        	variable startbl=v_value
        	
        	controlinfo/W=photostim_ops refine_bl_end
        	variable endbl=v_value 
        	
        	offset_y(startbl,endbl)
        	remove_avg()
        	photostim_avg()
        	break
       case -1: //control being killed
       	break
       endswitch
       
       return 0
 end

Function getHStoDisplay()
	controlinfo/W=photostim_ops HS_all
	variable allCheck=v_value
	variable i
	wave HS_check=root:opto_df:HS_selection
	if (allCheck==1)
		HS_check=1
	else
		for(i=0;i<=3;i+=1)
			string controlname="HS_"+num2str(i)
			controlinfo/W=photostim_ops $controlname
			HS_check[i]=v_value
		endfor
	endif
end
	
Function HS_CB_proc(CB_Struct) : CheckBoxControl
	STRUCT WMCheckboxAction &CB_Struct
	getHStoDisplay()
	controlinfo/W=photostim_ops popup_PSID
   variable PSID=str2num(s_value)
   plot_stimID(PSID)
	return 0
End

Function/S power_list()
	controlinfo/W=photostim_ops popup_PSID
	variable PSID_index=v_value-1
	wave uniquePSID=root:opto_df:uniqueStimIDs
	variable PSID=uniquePSID[PSID_index]
	find_powers(PSID)
	DFREF saveDFR = GetDataFolderDFR()
	setdatafolder root:opto_df:
	wave unique_powers
	variable length=numpnts(unique_powers)
	variable i
	string list="all;"
	for (i=0; i<length; i+=1)
		list=list+num2str(unique_powers[i])+";"
	endfor
	return list	
	SetDataFolder saveDFR
end

Function plot_power_drop(PU_Struct) : PopupMenuControl
	STRUCT WMPopupAction &PU_Struct
	controlinfo/W=photostim_ops popup_PSID
	variable PSID_index=v_value-1
	wave uniquePSID=root:opto_df:uniqueStimIDs
	variable PSID=uniquePSID[PSID_index]
	controlinfo/W=photostim_ops popup_power
	variable power_index=v_value-2
	controlinfo/W=photostim_ops checkQC
	variable QC=v_value
	if (power_index>=0)
		wave unique_powers=root:opto_df:unique_powers
		variable power=unique_powers[power_index]
		plot_stimID(PSID, power=power, applyQC=QC)
		
	else 
		plot_stimID(PSID, applyQC=QC)
		
	endif
	return 0
end
	

	
	
end

Function SV_setxscale(SV_Struct) : SetVariableControl
	STRUCT WMSetVariableAction &SV_Struct
	setxscale()
	return 0
End


Function fullScale_Checkbox_proc(CB_Struct) : CheckBoxControl
	STRUCT WMCheckboxAction &CB_Struct
	setxscale()
	return 0
End


Function color_CB_proc(CB_Struct) : CheckBoxControl
	STRUCT WMCheckboxAction &CB_Struct
	color_ps_graph()
	return 0
End


Function avg_CB_proc(CB_Struct) : CheckBoxControl
	STRUCT WMCheckboxAction &CB_Struct
	controlinfo/W=photostim_ops checkAverage
	variable avg=v_value
	if(avg==1)
		photostim_avg()
	else
		
		remove_avg()
	endif
	return 0
End

Function PS_Yoffset_proc(CB_Struct) : CheckBoxControl
	STRUCT WMCheckboxAction &CB_Struct
	controlinfo/W=photostim_ops checkyoffset
	variable check=v_value
	if (check==1)
		offset_PSgraph()
	else
		wave uniqueIDs=root:opto_df:uniqueStimIDs
		controlinfo/W=photostim_ops popup_PSID
		variable param0=v_value
		variable PSID=uniqueIDs[param0-1]
		controlinfo/W=photostim_ops checkQC
		variable QC=v_value
       plot_stimID(PSID, applyQC=QC)
   endif
	
	return 0
End

Function color_ps_graph()
	controlinfo/W=photostim_ops checkcoloron
	variable color=v_value
	if(v_value==1)
		Execute "ColorWaves()"
	else
		ModifyGraph rgb=(0,0,0)
	endif
end

Function distribute_ps_graph()
	controlinfo/W=photostim_ops checkDistOn
	variable dist=v_value
	if(v_value == 1)
		distribute_sweeps()
	else
		ModifyGraph offset={0,0}
	endif
end

Function PS_CheckDist_proc(CB_Struct) : CheckBoxControl
	STRUCT WMCheckboxAction &CB_Struct
		distribute_ps_graph()          
   	return 0
End

Function PS_Checkbox_proc(CB_Struct) : CheckBoxControl
	STRUCT WMCheckboxAction &CB_Struct
		     print "box was clicked"          
   	return 0
End

Function PS_ButtonProc_plot_prev(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
        		getuniquestimids()
            controlinfo/W=photostim_ops popup_recent
        		variable recent=V_value
        		controlinfo/W=photostim_ops checkQC
				variable QC=v_value
        		wave uniqueIDs=root:opto_df:uniqueStimIDs
        		if(recent==2)
        			controlinfo/W=photostim_ops popup_PSID
            		
            		variable currentID=str2num(s_value)	
        			getrecentstimpoints()
        			wave recent_Ids=root:opto_df:recent_ids
        			FindValue/V=(currentID) recent_ids
        			variable index=v_value
        			if(index==0)
        				variable PSID=recent_ids[numpnts(recent_ids)-1]
        			else
        				PSID=recent_ids[index-1]
        			endif
        			FindValue/V=(PSID) uniqueIDs
        			variable new_setting=v_value-1
        			PopupMenu popup_PSID win=photostim_ops, mode=new_setting
            		wave round_wv=root:opto_df:round_count
            		variable round_num=round_wv[0]
            		plot_stimID(PSID, round_num=round_num, applyQC=QC)
            
            	else	
            		controlinfo/W=photostim_ops popup_PSID
            		variable param0=v_value
            		variable new_param=param0-1
            		//print new_param
            		if(new_param>0)
            			PopupMenu popup_PSID win=photostim_ops, mode=new_param
            		
            			PSID=uniqueIDs[new_param-1]
            		else
            			wavestats/q/M=1 uniqueIDs
            			PopupMenu popup_PSID win=photostim_ops, mode=V_max
            			PSID=uniqueIDs[V_maxloc]
            		endif
            		plot_stimID(PSID, applyQC=QC)
            	endif
            	
            break
        case -1: // control being killed
            break
    endswitch

    return 0
End


Function PS_ButtonProc_update(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
        	controlinfo/W=photostim_ops popup_PSID
        	variable PSID=str2num(s_value)
        	controlinfo/W=photostim_ops popup_recent
        	variable recent=V_value
        	string roundString=S_value
        	controlinfo/W=photostim_ops checkQC
			variable QC=v_value
        	if(recent==2)
        		wave round_wv=root:opto_df:round_count
            	variable round_num=round_wv[0]
            	plot_stimID(PSID, round_num=round_num, applyQC=QC)
          elseif(recent>2)
          	round_num=str2num(roundString)
          	plot_stimID(PSID, round_num=round_num, applyQC=QC)
        	else
        		plot_stimID(PSID, applyQC=QC)
        	endif
        	break
       case -1: //control being killed
       	break
       endswitch
       
       return 0
 end



Function PS_ButtonProc_plot_next(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
        		getuniquestimids()
        		controlinfo/W=photostim_ops popup_recent
        		variable recent=V_value
        		controlinfo/W=photostim_ops checkQC
				variable QC=v_value
        		wave uniqueIDs=root:opto_df:uniqueStimIDs
        		if(recent==2)
        			controlinfo/W=photostim_ops popup_PSID
            		
            		variable currentID=str2num(s_value)	
        			getrecentstimpoints()
        			wave recent_Ids=root:opto_df:recent_ids
        			FindValue/V=(currentID) recent_ids
        			variable index=v_value
        			if(index>=numpnts(recent_ids)-1)
        				variable PSID=recent_ids[0]
        			else
        				PSID=recent_ids[index+1]
        			endif
        			FindValue/V=(PSID) uniqueIDs
        			variable new_setting=v_value+1
        			PopupMenu popup_PSID win=photostim_ops, mode=new_setting
        			wave round_wv=root:opto_df:round_count
            		variable round_num=round_wv[0]
            		plot_stimID(PSID, round_num=round_num, applyQC=QC)
        		else	
            		controlinfo/W=photostim_ops popup_PSID
            		variable param0=v_value
            		variable new_param=param0+1
            		if(new_param-1<numpnts(uniqueIDs))
            			PopupMenu popup_PSID win=photostim_ops, mode=new_param
            		
            			PSID=uniqueIDs[new_param-1]
            		else
            			PopupMenu popup_PSID win=photostim_ops, mode=1
            			PSID=uniqueIDs[0]
            		endif
            		plot_stimID(PSID, applyQC=QC)
            	endif
            	
            		
            break
        case -1: // control being killed
            break
    endswitch

    return 0
End


Function ButtonProc_fail(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
        	fail_selected_sweep()
        	PS_ButtonProc_update(ba)
        	break
       case -1: //control being killed
       	break
       endswitch
       
       return 0
 end




Function/S PSID_List()
	DFREF saveDFR = GetDataFolderDFR()
	setdatafolder root:opto_df:
	wave mapInfo
	variable length=dimsize(mapInfo,0)
	make/o/n=(length) stimIDs
	stimIDs=mapInfo[p][1]
	if(length>1)
		FindDuplicates/RN=uniqueStimIDs stimIDs
		Sort uniqueStimIDs uniqueStimIDs
		WaveTransform zapNaNs, uniqueStimIds
	else 
		Duplicate/o stimIDs uniqueStimIds
	endif
	variable i
	string list=""
	for (i=0; i<numpnts(uniqueStimIDs); i+=1)
		if (uniqueStimIds[i]!=0)
			list=list+num2str(uniqueStimIDs[i])+";"
		endif
	endfor
	return list
	
	
	SetDataFolder saveDFR
end


Function/S round_list()
	DFREF saveDFR = GetDataFolderDFR()
	setdatafolder root:opto_df:
	wave mapInfo
	variable length=dimsize(mapInfo,0)
	make/o/n=(length) rounds
	rounds=mapInfo[p][6]
	if(length>1)
		FindDuplicates/RN=uniqueRounds rounds
		Sort uniqueRounds uniqueRounds
		WaveTransform zapNaNs, uniqueRounds
	else 
		Duplicate/o Rounds uniqueRounds
	endif
	variable i
	string list="all;recent;"
	for (i=0; i<numpnts(uniqueRounds); i+=1)
		if (uniqueRounds[i]!=0)
			list=list+num2str(uniqueRounds[i])+";"
		endif
	endfor
	return list
	
	
	SetDataFolder saveDFR
end	


Function getUniqueStimIDs()
	DFREF saveDFR = GetDataFolderDFR()
	setdatafolder root:opto_df:
	wave mapInfo
	variable length=dimsize(mapInfo,0)
	make/o/n=(length) stimIDs
	stimIDs=mapInfo[p][1]
	if(length>1)
		FindDuplicates/RN=uniqueStimIDs stimIDs
		Sort uniqueStimIDs uniqueStimIDs
		WaveTransform zapNaNs, uniqueStimIds
	else 
		Duplicate/o stimIDs uniqueStimIds
	endif
	SetDataFolder saveDFR
end


Function getRecentStimPoints_old()
	DFREF saveDFR = GetDataFolderDFR()
	setdatafolder root:opto_df:
	wave mapInfo
	variable length=dimsize(mapInfo,0)
	make/o/n=(length) stimIDs
	stimIDs=mapInfo[p][1]
	variable lastID=stimIDs[0]
	FindValue/s=1/V=(lastID) stimIDs
	variable repeat_i=v_value
	Duplicate/o/r=[0,repeat_i-1] stimIds recent_ids
	Sort recent_ids recent_ids
	SetDataFolder saveDFR	
end


Function getRecentStimPoints()
	DFREF saveDFR = GetDataFolderDFR()
	setdatafolder root:opto_df:
	wave mapInfo
	variable length=dimsize(mapInfo,0)
	make/o/n=(length) round_wave, stimIDs
	round_wave=mapInfo[p][6]
	stimIDs=mapInfo[p][1]
	variable last_round=wavemax(round_wave)
	Duplicate/o stimIDs recent_ids, temp
	temp=(round_wave[p]==last_round) ? stimIDs[p] : NaN
	WaveTransform zapNaNs, temp
	
	FindDuplicates/RN=recent_ids temp
	Sort recent_ids recent_ids

	SetDataFolder saveDFR
end
	
	
	


Function plot_ID_drop(PU_Struct) : PopupMenuControl
	STRUCT WMPopupAction &PU_Struct
	controlinfo/W=photostim_ops popup_PSID
	variable PSID_index=v_value-1
	wave uniquePSID=root:opto_df:uniqueStimIDs
	variable PSID=uniquePSID[PSID_index]
	controlinfo/W=photostim_ops checkQC
	variable QC=v_value
	plot_stimID(PSID, applyQC=QC)
	return 0
end

function find_powers(id)
	variable id
	DFREF saveDFR = GetDataFolderDFR()
	setdatafolder root:opto_df:
	wave mother_wv=root:opto_df:mapInfo
	variable length=dimsize(mother_wv,0)
	Make/o/n=(length) stimIDs, sweeps, powers
	stimIDs=mother_wv[p][1]
	
	duplicate/o stimIDs indexes
	indexes=(stimIDs[p]==id) ? p : NaN
	WaveTransform zapNaNs, indexes
	duplicate/o indexes sweeps, powers
	variable i
	for (i=0;i<numpnts(indexes);i+=1)
		sweeps[i]=mother_wv[indexes[i]][0]
		powers[i]=mother_wv[indexes[i]][4]
	endfor
	if(numpnts(powers)>1)
		findduplicates/rn=unique_powers powers
		sort unique_powers unique_powers
		WaveTransform zapNaNs, unique_powers
	else
		duplicate/o powers unique_powers
	endif
	SetDataFolder saveDFR
end


function find_id(id)
	variable id
	DFREF saveDFR = GetDataFolderDFR()
	setdatafolder root:opto_df:
	wave mother_wv=root:opto_df:mapInfo
	variable length=dimsize(mother_wv,0)
	Make/o/n=(length) stimIDs, sweeps, powers, z_offs
	stimIDs=mother_wv[p][1]
	powers=mother_wv[p][4]
	z_offs=mother_wv[p][13]
	duplicate/o stimIDs indexes
	indexes=(stimIDs[p]==id && powers[p]!=0 && z_offs[p]==0) ? p : NaN //indexes for stims with given ID and power not equal to 0 (trace hasn't been analyzed yet) and no z-offset
	WaveTransform zapNaNs, indexes
	duplicate/o indexes sweeps
	variable i
	for (i=0;i<numpnts(indexes);i+=1)
		sweeps[i]=mother_wv[indexes[i]][0]
	endfor
	SetDataFolder saveDFR
end


Function find_id_power(id, power)
	variable id, power
	DFREF saveDFR = GetDataFolderDFR()
	setdatafolder root:opto_df:
	wave mother_wv=root:opto_df:mapInfo
	variable length=dimsize(mother_wv,0)
	Make/o/n=(length) stimIDs, powers, z_offs
	stimIDs=mother_wv[p][1]
	powers=mother_wv[p][4]
	z_offs=mother_wv[p][13]
	duplicate/o stimIDs indexes
	indexes=(stimIDs[p]==id && powers[p]==power && z_offs[p]==0) ? p : NaN
	WaveTransform zapNaNs, indexes
	duplicate/o indexes sweeps
	variable i
	for (i=0;i<numpnts(indexes);i+=1)
		sweeps[i]=mother_wv[indexes[i]][0]
	endfor
	SetDataFolder saveDFR
	
end


Function getPassedSweeps(stim)
	variable stim
	wave mapinfo
	variable length=dimsize(mapInfo,0)
	make/o/n=(length) stimIDs, HS0QC
	stimIDs=mapinfo[p][1]
	hs0qc=mapinfo[p][7]
	duplicate/o stimIds temp
	temp=(stimIDs[p]==stim && HS0QC[p]==0) ? p : NaN
	wavestats/q/M=1 temp
	print num2str(V_npnts)+" passed QC"
end



Function find_id_round(id, round_num)
	variable id, round_num
	DFREF saveDFR = GetDataFolderDFR()
	setdatafolder root:opto_df:
	wave mother_wv=root:opto_df:mapInfo
	variable length=dimsize(mother_wv,0)
	Make/o/n=(length) stimIDs, rounds
	stimIDs=mother_wv[p][1]
	rounds=mother_wv[p][6]
	duplicate/o stimIDs indexes
	indexes=(stimIDs[p]==id && rounds[p]==round_num) ? p : NaN
	WaveTransform zapNaNs, indexes
	duplicate/o indexes sweeps
	variable i
	for (i=0;i<numpnts(indexes);i+=1)
		sweeps[i]=mother_wv[indexes[i]][0]
	endfor
	
	
	
	SetDataFolder saveDFR
end

Function clear_graph() //remove all sweeps from graph
	string sweeplist=tracenamelist("",";",1)
	variable i
	for (i=itemsinlist(sweeplist,";")-1; i>=0;i-=1) //remove all existing sweeps, this may be made optional later
		string sweepname=stringfromlist(i,sweeplist)
		RemoveFromGraph/W=photoStim_graph/Z $sweepname
	endfor
end
	
Function clean_optoDF()
	DFREF saveDFR = GetDataFolderDFR()

	setdatafolder root:opto_df:
	variable i
	string kill_list=wavelist("Sweep_*", ";","")  //sounds dark, unfortunately
	for (i=0; i<itemsinlist(kill_list,";"); i+=1)
		KillWaves/Z $(StringFromList(i, kill_list))
	endfor
	SetDataFolder saveDFR
end

Function plot_stimID(stimID,[power,round_num,applyQC])
	variable stimID, power, round_num,applyQC
	DFREF saveDFR = GetDataFolderDFR()
	clear_graph()
	clean_optoDF()
	if (ParamIsDefault(power)==1 && ParamIsDefault(round_num)==1)
		find_id(stimID)
	elseif (ParamIsDefault(round_num)==0)
		find_id_round(stimID, round_num)
	else
		find_id_power(stimID, power)
	endif
	wave sweeps=root:opto_df:sweeps
	wave indexes=root:opto_df:indexes
	wave tracking=root:opto_df:mapInfo
	variable i,j
	variable reps=numpnts(sweeps)
	DFREF saveDFR = GetDataFolderDFR()
	wave HS_check=root:opto_df:HS_selection
	//setdatafolder root:opto_df:
	string sweeplist=tracenamelist("",";",1)
	for (i=itemsinlist(sweeplist,";")-1; i>=0;i-=1) //remove all existing sweeps, this may be made optional later
		string sweepname=stringfromlist(i,sweeplist)
		RemoveFromGraph/Z $sweepname
	endfor
	
	setdatafolder root:MIES:ITCDevices:ITC18USB:Device0:Data:
	for(i=0; i<reps; i+=1) //for each sweep
		variable sweepnumber=sweeps[i]
		variable index=indexes[i]
		string config_name="Config_Sweep_"+num2str(sweepnumber)
		string sweep_name="Sweep_"+num2str(sweepnumber)
		variable pockel_start=tracking[index][3]
		
		pockel_start*=-1
		//print pockel_start
		wave W_config=$config_name
		wave W_sweep=$sweep_name
		variable trace_count=0
		for (j=0;j<dimsize(W_config,0);j+=1) //for each channel...
			if(numtype(pockel_start)==2)
				
				break
			endif
			if (W_config[j][0] == 0) //if this is an AD_trace...
				variable HS_num=W_config[j][1]
				if(HS_check[HS_num]==1) //if we want to display this trace
					if(HS_num==6)
						variable QC_state=0
					else
						QC_state=tracking[index][HS_num+7] //kludgey until something better
					endif
					if(applyQC==0 || QC_state==0) //if either QC is turned off, or this sweep/HS has not failed, plot it
					
						string temp_name=sweep_name+"_AD"+num2str(HS_num)
						string unit_s=AFH_GetChannelUnit(W_config, HS_num, 0)
						
						Duplicate/o/r=[][j] W_sweep root:opto_df:$temp_name
						wave temp_wave=root:opto_df:$temp_name
						variable dt=deltax(temp_wave)
						SetScale/P x pockel_start, dt, temp_wave
						SetScale d 0,0, unit_s, temp_wave
						if(dt<0.04)
							smooth 32, temp_wave
						else	
							smooth 20, temp_wave
						endif
						string axis_name="L_AD"+num2str(HS_num)
					
						appendtograph/L=$axis_name root:opto_df:$temp_name //append it to the correct axis				
						trace_count+=1
					endif
				endif
			endif
		endfor //end of channel loop
	endfor //end of sweep loop
	prettygraph()
	setxScale()
	color_ps_Graph()
	offset_PSgraph()
	photostim_avg()
	SetDataFolder saveDFR
end

Function prettygraph()
	DFREF saveDFR = GetDataFolderDFR()
	SetDataFolder root:opto_df
	variable i, j
	string axis_name
	string axes=axislist("")
	axes=listmatch(axes,"L*")
	axes=sortlist(axes)
	variable numaxes=itemsinlist(axes,";")
	Make/o/n=(numaxes) axeslimits
	axeslimits=1-0.9*x/(numaxes-1)
	j=0
	for (i=0;i<(numaxes);i+=1)
		axis_name=stringfromlist(i,axes)
		if(CmpStr(axis_name, "L_AD6")!=0)
			variable axisbottom = axeslimits[j+1]+.01
			variable axistop = axeslimits[j]-.01
			ModifyGraph freePos($axis_name)=0
			ModifyGraph axisEnab($axis_name)={axisbottom,axistop}
			Label $axis_name axis_name[2,4]+" (\\U)"
			ModifyGraph lblPos($axis_name)=50
			SetAxis/A=2 $axis_name
			j+=1
		endif
	endfor
	ModifyGraph margin(right)=1,margin(top)=1,margin(left)=35,margin(bottom)=30
	ModifyGraph freePos(L_AD6)=0
	ModifyGraph axisEnab(L_AD6)={0,0.09}
	Label L_AD6 "L_AD6"
	ModifyGraph lblPos(L_AD6)=50
	ModifyGraph fSize=8
	ModifyGraph axThick=1.2
	ModifyGraph nticks=3
	ModifyGraph grid(bottom)=1,gridStyle(bottom)=2,gridHair(bottom)=0
	SetDataFolder saveDFR
end


Function setXScale()
	controlinfo/W=photostim_ops checkscale
	variable scale=v_value
	if (scale==1)
		Setaxis/A/W=photostim_graph bottom
	else
		controlinfo/W=photostim_ops setvarXmin
		variable minx=v_value
		controlinfo/W=photostim_ops setvarXmax
		variable maxx=v_value
		Setaxis/W=photoStim_Graph bottom minx, maxx
	endif
end


Function average_each_axis()
	DFREF saveDFR = GetDataFolderDFR()
	SetDataFolder root:opto_df
	controlinfo/W=photostim_ops popup_PSID
	variable PSID_index=v_value-1
	wave uniquePSID=root:opto_df:uniqueStimIDs
	variable PSID=uniquePSID[PSID_index]
	string axes=axislist("")
	axes=listmatch(axes, "L*")
	variable numaxes = itemsinlist(axes,";")
	variable i
	for (i=0; i<(numaxes);i+=1)
		string axis_name=stringfromlist(i,axes)
		if(CmpStr(axis_name,"L_AD6")!=0)
			string wavematch=axis_name[2,4]
			string average_name = "photoStim_"+num2str(PSID)+"_"+wavematch+"_avg"
			string error_name = "photoStim_"+num2str(PSID)+"_"+wavematch+"_err"
			string sweep_list_axis = waveList(("*"+wavematch), ";", "WIN:")
			fWaveAverage(sweep_list_axis,"",1,1,average_name,error_name)
			wave average_wave=$average_name
			wave error_wave=$error_name
			appendtograph/l=$axis_name average_wave		
			ErrorBars $average_name SHADE= {0,4,(0,0,0,0),(0,0,0,0)},wave=(error_wave,error_wave)
			ModifyGraph lsize($average_name)=1.2
		endif
	endfor
	SetDataFolder saveDFR
end

Function photostim_avg()
	controlinfo/W=photostim_ops checkAverage
	variable average=v_value
	if (average==1)
		average_each_axis()

	endif
end

Function remove_avg()
	string sweeplist=tracenamelist("",";",1)
	sweeplist=listmatch(sweeplist, "*_avg")
	variable i
	for (i=itemsinlist(sweeplist,";")-1; i>=0;i-=1) 
		string sweepname=stringfromlist(i,sweeplist)
		
		RemoveFromGraph/W=photoStim_graph/Z $sweepname
	endfor
end



Function offset_y(start_base,end_base)
	variable start_base, end_base
	string sweeplist=tracenamelist("",";",1)
	variable total_traces=itemsinlist(sweeplist,";")
	variable trace
	for (trace=0;trace<total_traces; trace+=1)
		wave theWave=WaveRefINdexed("",trace,1)
		variable med=median(theWave,start_base,end_base)
		theWave=theWave-med
	endfor

end

Function offset_PSgraph()
	controlinfo/W=photostim_ops checkyoffset
	variable check=v_value
	if(check==1)
		offset_y(-50,0)
	endif
end




Function makeTempSweep(variable sweepnumber)
	
	string sweep_name="sweep_"+num2str(sweepnumber)
	string config_name="Config_Sweep_"+num2str(sweepnumber)
	wave mapinfo=root:opto_df:mapinfo
	wave HS_check=root:opto_df:HS_selection
	variable index=finddimlabel(mapinfo,0,sweep_name)
	setdatafolder root:MIES:ITCDevices:ITC18USB:Device0:Data:
	
		
		
	//string sweep_name="Sweep_"+num2str(sweepnumber)
	variable pockel_start=mapinfo[index][3]

	pockel_start*=-1
	
	wave W_config=$config_name
	wave W_sweep=$sweep_name
	variable j
	for (j=0;j<dimsize(W_config,0);j+=1) //for each channel...
		if(pockel_start>0)
				
			
		
			if (W_config[j][0] == 0) //if this is an AD_trace...
				variable HS_num=W_config[j][1]
					if(HS_check[HS_num]==1)
					
					string temp_name=sweep_name+"_AD"+num2str(HS_num)
				
					Duplicate/o/r=[][j] W_sweep root:opto_df:$temp_name
					wave temp_wave=root:opto_df:$temp_name
					SetScale/P x pockel_start, deltax(temp_wave), temp_wave
					//string axis_name="L_AD"+num2str(HS_num)
					//appendtograph/L=$axis_name root:opto_df:$temp_name //append it to the correct axis				
					
					endif
			endif
		endif
		endfor //end of channel loop
		
	
end


Function check_baseline_for_sweep(sweep,[target_v])
	variable sweep, target_v
	variable tolerance = 5
	variable clampMode
	DFREF saveDFR = GetDataFolderDFR()
	wave mapInfo_wv=root:opto_df:mapInfo
	string panelTitle="ITC18USB_Dev_0"
	WAVE numericalValues = GetLBNumericalValues(panelTitle)
	
	wave/z clampModes=getlastsetting(numericalValues,sweep,"Clamp Mode",DATA_ACQUISITION_MODE)
	wavestats/q clampModes
	variable anyCC=V_sum
	if(anyCC>0)
		wave/z targetVs=getlastsetting(numericalValues,sweep,"Autobias Vcom",DATA_ACQUISITION_MODE)
	endif
	setdatafolder root:MIES:ITCDevices:ITC18USB:Device0:Data:
	string config_name="Config_Sweep_"+num2str(sweep)
	string sweep_name="Sweep_"+num2str(sweep)
	variable dimLabel=FindDimLabel(mapInfo_wv,0,sweep_name)
	if(dimLabel==-2)
		print "sweep "+num2str(sweep)+" not found during baseline check"
	endif
	wave W_config=$config_name
	wave W_sweep=$sweep_name
	variable pockel_start=mapInfo_wv[dimLabel][3]
		
	pockel_start*=-1
	variable j
	for (j=0;j<dimsize(W_config,0);j+=1)
		if (W_config[j][0] == 0) //if this is an AD_trace...
			variable HS_num=W_config[j][1]
			if (HS_num<=3)
				string dimlabel_name="AD"+num2str(HS_num)+"_qc"
				variable HS_dimLabel=FindDimLabel(mapInfo_wv,1,dimlabel_name)
				if(numtype(mapinfo_wv[dimlabel][HS_dimlabel])==2)
					mapinfo_wv[dimlabel][HS_dimlabel]=0
			
					string temp_name=sweep_name+"_AD"+num2str(HS_num)
					//print "target V is "+num2str(targetvs[HS_num])
					
					clampMode=clampModes[HS_num]
					if (clampMode == 1)
						target_v=targetvs[HS_num]
						Duplicate/o/r=[][j] W_sweep root:opto_df:$temp_name
						wave temp_wave=root:opto_df:$temp_name
						SetScale/P x pockel_start, deltax(temp_wave), temp_wave
						wavestats/M=1/q/r=[0,100] temp_wave
						variable startV=V_avg
						if (abs(startV-target_v)>tolerance)
							print sweep_name+", headstage "+num2str(HS_num)
							print "    starting V = "+num2str(startV)
							mapinfo_wv[dimlabel][HS_dimlabel]+=1
						endif
						variable lastp=numpnts(temp_wave)
						wavestats/M=1/q/r=[lastp-100, lastp] temp_wave
						variable endV=V_avg
						if(abs(endV-startv)>3)
							print sweep_name+", headstage "+num2str(HS_num)
							print "    big change"
							mapinfo_wv[dimlabel][HS_dimlabel]+=1
						endif
						wavestats/M=1/q/r=(-20,0) temp_wave
						variable range=V_max-V_min
						if(range>=1)
							print sweep_name+", headstage "+num2str(HS_num)
							print "   sudden change before stim"
							mapinfo_wv[dimlabel][HS_dimlabel]+=1
						endif
					endif
				endif
			endif
				
			
	
	
		endif
	endfor
	SetDataFolder saveDFR
end


	
Function fail_selected_sweep()
	string trace_name=csrwave(A)
	variable sweepend=strsearch(trace_name,"_",6) //sweep name will be Sweep_**_AD* number of digits in sweep number could be 1-4
	variable sweep_number=str2num(trace_name[6,sweepend-1])
	variable HS_number=str2num(trace_name[strlen(trace_name)-1,strlen(trace_name)])
	wave mapinfo_wv=root:opto_df:mapinfo
	string sweep_name="Sweep_"+num2str(sweep_number)
	variable dimLabel=FindDimLabel(mapinfo_wv,0,sweep_name)
	variable column_number=7+HS_number
	mapinfo_wv[dimLabel][column_number]+=10
end

Function call_cnx(riseOrFall)
	variable riseOrFall
	string trace_name=csrwave(A, "photoStim_graph")
	if (strlen(trace_name)<1)
		print "cursor is not on a wave"
		return 0
	endif
	variable HS_loc=strsearch(trace_name, "AD",0)+2
	variable headstage=str2num(trace_name[HS_loc])
	
	controlinfo/W=photostim_ops popup_PSID
    
   string photostim_name="photoStim_"+s_value+"_AD"+num2str(headstage)
   variable PS_ID=str2num(s_value)
	make_cnx_folder(photostim_name)
	//SetDataFolder "root:opto_df:"+photostim_name
	//get_EPSP_props_graph(PS_ID,headstage, photostim_name)
	get_PSP_props_graph(riseORfall, PS_ID, headstage, photostim_name)
end





function check_baselin_for_sweep_CC(sweep_wv, HS_num, dimLabel, HS_dimLabel)
	wave sweep_wv
	variable HS_num, dimLabel, HS_dimLabel
	variable tolerance=5
	wave mapInfo_wv=root:opto_df:mapInfo
	wave targetvs=root:opto_df:targetvs
	string panelTitle="ITC18USB_Dev_0"
	string sweep_name=nameofwave(sweep_wv)
	wavestats/M=1/q/r=[0,100] sweep_wv
	variable target_v=targetvs[HS_num]
	variable startV=V_avg
	if (abs(startV-target_v)>tolerance)
		print sweep_name+", headstage "+num2str(HS_num)
		print "    starting V = "+num2str(startV)
		mapinfo_wv[dimlabel][HS_dimlabel]+=1
	endif
	variable lastp=numpnts(sweep_wv)
	wavestats/M=1/q/r=[lastp-100, lastp] sweep_wv
	variable endV=V_avg
	if(abs(endV-startv)>3)
		print sweep_name+", headstage "+num2str(HS_num)
		print "    big change"
		mapinfo_wv[dimlabel][HS_dimlabel]+=1
	endif
	wavestats/M=1/q/r=(-20,0) sweep_wv
	variable range=V_max-V_min
	if(range>=1)
		print sweep_name+", headstage "+num2str(HS_num)
		print "   sudden change before stim"
		mapinfo_wv[dimlabel][HS_dimlabel]+=1
	endif

end

function check_baseline_for_sweep_VC(sweep_wv, HS_num, dimLabel, HS_dimLabel)
	wave sweep_wv
	variable HS_num, dimLabel, HS_dimLabel
	variable max_i=1000
	wave mapInfo_wv=root:opto_df:mapInfo
	string panelTitle="ITC18USB_Dev_0"
	string sweep_name=nameofwave(sweep_wv)
	wavestats/M=1/q/r=[0,100] sweep_wv
	variable startI=V_avg
	if (abs(startI)>max_i)
		print sweep_name+", headstage "+num2str(HS_num)
		print "    holding current "+num2str(startI)
		mapinfo_wv[dimlabel][HS_dimlabel]+=1
	endif
	variable lastp=numpnts(sweep_wv)
	wavestats/M=1/q/r=[lastp-100, lastp] sweep_wv
	variable endI=V_avg
	if(abs(endI-startI)>100)
		print sweep_name+", headstage "+num2str(HS_num)
		print "    big change"
		mapinfo_wv[dimlabel][HS_dimlabel]+=1
	endif
end





Function show_z_off(stimPoint, HS, round_id, applyQC)
	variable stimPoint, HS, round_id, applyQC
	variable i,j
	DFREF saveDFR = GetDataFolderDFR()
	find_id_round(stimPoint, round_id)
	wave sweeps=root:opto_df:sweeps
	wave indexes=root:opto_df:indexes
	wave tracking=root:opto_df:mapInfo
	variable reps=numpnts(sweeps)
	Display
	
	setdatafolder root:MIES:ITCDevices:ITC18USB:Device0:Data:
	for(i=0; i<reps; i+=1) //for each sweep
		variable sweepnumber=sweeps[i]
		variable index=indexes[i]
		string config_name="Config_Sweep_"+num2str(sweepnumber)
		string sweep_name="Sweep_"+num2str(sweepnumber)
		variable pockel_start=tracking[index][3]
		
		pockel_start*=-1
		
		wave W_config=$config_name
		wave W_sweep=$sweep_name
		variable trace_count=0
		for (j=0;j<dimsize(W_config,0);j+=1) //for each channel...
			if(numtype(pockel_start)==2)
				
				break
			endif
			if (W_config[j][0] == 0) //if this is an AD_trace...
				variable HS_num=W_config[j][1]
				if(HS_num==HS || HS_num==6) //if we want to display this trace
					if(HS_num==6)
						variable QC_state=0
						string axis_name="L_AD"+num2str(HS_num)
						string z_string=""
					else
						QC_state=tracking[index][HS_num+7] //kludgey until something better
						variable z_off=tracking[index][13]*1e6
						if(z_off<0)
							//axis_name="L_n"+num2str(abs(z_off))
							z_string="n"+num2str(abs(z_off))
						else
							z_string="p"+num2str(abs(z_off))
							//axis_name="L_"+num2str(z_off)
						endif
							axis_name="L_"+z_string
					endif
					if(applyQC==0 || QC_state==0) //if either QC is turned off, or this sweep/HS has not failed, plot it
					
						string temp_name=sweep_name+"_AD"+num2str(HS_num)+z_string
						string unit_s=AFH_GetChannelUnit(W_config, HS_num, 0)
						
						Duplicate/o/r=[][j] W_sweep root:opto_df:$temp_name
						wave temp_wave=root:opto_df:$temp_name
						variable dt=deltax(temp_wave)
						SetScale/P x pockel_start, dt, temp_wave
						SetScale d 0,0, unit_s, temp_wave
						if(dt<0.04)
							smooth 32, temp_wave
						else	
							smooth 20, temp_wave
						endif
						
					
						appendtograph/L=$axis_name root:opto_df:$temp_name //append it to the correct axis				
						trace_count+=1
					endif
				endif
			endif
		endfor //end of channel loop
	endfor //end of sweep loop
	ModifyGraph rgb=(0,0,0)
	SetDataFolder saveDFR
	offset_y(-10,0)
	pretty_zoff()
	zoff_avg()

end

function pretty_zoff()
	DFREF saveDFR = GetDataFolderDFR()
	SetDataFolder root:opto_df
	variable i, j
	string axis_name
	string axes="L_p30;L_p20;L_p10;L_p0;L_n10;L_n20;L_n30;L_ad6"
	string labels="+30 μm\r(\\U);+20μm\r(\\U);+10μm\r(\\U);0μm\r(\\U);-10μm\r(\\U);-20μm\r(\\U);-30μm\r(\\U)"
	variable numaxes=itemsinlist(axes,";")
	Make/o/n=(numaxes) axeslimits
	axeslimits=1-0.9*x/(numaxes-1)
	j=0
	for (i=0;i<(numaxes);i+=1)
		axis_name=stringfromlist(i,axes)
		string label_i=stringfromlist(i,labels)
		if(CmpStr(axis_name, "L_AD6")!=0)
			variable axisbottom = axeslimits[j+1]+.01
			variable axistop = axeslimits[j]-.01
			ModifyGraph freePos($axis_name)=0
			ModifyGraph axisEnab($axis_name)={axisbottom,axistop}
			//Label $axis_name axis_name[2,4]+" (\\U)"
			Label $axis_name label_i
			ModifyGraph lblPos($axis_name)=50
			SetAxis/A=2 $axis_name
			j+=1
		endif
	endfor
	ModifyGraph margin(right)=1,margin(top)=1,margin(left)=35,margin(bottom)=30
	ModifyGraph freePos(L_AD6)=0
	ModifyGraph axisEnab(L_AD6)={0,0.09}
	Label L_AD6 "L_AD6"
	ModifyGraph lblPos(L_AD6)=50
	ModifyGraph fSize=8
	ModifyGraph axThick=1.2
	ModifyGraph nticks=3
	SetDataFolder saveDFR
end

function zoff_avg()
	DFREF saveDFR = GetDataFolderDFR()
	SetDataFolder root:opto_df
	string axes=axislist("")
	axes=listmatch(axes, "L*")
	variable numaxes = itemsinlist(axes,";")
	variable i
	for (i=0; i<(numaxes);i+=1)
		string axis_name=stringfromlist(i,axes)
		if(CmpStr(axis_name,"L_AD6")!=0)
			string wavematch=axis_name[2,4]
			string average_name=wavematch+"_avg"
			string error_name=wavematch+"_err"
			string sweep_list_axis = waveList(("*"+wavematch+"*"), ";", "WIN:")
			fWaveAverage(sweep_list_axis,"",1,1,average_name,error_name)
			wave average_wave=$average_name
			wave error_wave=$error_name
			appendtograph/l=$axis_name average_wave		
			ErrorBars $average_name SHADE= {0,4,(0,0,0,0),(0,0,0,0)},wave=(error_wave,error_wave)
			ModifyGraph lsize($average_name)=1.2
		endif
	endfor
	SetDataFolder saveDFR
end


