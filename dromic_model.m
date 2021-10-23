classdef dromic_model < ws.model
    properties
        trigger_device_type_ = device_type_type.nidq 
        trigger_device_index0_ = 0        
        trigger_channel_index0_ = 8  % assumed to be digital
        trigger_bit_index0_ = 0 
        monitored_device_type_ = device_type_type.imec
        monitored_device_index0_ = 0
        monitored_channel_index0_ = 0  % assumed to be an imec channel
        monitored_threshold_ = 0  % in units of plotted channel
        pre_trigger_duration_ = 100  % ms
        post_trigger_duration_ = 100 % ms
        bin_duration_ = 10  % ms
        do_center_bin_at_zero_ = false  % if true, there's a bin center at t==0, if false there's a bin edge at t==0
        timer_period_ = 200  % ms
        minimum_time_between_spikes_ = 5  % ms
        timer_ = []
        bin_edges_ = []  % ms
        bin_centers_ = []  % ms
        trigger_count_ = 0  % How many triggers have been detected since creation or last reset
        event_count_from_bin_index_ = [] 
        %trigger_index_from_sweep_index_ = zeros(0,1)
        %time_from_spike_index_from_sweep_index_ = cell(0,1)
        spikegl_interface_ = []  
        imec_scan_rate_ = []  % Hz
        nidq_scan_rate_ = []  % Hz
        %imec_scan_interval_ = []  % ms
        %nidq_scan_interval_ = []  % ms
        scan_count_after_trigger_ = []
        carryover_nidq_scan_index_ = -inf
        carryover_trigger_value_ = true  % this prevents a false-positive trigger at the start
        is_running_ = false 
        is_auto_y_ = true
        y_max_ = 10
        handle_timer_tick_call_count_ = 0 
        nidq_scan_index_from_unplotted_trigger_index_ = zeros(0,1)        
        % is_first_tick_after_start_ = true
    end

    methods
        function self = dromic_model(kind_string)
            % if kind_string=='fake', use a fake spikegl
            do_use_fake_spikegl = exist('kind_string', 'var') && strcmp(kind_string, 'fake')  ;
            do_use_real_spikegl = ~do_use_fake_spikegl ;

            % Connect to SpikeGLX
            if do_use_real_spikegl ,
                self.spikegl_interface_ = spikegl_interface_type() ;  % use loopback
            else
                self.spikegl_interface_ = fake_spikegl_interface_type() ;  % use loopback
            end

            % Get sampling rates
            self.imec_scan_rate_ = GetStreamSampleRate(self.spikegl_interface_, device_type_type.imec, self.monitored_device_index0) ;  % Hz
            self.nidq_scan_rate_ = GetStreamSampleRate(self.spikegl_interface_, device_type_type.nidq, self.trigger_device_index0) ;  % Hz
            
            % Initialize the bookkeepings properties
            %self.trigger_index_from_sweep_index_ = zeros(0,1) ;  
            %self.time_from_spike_index_from_sweep_index_ = cell(0,1) ;  
            [self.bin_edges_, self.bin_centers_] = ...
                compute_bins(self.pre_trigger_duration_, self.post_trigger_duration_, self.bin_duration_, self.do_center_bin_at_zero_) ;
            self.event_count_from_bin_index_ = zeros(size(self.bin_centers_)) ;
            self.trigger_count_ = 0 ;
            self.scan_count_after_trigger_ = round(0.001*self.bin_edges_(end)*self.nidq_scan_rate_) ;

            % Create the timer
            self.timer_ = timer('Period', 0.001*self.timer_period, 'ExecutionMode', 'fixedRate', 'TimerFcn', @(~, ~)(self.handle_timer_tick())) ;
        end

        function delete(self)
            self.controller_ = [] ;
            if ~isempty(self.timer_) 
                if isvalid(self.timer_) 
                    self.timer_.stop() ;
                    delete(self.timer_) ;
                end
                self.timer_ = [] ;
            end
            if ~isempty(self.spikegl_interface_)
                if isvalid(self.spikegl_interface_) 
                    delete(self.spikegl_interface_) ;
                end
                self.spikegl_interface_ = [] ;
            end
        end

        function start(self)
            self.carryover_nidq_scan_index_ = -inf ;
            self.carryover_trigger_value_ = true ;  % this prevents a false-positive trigger at the start
            self.is_running_ = true ;
            self.timer_.start() ;
            self.update_control_properties_() ;
        end

        function stop(self)
            self.timer_.stop() ;
            self.is_running_ = false ;
            self.update_control_properties_() ;
        end
        
        function toggle_is_running(self)
            if self.is_running_ ,
                self.stop() ;
            else
                self.start() ;
            end
        end

        function clear_sweeps(self)
            self.trigger_index_from_sweep_index_ = zeros(0,1) ;  
            self.time_from_spike_index_from_sweep_index_ = cell(0,1) ;
            [self.bin_edges_, self.bin_centers_] = compute_bins(self.peri_trigger_window, self.bin_duration) ;
            self.event_count_from_bin_index_ = zeros(size(self.bin_centers_)) ;
            self.trigger_count_ = 0 ;
        end

        function handle_timer_tick(self)
            self.handle_timer_tick_call_count_ = self.handle_timer_tick_call_count_ + 1 ;
            %fprintf('handle_timer_tick() called.  Call count: %d\n', self.handle_timer_tick_call_count_) ;
            if ~self.allow_timer_callback_ ,
                return
            end            
            if ~isempty(self.spikegl_interface_) && IsRunning(self.spikegl_interface_)     
                maximum_nidq_scan_count = ...
                    round(0.001 * self.timer_period * timer_periods_to_fetch() * self.nidq_scan_rate_) ;
                    % Grab at most a few timer periods worth of data
                [int16_nidq_data_from_local_nidq_scan_index, nidq_data_first_nidq_scan_index] = FetchLatest( ...
                    self.spikegl_interface_, ...
                    device_type_type.nidq, ...
                    self.trigger_device_index0, ...
                    maximum_nidq_scan_count, ...
                    self.trigger_channel_index0) ;
                nidq_scan_count = size(int16_nidq_data_from_local_nidq_scan_index, 1) ;
                nidq_data_last_nidq_scan_index = nidq_data_first_nidq_scan_index + nidq_scan_count - 1 ;
                nidq_scan_index_from_local_nidq_scan_index = ...
                    ( nidq_data_first_nidq_scan_index : nidq_data_last_nidq_scan_index )' ;

                % Pare it down to the 'recent' scans, the ones that arrived since the last
                % scan seen in the last call to update_data()
                is_after_last_scan_from_local_nidq_scan_index = ...
                    (nidq_scan_index_from_local_nidq_scan_index>self.carryover_nidq_scan_index_ ) ;
                int16_nidq_data_from_recent_nidq_scan_index = int16_nidq_data_from_local_nidq_scan_index(is_after_last_scan_from_local_nidq_scan_index,:) ;
                nidq_scan_index_from_recent_nidq_scan_index = ...
                    nidq_scan_index_from_local_nidq_scan_index(is_after_last_scan_from_local_nidq_scan_index) ;
                %recent_nidq_scan_count = length(nidq_scan_index_from_recent_nidq_scan_index) ;
                trigger_from_recent_nidq_scan_index = bitget(int16_nidq_data_from_recent_nidq_scan_index, self.trigger_bit_index0+1) ;
                    % bitget() works on int16, properly interpreting them as twos-complement
                if isfinite(self.carryover_nidq_scan_index_) && nidq_data_first_nidq_scan_index > self.carryover_nidq_scan_index_ + 1 
                    % For whatever reason, there's a gap between this chunk of data and the
                    % last
                    self.carryover_trigger_value_ = true ;  
                        % prevents a false-positive trigger at the start.
                        % Missing a trigger is likely better than including a false-positive
                        % trigger.
                    warning('Gap in trigger data: we may have missed one or more trigger events') ;
                end

                % Extract rising edge scan indices from the trigger channel
                trigger_from_recent_nidq_scan_index_plus_one = vertcat(self.carryover_trigger_value_, trigger_from_recent_nidq_scan_index(1:end-1)) ;
                is_rising_edge_from_recent_nidq_scan_index = ...
                    trigger_from_recent_nidq_scan_index & ~trigger_from_recent_nidq_scan_index_plus_one ;
                recent_nidq_scan_index_from_trigger_index = find(is_rising_edge_from_recent_nidq_scan_index) ; 
                nidq_scan_index_from_trigger_index = nidq_scan_index_from_recent_nidq_scan_index(recent_nidq_scan_index_from_trigger_index) ;  %#ok<FNDSB> 
                self.nidq_scan_index_from_unplotted_trigger_index_ = ...
                    vertcat(self.nidq_scan_index_from_unplotted_trigger_index_, ...
                            nidq_scan_index_from_trigger_index) ;

                % If there are unplotted triggers, see if they are ripe for plotting yet
                nidq_scan_index_from_unplotted_trigger_index = self.nidq_scan_index_from_unplotted_trigger_index_ ;
                unplotted_trigger_count = length(nidq_scan_index_from_unplotted_trigger_index) ;
                did_plot_from_unplotted_trigger_index = false(size(nidq_scan_index_from_unplotted_trigger_index)) ;
                if unplotted_trigger_count > 0 ,
                    imec_scan_interval = 1000/self.imec_scan_rate_ ;  % ms
                    imec_window_start_offset_in_scans = floor(self.bin_edges_(1) / imec_scan_interval) ;  % typically negative
                    imec_window_end_offset_in_scans = ceil(self.bin_edges_(end) / imec_scan_interval) ;  % typically positive
                    peri_timestamp_from_imec_window_scan_index = ...
                        imec_scan_interval * (imec_window_start_offset_in_scans : imec_window_end_offset_in_scans) ;   % ms
                    for unplotted_trigger_index = 1 : unplotted_trigger_count ,
                        trigger_nidq_scan_index = nidq_scan_index_from_unplotted_trigger_index(unplotted_trigger_index) ;
                        trigger_imec_scan_index = MapSample( ...
                            self.spikegl_interface_, ...
                            device_type_type.imec, ...
                            self.monitored_device_index0, ...
                            trigger_nidq_scan_index, ...
                            device_type_type.nidq, ...
                            self.trigger_device_index0) ;                        
                           % Fundamentally, we assume that trigger_nidq_scan_index and
                           % trigger_nidq_scan_index occur at the exact same time.  This
                           % should be true plus or minus a scan interval.
                        imec_window_start_in_scans = trigger_imec_scan_index + imec_window_start_offset_in_scans ;
                        imec_window_end_in_scans = trigger_imec_scan_index + imec_window_end_offset_in_scans ;
                        imec_window_scan_count = imec_window_end_in_scans - imec_window_start_in_scans + 1 ;
                        [imec_data_from_window_imec_scan_index, imec_window_scan_count_check] = Fetch( ...
                            self.spikegl_interface_, ...
                            device_type_type.imec, ...
                            self.monitored_device_index0, ...
                            imec_window_start_in_scans, ...
                            imec_window_scan_count, ...
                            self.monitored_channel_index0) ;
                        if imec_window_scan_count_check < imec_window_scan_count ,
                            % The trigger must be too recent to accommodate the post-trigger duration
                            continue
                        end
                        %figure; plot(peri_timestamp_from_imec_window_scan_index, imec_data_from_window_imec_scan_index) ;
                        refractory_scan_count = round(0.001*self.minimum_time_between_spikes*self.imec_scan_rate_) ;
                        is_spike_from_window_imec_scan_index = threshold_crossings_with_refractory_period( ...
                            imec_data_from_window_imec_scan_index, ...
                            self.monitored_threshold, ...
                            refractory_scan_count, ...
                            -inf, ...
                            +inf) ;
                        peri_timestamp_from_spike_index = peri_timestamp_from_imec_window_scan_index(is_spike_from_window_imec_scan_index) ;
                        spike_count_for_this_trigger_from_bin_index = histcounts(peri_timestamp_from_spike_index, self.bin_edges_) ;
                        %max_spike_count_per_bin_for_this_trigger = max(spike_count_for_this_trigger_from_bin_index)
                        self.event_count_from_bin_index_ = self.event_count_from_bin_index_ + spike_count_for_this_trigger_from_bin_index ;
                        self.trigger_count_ = self.trigger_count_ + 1 ;   
                        did_plot_from_unplotted_trigger_index(unplotted_trigger_index) = true ;
                    end
                end

                % Prepare for next data update
                % Update self.last_trigger_value_, etc
                self.nidq_scan_index_from_unplotted_trigger_index_ = ...
                    self.nidq_scan_index_from_unplotted_trigger_index_(~did_plot_from_unplotted_trigger_index) ;
                self.carryover_nidq_scan_index_ = nidq_data_last_nidq_scan_index ;
                self.carryover_trigger_value_ = trigger_from_recent_nidq_scan_index(end) ;

                % show the histogram in text
                %spike_count_from_bin_index = self.spike_count_from_bin_index_
            end

            % Set the y_max, if called for
            if self.is_auto_y_ ,
                self.sync_y_max_from_event_count_from_bin_index_() ;
            end                

