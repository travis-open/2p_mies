#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// This file can be used for user analysis functions.
// It will not be overwritten by MIES on an upgrade.



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



Function check_pockel(paneltitle, s) //this function can be associated with mapping sweep, to be cleaned up, appended
	string paneltitle
	STRUCT AnalysisFunction_V3 &s
	
	switch(s.eventType)
		case PRE_DAQ_EVENT:
			//print "this pre-daq!"
			
		case PRE_SET_EVENT:
			print "I hope there's a Pockel cell pulse!"

			break
		case POST_SWEEP_EVENT:
			setdatafolder root:MIES:ITCDevices:ITC18USB:Device0:Data:
    		variable LastSweep = AFH_GetLastSweepAcquired("ITC18USB_Dev_0")
    
    
    		string config_name="Config_Sweep_"+num2str(LastSweep)
    		string sweep_name="Sweep_"+num2str(LastSweep)
    		wave W_config=$config_name
    		wave W_sweep=$sweep_name
    		variable col_num=AFH_GetITCDataColumn(W_config, 6, 0) //data column corresponding to AD_6, where we record PC output
    		Duplicate/o/r=[][col_num] W_sweep, tempAD6
    		FindLevel/q tempAD6 0.05
    		variable time_crossing=V_LevelX
    		if (V_flag == 1)
        		//make_missed_pockel(LastSweep)
        		print "No Pockel cell output detected when one was expected on "+sweep_name
        	else 
        		print "crossing occured at " +num2str(time_crossing)+" ms"
    		endif

			break
		case POST_SET_EVENT:
			print "set is over"
			break
	endswitch
	
	
end





