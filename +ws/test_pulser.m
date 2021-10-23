classdef test_pulser < ws.model 
    properties  (Access=protected)  % need to see if some of these things should be transient
        electrode_index_  % index into the array of *all* electrodes (or empty)
        pulse_duration_  % the duration of the pulse, in s.  The sweep duration is twice this.
        do_subtract_baseline_
        ylimits_
        is_auto_y_  % if true, the y limits are synced to the monitor signal currently in view
        is_auto_yrepeating_
            % If IsAutoY_ is true:
            %     If IsAutoYRepeating_ is true , we sync the y limits to the monitor signal currently in
            %     view every N test pulses.  if false, the syncing is only done once,
            %     after one of the early test pulses
            % If IsAutoY_ is false:
            %     Has no effect.
        desired_rate_of_auto_ying_ = 10  % Hz, for now this never changes
            % The desired rate of syncing the Y to the data
    end
    
    properties  (Access=protected, Transient=true)
        is_running_
        update_rate_
        nsweeps_completed_this_run_
        input_task_
        output_task_
        timer_value_
        last_toc_
        amplitude_per_electrode_cached_  % cached double version of AmplitudeAsDoublePerElectrode, for speed during sweeps
        is_ccper_electrode_cached_  
        is_vcper_electrode_cached_  
        monitor_channel_inverse_scale_per_electrode_cached_
        monitor_cached_  % a cache of the monitor signal for the current electrode
        nscans_in_sweep_cached_
        nelectrodes_cached_
        i0_base_cached_
        if_base_cached_
        i0_pulse_cached_
        if_pulse_cached_
        gain_per_electrode_
        gain_or_resistance_per_electrode_
        monitor_per_electrode_
        nsweeps_per_auto_y_  % if IsAutoY_ and IsAutoYRepeating_, we update the y limits every this many sweeps (if we can)
        nsweeps_completed_as_of_last_ylimits_update_
        gain_or_resistance_units_per_electrode_cached_
        sampling_rate_cached_
    end    
    
    methods
        function self = test_pulser()            
            %self@ws.Model() ;
            % ElectrodeIndex_ defaults to empty, therefore there is no test pulse
            % electrode as far as we're concerned
            self.pulse_duration_ = 10e-3 ;  % s
            self.do_subtract_baseline_=true;
            self.is_auto_y_=true;
            self.is_auto_yrepeating_=false;
            self.ylimits_=[-10 +10];
            self.is_running_=false;
            self.update_rate_=nan;
            self.monitor_per_electrode_ = [] ;
        end  % method
        
        function delete(self)  %#ok<INUSD>
            %self.Parent_=[];  % not necessary, but harmless
        end  % method
        
        function did_set_analog_channel_units_or_scales(self)
            self.clear_existing_sweep_if_present_();
            %self.broadcast('Update');            
        end
           
        function result = get_electrode_index(self)
            result = self.electrode_index_ ;
        end

        function set_electrode_index(self, new_value)
            old_value = self.electrode_index_ ;
            self.electrode_index_ = new_value ;
            if ~isequal(new_value, old_value) ,
                self.clear_existing_sweep_if_present_() ;
            end
            %self.setCurrentTPElectrodeToFirstTPElectrodeIfInvalidOrEmpty_(electrodeCount) ;
        end
        
        function value=get_pulse_duration_(self)  % s
            %value=1e-3*str2double(self.PulseDurationInMsAsString_);  % ms->s
            value = self.pulse_duration_ ;
        end
        
        function set_pulse_duration(self, new_value)  % the duration of the pulse, in seconds.  The sweep duration is twice this.
            if isscalar(new_value) && isreal(new_value) && isfinite(new_value) ,
                self.pulse_duration_ = max(5e-3, min(double(new_value), 500e-3)) ;
                self.clear_existing_sweep_if_present_() ;
            end
            %self.broadcast('Update');
        end

        function commands = get_command_per_electrode(self, fs, amplitude_per_electrode)  
            % Command signal for each test pulser electrode, each in units given by the ChannelUnits property 
            % of the Stimulation object
            %t = self.Time ;  % col vector
            t = self.get_time_(fs) ;  % col vector
            delay = self.pulse_duration_/2 ;
            %amplitudePerElectrode = self.AmplitudePerElectrode ;  % row vector
            unscaled_command = (delay<=t)&(t<delay+self.pulse_duration_) ;  % col vector
            commands = bsxfun(@times, amplitude_per_electrode, unscaled_command) ;
        end  
        
        function commands_in_volts = get_command_in_volts_per_electrode(self, fs, amplitude_per_electrode, command_channel_scale_per_test_pulse_electrode)  
            % the command signals, in volts to be sent out the AO channels
            %commands=self.CommandPerElectrode;   % (nScans x nCommandChannels)
            commands = self.get_command_per_electrode(fs, amplitude_per_electrode) ;  % (nScans x nCommandChannels)
            %commandChannelScales=self.CommandChannelScalePerElectrode;  % 1 x nCommandChannels
            inverse_channel_scales=1./command_channel_scale_per_test_pulse_electrode;
            % zero any channels that have infinite (or nan) scale factor
            sanitized_inverse_channel_scales=ws.fif(isfinite(inverse_channel_scales), inverse_channel_scales, zeros(size(inverse_channel_scales)));
            commands_in_volts=bsxfun(@times,commands,sanitized_inverse_channel_scales);
        end                                                        

        function value=get_do_subtract_baseline_(self)
            value=self.do_subtract_baseline_;
        end
        
        function set_do_subtract_baseline(self, new_value)
            if islogical(new_value) ,
                self.do_subtract_baseline_ = new_value ;
                self.clear_existing_sweep_if_present_();
            end
            %self.broadcast('Update');
        end
        
        function value=get_is_auto_y_(self)
            value=self.is_auto_y_;
        end
        
        function set_is_auto_y_(self,new_value)
            if islogical(new_value) ,
                self.is_auto_y_=new_value;
                if self.is_auto_y_ ,                
                    y_limits=self.automatic_ylimits();
                    if ~isempty(y_limits) ,                    
                        self.ylimits_=y_limits;
                    end
                end
            end
            %self.broadcast('Update');
        end
        
        function value=get_is_auto_yrepeating_(self)
            value=self.is_auto_yrepeating_;
        end
        
        function set_is_auto_yrepeating_(self, new_value)
            if islogical(new_value) && isscalar(new_value) ,
                self.is_auto_yrepeating_=new_value;
            end
            %self.broadcast('Update');
        end
              
        function value = get_time_(self, fs)  % s
            dt = 1/fs ;  % s
            n_scans_in_sweep = self.get_nscans_in_sweep_(fs) ;
            value = dt*(0:(n_scans_in_sweep-1))' ;  % s
        end
        
        function value = get_nscans_in_sweep_(self, fs)
            dt = 1/fs ;  % s
            sweep_duration = 2*self.pulse_duration_ ;
            value = round(sweep_duration/dt) ;
        end
        
        function value=get_is_running_(self)
            value=self.is_running_;
        end

        function result = get_gain_or_resistance_units_per_test_pulse_electrode_cached_(self)
            result = self.gain_or_resistance_units_per_electrode_cached_ ;
        end        

        function result = get_gain_or_resistance_per_electrode(self)
            result = self.gain_or_resistance_per_electrode_ ;
        end
        
        function value = get_update_rate_(self)
            value = self.update_rate_ ;
        end
        
        function y_limits = automatic_ylimits(self)
            % Trys to determine the automatic y limits from the monitor
            % signal.  If succful, returns them.  If unsuccessful, returns empty.
            monitor = self.monitor_cached_ ;
            if isempty(monitor) ,
                y_limits = [] ;
            else
                monitor_max=max(monitor);
                monitor_min=min(monitor);
                if ~isempty(monitor_max) && ~isempty(monitor_min) && isfinite(monitor_min) && isfinite(monitor_max) ,
                    monitor_center=(monitor_min+monitor_max)/2;
                    monitor_radius=(monitor_max-monitor_min)/2;
                    if monitor_radius==0 ,
                        y_lo=monitor_center-10;
                        y_hi=monitor_center+10;
                    else
                        y_lo=monitor_center-1.2*monitor_radius;
                        y_hi=monitor_center+1.2*monitor_radius;
                    end
                    y_limits=[y_lo y_hi];
                else
                    y_limits=[];
                end            
            end
        end  % function

        function set_ylimits(self, new_value)
            if isnumeric(new_value) && isequal(size(new_value),[1 2]) && all(isfinite(new_value)) && new_value(1)<new_value(2),
                self.ylimits_=new_value;
            end
            %self.broadcast('Update');
        end
        
        function result = get_ylimits_(self)
            result = self.ylimits_ ;
        end

        function adding_electrode(self, new_electrode_index, electrode_count_after)  %#ok<INUSL>
            % Called by the parent Ephys when an electrode is added.
            %self.clearExistingSweepIfPresent_() ;
            %if isempty(self.ElectrodeIndex_) && isElectrodeMarkedForTestPulseAfter,
            %    self.ElectrodeIndex_ = electrodeIndex ;
            %end
            if isempty(self.electrode_index_) && electrode_count_after>=1 ,
                self.set_electrode_index(1) ;
            end
            %self.broadcast('Update') ;
        end

        function electrodes_removed(self, was_removed, electrode_count_after)
            % Called by the parent Ephys when one or more electrodes are
            % removed.
            electrode_index_before = self.electrode_index_ ;
            
            if isempty(electrode_index_before) ,
                % Not much to do in this case
            else                
                % Check if the TP trode was removed
                was_tpelectrode_removed = was_removed(electrode_index_before) ;
                if was_tpelectrode_removed ,
                    % TP trode *was* removed
                    if electrode_count_after>=1 ,
                        % If there's any other electrodes, set the TP trode to the first one
                        % Can't use setElectrodeIndex() b/c want to force the clearing of the
                        % existing sweep
                        self.set_electrode_index(1) ;
                        if electrode_index_before==1 ,
                            % setElectrodeIndex() won't do this if the new index is the same, even though
                            % it's a different trode now.
                            self.clear_existing_sweep_if_present_() ;
                        end
                    else
                        % If no electrodes left, there can be no TP trode
                        self.set_electrode_index([]) ;  % this will clear, b/c electrodeIndexBefore is nonempty
                    end
                else                    
                    % TP trode was *not* removed
                    % Correct the electrode index
                    self.electrode_index_ = ws.correct_index_after_removal(electrode_index_before, was_removed) ;
                end
            end
            
            %self.broadcast('Update') ;
        end  % function
        
        function prepare_for_start(self, ...
                                 amplitude_per_test_pulse_electrode, ...
                                 fs, ...
                                 gain_or_resistance_units_per_test_pulse_electrode, ...
                                 is_vcper_test_pulse_electrode, ...
                                 is_ccper_test_pulse_electrode, ...
                                 command_terminal_idper_test_pulse_electrode, ...
                                 monitor_terminal_idper_test_pulse_electrode, ...
                                 command_channel_scale_per_test_pulse_electrode, ...
                                 monitor_channel_scale_per_test_pulse_electrode, ...
                                 device_name, ...
                                 primary_device_name, ...
                                 is_primary_device_apxidevice, ...
                                 ws_model)
            % Get the stimulus
            commands_in_volts = self.get_command_in_volts_per_electrode(fs, amplitude_per_test_pulse_electrode, command_channel_scale_per_test_pulse_electrode) ;
            n_scans=size(commands_in_volts,1);
            n_electrodes=size(commands_in_volts,2);

            % Set up the input task
            % fprintf('About to create the input task...\n');
            %self.InputTask_ = ws.dabs.ni.daqmx.Task('Test Pulse Input');
            self.input_task_ = ws.ni('DAQmxCreateTask', 'Test Pulse Input') ;
            for i=1:n_electrodes ,
                %self.InputTask_.createAIVoltageChan(deviceName, monitorTerminalIDPerTestPulseElectrode(i));  % defaults to differential
                terminal_id = monitor_terminal_idper_test_pulse_electrode(i) ;
                physical_channel_name = sprintf('%s/ai%d', device_name, terminal_id) ;                
                ws.ni('DAQmxCreateAIVoltageChan', ...
                      self.input_task_, ...
                      physical_channel_name, ...
                      'DAQmx_Val_Diff') ;
            end
            [reference_clock_source, reference_clock_rate] = ...
                ws.get_reference_clock_source_and_rate(device_name, primary_device_name, is_primary_device_apxidevice) ;
            %set(self.InputTask_, 'refClkSrc', referenceClockSource) ;
            %set(self.InputTask_, 'refClkRate', referenceClockRate) ;            
            ws.ni('DAQmxSetRefClkSrc', self.input_task_, reference_clock_source) ;
            ws.ni('DAQmxSetRefClkRate', self.input_task_, reference_clock_rate) ;
            %deviceName = self.Parent.Parent.DeviceName ;
            clock_string=sprintf('/%s/ao/SampleClock',device_name);  % device name is something like 'Dev3'
            %self.InputTask_.cfgSampClkTiming(fs,'DAQmx_Val_ContSamps',[],clockString);
            ws.ni('DAQmxCfgSampClkTiming', self.input_task_, clock_string, fs, 'DAQmx_Val_Rising', 'DAQmx_Val_ContSamps', 0);            
              % set the sampling rate, and use the AO sample clock to keep
              % acquisiton synced with analog output
            %self.InputTask_.cfgInputBuffer(10*nScans);
            ws.ni('DAQmxCfgInputBuffer', self.input_task_, 10*n_scans);
            
            % Set up the output task
            % fprintf('About to create the output task...\n');
            %self.OutputTask_ = ws.dabs.ni.daqmx.Task('Test Pulse Output');
            self.output_task_ = ws.ni('DAQmxCreateTask', 'Test Pulse Output') ;
            for i=1:n_electrodes ,
                %self.OutputTask_.createAOVoltageChan(deviceName, commandTerminalIDPerTestPulseElectrode(i));
                terminal_id = command_terminal_idper_test_pulse_electrode(i) ;
                physical_channel_name = sprintf('%s/ao%d', device_name, terminal_id) ;
                ws.ni('DAQmxCreateAOVoltageChan', self.output_task_, physical_channel_name) ;
            end
            %set(self.OutputTask_, 'refClkSrc', referenceClockSource) ;
            %set(self.OutputTask_, 'refClkRate', referenceClockRate) ;            
            ws.ni('DAQmxSetRefClkSrc', self.output_task_, reference_clock_source) ;
            ws.ni('DAQmxSetRefClkRate', self.output_task_, reference_clock_rate) ;
            %self.OutputTask_.cfgSampClkTiming(fs,'DAQmx_Val_ContSamps',nScans);
            ws.ni('DAQmxCfgSampClkTiming', self.output_task_, '', fs, 'DAQmx_Val_Rising', 'DAQmx_Val_ContSamps', n_scans);

            % Limit the stimulus to the allowable range
            limited_commands_in_volts=max(-10,min(commands_in_volts,+10));

            % Write the command to the output task                
            %self.OutputTask_.writeAnalogData(limitedCommandsInVolts);
            auto_start = false ;  % Don't automatically start the task.  This is typically what you want for a timed task.
            timeout = -1 ;  % wait indefinitely
            ws.ni('DAQmxWriteAnalogF64', self.output_task_, auto_start, timeout, limited_commands_in_volts) ;

            % Set up the input task callback
            %nSamplesPerSweep=nScans*nElectrodes;
            %self.InputTask_.everyNSamples = nScans ;
            %self.InputTask_.everyNSamplesEventCallbacks = @(varargin)(wsModel.completingTestPulserSweep()) ;
            ws.ni('DAQmxRegisterEveryNSamplesEvent', self.input_task_, n_scans, @()(ws_model.completing_test_pulser_sweep())) ;

            % Does this help?  Yes!!! This fixes it!!!!
            %ws.ni('DAQmxStopTask', self.InputTask_) ;  % For some reason, this makes registering the callback work on the 2nd and subsequent times
            %  Moved the stop call into ws.ni('DAQmxRegisterEveryNSamplesEvent', ...)
            %  'method'.  Seems to do the trick.
            %ws.restlessSleep(0.010);  % pause for 10 ms  % this does not seem to matter,
                                       % but leave it here but commented in case there's trouble later
            
            % Cache some things for speed during sweeps
            self.is_vcper_electrode_cached_ = is_vcper_test_pulse_electrode ;
            self.is_ccper_electrode_cached_ = is_ccper_test_pulse_electrode;
            self.monitor_channel_inverse_scale_per_electrode_cached_ = 1./monitor_channel_scale_per_test_pulse_electrode ;
            self.amplitude_per_electrode_cached_ = amplitude_per_test_pulse_electrode ;
            %self.IndexOfElectrodeWithinTPElectrodesCached_ = indexOfTestPulseElectrodeWithinTestPulseElectrodes ;
            self.nscans_in_sweep_cached_ = self.get_nscans_in_sweep_(fs) ;
            self.nelectrodes_cached_ = double(~isempty(self.electrode_index_)) ;
            self.gain_or_resistance_units_per_electrode_cached_ = gain_or_resistance_units_per_test_pulse_electrode ;
            self.sampling_rate_cached_ = fs ;

            % Compute some indices and cache them, again for speed during
            % sweeps
            sweep_duration = 2 * self.pulse_duration_ ;  % s
            t0_base=0; % s
            tf_base=1/8*sweep_duration; % s
            t0_pulse=5/8*sweep_duration; % s
            tf_pulse=6/8*sweep_duration; % s
            %dt=self.Dt;
            dt = 1/fs;  % s
            self.i0_base_cached_ = floor(t0_base/dt)+1;
            self.if_base_cached_ = floor(tf_base/dt);
            self.i0_pulse_cached_ = floor(t0_pulse/dt)+1;
            self.if_pulse_cached_ = floor(tf_pulse/dt);            

            % Set the where-the-rubber-meets-the-road auto-Y parameters, given the user-supplied parameters
            if self.is_auto_y_ ,
                if self.is_auto_yrepeating_ ,
                    % repeating auto y
                    self.nsweeps_completed_as_of_last_ylimits_update_ = -inf ;
                    self.nsweeps_per_auto_y_ =  min(1,round(1/(sweep_duration * self.desired_rate_of_auto_ying_))) ;
                else
                    % Auto Y only at start
                    self.nsweeps_completed_as_of_last_ylimits_update_ = -inf ;
                    self.nsweeps_per_auto_y_ = inf ;
                        % this ends up working b/c inf>=inf in IEEE
                        % floating-point 
                end
            else
                % No auto Y
                self.nsweeps_completed_as_of_last_ylimits_update_ = inf ;  % this will make it so that y limits are never updated
                self.nsweeps_per_auto_y_ = 1 ;  % this doesn't matter, b/c of the line above, so just set to unity
            end

            % Finish up the prep
            self.nsweeps_completed_this_run_=0;
            self.is_running_=true;
        end  % function
        
        function start_(self)
            % Set up timing
            self.timer_value_=tic();
            self.last_toc_=toc(self.timer_value_);
            
            % actually start the data acq tasks
            %self.InputTask_.start();  % won't actually start until output starts b/c see above
            %self.OutputTask_.start();
            ws.ni('DAQmxStartTask', self.input_task_) ;  % won't actually start until output starts b/c see above
            ws.ni('DAQmxStartTask', self.output_task_) ;
        end
        
        function stop_(self)
            % This is what gets called when the user presses the 'Stop' button,
            % for instance.
            %fprintf('Just entered stop()...\n');            
            % Takes some time to stop...
            %self.changeReadiness(-1);
            %self.IsReady_ = false ;
            %self.broadcast('UpdateReadiness');

            %if self.IsStopping_ ,
            %    fprintf('Stopping while already stopping...\n');
            %    dbstack
            %else
            %    self.IsStopping_=true;
            %end
            if ~isempty(self.output_task_) ,
                %self.OutputTask_.stop();
                %fprintf('About to stop task at point 1\n');
                ws.ni('DAQmxStopTask', self.output_task_) ;
                %fprintf('Done stopping task at point 1\n');
            end
            if ~isempty(self.input_task_) ,            
                %self.InputTask_.stop();
                %fprintf('About to stop task at point 2\n');
                ws.ni('DAQmxStopTask', self.input_task_) ;
                %fprintf('Done stopping task at point 2\n');
            end

            %
            % make sure the output is set to the non-pulsed state
            % (Is there a better way to do this?)
            %
            n_scans = 1000 ;  % 2 scans doesn't seem to work reliably, not sure where the cutoff is
            %self.OutputTask_.cfgSampClkTiming(self.SamplingRateCached_,'DAQmx_Val_ContSamps',nScans);
            ws.ni('DAQmxCfgSampClkTiming', self.output_task_, '', self.sampling_rate_cached_, 'DAQmx_Val_Rising', 'DAQmx_Val_ContSamps', n_scans);
            %commandsInVolts=zeros(self.NScansInSweep,self.NElectrodes);
            commands_in_volts = zeros(n_scans,self.nelectrodes_cached_) ;
            %self.OutputTask_.writeAnalogData(commandsInVolts);
            auto_start = false ;  % Don't automatically start the task.  This is typically what you want for a timed task.
            timeout = -1 ;  % wait indefinitely
            ws.ni('DAQmxWriteAnalogF64', self.output_task_, auto_start, timeout, commands_in_volts) ;
            %self.OutputTask_.start();
            ws.ni('DAQmxStartTask', self.output_task_) ;
            % pause for 10 ms without relinquishing control
