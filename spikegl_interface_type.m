classdef spikegl_interface_type < handle
    % Wrapper for the SpikeGL class, which is an old-style class.  (I wanted to
    % be able call SpikeGL methods using new-style object.method() syntax.)
    % Also this provides the facility to connect to a fake SpikeGL instance,
    % that generates data suitable for testing dromic.

    properties
        spikegl_
    end

    methods
        function self = spikegl_interface_type()
            % Connect to SpikeGLX
            self.spikegl_ = SpikeGL() ;  % use loopback
        end

        function delete(self)
            if ~isempty(self.spikegl_) 
                Close(self.spikegl_) ;
                self.spikegl_ = [] ;
            end
        end           

        function result = GetStreamSampleRate(self, device_type, device_index0)
            result = GetStreamSampleRate(self.spikegl_, device_type, device_index0) ;
        end

        function result = IsRunning(self)
            result = IsRunning(self.spikegl_) ;
        end

        function [data, first_scan_index] = FetchLatest(self, device_type, device_index0, maximum_scan_count, channel_index0)
            [data, first_scan_index] = ...
                FetchLatest( ...
                    self.spikegl_, ...
                    device_type, ...
                    device_index0, ...
                    maximum_scan_count, ...
                    channel_index0) ;
        end

        function output_scan_index = MapSample(self, output_device_type, output_device_index0, input_scan_index, input_device_type, input_device_index)
            output_scan_index = MapSample(self.spikegl_, output_device_type, output_device_index0, input_scan_index, input_device_type, input_device_index) ;
        end

        function [data, window_start_in_scans_check] = Fetch(self, ...
                                                             device_type, ...
                                                             device_index0, ...
                                                             window_start_in_scans, ...
                                                             window_scan_count, ...
                                                             channel_index0)
            [data, window_start_in_scans_check] = Fetch(self.spikegl_, ...
                                                        device_type, ...
                                                        device_index0, ...
                                                        window_start_in_scans, ...
                                                        window_scan_count, ...
                                                        channel_index0) ;
        end

        function result = GetStreamI16ToVolts(self, monitored_device_type, monitored_device_index0, monitored_channel_index0) 
            result = GetStreamI16ToVolts(self.spikegl_, monitored_device_type, monitored_device_index0, monitored_channel_index0) ;
        end
    end
end