#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.



Function update_mapInfo() //add columns for QC
	wave mapInfo=root:opto_df:mapInfo
	Redimension/N=(-1,14) mapInfo
	SetDimLabel 1, 6, round_ID, mapinfo
	SetDimLabel 1, 7, AD0_qc, mapinfo
	SetDimLabel 1, 8, AD1_qc, mapinfo
	SetDimLabel 1, 9, AD2_qc, mapinfo
	SetDimLabel 1, 10, AD3_qc, mapinfo
	SetDimLabel 0, 0, sweep_0, mapInfo
	mapInfo[][7]=NaN
	mapInfo[][8]=NaN
	mapInfo[][9]=NaN
	mapInfo[][10]=NaN
	make_cnx_stats()
end

function posthoc_qc(first, last)
	variable first, last
	variable i
	for (i=first; i<=last; i+=1)
		pockel_times_for_sweep(i)
		check_baseline_for_sweep(i)
	endfor
	
end


function get_EPSP_props_graph(PS_ID, headstage, photostim_name, [time_start, time_end]) //measure PSP properties based on plotted sweeps for a given headstage
	variable PS_ID, headstage, time_start, time_end
	string photostim_name
	variable start_window=xcsr(A)
	variable end_window=xcsr(B)
	if (paramisdefault(time_start)==1)
		time_start=0
	endif
	if (paramisdefault(time_end)==1)
		time_end=50
	endif
	wave stats_wave=root:opto_df:stats_values
	stats_wave[0]=PS_ID
	stats_wave[1]=headstage
	DFREF opto_df=root:opto_df:
	dfref PS_df= root:opto_df:$photostim_name
	SetDataFolder opto_df
	string traceList=tracenamelist("",";",1)
	string HS_match="AD"+num2str(headstage)
	string sweep_list_HS=waveList(("*"+HS_match), ";", "WIN:")
	sweep_list_Hs=sortlist(sweep_list_HS)
	
	Make/o/T/N=(ItemsInList(sweep_list_HS, ";")) sweeps_used
	sweeps_used = StringFromList(p, sweep_list_HS, ";")
	string avg_list=waveList(("*"+HS_match+"_avg"), ";", "WIN:")
	string avg_name=stringfromlist(0,avg_list)
	string decon_name=avg_name+"decon"
	wave avg_wave= root:opto_df:$avg_name
	
	deconvolve_wave(avg_wave,20)
	wave decon_wave=$decon_name
	
	
	wavestats/q/r=(-50,0) decon_wave
	wavestats/q/r=(0,50) decon_wave
	variable threshold=V_max*0.5
	FindLevels/q/EDGE=1/B=5/R=(0,50)/DEST=crossings/M=4 decon_wave, threshold
	if(numpnts(crossings)>1)
		variable start=crossings[0]
		FindLevel/q/EDGE=2/B=5/R=(crossings[0],crossings[1]) decon_wave, 0 //find where the deconv wave is flat and use that as the end point in peak search
		variable stop=V_LevelX
		wavestats/q/r=(crossings[0], crossings[1]) decon_wave
		stop=V_minloc
		
		//estimate PPR here
		wavestats/q/r=(start, stop) decon_wave
		variable first=V_max
		variable first_time=V_maxloc
		if(numpnts(crossings)>2)
			FindLevel/q/EDGE=2/B=5/R=(crossings[1],crossings[2]) decon_wave, 0 //find where the deconv wave is flat and use that as the end point in peak search
			variable stop2=V_levelX
			
			wavestats/q/r=(crossings[1],stop2) decon_wave
			variable second=V_max
			variable second_time=V_maxloc
		else
			wavestats/q/r=(crossings[1],crossings[1]+5) decon_wave
			second=V_max
			second_time=V_maxloc
		endif
		variable PPR=second/first
		variable PPR_interval=second_time-first_time
		
	else
		start=crossings[0]
		
		stop=crossings[0]+5	
		PPR=NaN
		PPR_interval=NaN
	endif
	
	stats_wave[10]=PPR
	stats_wave[11]=PPR_interval
	wavestats/q/r=(start, stop) avg_wave
	variable peak_in_avg=V_max
	stats_wave[2]=peak_in_avg
	variable timeOfPeak=V_maxloc
	stats_wave[8]=timeOfPeak
	
	FindLevel/q/EDGE=1/R=(0,timeOfPeak) avg_wave, peak_in_avg*.1
	variable t10=V_levelX
	FindLevel/q/EDGE=1/R=(0,timeOfPeak) avg_wave, peak_in_avg*.2
	variable t20=V_levelX
	FindLevel/q/EDGE=1/R=(0,timeOfPeak) avg_wave, peak_in_avg*.5
	variable t50=V_levelX
	FindLevel/q/EDGE=1/R=(0,timeOfPeak) avg_wave, peak_in_avg*.8
	variable t80=V_levelX
	FindLevel/q/EDGE=1/R=(0,timeOfPeak) avg_wave, peak_in_avg*.9
	variable t90=V_levelX
	FindLevel/q/EDGE=2/R=(timeOfPeak,rightx(avg_wave)) avg_wave, peak_in_avg*.5
	variable t50fall=V_levelX
	
	
	variable rise2080=t80-t20
	variable rise1090=t90-t10
	if(numpnts(crossings)>1)
		variable halfwidth=NaN
	else
		halfwidth=t50fall-t50
	endif
	stats_wave[5]=rise1090
	stats_wave[6]=rise2080
	stats_wave[7]=halfwidth
	variable i
	variable numberOfSweeps=itemsinlist(sweep_list_hs,";")
	
	Make/o/n=(numberofsweeps) peaks, peak_times

	
	for (i=0; i<numberofsweeps;i+=1)
		string thisWaveName=stringfromlist(i,sweep_list_HS)
		wave thisWave=root:opto_df:$thisWaveName
		wavestats/q/r=(timeOfPeak-2.5,stop) thisWave //find a peak near the avg peak
		//wavestats/q/r=(start_window,end_window) thiswave
		
		
		peaks[i]=V_max
		peak_times[i]=V_maxLoc
		//deconvolve_wave(thisWave,20)
		//string idecon_wave_name=thisWaveName+"decon"
		//wave idecon_wave=$idecon_wave_name
		//wavestats/q/r=(start_window,end_window) idecon_wave
		//variable peakDc=V_maxloc
		//variable newstart=leftx(idecon_wave)-peakDc
		//SetScale/P x newstart,deltax(idecon_wave), idecon_wave
		//SetScale/P x newstart,deltax(thisWave), thiswave
	endfor
	wavestats/q peaks
	variable avg_by_peaks=V_avg
	variable CV=abs(V_sdev/V_avg)
	stats_wave[4]=CV
	stats_wave[3]=avg_by_peaks
	wavestats/q peak_times
	variable jitter=V_sdev
	stats_wave[9]=jitter
	Duplicate/o peaks PS_df:peaks
	Duplicate/o peak_times PS_df:peak_times
	Duplicate/o sweeps_used PS_df:sweeps_used
	Duplicate/o avg_wave PS_df:avg_wave
	save_cnx_stats(photostim_name, stats_wave)
end



