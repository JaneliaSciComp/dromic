classdef fake_spikegl_interface_type < handle
    % Wrapper for the SpikeGL class, which is an old-style class.  (I wanted to
    % be able call SpikeGL methods using new-style object.method() syntax.)
    % Also this provides the facility to connect to a fake SpikeGL instance,
    % that generates data suitable for testing dromic.

    properties
        start_tic_id_
    end

    methods
        function self = fake_spikegl_interface_type()
            self.start_tic_id_ = tic() ;
        end

        function delete(self) %#ok<INUSD> 
        end           

        function result = GetStreamSampleRate(self, device_type, device_index0)  %#ok<INUSL,INUSD> 
            if device_type == device_type_type.nidq ,
                result = 25000 ;
            else
                result = 30000 ;
            end
        end

        function result = IsRunning(self)  %#ok<MANU> 
            result = true ;
        end

        function [data, first_scan_index0] = FetchLatest(self, device_type, device_index0, maximum_scan_count, channel_index0)   
            current_time = toc(self.start_tic_id_) ;  % seconds
            fs = self.GetStreamSampleRate(device_type, device_index0) ;  % Hz           
            last_scan_index0 = floor(current_time * fs) ;
            first_scan_index0 = last_scan_index0 - maximum_scan_count + 1 ;
            if first_scan_index0<0 ,
                first_scan_index0 = 0 ;
            end
            scan_count = last_scan_index0 - first_scan_index0 + 1 ;
            [data, first_scan_index0_check] = ...
                self.Fetch(device_type, ...
                           device_index0, ...
                           first_scan_index0, ...
                           scan_count, ...
                           channel_index0) ;
        end

        function output_scan_index0 = MapSample(self, output_device_type, output_device_index0, input_scan_index0, input_device_type, input_device_index0)
            if input_device_type == output_device_type ,
                output_scan_index0 = input_scan_index0 ;
            else
                input_fs = self.GetStreamSampleRate(input_device_type, input_device_index0) ;
                input_dt = 1 / input_fs ;
                t = (input_scan_index0+1/2) * input_dt ;  % sample with index 0 should have timestamp dt/2
                output_fs = self.GetStreamSampleRate(output_device_type, output_device_index0) ;
                output_dt = 1 / output_fs ;
                output_scan_index0 = floor(t/output_dt) ;
            end
        end

        function [data, first_scan_index0_check] = Fetch(self, ...
                                                         device_type, ...
                                                         device_index0, ...
                                                         first_scan_index0, ...
                                                         scan_count, ...
                                                         channel_index0)  %#ok<INUSD>
            last_scan_index0 = first_scan_index0 + scan_count - 1 ;
            fs = self.GetStreamSampleRate(device_type, device_index0) ;            
            dt = 1 / fs ;
            t = dt * ( (first_scan_index0:last_scan_index0)' + 1/2 ) ;  % seconds, col vector, 1/2 is to make sampling less likely to land on an edge
            
            if device_type == device_type_type.nidq ,
                % If nidq, result should be a int16 that represents a uint16, with the
                % lowest-order bit executing a 1 Hz square wave with 50% duty cycle.
                bit = mod(t,1)<0.5 ;
                data = int16(bit) ;
            else
                % If imec, still int16, but I'm not sure how they handle units.  I guess we'll 
                % just have the signal blip from zero to 10,000 counts.
                is_odd = mod(floor(t/1),2) ;  % Whether it's been an even or odd number of seconds since the start
                is_even = 1-is_odd ;                
                data = int16(1e4*(mod(t-is_odd*0.025-is_even*0.055,1)<0.05)) ;  % Have it blip high from 50 ms.  On odd/even cycles, 250/500 ms after the trigger.
            end
            first_scan_index0_check = first_scan_index0 ;
        end

    end
end