%             % Note that this is not the first tick after a start
%             self.is_first_tick_after_start_ = false ;

            % Message the controller to update, if there is a controller
            self.update_histogram_() ;
        end  % method

        function sync_y_max_from_event_count_from_bin_index_(self)
            % Determine a good y_max
            event_count_from_bin_index = self.event_count_from_bin_index_ ;
            fallback_result = 10 ;
            if isempty(event_count_from_bin_index) ,
                self.y_max_ = fallback_result ;
            else
                max_event_count = max(event_count_from_bin_index) ;
                if isfinite(max_event_count) ,
                    naive_buffer = ceil(0.05*max_event_count) ;
                    buffer = max(naive_buffer, 1) ;
                    naive_result = max_event_count + buffer ;
                    self.y_max_ = max(naive_result, fallback_result) ;
                else
                    self.y_max_ = fallback_result ;
                end
            end            
        end

        function result = trigger_device_type(self)
            result = self.trigger_device_type_ ;            
        end

        function set_trigger_device_type(self, new_value)
            new_value_maybe = device_type_maybe_from_whatever(new_value) ;
            if ~isempty(new_value_maybe) ,             
                self.trigger_device_type_ = new_value_maybe{1} ;
            end
            self.update_control_properties_() ;
            if isempty(new_value_maybe) ,
                error('ws:invalid_value', 'Invalid value for trigger_device_type') ;
            end
        end

        function result = trigger_device_index0(self)
            result = self.trigger_device_index0_ ;            
        end

        function set_trigger_device_index0(self, new_value)
            self.trigger_device_index0_ = new_value ;
            self.update_control_properties_() ;
        end

        function result = trigger_channel_index0(self)
            result = self.trigger_channel_index0_ ;
        end

        function set_trigger_channel_index0(self, new_value)
            self.trigger_channel_index0_ = new_value ;
            self.update_control_properties_() ;
        end

        function result = trigger_bit_index0(self)
            result = self.trigger_bit_index0_ ;
        end

        function set_trigger_bit_index0(self, new_value)
            self.trigger_bit_index0_ = new_value ;
            self.update_control_properties_() ;
        end

        function result = monitored_device_type(self)
            result = self.monitored_device_type_ ;            
        end

        function set_monitored_device_type(self, new_value)
            new_value_maybe = device_type_maybe_from_whatever(new_value) ;
            if ~isempty(new_value_maybe) ,             
                self.monitored_device_type_ = new_value_maybe{1} ;
            end
            self.update_control_properties_() ;
            if isempty(new_value_maybe) ,             
                error('ws:invalid_value', 'Invalid value for monitored_device_type') ;                
            end
        end

        
        function result = monitored_device_index0(self)
            result = self.monitored_device_index0_ ;
        end

        function set_monitored_device_index0(self, new_value)
            self.monitored_device_index0_ = new_value ;
            self.update_control_properties_() ;
        end

        function result = monitored_channel_index0(self)
            result = self.monitored_channel_index0_ ;
        end

        function set_monitored_channel_index0(self, new_value)
            self.monitored_channel_index0_ = new_value ;
            self.update_control_properties_() ;
        end

        function result = monitored_threshold(self)
            result = self.monitored_threshold_ ;
        end

        function set_monitored_threshold(self, new_value)
            self.monitored_threshold_ = new_value ;
            self.update_control_properties_() ;
        end

        function result = pre_trigger_duration(self)
            result = self.pre_trigger_duration_ ;
        end

        function set_pre_trigger_duration(self, new_value)
            self.pre_trigger_duration_ = new_value ;
            [self.bin_edges_, self.bin_centers_] = ...
                compute_bins(self.pre_trigger_duration_, self.post_trigger_duration_, self.bin_duration_, self.do_center_bin_at_zero_) ;
            self.event_count_from_bin_index_ = zeros(size(self.bin_centers_)) ;
            self.trigger_count_ = 0 ;
            self.scan_count_after_trigger_ = round(0.001*self.bin_edges_(end)*self.nidq_scan_rate_) ;
            self.update_control_properties_() ;
        end

        function result = post_trigger_duration(self)
            result = self.post_trigger_duration_ ;
        end

        function set_post_trigger_duration(self, new_value)
            self.post_trigger_duration_ = new_value ;
            [self.bin_edges_, self.bin_centers_] = ...
                compute_bins(self.pre_trigger_duration_, self.post_trigger_duration_, self.bin_duration_, self.do_center_bin_at_zero_) ;
            self.event_count_from_bin_index_ = zeros(size(self.bin_centers_)) ;
            self.trigger_count_ = 0 ;
            self.scan_count_after_trigger_ = round(0.001*self.bin_edges_(end)*self.nidq_scan_rate_) ;
            self.update_control_properties_() ;
        end

        function result = bin_duration(self)
            result = self.bin_duration_ ;
        end

        function set_bin_duration(self, new_value)
            self.bin_duration_ = new_value ;
            [self.bin_edges_, self.bin_centers_] = ...
                compute_bins(self.pre_trigger_duration_, self.post_trigger_duration_, self.bin_duration_, self.do_center_bin_at_zero_) ;
            self.event_count_from_bin_index_ = zeros(size(self.bin_centers_)) ;
            self.trigger_count_ = 0 ;
            self.scan_count_after_trigger_ = round(0.001*self.bin_edges_(end)*self.nidq_scan_rate_) ;
            self.update_control_properties_() ;
        end

        function result = do_center_bin_at_zero(self)
            result = self.do_center_bin_at_zero_ ;
        end

        function set_do_center_bin_at_zero(self, new_value)
            self.do_center_bin_at_zero_ = new_value ;
            [self.bin_edges_, self.bin_centers_] = ...
                compute_bins(self.pre_trigger_duration_, self.post_trigger_duration_, self.bin_duration_, self.do_center_bin_at_zero_) ;
            self.event_count_from_bin_index_ = zeros(size(self.bin_centers_)) ;
            self.trigger_count_ = 0 ;
            self.scan_count_after_trigger_ = round(0.001*self.bin_edges_(end)*self.nidq_scan_rate_) ;
            self.update_control_properties_() ;
        end

        function result = timer_period(self)
            result = self.timer_period_ ;
        end

        function set_timer_period(self, new_value)
            self.timer_period_ = new_value ;
            self.update_control_properties_() ;
        end

        function result = minimum_time_between_spikes(self)
            result = self.minimum_time_between_spikes_ ;
        end

        function set_minimum_time_between_spikes(self, new_value)
            self.minimum_time_between_spikes_ = new_value ;
            self.update_control_properties_() ;
        end

        function result = event_count_from_bin_index(self)
            result = self.event_count_from_bin_index_ ;
        end

        function result = is_running(self)
            result = self.is_running_ ;
        end

        function result = y_limits(self)
            result = [0 self.y_max_] ;
        end

        function result = y_max(self)
            result = self.y_max_ ;
        end

        function zoom_in(self)
            y_max = self.y_max_ ;
            new_y_max = y_max/2 ;
            self.y_max_ = new_y_max ;
            self.update_() ;
        end  % function
        
        function zoom_out(self)
            y_max = self.y_max_ ;
            new_y_max = y_max*2 ;
            self.y_max_ = new_y_max ;
            self.update_() ;
        end  % function
        