function get_PSP_props_graph(riseORfall, PS_ID, headstage, photostim_name, [time_start, time_end]) //measure PSP properties based on plotted sweeps for a given headstage
	variable riseORfall, PS_ID, headstage, time_start, time_end
	string photostim_name
	make_cnx_folder(photostim_name) //make a data folder to keep connection info
	variable start_window=xcsr(A) //not implemented yet, possibly have user indicate where on trace peak of interest occured
	variable end_window=xcsr(B)
	if (paramisdefault(time_start)==1)
		time_start=0  //by default look for PSP responses from 0 to 50 ms after the start of the pulse
	endif
	if (paramisdefault(time_end)==1)
		time_end=50
	endif
	wave stats_wave=root:opto_df:stats_values //reference to where cnx info is stored for an experiment
	stats_wave[0]=PS_ID   // store PS_ID and headstage
	stats_wave[1]=headstage
	DFREF opto_df=root:opto_df:
	dfref PS_df= root:opto_df:$photostim_name
	SetDataFolder opto_df
	string traceList=tracenamelist("",";",1) //all plotted traces
	string HS_match="AD"+num2str(headstage)
	string sweep_list_HS=waveList(("*"+HS_match), ";", "WIN:") //all plotted traces for a given headstage
	sweep_list_Hs=sortlist(sweep_list_HS)
	
	Make/o/T/N=(ItemsInList(sweep_list_HS, ";")) sweeps_used //make the list a textwave for storing
	sweeps_used = StringFromList(p, sweep_list_HS, ";")
	string avg_list=waveList(("*"+HS_match+"_avg"), ";", "WIN:")
	string avg_name=stringfromlist(0,avg_list) 
	string decon_name=avg_name+"decon"
	wave avg_wave= root:opto_df:$avg_name  //the average response corresponding to the PS_ID, headstage combo
	if (riseORfall==1)  //if looking for EPSP, rising response, deconvolve with tau=20 ms
		deconvolve_wave(avg_wave,20)
	else
		deconvolve_wave(avg_wave,50)  //if looking for IPSP use 50 ms.
	endif
	wave decon_wave=$decon_name
	
	
	wavestats/q/r=(-50,0) decon_wave
	wavestats/q/r=(0,50) decon_wave
	if(riseORfall==1)
		variable threshold=V_max*0.5
	else
		threshold=V_min*0.5
		
	endif
	FindLevels/q/EDGE=(riseORfall)/B=20/R=(3,50)/DEST=crossings/M=3 decon_wave, threshold
	if(numpnts(crossings)>1)
		variable start=crossings[0]
		
		wavestats/q/r=(start, crossings[1]) decon_wave
		if(riseORfall==1)
			variable stop=V_minloc
		else
			stop=V_maxloc
		endif
		//estimate PPR here
		wavestats/q/r=(start, stop) decon_wave
		if(riseORfall==1)
			variable first=V_max
			variable first_time=V_maxloc
		else
			first=V_min
			first_time=V_minloc
		endif
		if(numpnts(crossings)>2)
			wavestats/q/r=(crossings[1], crossings[2]) decon_wave
			if(riseORfall==1)
				variable stop2=V_min
			else
				stop2=V_max
			endif
			wavestats/q/r=(crossings[1],stop2) decon_wave
			if(riseORfall==1)
				variable second=V_max
				variable second_time=V_maxloc
			else
				second=V_min
				second_time=V_minloc
			endif
		else
			print "Im here"
			wavestats/q/r=(crossings[1],crossings[1]+5) decon_wave
			if(riseORfall==1)
				second=V_max
				second_time=V_maxloc
			else
				second=V_min
				second_time=V_minloc
			endif
		endif
		variable PPR=second/first
		variable PPR_interval=second_time-first_time
		
	else
		start=crossings[0]
		
		stop=crossings[0]+20	
		PPR=NaN
		PPR_interval=NaN
	endif
	
	stats_wave[10]=PPR
	stats_wave[11]=PPR_interval
	wavestats/q/r=(start, stop) avg_wave
	if(riseORfall==1)
		variable peak_in_avg=V_max
		variable timeOfPeak=V_maxloc
	else
		peak_in_avg=V_min
		timeOfPeak=V_minloc
	endif
	stats_wave[2]=peak_in_avg
	stats_wave[8]=timeOfPeak
	
	FindLevel/q/EDGE=(riseOrFall)/R=(0,timeOfPeak) avg_wave, peak_in_avg*.1
	variable t10=V_levelX
	FindLevel/q/EDGE=(riseOrFall)/R=(0,timeOfPeak) avg_wave, peak_in_avg*.2
	variable t20=V_levelX
	FindLevel/q/EDGE=(riseOrFall)/R=(0,timeOfPeak) avg_wave, peak_in_avg*.5
	variable t50=V_levelX
	FindLevel/q/EDGE=(riseOrFall)/R=(0,timeOfPeak) avg_wave, peak_in_avg*.8
	variable t80=V_levelX
	FindLevel/q/EDGE=(riseOrFall)/R=(0,timeOfPeak) avg_wave, peak_in_avg*.9
	variable t90=V_levelX
	if(riseORfall==1)
		FindLevel/q/EDGE=2/R=(timeOfPeak,rightx(avg_wave)) avg_wave, peak_in_avg*.5
		variable t50fall=V_levelX
	else
		FindLevel/q/EDGE=1/R=(timeOfPeak,rightx(avg_wave)) avg_wave, peak_in_avg*.5
		t50fall=V_levelX
	endif
	variable rise2080=t80-t20
	variable rise1090=t90-t10
	if(numpnts(crossings)>1)
		variable halfwidth=NaN
	else
		halfwidth=t50fall-t50
	endif
	stats_wave[5]=rise1090
	stats_wave[6]=rise2080
	stats_wave[7]=halfwidth
	variable i
	variable numberOfSweeps=itemsinlist(sweep_list_hs,";")
	
	Make/o/n=(numberofsweeps) peaks, peak_times

	
	for (i=0; i<numberofsweeps;i+=1)
		string thisWaveName=stringfromlist(i,sweep_list_HS)
		wave thisWave=root:opto_df:$thisWaveName
		wavestats/q/r=(timeOfPeak-2.5,stop) thisWave //find a peak near the avg peak
		
		if(riseORfall==1)
		
			peaks[i]=V_max
			peak_times[i]=V_maxLoc
			
		else
			peaks[i]=V_min
			peak_times[i]=V_minloc
		endif
	endfor
	wavestats/q peaks
	variable avg_by_peaks=V_avg
	variable CV=abs(V_sdev/V_avg)
	stats_wave[4]=CV
	stats_wave[3]=avg_by_peaks
	wavestats/q peak_times
	variable jitter=V_sdev
	stats_wave[9]=jitter
	Duplicate/o peaks PS_df:peaks
	Duplicate/o peak_times PS_df:peak_times
	Duplicate/o sweeps_used PS_df:sweeps_used
	Duplicate/o avg_wave PS_df:avg_wave
	save_cnx_stats(photostim_name, stats_wave)
end

Function/S textWave2array(tw)
	wave/t tw
	string full=tw[0]
	variable last_stri=strsearch(full,"AD",0)-2
	string sub=full[6,last_stri]
	string output = "["+sub
	
	variable i
	
	for (i=1;i<numpnts(tw);i+=1)
		full=tw[i]
		last_stri=strsearch(full,"AD",0)-2
		sub=full[6,last_stri]
		output+=", "+sub
	endfor
	output+="]"
	return output
end

Function make_sweeps_used_exp() 
	wave cnx_stats=root:opto_df:cnx_stats
	variable cnxs=dimsize(cnx_stats,0)
	
	Make/T/O/N=(cnxs) root:opto_df:sweeps_Used_exp
	wave/t sweeps_used_exp=root:opto_df:sweeps_used_exp
	variable i
	for (i=0;i<cnxs;i+=1)
		string cnx_name=getdimlabel(cnx_stats,0,i)
		string cnx_df="root:opto_df:"+cnx_name
		Setdatafolder cnx_df
		wave sweeps_used
		string sweeps_i=textwave2array(sweeps_used)
		sweeps_used_exp[i]=sweeps_i
	endfor
end

Function make_sweeps_used_SNR_exp() 
	wave SNR_wv=root:opto_df:SNR_df:SNR_wave
	variable cnxs=dimsize(SNR_wv,0)
	
	Make/T/O/N=(cnxs) root:opto_df:sweeps_Used_SNR_exp
	wave/t sweeps_used_SNR_exp=root:opto_df:sweeps_used_SNR_exp
	variable i
	for (i=0;i<cnxs;i+=1)
		string cnx_name=getdimlabel(SNR_wv,0,i)
		string cnx_df="root:opto_df:"+cnx_name
		Setdatafolder cnx_df
		wave sweeps_used_SNR
		string sweeps_i=textwave2array(sweeps_used_SNR)
		sweeps_used_SNR_exp[i]=sweeps_i
	endfor
end

Function/wave deconvolve_wave(source_wave, tau) //and smooth
	wave source_wave
	variable tau
	variable dt=deltax(source_wave)
	variable deconv_length=numpnts(source_wave)-10
	string output_name=nameofwave(source_wave)+"decon"
	duplicate/o/r=[0,deconv_length] source_wave, $output_name
	wave deconv_wave=$output_name
	deconv_wave=source_wave[p]+(tau/dt)*(source_wave[p+1] - source_wave[p])
	if(dt<0.04)
		smooth 320, deconv_wave
	else
		smooth 200, deconv_wave
	endif
	//display deconv_wave, source_wave
	return deconv_wave
end

