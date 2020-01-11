#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// This file can be used for user analysis functions.
// It will not be overwritten by MIES on an upgrade.







Function check_pockel(paneltitle, s) //this function can be associated with mapping sweep, to be cleaned up, appended
	string paneltitle
	STRUCT AnalysisFunction_V3 &s
	wave mapInfo_wv=root:opto_df:mapInfo
	switch(s.eventType)
		case PRE_DAQ_EVENT:
			//print "this pre-daq!"
			break
		case PRE_SET_EVENT:
			//print "I hope there's a Pockel cell pulse!"

			break
		case POST_SWEEP_EVENT:
			
			
			//setdatafolder root:MIES:ITCDevices:ITC18USB:Device0:Data:
    		variable LastSweep = AFH_GetLastSweepAcquired("ITC18USB_Dev_0")
    		//print lastsweep
    		//string dim_name="sweep_"+num2str(LastSweep)
			//variable dimLabel=FindDimLabel(mapInfo_wv,0,dim_name)
			//if(dimLabel==-2) //if there's not a row for this sweep yet - could be cleaned up when other variables are settled on
				//InsertPoints/M=0 0, 1, mapInfo_wv
				//SetDimLabel 0, 0, $dim_name, mapInfo_wv
				//dimLabel=0
			//endif	
			//mapInfo_wv[dimLabel][0]=LastSweep
			//variable stimPoint_ID=mapInfo_wv[dimLabel][1]
			//variable stim_num=mapInfo_wv[dimLabel][2]
			wave sP_ID_wv=root:opto_df:photoStim_ID
			wave stim_num_wv=root:opto_df:stim_num
			wave x_off_wv=root:opto_df:x_off
			wave y_off_wv=root:opto_df:y_off
			wave z_off_wv=root:opto_df:z_off
			//sp_ID_wv[8]=stimPoint_ID
			//stim_num_wv[8]=stim_num
			ED_addentrytolabnotebook("ITC18USB_Dev_0", "stimPoint_ID", sP_ID_wv)
			ED_addentrytolabnotebook("ITC18USB_Dev_0", "stim_num", stim_num_wv)
			ED_addentrytolabnotebook("ITC18USB_Dev_0", "x_offset", x_off_wv)
			ED_addentrytolabnotebook("ITC18USB_Dev_0", "y_offset", y_off_wv)
			ED_addentrytolabnotebook("ITC18USB_Dev_0", "z_offset", z_off_wv)
			pockel_times_for_sweep(LastSweep)
			check_baseline_for_sweep(LastSweep)
			break
		case POST_SET_EVENT:
			
			break
	endswitch
	
	
end