%         function scroll_up(self)
%             y_limits=self.y_limits_;
%             y_middle=mean(y_limits);
%             y_span=diff(y_limits);
%             y_radius=0.5*y_span;
%             new_y_limits=(y_middle+0.1*y_span)+y_radius*[-1 +1];
%             self.y_limits_ = new_y_limits ;
%             self.update_() ;
%         end  % function
%         
%         function scroll_down(self)
%             y_limits=self.y_limits_;
%             y_middle=mean(y_limits);
%             y_span=diff(y_limits);
%             y_radius=0.5*y_span;
%             new_y_limits=(y_middle-0.1*y_span)+y_radius*[-1 +1];
%             self.y_limits_ = new_y_limits ;
%             self.update_() ;
%         end  % function

        function set_y_max(self, new_value)
            if isnumeric(new_value) && isscalar(new_value) && isfinite(new_value) && 0<new_value ,
                self.is_auto_y_ = false ;
                self.y_max_ = new_value ;
            end
            self.update_() ;
        end

        function update_histogram_(self)
            if ~isempty(self.controller_) && isvalid(self.controller_) 
                self.controller_.update_histogram() ;
            end
        end        

        function result = bin_centers(self)
            result = self.bin_centers_ ;
        end
        
        function result = bin_edges(self)
            result = self.bin_edges_ ;
        end
        
        function result = is_auto_y(self)
            result = self.is_auto_y_ ;
        end

        function set_is_auto_y(self, new_value)
            self.is_auto_y_ = new_value ;
            if self.is_auto_y_ ,
                self.sync_y_max_from_event_count_from_bin_index_() ;
            end
            self.update_control_properties_() ;
        end
    end  % methods
end