Function find_event_times_sweep(sweep,threshold)
	wave sweep
	variable threshold
	smooth 100, sweep
	wave decon_wave=deconvolve_wave(sweep,20)
	FindLevels/Edge=1/D=event_times/q/r=(0,50) decon_wave, threshold
	if(V_flag==2)
		Make/o/n=1 event_times
		event_times=NaN
	endif
	duplicate/o event_times, event_decon_amps, event_amps
	variable i
	variable event_count=numpnts(event_times)
	if(V_flag==1)
		for(i=0;i<(event_count-1);i+=1)
			wavestats/r=(event_times[i],event_times[i+1])/q decon_wave
			event_times[i]=V_maxloc
			event_decon_amps[i]=V_max
			wavestats/r=(event_times[i], event_times[i+1])/q sweep
			event_amps[i]=V_max
		endfor
		wavestats/r=(event_times[event_count-1],event_times[event_count-1]+20)/q decon_wave
		event_times[event_count-1]=V_maxloc
		event_decon_amps[event_count-1]=V_max
		wavestats/r=(event_times[event_count-1],event_times[event_count-1]+20)/q sweep
		event_amps[event_count-1]=V_max
	endif
	//now pre_window
	FindLevels/Edge=1/D=event_times_pre/q/r=(-70,-20) decon_wave, threshold
	if(V_flag==2)
		Make/o/n=1 event_times_pre
		event_times_pre=NaN
	endif
	duplicate/o event_times_pre, event_decon_amps_pre, event_amps_pre
	variable event_count_pre=numpnts(event_times_pre)
	if(V_flag==1)
		for(i=0;i<(event_count_pre-1);i+=1)
			wavestats/r=(event_times_pre[i],event_times_pre[i+1])/q decon_wave
			event_times_pre[i]=V_maxloc
			event_decon_amps_pre[i]=V_max
			wavestats/r=(event_times_pre[i], event_times_pre[i+1])/q sweep
			event_amps_pre[i]=V_max
		endfor
		wavestats/r=(event_times_pre[event_count_pre-1],event_times_pre[event_count_pre-1]+20)/q decon_wave
		event_times_pre[event_count_pre-1]=V_maxloc
		event_decon_amps_pre[event_count_pre-1]=V_max
		wavestats/r=(event_times_pre[event_count_pre-1],event_times_pre[event_count_pre-1]+20)/q sweep
		event_amps_pre[event_count_pre-1]=V_max
	endif
	Killwaves decon_wave
end



Function display_event_times(PS_ID, hs_wave)
	variable PS_ID
	wave hs_wave
	variable i, j 
	
	wave marker_wave=root:opto_df:marker_wave
	display
	for(i=0;i<numpnts(hs_wave);i+=1)
		variable hs=hs_wave[i]
		string PS_df_name="photoStim_"+num2str(PS_ID)+"_AD"+num2str(HS)
		SetDataFolder root:opto_df:
		SetDataFolder $PS_df_name
		string event_t_list=wavelist("*_event_times",";","")
		for(j=0;j<itemsinlist(event_t_list);j+=1)
			string name=stringfromlist(j,event_t_list)
			variable last_stri=strsearch(name,"AD",0)-2
			variable sweep_num=str2num(name[6,last_stri])
			
			wave event_t=$name
			appendtograph marker_wave/TN=$name vs event_t
			ModifyGraph offset($name)={0,sweep_num}
			ModifyGraph mode=3, marker($name)=29
			if(HS==0)
				ModifyGraph rgb($name)=(65535,0,0,32768)
			elseif(HS==1)
				ModifyGraph rgb($name)=(26411,1,52428,32768)
			elseif(HS==2)
				ModifyGraph rgb($name)=(65535,43690,0,32768)
			else
				ModifyGraph rgb($name)=(0,26214,13293,32768)
			endif
		endfor
	endfor
	setdatafolder root:opto_df:
end


Function measure_synch(PS_ID, HSi, HSj, time_window)
	variable PS_ID, HSi, HSj, time_window
	variable index, event_index
	string PSi_df_name="photoStim_"+num2str(PS_ID)+"_AD"+num2str(HSi)
	string PSj_df_name="photoStim_"+num2str(PS_ID)+"_AD"+num2str(HSj)
	SetDataFolder root:opto_df:
	SetDataFolder $PSi_df_name
	DFREF DF_j=root:opto_df:$PSj_df_name
	string event_t_list_i=wavelist("*_event_times",";","")
	
	for (index=0;index<itemsinlist(event_t_list_i);index+=1) //for each sweep
		string name_i=stringfromlist(index,event_t_list_i)
		string name_j=replacestring("AD"+num2str(HSi),name_i,"AD"+num2str(HSj))
		wave etimes_i=$name_i
		wave etimes_j=DF_j:$name_j
		string synch_name=replacestring("event_times",nameofwave(etimes_i),"synch"+num2str(HSj))
		string synch_times_name=synch_name+"_times"
		duplicate/o etimes_i $synch_name $synch_times_name
		wave synch_wv=$synch_name
		wave synch_times=$synch_times_name
		synch_wv=0
		for (event_index=0;event_index<numpnts(etimes_i);event_index+=1)
			variable etime=etimes_i[event_index]
			FindValue/t=(time_window)/V=(etime) etimes_j
			if (V_value!=-1)
				synch_wv[event_index]=1
			else 
				synch_times[event_index]=NaN
			endif
		
		endfor
		WaveTransform zapNaNs, synch_times
	endfor
end

function concatenate_synch(PS_ID, HSi, HSj)
	variable PS_ID, HSi, HSj
	wave sweeps=root:opto_df:sweeps
	variable i
	string PSi_df_name="photostim_"+num2str(PS_ID)+"_AD"+num2str(HSi)
	string PSj_df_name="photostim_"+num2str(PS_ID)+"_AD"+num2str(HSj)
	string master_times_name="photostim_"+num2str(PS_ID)+"_"+num2str(HSi)+num2str(HSj)+"_t"
	string master_synch_name="photostim_"+num2str(PS_ID)+"_"+num2str(HSi)+num2str(HSj)+"_synch"
	string master_synch_times_name="photostim_"+num2str(PS_ID)+"_"+num2str(HSi)+num2str(HSj)+"_synch_t"

	SetDataFolder root:opto_df:
	Make/o/n=0 $master_times_name, $master_synch_name, $master_synch_times_name
	wave master_times=$master_times_name
	wave master_synch=$master_synch_name
	wave master_synch_times=$master_synch_times_name
	SetDataFolder $PSi_df_name
	for (i=0;i<numpnts(sweeps);i+=1)
		variable sweep=sweeps[i]
		string etimes_name="Sweep_"+num2str(sweep)+"_AD"+num2str(HSi)+"_event_times"
		string synch_name="Sweep_"+num2str(sweep)+"_AD"+num2str(HSi)+"_synch"+num2str(HSj)
		string synch_times_name="Sweep_"+num2str(sweep)+"_AD"+num2str(HSi)+"_synch"+num2str(HSj)+"_times" 
		wave etimes_wv=$etimes_name
		wave synch_wv=$synch_name
		wave synch_times_wv=$synch_times_name
		Duplicate/o master_times temp_times
		Duplicate/o master_synch temp_synch
		Duplicate/o master_synch_times temp_synch_times
		Concatenate/o/NP {temp_times, etimes_wv}, master_times
		Concatenate/o/NP {temp_synch, synch_wv}, master_synch
		Concatenate/o/NP {temp_synch_times, synch_times_wv}, master_synch_times
	endfor
	Sort master_times,master_synch,master_times
	display master_synch vs master_times
	SetDataFolder root:opto_df:
	Duplicate/o master_times $master_times_name
	Duplicate/o master_synch $master_synch_name
	Duplicate/o master_synch_times $master_synch_times_name
end


Function synch_prob(all_times, synch_times)
	wave all_times, synch_times
	variable start=-75
	variable stop=100
	variable binsize=1
	variable bin_count=(stop-start)/binsize
	string synch_hist_name=nameofwave(synch_times)+"_Hist"
	string all_hist_name=nameofwave(all_times)+"_Hist"
	string prob_name=replacestring("synch_t",nameofwave(synch_times),"prob")
	
	Make/N=(bin_count)/O $synch_Hist_name, $all_hist_name
	Histogram/B={start,binsize,bin_count} synch_times, $synch_hist_name
	Histogram/B={start,binsize,bin_count} all_times, $all_hist_name
	wave synch_hist=$synch_hist_name
	wave all_hist=$all_hist_name
	duplicate/o all_hist, $prob_name
	wave prob=$prob_name
	prob=synch_hist/all_hist
	MatrixOp/O prob = replaceNaNs(prob,0)
	Display prob

end

function make_cnx_folder(photoStim_name)
	string photostim_name
	string folderPath="root:opto_df:"+photostim_name
	//print folderPath
	if(DataFolderExists(folderpath)==0)
	
		newdatafolder $folderPath
	endif
end