%             timerVal=tic();
%             while (toc(timerVal)<0.010)
%                 x=1+1; %#ok<NASGU>
%             end            
            ws.restless_sleep(0.010);  % pause for 10 ms
            %self.OutputTask_.stop();
            %fprintf('About to stop task at point 3\n');
            ws.ni('DAQmxStopTask', self.output_task_) ;
            %fprintf('Done stopping task at point 3\n');
            % % Maybe try this: java.lang.Thread.sleep(10);

            % Continue with stopping stuff
            % fprintf('About to delete the tasks...\n');
            %self
            %delete(self.InputTask_);  % Have to explicitly delete b/c it's a DABS task
            %delete(self.OutputTask_);  % Have to explicitly delete b/c it's a DABS task
            %fprintf('About to clear input task\n') ;
            ws.ni('DAQmxClearTask', self.input_task_) ;
            %fprintf('Done clearing input task\n') ;
            self.input_task_=[];
            ws.ni('DAQmxClearTask', self.output_task_) ;
            self.output_task_=[];
            % maybe need to do more here...
            self.is_running_=false;

%                 % Notify the rest of Wavesurfer
%                 ephys=self.Parent;
%                 wavesurferModel=[];
%                 if ~isempty(ephys) ,
%                     wavesurferModel=ephys.Parent;
%                 end                
%                 if ~isempty(wavesurferModel) ,
%                     wavesurferModel.didPerformTestPulse();
%                 end

            % Takes some time to stop...
            %self.changeReadiness(+1);
            %self.IsReady_ = true ;
            %self.broadcast('Update');
        end  % function
        
        function abort(self)
            % This is called when a problem arises during test pulsing, and we
            % want to try very hard to get back to a known, sane, state.

            % % And now we are once again ready to service method calls...
            % self.changeReadiness(-1);

            % Try to gracefully wind down the output task
            if isempty(self.output_task_) ,
                % nothing to do here
            else
                try
                    %self.OutputTask_.stop();
                    %delete(self.OutputTask_);  % it's a DABS task, so have to manually delete
                    %fprintf('About to stop task at point 4\n');
                    ws.ni('DAQmxStopTask', self.output_task_) ;
                    %fprintf('Done stopping task at point 4\n');
                    ws.ni('DAQmxClearTask', self.output_task_) ;
                      % this delete() can throw, if, e.g. the daq board has
                      % been turned off.  We discard the error because we're
                      % trying to do the best we can here.
                catch me  %#ok<NASGU>
                    % Not clear what to do here...
                    % For now, just ignore the error and forge ahead
                end
                % At this point self.OutputTask_ is no longer valid
                self.output_task_ = [] ;
            end
            
            % Try to gracefully wind down the input task
            if isempty(self.input_task_) ,
                % nothing to do here
            else
                try
                    %self.InputTask_.stop();
                    %delete(self.InputTask_);  % it's a DABS task, so have to manually delete
                    %fprintf('About to stop task at point 5\n');
                    ws.ni('DAQmxStopTask', self.input_task_) ;
                    %fprintf('Done stopping task at point 5\n');
                    ws.ni('DAQmxClearTask', self.input_task_) ;
                      % this delete() can throw, if, e.g. the daq board has
                      % been turned off.  We discard the error because we're
                      % trying to do the best we can here.
                catch me  %#ok<NASGU>
                    % Not clear what to do here...
                    % For now, just ignore the error and forge ahead
                end
                % At this point self.InputTask_ is no longer valid
                self.input_task_ = [] ;
            end
            
            % Set the current run state
            self.is_running_=false;

