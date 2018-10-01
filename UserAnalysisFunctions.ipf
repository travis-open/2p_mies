#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// This file can be used for user analysis functions.
// It will not be overwritten by MIES on an upgrade.







Function check_pockel(paneltitle, s) //this function can be associated with mapping sweep, to be cleaned up, appended
	string paneltitle
	STRUCT AnalysisFunction_V3 &s
	wave sweep_track_wv=root:opto_df:sweep_tracking
	switch(s.eventType)
		case PRE_DAQ_EVENT:
			//print "this pre-daq!"
			
		case PRE_SET_EVENT:
			//print "I hope there's a Pockel cell pulse!"

			break
		case POST_SWEEP_EVENT:
			
			//InsertPoints/M=0 0, 1, sweep_track_wv
			setdatafolder root:MIES:ITCDevices:ITC18USB:Device0:Data:
    		variable LastSweep = AFH_GetLastSweepAcquired("ITC18USB_Dev_0")
    		string config_name="Config_Sweep_"+num2str(LastSweep)
    		string sweep_name="Sweep_"+num2str(LastSweep)
    		wave W_config=$config_name
    		wave W_sweep=$sweep_name
    		variable col_num=AFH_GetITCDataColumn(W_config, 6, 0) //data column corresponding to AD_6, where we record PC output
    		Duplicate/o/r=[][col_num] W_sweep, tempAD6
    		FindLevel/q tempAD6 0.05
    		if (V_flag == 1)
    			print "No Pockel cell output detected when one was expected on "+sweep_name
    			variable time_crossing=NaN
    		else
    			time_crossing=V_LevelX
    		endif
    		string dim_name="sweep_"+num2str(LastSweep)
			variable dimLabel=FindDimLabel(sweep_track_wv,0,dim_name)
			if(dimLabel==-2) //if there's not a row for this sweep yet - could be cleaned up when other variables are settled on
				InsertPoints/M=0 0, 1, sweep_track_wv
				SetDimLabel 0, 0, $dim_name, sweep_track_wv
				sweep_track_wv[0][%sweep]=LastSweep
				sweep_track_wv[0][%pockel_start]=time_crossing
			else
				sweep_track_wv[dimLabel][%sweep]=LastSweep
				sweep_track_wv[dimLabel][%pockel_start]=time_crossing
			endif

			break
		case POST_SET_EVENT:
			
			break
	endswitch
	
	
end