Function save_cnx_stats(photoStim_Name, stats_wave)
	string photostim_Name	
	wave stats_wave
	wave cnx_stats=root:opto_df:cnx_stats
	variable dimIndex=FindDimLabel(cnx_stats, 0, photostim_name)
	if(dimIndex==-2)
		InsertPoints/M=0 0, 1, cnx_stats
		cnx_stats[0][]=NaN
		SetDimLabel 0,0, $photostim_name, cnx_stats
		dimIndex=0
	endif
	cnx_stats[dimIndex][]=stats_wave[q]	
end


Function write_all_cnx_to_csv(expName)
	string expName
	wave cnx_stats=root:opto_df:cnx_Stats
	variable rows=dimsize(cnx_stats,0)
	make_sweeps_used_exp()
	wave sweeps_used_exp=root:opto_df:sweeps_used_exp
	Make/o/n=(rows)/T exp_id
	exp_id=expName
	Edit exp_id, cnx_stats.ld, sweeps_used_exp
	
	Save/J/M="\r\n"/DLIM=","/U={0,0,1,0} cnx_stats as expName+"_cnxstats.csv"
end

Function exp_snr(expName)
	string expName
	wave snr_wave=root:opto_df:snr_df:snr_wave
	variable rows=dimsize(snr_wave,0)
	make_sweeps_used_Snr_exp()
	wave sweeps_used_snr_exp=root:opto_df:sweeps_used_snr_exp
	Make/o/n=(rows)/T exp_id_snr
	exp_id_snr=expName
	Edit exp_id_snr, snr_wave.ld, sweeps_used_snr_exp
	
end


Function PPR(crossings, deconv_wave)
	wave crossings, deconv_wave
	//FindLevels/r=(0,50) 
	
	
end	


function align_psps()
	wave sweeps_used
	variable i
		
end


function measure_background_peak(input_wv, PS_ID, HS)
	wave input_wv
	variable PS_ID, HS
	wave sigNoise=root:opto_df:sigNoise
	
	wavestats/q/r=(-50,0) input_wv
	variable backPeak=V_max
	wavestats/q/r=(0,50) input_wv
	variable sigPeak=V_max
	variable back_i=HS*2
	variable sig_i=HS*2+1
	sigNoise[PS_ID][back_i]=backPeak
	sigNoise[PS_ID][sig_i]=sigPeak
	

end

Function back_peak_plotted()
	DFREF saveDFR = GetDataFolderDFR()
	SetDataFolder root:opto_df
	controlinfo/W=photostim_ops popup_PSID

	variable PSID=str2num(S_value)
	print PSID
	string axes=axislist("")
	axes=listmatch(axes, "L*")
	variable numaxes = itemsinlist(axes,";")
	variable i
	for (i=0; i<(numaxes);i+=1)
	
	
	
	endfor

end


Function make_SNR_df()
	if(DataFolderExists("root:opto_df:SNR_df:")==0)
		NewDataFolder root:opto_df:SNR_df
		SetDataFolder root:opto_df:SNR_df

		make_snr_wave()
		Make/o/n=1 temp_crossings
		temp_crossings=NaN
		//make_power0_wave()
	endif
end

Function make_SNR_wave()
	DFREF saveDFR=GetDataFolderDFR()
	SetDataFolder root:opto_df:SNR_df
	Make/o/N=(1,32)/D SNR_wave
	SetDimLabel 1,0, photostim_ID, SNR_wave
	SetDimLabel 1,1, headstage_ID, SNR_wave
	SetDimLabel 1,2, DC_baseline_avg, SNR_wave
	SetDimLabel 1,3, DC_baseline_SD, SNR_wave
	SetDimLabel 1,4, DC_post_peak, SNR_wave
	SetDimLabel 1,5, DC_post_crossings3x, SNR_wave
	SetDimLabel 1,6, DC_post_crossings5x, SNR_wave
	SetDimLabel 1,7, DC_pre_peak, SNR_wave
	SetDimLabel 1,8, DC_pre_crossings3x, SNR_wave
	SetDimLabel 1,9, DC_pre_crossings5x, SNR_wave
	SetDimLabel 1,10, DC_post_peak_time, SNR_wave
	SetDimLabel 1, 11, DC_pre_peak_time, SNR_wave
	SetDimLabel 1, 12, post_3x_crossing_time, SNR_wave
	SetDimLabel 1, 13, post_5x_crossing_time, SNR_wave
	SetDimLabel 1, 14, pre_3x_crossing_time, SNR_wave
	SetDimLabel 1, 15, pre_5x_crossing_time, SNR_wave
	SetDimLabel 1, 16, post_cross_persweep, SNR_wave
	SetDimLabel 1, 17, post_cross_persweep_sd, SNR_wave
	SetDimLabel 1, 18, pre_cross_persweep, SNR_wave
	SetDimLabel 1, 19, pre_cross_persweep_sd, SNR_wave
	SetDimLabel 1, 20, post_first_cross_avg, SNR_wave
	SetDimLabel 1, 21, post_first_cross_SD, SNR_wave
	SetDimLabel 1, 22, pre_first_cross_avg, SNR_wave
	SetDimLabel 1, 23, pre_first_cross_SD, SNR_wave
	SetDimLabel 1, 24, avg_peak, SNR_wave
	SetDimLabel 1, 25, avg_peak_time, SNR_wave
	SetDimLabel 1, 26, SD_peak_time, SNR_wave
	SetDimLabel 1, 27, avg_peak_pre, SNR_wave
	SetDimLabel 1, 28, avg_peak_time_pre, SNR_wave
	SetDimLabel 1, 29, SD_peak_time_pre, SNR_wave
	SetDimLabel 1, 30, baseline_SD, SNR_wave
	SetDimLabel 1, 31, T_index, SNR_wave
	SNR_wave=NaN
	
end


Function make_SNR_wave_VC()
	DFREF saveDFR=GetDataFolderDFR()
	SetDataFolder root:opto_df:SNR_df
	Make/o/N=(1,34)/D SNR_wave_VC
	SetDimLabel 1,0, photostim_ID, SNR_wave_VC
	SetDimLabel 1,1, headstage_ID, SNR_wave_VC
	SetDimLabel 1,2, DC_baseline_avg, SNR_wave_VC
	SetDimLabel 1,3, DC_baseline_SD, SNR_wave_VC
	SetDimLabel 1,4, DC_post_peak, SNR_wave_VC
	SetDimLabel 1,5, DC_post_crossings3x, SNR_wave_VC
	SetDimLabel 1,6, DC_post_crossings5x, SNR_wave_VC
	SetDimLabel 1,7, DC_pre_peak, SNR_wave_VC
	SetDimLabel 1,8, DC_pre_crossings3x, SNR_wave_VC
	SetDimLabel 1,9, DC_pre_crossings5x, SNR_wave_VC
	SetDimLabel 1,10, DC_post_peak_time, SNR_wave_VC
	SetDimLabel 1, 11, DC_pre_peak_time, SNR_wave_VC
	SetDimLabel 1, 12, post_3x_crossing_time, SNR_wave_VC
	SetDimLabel 1, 13, post_5x_crossing_time, SNR_wave_VC
	SetDimLabel 1, 14, pre_3x_crossing_time, SNR_wave_VC
	SetDimLabel 1, 15, pre_5x_crossing_time, SNR_wave_VC
	SetDimLabel 1, 16, post_cross_persweep, SNR_wave_VC
	SetDimLabel 1, 17, post_cross_persweep_sd, SNR_wave_VC
	SetDimLabel 1, 18, pre_cross_persweep, SNR_wave_VC
	SetDimLabel 1, 19, pre_cross_persweep_sd, SNR_wave_VC
	SetDimLabel 1, 20, post_first_cross_avg, SNR_wave_VC
	SetDimLabel 1, 21, post_first_cross_SD, SNR_wave_VC
	SetDimLabel 1, 22, pre_first_cross_avg, SNR_wave_VC
	SetDimLabel 1, 23, pre_first_cross_SD, SNR_wave_VC
	SetDimLabel 1, 24, avg_peak, SNR_wave_VC
	SetDimLabel 1, 25, avg_peak_time, SNR_wave_VC
	SetDimLabel 1, 26, SD_peak_time, SNR_wave_VC
	SetDimLabel 1, 27, avg_peak_pre, SNR_wave_VC
	SetDimLabel 1, 28, avg_peak_time_pre, SNR_wave_VC
	SetDimLabel 1, 29, SD_peak_time_pre, SNR_wave_VC
	SetDimLabel 1, 30, baseline_SD, SNR_wave_VC
	SetDimLabel 1, 31, T_index, SNR_wave_VC
	SetDimLabel 1, 32, charge, SNR_wave_VC
	SetDimLabel 1, 33, pre_charge, SNR_wave_VC
	SNR_wave_VC=NaN
	