%             % Notify the rest of Wavesurfer
%             ephys=self.Parent;
%             wavesurferModel=[];
%             if ~isempty(ephys) ,
%                 wavesurferModel=ephys.Parent;
%             end                
%             if ~isempty(wavesurferModel) ,
%                 wavesurferModel.didAbortTestPulse();
%             end
            
            % % And now we are once again ready to service method calls...
            % self.changeReadiness(+1);
        end  % function
        
        function completing_sweep(self)
            % compute resistance
            % compute delta in monitor
            % Specify the time windows for measuring the baseline and the pulse amplitude
            %rawMonitor=self.InputTask_.readAnalogData(self.NScansInSweepCached_);  % rawMonitor is in V, is NScansInSweep x NElectrodes
            raw_monitor = ws.ni('DAQmxReadAnalogF64', self.input_task_, self.nscans_in_sweep_cached_, -1) ;
                % We now read exactly the number of scans we expect.  Not
                % doing this seemed to work fine on ALT's machine, but caused
                % nasty jitter issues on Minoru's rig machine.  In retrospect, kinda
                % surprising it ever worked without specifying this...
            if size(raw_monitor,1)~=self.nscans_in_sweep_cached_ ,
                % this seems to happen occasionally, and when it does we abort the update
                return  
            end
            scaled_monitor=bsxfun(@times,raw_monitor,self.monitor_channel_inverse_scale_per_electrode_cached_);
            i0_base=self.i0_base_cached_;
            if_base=self.if_base_cached_;
            i0_pulse=self.i0_pulse_cached_;
            if_pulse=self.if_pulse_cached_;
            base=mean(scaled_monitor(i0_base:if_base,:),1);
            pulse=mean(scaled_monitor(i0_pulse:if_pulse,:),1);
            monitor_delta=pulse-base;
            self.gain_per_electrode_=monitor_delta./self.amplitude_per_electrode_cached_;
            % Compute resistance per electrode
            self.gain_or_resistance_per_electrode_=self.gain_per_electrode_;
            self.gain_or_resistance_per_electrode_(self.is_vcper_electrode_cached_)= ...
                1./self.gain_per_electrode_(self.is_vcper_electrode_cached_);
            if self.do_subtract_baseline_ ,
                self.monitor_per_electrode_=bsxfun(@minus,scaled_monitor,base);
            else
                self.monitor_per_electrode_=scaled_monitor;
            end
            self.monitor_cached_=self.monitor_per_electrode_ ;
            self.try_to_set_ylimits_if_called_for_();
            self.nsweeps_completed_this_run_=self.nsweeps_completed_this_run_+1;
            
            % Update the UpdateRate_
            this_toc=toc(self.timer_value_);
            if ~isempty(self.last_toc_) ,
                update_interval=this_toc-self.last_toc_;  % s
                self.update_rate_=1/update_interval;  % Hz
                %fprintf('Update frequency: %0.1f Hz\n',updateFrequency);
            end
            self.last_toc_=this_toc;
            
            %self.broadcast('UpdateTrace');
            %fprintf('About to exit TestPulser::completingSweep()\n');            
        end  % function
        
        function zoom_in(self)
            y_limits=self.ylimits_;
            y_middle=mean(y_limits);
            y_radius=0.5*diff(y_limits);
            new_ylimits=y_middle+0.5*y_radius*[-1 +1];
            self.ylimits_ = new_ylimits;
            %self.broadcast('Update');
        end  % function
        
        function zoom_out(self)
            y_limits=self.ylimits_;
            y_middle=mean(y_limits);
            y_radius=0.5*diff(y_limits);
            new_ylimits=y_middle+2*y_radius*[-1 +1];
            self.ylimits_ = new_ylimits ;
            %self.broadcast('Update');
        end  % function
        
        function scroll_up(self)
            y_limits=self.ylimits_;
            y_middle=mean(y_limits);
            y_span=diff(y_limits);
            y_radius=0.5*y_span;
            new_ylimits=(y_middle+0.1*y_span)+y_radius*[-1 +1];
            self.ylimits_ = new_ylimits ;
            %self.broadcast('Update');
        end  % function
        
        function scroll_down(self)
            y_limits=self.ylimits_;
            y_middle=mean(y_limits);
            y_span=diff(y_limits);
            y_radius=0.5*y_span;
            new_ylimits=(y_middle-0.1*y_span)+y_radius*[-1 +1];
            self.ylimits_ = new_ylimits ;
            %self.broadcast('Update');
        end  % function
                
        function did_set_acquisition_sample_rate(self, new_value)  %#ok<INUSD>
            % newValue has already been validated
            %self.setSamplingRate_(newValue) ;  % This will fire Update, etc.
            self.clear_existing_sweep_if_present_() ;        
        end       
        
