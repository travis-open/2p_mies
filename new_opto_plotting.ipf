#pragma TextEncoding = "Windows-1252"
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
	PopupMenu popup_recent, title=" ", help={"display all data or only most recent round"}, value="all;recent"
	Checkbox checkAverage, title="average", value=0, help={"plot the average and S.D., other options may be ignored"}, proc=avg_CB_proc
	Checkbox checkYoffset, title="offset Y", value=1, help={"crude baseline offset"}, proc=PS_Yoffset_proc
	Checkbox checkScale, title="full scale?", value=0, help={"display entire wave, ignore settings below"}, proc=fullscale_checkbox_proc
	Checkbox checkDistOn, title="distribute", value=0, help={"keep distribute on"},  proc=PS_CheckDist_proc
	Checkbox checkColorOn, title="color", value=0, help={"keep color on"},  proc=color_CB_proc
	SetVariable setvarXmin title="X min", bodyWidth=45, value= _NUM:-50, limits={-10000,10000,10}, proc=SV_setxscale
	SetVariable setvarXmax title="X max", bodyWidth=45, value= _NUM:150, limits={-10000,10000,10}, proc=SV_setxscale
	Button button2 title="highlighter", proc=ButtonProc_highlighter, size={70,20}, help={"highlight single trace, cycles through"}
	PopupMenu popup_power title="powers", value=power_list(), proc=plot_power_drop, help={"select power(s) to display"}
	Button buttonQC title="QC", proc=PS_ButtonProc_QC, size={35,20}, help={"check photostim timing"}
	Checkbox HS_all, title="all", value=1, help={"display all headstages with data"}, proc=HS_CB_proc
	Checkbox HS_0, title="HS 0", value=0, help={"toggle headstage display"}, proc=HS_CB_proc
	Checkbox HS_1, title="HS 1", value=0, help={"toggle headstage display"}, proc=HS_CB_proc
	Checkbox HS_2, title="HS 2", value=0, help={"toggle headstage display"}, proc=HS_CB_proc
	Checkbox HS_3, title="HS 3", value=0, help={"toggle headstage display"}, proc=HS_CB_proc
	
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
	if (power_index>=0)
		wave unique_powers=root:opto_df:unique_powers
		variable power=unique_powers[power_index]
		plot_stimID(PSID, power=power)
		
	else 
		plot_stimID(PSID)
		
	endif
	return 0
end
	
Function PS_ButtonProc_QC(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up : PopupMenuControl
		wave mapinfo=root:opto_df:mapinfo
		variable last_sweep=mapInfo[0][0]
		pockel_times_for_sweep(7)
		check_pockel_times()
		break
		case -1: // control being killed
            break
    endswitch

		
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
       plot_stimID(PSID)
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
            		plot_stimID(PSID, round_num=round_num)
            
            	else	
            		controlinfo/W=photostim_ops popup_PSID
            		variable param0=v_value
            		variable new_param=param0-1
            		print new_param
            		if(new_param>0)
            			PopupMenu popup_PSID win=photostim_ops, mode=new_param
            		
            			PSID=uniqueIDs[new_param-1]
            		else
            			wavestats/q uniqueIDs
            			PopupMenu popup_PSID win=photostim_ops, mode=V_max
            			PSID=uniqueIDs[V_maxloc]
            		endif
            		plot_stimID(PSID)
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
        	if(recent==2)
        		wave round_wv=root:opto_df:round_count
            	variable round_num=round_wv[0]
            	plot_stimID(PSID, round_num=round_num)
          else
        	
        		plot_stimID(PSID)
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
            		plot_stimID(PSID, round_num=round_num)
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
            		plot_stimID(PSID)
            	endif
            	
            		
            break
        case -1: // control being killed
            break
    endswitch

    return 0
End

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
	plot_stimID(PSID)
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
	Make/o/n=(length) stimIDs, sweeps, powers
	stimIDs=mother_wv[p][1]
	powers=mother_wv[p][4]
	duplicate/o stimIDs indexes
	indexes=(stimIDs[p]==id && powers[p]!=0) ? p : NaN //indexes for stims with given ID and power not equal to 0 (trace hasn't been analyzed yet)
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
	Make/o/n=(length) stimIDs, powers
	stimIDs=mother_wv[p][1]
	powers=mother_wv[p][4]
	duplicate/o stimIDs indexes
	indexes=(stimIDs[p]==id && powers[p]==power) ? p : NaN
	WaveTransform zapNaNs, indexes
	duplicate/o indexes sweeps
	variable i
	for (i=0;i<numpnts(indexes);i+=1)
		sweeps[i]=mother_wv[indexes[i]][0]
	endfor
	SetDataFolder saveDFR
	
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

Function plot_stimID(stimID,[power,round_num])
	variable stimID, power, round_num
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
				if(HS_check[HS_num]==1)
					
					string temp_name=sweep_name+"_AD"+num2str(HS_num)
				
					Duplicate/o/r=[][j] W_sweep root:opto_df:$temp_name
					wave temp_wave=root:opto_df:$temp_name
					SetScale/P x pockel_start, deltax(temp_wave), temp_wave
					string axis_name="L_AD"+num2str(HS_num)
					appendtograph/L=$axis_name root:opto_df:$temp_name //append it to the correct axis				
					trace_count+=1
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
			Label $axis_name axis_name
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
	for (i=itemsinlist(sweeplist,";")-1; i>=0;i-=1) //remove all existing sweeps, this may be made optional later
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