end

Function SNR_graph(riseOrFall, tau)
	variable riseOrfall, tau
	DFREF saveDFR=GetDataFolderDFR()
	controlinfo/W=photostim_ops popup_PSID
	SetDataFolder root:opto_df:
	variable PS_ID=str2num(s_value)
	string axes=axislist("")
	axes=listmatch(axes, "L*")
	variable numaxes = itemsinlist(axes, ";")
	variable i
	for (i=0; i<(numaxes);i+=1)
		string axis_name=stringfromlist(i,axes)
		if(CmpStr(axis_name,"L_AD6")!=0)
			
			variable HS=str2num(axis_name[4])
			string avg_wave_name="photostim_"+num2str(PS_ID)+"_AD"+num2str(HS)+"_avg"
			string SD_wave_name="photostim_"+num2str(PS_ID)+"_AD"+num2str(HS)+"_err"
			wave avg_wave=$avg_wave_name
			wave SD_wave=$SD_wave_name
			wave decon_wave=deconvolve_wave(avg_wave, tau)
			measure_SNR_avg(avg_wave, SD_wave, PS_ID, HS, riseOrFAll)
			measure_SNR_DC(decon_wave, PS_ID, HS,riseOrFAll)
			
		endif
	endfor
	
	SetDataFolder saveDFR
end

Function SNR_graph_VC(riseOrFall, tau)
	variable riseOrfall, tau
	DFREF saveDFR=GetDataFolderDFR()
	controlinfo/W=photostim_ops popup_PSID
	SetDataFolder root:opto_df:
	variable PS_ID=str2num(s_value)
	string axes=axislist("")
	axes=listmatch(axes, "L*")
	variable numaxes = itemsinlist(axes, ";")
	variable i
	for (i=0; i<(numaxes);i+=1)
		string axis_name=stringfromlist(i,axes)
		if(CmpStr(axis_name,"L_AD6")!=0)
			
			variable HS=str2num(axis_name[4])
			string avg_wave_name="photostim_"+num2str(PS_ID)+"_AD"+num2str(HS)+"_avg"
			string SD_wave_name="photostim_"+num2str(PS_ID)+"_AD"+num2str(HS)+"_err"
			wave avg_wave=$avg_wave_name
			wave SD_wave=$SD_wave_name
			wave decon_wave=deconvolve_wave(avg_wave, tau)
			measure_SNR_vclamp(avg_wave, SD_wave, PS_ID, HS, riseOrFAll)
			measure_SNR_DC_vc(decon_wave, PS_ID, HS,riseOrFAll)
			
		endif
	endfor
	
	SetDataFolder saveDFR
end

Function SNR_graph_T(riseOrFAll, tau)
	variable riseOrFall, tau
	DFREF saveDFR=GetDataFolderDFR()
	
	SetDataFolder root:opto_df:
	controlinfo/W=stim_monitor_ops setvarSweep
	variable PS_ID=v_value
	controlinfo/W=stim_monitor_ops setvarMPT
	variable T_index=v_value
	string axes=axislist("")
	axes=listmatch(axes, "L*")
	variable numaxes = itemsinlist(axes, ";")
	variable i
	for (i=0; i<(numaxes);i+=1)
		string axis_name=stringfromlist(i,axes)
		if(CmpStr(axis_name,"L_AD6")!=0)
			
			variable HS=str2num(axis_name[4])
			string avg_wave_name="T"+num2str(PS_ID)+"_"+num2str(T_index)+"_AD"+num2str(HS)+"_avg"
			
			string SD_wave_name="T"+num2str(PS_ID)+"_"+num2str(T_index)+"_AD"+num2str(HS)+"_err"
			wave avg_wave=$avg_wave_name
			wave SD_wave=$SD_wave_name
			wave decon_wave=deconvolve_wave(avg_wave, tau)
			measure_SNR_avg_T(avg_wave, SD_wave, PS_ID, T_index, HS, riseOrFAll)
			measure_SNR_DC_T(decon_wave, PS_ID, T_index, HS,riseOrFAll)
			
		endif
	endfor
	
	SetDataFolder saveDFR
	
end

Function loop_snr(start, stop, riseORFAll, tau)
	variable start, stop, riseorfall, tau
	variable i
	
	for(i=start; i<=stop; i+=1)
		PopupMenu popup_PSID win=photostim_ops, mode=i
		controlinfo/W=photostim_ops popup_PSID
		variable PSID_index=v_value-1
		wave uniquePSID=root:opto_df:uniqueStimIDs
		variable PSID=uniquePSID[PSID_index]
		controlinfo/W=photostim_ops checkQC
		variable QC=v_value
		plot_stimID(PSID, applyQC=QC)
		SNR_graph(riseOrFAll, tau)
	endfor
end


Function loop_t()
	variable i, j
	wave T_start=root:opto_df:T_start
	wave roi=root:opto_df:roi
	wave reps=root:opto_df:reps
	
	for (i=0;i<numpnts(T_start);i+=1)
		variable T=T_start[i]
		SetVariable setvarsweep win=stim_monitor_ops, value=_NUM:T
		variable number_rois=roi[i]
		variable number_reps=reps[i]
		for(j=1;j<=number_rois;j+=1)
			SetVariable setvarMPT win=stim_monitor_ops, value=_NUM:j
			plot_avg(T, number_rois, number_reps, 1, -100,150, j, 0)
			snr_graph_t(1,20)
			
			
			
		endfor
	
	endfor

end


function measure_SNR_Vclamp(input_wv, input_wv_SD, PS_ID, HS, riseOrFall)
	
	wave input_wv, input_wv_SD
	variable PS_ID, HS, riseOrFall
	DFREF saveDFR=GetDataFolderDFR()
	wave SNR_wave_VC=root:opto_df:SNR_df:SNR_wave_VC
	string photostim_Name="photoStim_"+num2str(PS_ID)+"_AD"+num2str(HS)
	wavestats/q/r=(0,50) input_wv
	
	if (riseOrFall==1)
		variable peak=V_max
		variable peaktime=V_maxloc
		variable SD=input_wv_SD(peaktime)
	else
		peak=V_min
		peaktime=V_minloc
		SD=input_wv_SD(peaktime)
	endif
	
	FindLevel/R=(peaktime,0)/q input_wv, peak*.01
	if (V_flag==0)
		variable start_x=V_levelx
	else
		start_x=0
	endif
	
	FindLevel/R=(peaktime,peaktime+100)/q input_wv, 0
	if(V_flag==0)
		variable end_x=V_LevelX
	else
		end_x=peaktime+100
	endif
	
	Duplicate/r=(start_x,end_x)/o input_wv, int_wave
	Integrate int_wave
	variable charge=int_wave[numpnts(int_wave)-1]
	print charge
	
	wavestats/q/r=(-70,-20) input_wv
	if (riseOrFall==1)
		variable peak_pre=V_max
		variable peaktime_pre=V_maxloc
		variable SD_pre=input_wv_SD(peaktime_pre)
	else
		peak_pre=V_min
		peaktime_pre=V_minloc
		SD_pre=input_wv_SD(peaktime_pre)
	endif
	
	FindLevel/R=(peaktime_pre,-70)/q input_wv, peak*.01
	if (V_flag==0)
		 start_x=V_levelx
	else
		start_x=0
	endif
	
	FindLevel/R=(peaktime_pre,peaktime_pre+100)/q input_wv, 0
	if(V_flag==0)
		end_x=V_LevelX
	else
		end_x=peaktime+100
	endif
	
	Duplicate/r=(start_x,end_x)/o input_wv, int_wave
	Integrate int_wave
	variable pre_charge=int_wave[numpnts(int_wave)-1]
	print pre_charge
	
	wavestats/r=(-20,0)/q input_wv
	variable baseline_SD=V_sdev
	
	
	
	variable dimIndex=FindDimLabel(SNR_wave_vc, 0, photostim_name)
	if(dimIndex==-2)
		InsertPoints/M=0 0, 1, SNR_wave_VC
		SNR_wave_VC[0][]=NaN
		SetDimLabel 0,0, $photostim_name, SNR_wave_VC
		dimIndex=0
	endif
	snr_wave_VC[dimIndex][24]=peak
	snr_wave_VC[dimIndex][25]=peaktime
	snr_wave_VC[dimIndex][26]=SD
	snr_wave_VC[dimIndex][27]=peak_pre
	snr_wave_VC[dimIndex][28]=peaktime_pre
	snr_wave_VC[dimIndex][29]=SD_pre
	snr_wave_VC[dimIndex][30]=baseline_SD
	snr_wave_vc[dimIndex][32]=charge
	snr_wave_vc[dimIndex][33]=pre_charge
	SetDataFolder saveDFR
	
	