%         function didSetIsInputChannelActive(self) 
%             %self.broadcast('DidSetIsInputChannelActive');
%         end
    end  % methods
        
    methods (Access=protected)                
        function clear_existing_sweep_if_present_(self)
            self.monitor_per_electrode_ = [] ;
            self.monitor_cached_ = [] ;
            if isempty(self.electrode_index_) ,                
                self.gain_per_electrode_ = [] ;
                self.gain_or_resistance_per_electrode_ = [] ;
            else
                self.gain_per_electrode_ = nan ;
                self.gain_or_resistance_per_electrode_ = nan ;
            end
            self.update_rate_ = nan ;
        end  % function
        
        function try_to_set_ylimits_if_called_for_(self)
            % If setting the y limits is appropriate right now, try to set them
            % Sets AreYLimitsForRunDetermined_ and YLimits_ if successful.
            if self.is_running_ ,
                n_sweeps_since_last_update = self.nsweeps_completed_this_run_ - self.nsweeps_completed_as_of_last_ylimits_update_ ;
                if n_sweeps_since_last_update >= self.nsweeps_per_auto_y_ ,
                    y_limits=self.automatic_ylimits();
                    if ~isempty(y_limits) ,
                        self.nsweeps_completed_as_of_last_ylimits_update_ = self.nsweeps_completed_this_run_ ;
                        self.ylimits_ = y_limits ;
                    end
                end
            end
        end  % function        
    end  % protected methods block
    
    methods
        function result = get_monitor_per_electrode_(self)
            result = self.monitor_per_electrode_ ;
        end
    end
    
    % These next two methods allow access to private and protected variables from ws.Encodable. 
    methods 
        function out = get_property_value_(self, name)
            out = self.(name);
        end  % function
        
        function set_property_value_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
    methods
        function mimic(self, other)
            ws.mimic_bang(self, other) ;
        end
        
        function synchronize_transient_state_to_persisted_state_(self)
            self.clear_existing_sweep_if_present_() ;  % mainly to dimension self.GainPerElectrode_ and self.GainOrResistancePerElectrode_ properly
        end  % function                
    end    
    
    methods
        % These are intended for getting/setting *public* properties.
        % I.e. they are for general use, not restricted to special cases like
        % encoding or ugly hacks.
        function result = get(self, property_name) 
            result = self.(property_name) ;
        end
        
        function set(self, property_name, new_value)
            self.(property_name) = new_value ;
        end           
    end  % public methods block        
    
end  % classdef