end




function measure_SNR_avg(input_wv, input_wv_SD, PS_ID, HS, riseOrFall)
	wave input_wv, input_wv_SD
	
	variable PS_ID, HS, riseOrFall
	DFREF saveDFR=GetDataFolderDFR()
	wave SNR_wave=root:opto_df:SNR_df:SNR_wave
	string photostim_Name="photoStim_"+num2str(PS_ID)+"_AD"+num2str(HS)
	wavestats/q/r=(0,50) input_wv
	if (riseOrFall==1)
		variable peak=V_max
		variable peaktime=V_maxloc
		variable SD=input_wv_SD(peaktime)
	else
		peak=V_min
		peaktime=V_minloc
		SD=input_wv_SD(peaktime)
	endif
	
	wavestats/q/r=(-70,-20) input_wv
	if (riseOrFall==1)
		variable peak_pre=V_max
		variable peaktime_pre=V_maxloc
		variable SD_pre=input_wv_SD(peaktime_pre)
	else
		peak_pre=V_min
		peaktime_pre=V_minloc
		SD_pre=input_wv_SD(peaktime_pre)
	endif
	variable dimIndex=FindDimLabel(SNR_wave, 0, photostim_name)
	if(dimIndex==-2)
		InsertPoints/M=0 0, 1, SNR_wave
		SNR_wave[0][]=NaN
		SetDimLabel 0,0, $photostim_name, SNR_wave
		dimIndex=0
	endif
	wavestats/r=(-20,0)/q input_wv
	variable baseline_SD=V_sdev
	snr_wave[dimIndex][24]=peak
	snr_wave[dimIndex][25]=peaktime
	snr_wave[dimIndex][26]=SD
	snr_wave[dimIndex][27]=peak_pre
	snr_wave[dimIndex][28]=peaktime_pre
	snr_wave[dimIndex][29]=SD_pre
	snr_wave[dimIndex][30]=baseline_SD
	SetDataFolder saveDFR
end

function measure_SNR_avg_T(input_wv, input_wv_SD, PS_ID, T_index, HS, riseOrFall)
	wave input_wv, input_wv_SD
	
	variable PS_ID, T_index, HS, riseOrFall
	DFREF saveDFR=GetDataFolderDFR()
	wave SNR_wave=root:opto_df:SNR_df:SNR_wave
	string photostim_Name="TSeries_"+num2str(PS_ID)+"_"+num2str(T_index)+"_AD"+num2str(HS)
	wavestats/q/r=(0,50) input_wv
	if (riseOrFall==1)
		variable peak=V_max
		variable peaktime=V_maxloc
		variable SD=input_wv_SD(peaktime)
	else
		peak=V_min
		peaktime=V_minloc
		SD=input_wv_SD(peaktime)
	endif
	
	wavestats/q/r=(-70,-20) input_wv
	if (riseOrFall==1)
		variable peak_pre=V_max
		variable peaktime_pre=V_maxloc
		variable SD_pre=input_wv_SD(peaktime_pre)
	else
		peak_pre=V_min
		peaktime_pre=V_minloc
		SD_pre=input_wv_SD(peaktime_pre)
	endif
	variable dimIndex=FindDimLabel(SNR_wave, 0, photostim_name)
	if(dimIndex==-2)
		InsertPoints/M=0 0, 1, SNR_wave
		SNR_wave[0][]=NaN
		SetDimLabel 0,0, $photostim_name, SNR_wave
		dimIndex=0
	endif
	wavestats/r=(-20,0)/q input_wv
	variable baseline_SD=V_sdev
	snr_wave[dimIndex][24]=peak
	snr_wave[dimIndex][25]=peaktime
	snr_wave[dimIndex][26]=SD
	snr_wave[dimIndex][27]=peak_pre
	snr_wave[dimIndex][28]=peaktime_pre
	snr_wave[dimIndex][29]=SD_pre
	snr_wave[dimIndex][30]=baseline_SD
	snr_wave[dimIndex][31]=T_index
	SetDataFolder saveDFR
end


function measure_SNR_DC(input_wv, PS_ID, HS, riseOrFall)

	wave input_wv
	
	variable PS_ID, HS, riseOrFall
	DFREF saveDFR=GetDataFolderDFR()
	wave SNR_wave=root:opto_df:SNR_df:SNR_wave
	wave crossings=root:opto_df:SNR_df:temp_crossings
	
	string photostim_Name="photoStim_"+num2str(PS_ID)+"_AD"+num2str(HS)
	wavestats/q/r=(-20,0) input_wv
	variable baseline_avg=V_avg
	variable baseline_SD=V_sdev
	wavestats/q/r=(0,50) input_wv
	if(riseORFall==1)
		variable sigPeak=V_max
		variable postPeakTime=V_maxloc
	else
		sigPeak=V_min
		postPeakTime=V_minloc
	endif
	wavestats/q/r=(-70,-20) input_wv
	if (riseOrFAll==1)
		variable prePeak=V_max
		variable prePeakTime=V_maxloc
	else 
		prePeak=V_min
		prePeakTime=V_minloc
	endif
	FindLevels/edge=(riseOrFall)/r=(0,50)/D=dest_wave/q input_wv, 3*baseline_SD
	variable post_cross3x=V_LevelsFound
	if (post_cross3x>0)
		
		variable post_cross3xtime=dest_wave[0]
	else 
		post_cross3xtime=NaN
	endif
	FindLevels/edge=(riseOrFall)/r=(0,50)/D=crossings/q input_wv, 5*baseline_SD
	variable post_cross5x=V_LevelsFound
	if (post_cross5x>0)
		variable post_cross5xtime=crossings[0]
	else 
		post_cross5xtime=NaN
	endif
	
	FindLevels/edge=(riseOrFall)/r=(-70,-20)/D=crossings/q input_wv, 3*baseline_SD
	variable pre_cross3x=V_LevelsFound
	if (pre_cross3x>0)
		variable pre_cross3xtime=crossings[0]
	else 
		pre_cross3xtime=NaN
	endif
	FindLevels/edge=(riseOrFall)/r=(-70,-20)/D=crossings/q input_wv, 5*baseline_SD
	variable pre_cross5x=V_LevelsFound
	if (pre_cross3x>0)
		variable pre_cross5xtime=crossings[0]
	else 
		pre_cross5xtime=NaN
	endif
	variable dimIndex=FindDimLabel(SNR_wave, 0, photostim_name)
	if(dimIndex==-2)
		InsertPoints/M=0 0, 1, SNR_wave
		SNR_wave[0][]=NaN
		SetDimLabel 0,0, $photostim_name, SNR_wave
		dimIndex=0
	endif
	snr_wave[dimIndex][0]=PS_ID
	snr_wave[dimINdex][1]=HS
	snr_wave[dimINdex][2]=baseline_avg
	snr_wave[dimINdex][3]=baseline_SD
	snr_wave[dimIndex][4]=sigPeak
	snr_wave[dimIndex][5]=post_cross3x
	snr_wave[dimINdex][6]=post_cross5x
	snr_wave[dimIndex][7]=prePeak
	snr_wave[dimINdex][8]=pre_cross3x
	snr_wave[dimIndex][9]=pre_cross5x
	snr_wave[dimIndex][10]=postPeakTime
	snr_wave[dimIndex][11]=prePeakTime
	snr_wave[dimIndex][12]=post_cross3xtime
	snr_wave[dimIndex][13]=post_cross5xtime
	snr_wave[dimIndex][14]=pre_cross3xtime
	snr_wave[dimIndex][15]=pre_cross5xtime
	find_event_times_plotted(1,PS_ID, HS, photostim_name, 10*baseline_SD)
	wave numCrossings_PSHS_wave,firstCrossing_PSHs_wave,numCrossings_PSHS_wave_pre,firstCrossing_PSHs_wave_pre
	wavestats/q numCrossings_PSHS_wave
	variable post_cross_perSweep=V_avg
	variable post_cross_perSweep_SD=V_Sdev
	wavestats/q numCrossings_PSHS_wave_pre
	variable pre_cross_perSweep=V_avg
	variable pre_cross_perSweep_SD=V_sdev
	wavestats/q firstcrossing_PSHS_wave
	variable post_first_cross_avg=V_avg
	variable post_first_cross_SD=V_sdev
	wavestats/q firstcrossing_PSHS_wave_pre
	variable pre_first_cross_avg=V_avg
	variable pre_first_cross_SD=V_sdev
	snr_wave[dimIndex][16]=post_cross_perSweep
	snr_wave[dimIndex][17]=post_cross_persweep_SD
	snr_wave[dimIndex][18]=pre_cross_persweep
	snr_wave[dimIndex][19]=pre_cross_persweep_SD
	snr_wave[dimIndex][20]=post_first_cross_avg
	snr_wave[dimIndex][21]=post_first_cross_SD
	snr_wave[dimIndex][22]=pre_first_cross_avg
	snr_wave[dimIndex][23]=pre_first_cross_SD
	setdatafolder saveDFR
end

function measure_SNR_DC_vc(input_wv, PS_ID, HS, riseOrFall)

	wave input_wv
	
	variable PS_ID, HS, riseOrFall
	DFREF saveDFR=GetDataFolderDFR()
	wave SNR_wave=root:opto_df:SNR_df:SNR_wave_vc
	wave crossings=root:opto_df:SNR_df:temp_crossings
	
	string photostim_Name="photoStim_"+num2str(PS_ID)+"_AD"+num2str(HS)
	wavestats/q/r=(-20,0) input_wv
	variable baseline_avg=V_avg
	variable baseline_SD=V_sdev
	wavestats/q/r=(0,50) input_wv
	if(riseORFall==1)
		variable sigPeak=V_max
		variable postPeakTime=V_maxloc
	else
		sigPeak=V_min
		postPeakTime=V_minloc
	endif
	wavestats/q/r=(-70,-20) input_wv
	if (riseOrFAll==1)
		variable prePeak=V_max
		variable prePeakTime=V_maxloc
	else 
		prePeak=V_min
		prePeakTime=V_minloc
	endif
	FindLevels/edge=(riseOrFall)/r=(0,50)/D=dest_wave/q input_wv, 3*baseline_SD
	variable post_cross3x=V_LevelsFound
	if (post_cross3x>0)
		
		variable post_cross3xtime=dest_wave[0]
	else 
		post_cross3xtime=NaN
	endif
	FindLevels/edge=(riseOrFall)/r=(0,50)/D=crossings/q input_wv, 5*baseline_SD
	variable post_cross5x=V_LevelsFound
	if (post_cross5x>0)
		variable post_cross5xtime=crossings[0]
	else 
		post_cross5xtime=NaN
	endif
	
	FindLevels/edge=(riseOrFall)/r=(-70,-20)/D=crossings/q input_wv, 3*baseline_SD
	variable pre_cross3x=V_LevelsFound
	if (pre_cross3x>0)
		variable pre_cross3xtime=crossings[0]
	else 
		pre_cross3xtime=NaN
	endif
	FindLevels/edge=(riseOrFall)/r=(-70,-20)/D=crossings/q input_wv, 5*baseline_SD
	variable pre_cross5x=V_LevelsFound
	if (pre_cross3x>0)
		variable pre_cross5xtime=crossings[0]
	else 
		pre_cross5xtime=NaN
	endif
	variable dimIndex=FindDimLabel(SNR_wave, 0, photostim_name)
	if(dimIndex==-2)
		InsertPoints/M=0 0, 1, SNR_wave
		SNR_wave[0][]=NaN
		SetDimLabel 0,0, $photostim_name, SNR_wave
		dimIndex=0
	endif
	snr_wave[dimIndex][0]=PS_ID
	snr_wave[dimINdex][1]=HS
	snr_wave[dimINdex][2]=baseline_avg
	snr_wave[dimINdex][3]=baseline_SD
	snr_wave[dimIndex][4]=sigPeak
	snr_wave[dimIndex][5]=post_cross3x
	snr_wave[dimINdex][6]=post_cross5x
	snr_wave[dimIndex][7]=prePeak
	snr_wave[dimINdex][8]=pre_cross3x
	snr_wave[dimIndex][9]=pre_cross5x
	snr_wave[dimIndex][10]=postPeakTime
	snr_wave[dimIndex][11]=prePeakTime
	snr_wave[dimIndex][12]=post_cross3xtime
	snr_wave[dimIndex][13]=post_cross5xtime
	snr_wave[dimIndex][14]=pre_cross3xtime
	snr_wave[dimIndex][15]=pre_cross5xtime
	find_event_times_plotted(1,PS_ID, HS, photostim_name, 10*baseline_SD)
	wave numCrossings_PSHS_wave,firstCrossing_PSHs_wave,numCrossings_PSHS_wave_pre,firstCrossing_PSHs_wave_pre
	wavestats/q numCrossings_PSHS_wave
	variable post_cross_perSweep=V_avg
	variable post_cross_perSweep_SD=V_Sdev
	wavestats/q numCrossings_PSHS_wave_pre
	variable pre_cross_perSweep=V_avg
	variable pre_cross_perSweep_SD=V_sdev
	wavestats/q firstcrossing_PSHS_wave
	variable post_first_cross_avg=V_avg
	variable post_first_cross_SD=V_sdev
	wavestats/q firstcrossing_PSHS_wave_pre
	variable pre_first_cross_avg=V_avg
	variable pre_first_cross_SD=V_sdev
	snr_wave[dimIndex][16]=post_cross_perSweep
	snr_wave[dimIndex][17]=post_cross_persweep_SD
	snr_wave[dimIndex][18]=pre_cross_persweep
	snr_wave[dimIndex][19]=pre_cross_persweep_SD
	snr_wave[dimIndex][20]=post_first_cross_avg
	snr_wave[dimIndex][21]=post_first_cross_SD
	snr_wave[dimIndex][22]=pre_first_cross_avg
	snr_wave[dimIndex][23]=pre_first_cross_SD
	setdatafolder saveDFR
end


function measure_SNR_DC_T(input_wv, PS_ID, T_index, HS, riseOrFall)

	wave input_wv
	
	variable PS_ID, T_index, HS, riseOrFall
	DFREF saveDFR=GetDataFolderDFR()
	wave SNR_wave=root:opto_df:SNR_df:SNR_wave
	wave crossings=root:opto_df:SNR_df:temp_crossings
	
	string photostim_Name="TSeries_"+num2str(PS_ID)+"_"+num2str(T_index)+"_AD"+num2str(HS)
	wavestats/q/r=(-20,0) input_wv
	variable baseline_avg=V_avg
	variable baseline_SD=V_sdev
	wavestats/q/r=(0,50) input_wv
	if(riseOrFall==1)
		variable sigPeak=V_max
		variable postPeakTime=V_maxloc
	else 
		sigPeak=V_min
		postPeakTime=V_minloc
	endif
	wavestats/q/r=(-70,-20) input_wv
	if(riseOrFall==1)
		variable prePeak=V_max
		variable prePeakTime=V_maxloc
	else
		prePeak=V_min
		prePeakTime=V_minloc
	endif
	FindLevels/edge=(riseOrFall)/r=(0,50)/D=dest_wave/q input_wv, 3*baseline_SD
	variable post_cross3x=V_LevelsFound
	if (post_cross3x>0)
		
		variable post_cross3xtime=dest_wave[0]
	else 
		post_cross3xtime=NaN
	endif
	FindLevels/edge=(riseOrFall)/r=(0,50)/D=crossings/q input_wv, 5*baseline_SD
	variable post_cross5x=V_LevelsFound
	if (post_cross5x>0)
		variable post_cross5xtime=crossings[0]
	else 
		post_cross5xtime=NaN
	endif
	
	FindLevels/edge=(riseOrFall)/r=(-70,-20)/D=crossings/q input_wv, 3*baseline_SD
	variable pre_cross3x=V_LevelsFound
	if (pre_cross3x>0)
		variable pre_cross3xtime=crossings[0]
	else 
		pre_cross3xtime=NaN
	endif
	FindLevels/edge=(riseOrFall)/r=(-70,-20)/D=crossings/q input_wv, 5*baseline_SD
	variable pre_cross5x=V_LevelsFound
	if (pre_cross3x>0)
		variable pre_cross5xtime=crossings[0]
	else 
		pre_cross5xtime=NaN
	endif
	variable dimIndex=FindDimLabel(SNR_wave, 0, photostim_name)
	if(dimIndex==-2)
		InsertPoints/M=0 0, 1, SNR_wave
		SNR_wave[0][]=NaN
		SetDimLabel 0,0, $photostim_name, SNR_wave
		dimIndex=0
	endif
	snr_wave[dimIndex][0]=PS_ID
	snr_wave[dimINdex][1]=HS
	snr_wave[dimINdex][2]=baseline_avg
	snr_wave[dimINdex][3]=baseline_SD
	snr_wave[dimIndex][4]=sigPeak
	snr_wave[dimIndex][5]=post_cross3x
	snr_wave[dimINdex][6]=post_cross5x
	snr_wave[dimIndex][7]=prePeak
	snr_wave[dimINdex][8]=pre_cross3x
	snr_wave[dimIndex][9]=pre_cross5x
	snr_wave[dimIndex][10]=postPeakTime
	snr_wave[dimIndex][11]=prePeakTime
	snr_wave[dimIndex][12]=post_cross3xtime
	snr_wave[dimIndex][13]=post_cross5xtime
	snr_wave[dimIndex][14]=pre_cross3xtime
	snr_wave[dimIndex][15]=pre_cross5xtime
	find_event_times_plotted(1,PS_ID, HS, photostim_name, 10*baseline_SD)
	wave numCrossings_PSHS_wave,firstCrossing_PSHs_wave,numCrossings_PSHS_wave_pre,firstCrossing_PSHs_wave_pre
	wavestats/q numCrossings_PSHS_wave
	variable post_cross_perSweep=V_avg
	variable post_cross_perSweep_SD=V_Sdev
	wavestats/q numCrossings_PSHS_wave_pre
	variable pre_cross_perSweep=V_avg
	variable pre_cross_perSweep_SD=V_sdev
	wavestats/q firstcrossing_PSHS_wave
	variable post_first_cross_avg=V_avg
	variable post_first_cross_SD=V_sdev
	wavestats/q firstcrossing_PSHS_wave_pre
	variable pre_first_cross_avg=V_avg
	variable pre_first_cross_SD=V_sdev
	snr_wave[dimIndex][16]=post_cross_perSweep
	snr_wave[dimIndex][17]=post_cross_persweep_SD
	snr_wave[dimIndex][18]=pre_cross_persweep
	snr_wave[dimIndex][19]=pre_cross_persweep_SD
	snr_wave[dimIndex][20]=post_first_cross_avg
	snr_wave[dimIndex][21]=post_first_cross_SD
	snr_wave[dimIndex][22]=pre_first_cross_avg
	snr_wave[dimIndex][23]=pre_first_cross_SD
	setdatafolder saveDFR
end

Function find_event_times_plotted(riseORfall, PS_ID, headstage, photostim_name, threshold) 
	variable riseORfall, PS_ID, headstage, threshold
	string photostim_name
	make_cnx_folder(photostim_name)
	DFREF opto_df=root:opto_df:
	dfref PS_df= root:opto_df:$photostim_name
	SetDataFolder opto_df
	string traceList=tracenamelist("",";",1)
	string HS_match="AD"+num2str(headstage)
	string sweep_list_HS=waveList(("*"+HS_match), ";", "WIN:")
	Make/o/T/N=(ItemsInList(sweep_list_HS, ";")) sweeps_used_SNR
	sweeps_used_SNR = StringFromList(p, sweep_list_HS, ";")
	Duplicate/o sweeps_used_SNR PS_df:sweeps_used_SNR
	variable numberOfSweeps=itemsinlist(sweep_list_hs,";")
	variable i
	SetDataFolder root:opto_df:snr_df
	Make/o/n=(numberOfSweeps) numCrossings_PSHS_wave, firstCrossing_PSHS_wave, numCrossings_PSHS_wave_pre, firstCrossing_PSHS_wave_pre
	SetDataFolder opto_df
	for (i=0; i<numberofsweeps;i+=1)
		string thisWaveName=stringfromlist(i,sweep_list_HS)
		wave thisWave=root:opto_df:$thisWaveName
		find_event_times_sweep(thisWave,threshold)
	
		wave event_times, event_decon_amps, event_amps
		wave event_times_pre, event_decon_amps_pre, event_amps_pre
		string times_name=thisWaveName+"_event_times"
		string dc_amps_name=thisWaveName+"_dc_amps"
		string amps_name=thisWaveName+"_amps"
		string times_name_pre=thisWaveName+"_event_times_pre"
		string dc_amps_name_pre=thisWaveName+"_dc_amps_pre"
		string amps_name_pre=thisWaveName+"_amps_pre"
		Duplicate/o event_times PS_df:$times_name
		Duplicate/o event_decon_amps PS_df:$dc_amps_name
		Duplicate/o event_amps PS_df:$amps_name
		Duplicate/o event_times_pre PS_df:$times_name_pre
		Duplicate/o event_decon_amps_pre PS_df:$dc_amps_name_pre
		Duplicate/o event_amps_pre PS_df:$amps_name_pre
		variable num_events=numpnts(event_times)
		variable first_event=event_times[0]
		variable num_events_pre=numpnts(event_times_pre)
		variable first_event_pre=event_times_pre[0]
		SetDataFolder root:opto_df:snr_df
		numCrossings_PSHS_wave[i]=num_events
		firstCrossing_PSHs_wave[i]=first_event
		numCrossings_PSHS_wave_pre[i]=num_events_pre
		firstCrossing_PSHs_wave_pre[i]=first_event_pre
	endfor
end

Function make_power0_wave() //make a wave to store SNR values for each pair probed at initial mapping power
	DFREF saveDFR=GetDataFolderDFR()
	SetDataFolder root:opto_df:SNR_df
	Make/o/N=(1,5)/D SNR_power0
		SetDimLabel 1,0, pairID, SNR_power0 //problem pairID has to be number since everything else is number
		SetDimLabel 1,1, noise, SNR_power0
		SetDimLabel 1,2, signal, SNR_power0
		SetDimLabel 1,3, SNR, SNR_power0
		SetDimLabel 1,4, numSweeps, SNR_power0
	SNR_power0=NaN
	

	
	SetDataFolder saveDFR
end

Function find_unique_stimP_HS_pairs()
	wave uniqueStimIds=root:opto_df:uniqueStimIds
	variable i
	for (i=0;i<numpnts(uniqueStimIds);i+=1)
		variable stim_id_i=uniqueStimIds[i]
		//incomplete, look for HS w/ QC values?
		//alternative strategy of looking for photoStims with a calculated average
	
	
	endfor

end


Function avg_for_HS_list(HS, sweeps_wave, root_name)
	variable HS
	wave sweeps_wave
	string root_name
	string avg_Name=root_name+"_avg"
	string sd_name=root_name+"_sd"
	variable i
	string sweep_list=""
	for (i=0; i<numpnts(sweeps_wave); i+=1)
		string sweep_name="Sweep_"+num2str(sweeps_wave[i])+"_AD"+num2str(HS)
		
		wave wv=$sweep_name
		if(WaveExists(wv)==1)
			sweep_list+=sweep_Name+";"
		endif
		
	endfor
	
	fWaveAverage(sweep_list,"",1,1,avg_name,sd_name)
end

Function avg_each_power(id, HS, plot_opt)
	variable id, HS, plot_opt
	DFREF saveDFR=GetDataFolderDFR()
	SetDataFolder root:opto_df:
	wave unique_powers
	wave sweeps
	variable i
	for (i=0; i<numpnts(unique_powers);i+=1)
		variable power=unique_powers[i]
		string root_name="photoStim_"+num2str(id)+"_AD"+num2str(HS)+"_"+num2str(power)+"p"
		string avg_name=root_name+"_avg"
		string sd_name=root_name+"_sd"
		find_id_power(id,power)
		avg_for_HS_list(HS, sweeps, root_name)
		if (plot_opt==1)
			string axis_name="L_AD"+num2str(HS)
			appendtograph/W=photostim_graph/L=$axis_name $avg_name
		
		endif
	endfor
	
		
		
	
	SetDataFolder saveDFR
end


Function average_each_axis_power()
	DFREF saveDFR=GetDataFolderDFR()
	controlinfo/W=photostim_ops popup_PSID
	variable PS_ID=str2num(s_value)
	string axes=axislist("")
	axes=listmatch(axes, "L*")
	variable numaxes = itemsinlist(axes, ";")
	variable i
	for (i=0; i<(numaxes);i+=1)
		string axis_name=stringfromlist(i,axes)
		if(CmpStr(axis_name,"L_AD6")!=0)
			
			variable HS=str2num(axis_name[4])
			avg_each_power(PS_ID, HS, 1)
		endif
	endfor
	
	SetDataFolder saveDFR
end


function measureSNR(input_wv)
	wave input_wv
	string pair_id=nameofwave(input_wv)
	wavestats/q/r=(-50,0) input_wv
	variable noise=V_sdev
	wavestats/q/r=(0,50) input_wv
	variable signal=V_max
	wave SNR=root:opto_df:SNR_df:SNR_power0
	

end