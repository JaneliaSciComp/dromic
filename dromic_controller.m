classdef dromic_controller < ws.controller
    properties 
        start_button_

        auto_colormap_max_checkbox_

        trigger_device_type_edit_label_text_
        trigger_device_type_edit_
        trigger_device_index0_edit_label_text_
        trigger_device_index0_edit_
        trigger_channel_index0_edit_label_text_
        trigger_channel_index0_edit_
        trigger_bit_index0_edit_label_text_
        trigger_bit_index0_edit_

        monitored_device_type_edit_label_text_
        monitored_device_type_edit_

        monitored_device_index0_edit_label_text_
        monitored_device_index0_edit_

        monitored_channel_indices0_spec_edit_label_text_
        monitored_channel_indices0_spec_edit_

        monitored_threshold_edit_label_text_
        monitored_threshold_edit_
        monitored_threshold_edit_units_text_

        monitored_threshold_rising_button_
        monitored_threshold_falling_button_

        pre_trigger_duration_edit_label_text_
        pre_trigger_duration_edit_
        pre_trigger_duration_edit_units_text_
        post_trigger_duration_edit_label_text_
        post_trigger_duration_edit_
        post_trigger_duration_edit_units_text_
        bin_duration_edit_label_text_
        bin_duration_edit_
        bin_duration_edit_units_text_

        heatmap_axes_
        heatmap_x_axis_label_
        heatmap_y_axis_label_
        colorbar_y_axis_label_
        heatmap_  % an image
        
        colorbar_axes_
        colorbar_
        
        clear_button_
        zoom_in_button_
        zoom_out_button_
        colormap_max_button_
    end  % properties
    
    properties
        the_colormap_max_dialog_controller_ = []
    end
    
    methods
        function self = dromic_controller(kind_string)
            % if kind_string=='fake', use a fake spikegl
            if ~exist('kind_string', 'var') || isempty(kind_string) ,
                kind_string = '' ;
            end
            dm = dromic_model(kind_string) ;
            self = self@ws.controller(dm) ;  % sets self.model_
            
            % Create the widgets (except figure, created in superclass
            % constructor)
            set(self.figure_, ...
                'Tag', 'dromic_figure', ...
                'Units', 'pixels', ...
                'Name', 'Dromic', ...
                'Menubar', 'none', ...
                'Toolbar', 'none', ...
                'Visible', 'off') ;
            
            % Position and size the figure on-screen
            self.set_initial_figure_position_() ;

            % Create the controls that will persist throughout the lifetime of the window              
            self.create_fixed_controls_() ;

            % Now that controls are created, set their callbacks based on the property
            % name
            self.set_nonidiomatic_properties_() ;

            % Make the model visible (This causes update() to be called, which causes layout_() to be called.)
            self.model_.set_is_visible(true) ;

            % Now that the controls exist, safe for the resize_() method to be called
            set(self.figure_, ...
                'ResizeFcn', @(source,event)(self.resize_())) ;            
        end  % constructor
        
        function delete(self)
            if ~isempty(self.the_colormap_max_dialog_controller_) && ishandle(self.the_colormap_max_dialog_controller_) ,
                delete(self.the_colormap_max_dialog_controller_) ;
            end
            if ~isempty(self.model_) && isvalid(self.model_) ,
                delete(self.model_) ;
            end
            delete@ws.controller(self) ;
        end  % function
        
        function update_heatmap(self, varargin)
            % If there are issues with either the host or the model, just return
            if ~self.are_updates_enabled ,
                return
            end
            if isempty(self.model_) || ~isvalid(self.model_) ,
                return
            end

            % Get the model
            model = self.model_ ;

            % Update the histogram
            event_count_from_channel_index_from_bin_index = model.event_count_from_channel_index_from_bin_index() ;
            bin_centers = model.bin_centers() ;
            channel_count = size(event_count_from_channel_index_from_bin_index, 1) ;
            if isempty(self.heatmap_) ,
                self.heatmap_ = image( ...
                    'Parent', self.heatmap_axes_, ...
                    'CDataMapping', 'scaled', ...
                    'XData', bin_centers, ...
                    'YData', 1:channel_count, ...
                    'CData', event_count_from_channel_index_from_bin_index) ;
            else
                set(self.heatmap_, ...
                    'XData', bin_centers, ...
                    'YData', 1:channel_count, ...
                    'CData', event_count_from_channel_index_from_bin_index) ;
            end

            % If "Auto Y" is engaged, set the y range
            if model.is_running() && model.is_auto_colormap_max() , 
                colormap_max = model.colormap_max() ;
                ylim = get(self.colorbar_axes_, 'YLim') ;
                if ylim(2) ~= colormap_max ,
                    set(self.colorbar_axes_, 'YLim', [0 colormap_max]) ;
                end
                y_data = get(self.colorbar_, 'YData') ;
                if y_data(2) ~= colormap_max ,
                    set(self.colorbar_, 'YData', [0 colormap_max]) ;
                end
                
            end
            
        end  % method
        
%         function updateIsReady(self,varargin)            
%             if isempty(testPulser) || testPulser.IsReady ,
%                 set(self.Figure_,'pointer','arrow');
%             else
%                 % Change cursor to hourglass
%                 set(self.Figure_,'pointer','watch');
%             end
%             drawnow('update');
%         end        
    end  % methods
    
    methods (Access=protected)
        function update_implementation_(self,varargin)
            % Syncs self with model, making no prior assumptions about what
            % might have changed or not changed in the model.
            %fprintf('update!\n');
            self.update_controls_in_existance_();
            self.update_control_properties_implementation_();
            self.layout_();
            self.update_visibility() ;
            % update readiness, without the drawnow()
            model = self.model_ ;
            if isempty(model) ,
                set(self.figure_,'pointer','arrow');
            else                
                %ephys = wsModel.Ephys ;
                if model.is_ready ,
                    set(self.figure_,'pointer','arrow');
                else
                    % Change cursor to hourglass
                    set(self.figure_,'pointer','watch');
                end
            end            
        end
        
        function update_control_properties_implementation_(self,varargin)
            % If there are issues with the model, just return
            if isempty(self.model_) || ~isvalid(self.model_) ,
                return
            end
                        
            % Get some handles we'll need
            model = self.model_ ;
            is_running = self.model_.is_running() ;
            is_idle = ~is_running ;
            
%             % Define some useful booleans
%             is_electrode_manual = isempty(tp_electrode_index) || isequal(model.get_test_pulse_electrode_property('Type'), 'Manual') ; 
%             is_electrode_manager_in_control_of_softpanel_mode_and_gains=model.is_in_control_of_softpanel_mode_and_gains;
%             is_wavesurfer_idle=isequal(model.state,'idle');
%             %isWavesurferTestPulsing=(wavesurferModel.State==ws.ApplicationState.TestPulsing);
%             is_wavesurfer_test_pulsing = model.is_running() ;
%             is_wavesurfer_idle_or_test_pulsing = is_wavesurfer_idle||is_wavesurfer_test_pulsing ;
            is_auto_colormap_max = model.is_auto_colormap_max ;
%             is_auto_colormap_maxrepeating = model.is_auto_colormap_maxrepeating_in_test_pulse_view ;
%             
%             % Update the graphics objects to match the model and/or host
%             is_start_button_enabled = model.is_test_pulsing_enabled() ;
            set(self.start_button_, ...
                'String',ws.fif(is_running,'Stop','Start'));
%             
%             electrode_names = model.get_all_electrode_names ;
%             electrode_name = model.get_test_pulse_electrode_property('Name') ;
%             ws.set_popup_menu_items_and_selection_bang(self.electrode_popup_menu_, ...
%                                                  electrode_names, ...
%                                                  electrode_name);
%             set(self.electrode_popup_menu_, ...
%                 'Enable',ws.on_iff(is_wavesurfer_idle_or_test_pulsing));
%                                          
%             set(self.subtract_baseline_checkbox_,'Value',model.do_subtract_baseline_in_test_pulse_view, ...
%                                               'Enable',ws.on_iff(is_wavesurfer_idle_or_test_pulsing));
            set(self.auto_colormap_max_checkbox_, ...
                'Value',is_auto_colormap_max, ...
                'Enable',ws.on_iff(is_idle));
%             set(self.auto_colormap_max_repeating_checkbox_,'Value',is_auto_colormap_maxrepeating, ...
%                                             'Enable',ws.on_iff(is_wavesurfer_idle_or_test_pulsing&&is_auto_colormap_max));
%                    
%             % Have to disable these togglebuttons during test pulsing,
%             % because switching an electrode's mode during test pulsing can
%             % fail: in the target mode, the electrode may not be
%             % test-pulsable (e.g. the monitor and command channels haven't
%             % been set for the target mode), or the monitor and command
%             % channels for the set of active electrode may not be mutually
%             % exclusive.  That makes computing whether the target mode is
%             % valid complicated.  We punt by just disabling the
%             % mode-switching toggle buttons during test pulsing.  The user
%             % can always stop test pulsing, switch the mode, then start
%             % again (if that's a valid action in the target mode).
%             % Hopefully this limitation is not too annoying for users.
%             mode = model.get_test_pulse_electrode_property('Mode') ;
%             set(self.vctoggle_, 'Enable', ws.on_iff(is_wavesurfer_idle && ...
%                                                   ~isempty(tp_electrode_index) && ...
%                                                   (is_electrode_manual||is_electrode_manager_in_control_of_softpanel_mode_and_gains)), ...
%                                'Value', ~isempty(tp_electrode_index)&&isequal(mode,'vc'));
%             set(self.cctoggle_, 'Enable', ws.on_iff(is_wavesurfer_idle && ...
%                                                   ~isempty(tp_electrode_index)&& ...
%                                                   (is_electrode_manual||is_electrode_manager_in_control_of_softpanel_mode_and_gains)), ...
%                                'Value', ~isempty(tp_electrode_index) && ...
%                                         (isequal(mode,'cc')||isequal(mode,'i_equals_zero')));
%                         
            trigger_device_type = model.trigger_device_type() ;
            set(self.trigger_device_type_edit_, ...
                'String',char(trigger_device_type), ...
                'Enable',ws.on_iff(is_idle)) ;
            set(self.trigger_device_type_edit_label_text_, ...
                'Enable',ws.on_iff(is_idle)) ;

            trigger_device_index0 = model.trigger_device_index0() ;
            set(self.trigger_device_index0_edit_, ...
                'String',num2str(trigger_device_index0), ...
                'Enable',ws.on_iff(is_idle)) ;
            set(self.trigger_device_index0_edit_label_text_, ...
                'Enable',ws.on_iff(is_idle)) ;

            trigger_channel_index0 = model.trigger_channel_index0() ;
            set(self.trigger_channel_index0_edit_, ...
                'String',num2str(trigger_channel_index0), ...
                'Enable',ws.on_iff(is_idle)) ;
            set(self.trigger_channel_index0_edit_label_text_, ...
                'Enable',ws.on_iff(is_idle)) ;

            trigger_bit_index0 = model.trigger_bit_index0() ;
            set(self.trigger_bit_index0_edit_, ...
                'String',num2str(trigger_bit_index0), ...
                'Enable',ws.on_iff(is_idle)) ;
            set(self.trigger_bit_index0_edit_label_text_, ...
                'Enable',ws.on_iff(is_idle)) ;







            monitored_device_type = model.monitored_device_type() ;
            set(self.monitored_device_type_edit_, ...
                'String',char(monitored_device_type), ...
                'Enable',ws.on_iff(is_idle)) ;
            set(self.monitored_device_type_edit_label_text_, ...
                'Enable',ws.on_iff(is_idle)) ;
            
            monitored_device_index0 = model.monitored_device_index0() ;
            set(self.monitored_device_index0_edit_, ...
                'String',num2str(monitored_device_index0), ...
                'Enable',ws.on_iff(is_idle)) ;
            set(self.monitored_device_index0_edit_label_text_, ...
                'Enable',ws.on_iff(is_idle)) ;

            monitored_channel_indices0_spec = model.monitored_channel_indices0_spec() ;  % a string
            set(self.monitored_channel_indices0_spec_edit_, ...
                'String',monitored_channel_indices0_spec, ...
                'Enable',ws.on_iff(is_idle)) ;
            set(self.monitored_channel_indices0_spec_edit_label_text_, ...
                'Enable',ws.on_iff(is_idle)) ;

            monitored_threshold = model.monitored_threshold() ;
            set(self.monitored_threshold_edit_, ...
                'String',num2str(monitored_threshold), ...
                'Enable',ws.on_iff(is_idle)) ;
            set(self.monitored_threshold_edit_label_text_, ...
                'Enable',ws.on_iff(is_idle)) ;

            monitored_threshold_crossing_sign = model.monitored_threshold_crossing_sign() ;
            set(self.monitored_threshold_rising_button_, ...
                'Value',monitored_threshold_crossing_sign>0, ...
                'Enable',ws.on_iff(is_idle)) ;
            set(self.monitored_threshold_falling_button_, ...
                'Value',monitored_threshold_crossing_sign<0, ...
                'Enable',ws.on_iff(is_idle)) ;

            pre_trigger_duration = model.pre_trigger_duration() ;
            set(self.pre_trigger_duration_edit_label_text_, ...
                'Enable',ws.on_iff(is_idle)) ;
            set(self.pre_trigger_duration_edit_, ...
                'String',sprintf('%g',pre_trigger_duration), ...
                'Enable',ws.on_iff(is_idle)) ;
            set(self.pre_trigger_duration_edit_units_text_, ...
                'Enable',ws.on_iff(is_idle)) ;

            post_trigger_duration = model.post_trigger_duration() ;
            set(self.post_trigger_duration_edit_label_text_, ...
                'Enable',ws.on_iff(is_idle)) ;
            set(self.post_trigger_duration_edit_, ...
                'String',sprintf('%g',post_trigger_duration), ...
                'Enable',ws.on_iff(is_idle)) ;
            set(self.post_trigger_duration_edit_units_text_, ...
                'Enable',ws.on_iff(is_idle)) ;
            
            bin_duration = model.bin_duration() ;
            set(self.bin_duration_edit_label_text_, ...
                'Enable',ws.on_iff(is_idle)) ;
            set(self.bin_duration_edit_, ...
                'String',sprintf('%g',bin_duration), ...
                'Enable',ws.on_iff(is_idle)) ;
            set(self.bin_duration_edit_units_text_, ...
                'Enable',ws.on_iff(is_idle)) ;
            
%             set(self.duration_edit_, 'String', sprintf('%g', 1e3*model.test_pulse_duration), ...
%                                    'Enable', ws.on_iff(is_wavesurfer_idle_or_test_pulsing)) ;
%             set(self.duration_edit_units_text_,'Enable',ws.on_iff(is_wavesurfer_idle_or_test_pulsing));
%             n_electrodes=length(self.gain_label_texts_);
%             is_vcper_test_pulse_electrode = model.get_is_vcper_test_pulse_electrode() ;
%             is_ccper_test_pulse_electrode = model.get_is_ccper_test_pulse_electrode() ;
%             tp_electrode_names = model.get_test_pulse_electrode_names() ;
%             for i=1:n_electrodes ,
%                 if is_ccper_test_pulse_electrode(i) || is_vcper_test_pulse_electrode(i) ,
%                     set(self.gain_label_texts_(i), 'String', sprintf('%s Resistance: ', tp_electrode_names{i})) ;
%                 else
%                     set(self.gain_label_texts_(i), 'String', sprintf('%s Gain: ', tp_electrode_names{i})) ;
%                 end
%                 %set(self.GainUnitsTexts(i),'String',string(testPulser.GainOrResistanceUnitsPerElectrode(i)));
%                 set(self.gain_units_texts_(i),'String','');
%             end
%             sweep_duration = 2*model.test_pulse_duration ;
%             set(self.heatmap_axes_,'XLim',1000*[0 sweep_duration]);
            colormap_max = model.colormap_max() ;
            set(self.heatmap_axes_,'CLim',[0 colormap_max]) ;
            set(self.heatmap_axes_,'XLim',[-pre_trigger_duration +post_trigger_duration]) ;
            channel_id_from_channel_index = model.monitored_channel_indices0() ;  
              % the "channel id" is the zero based index of the SpikeGL channel
              % the "channel index" is the index of each channel in the array (and so is
              % one-based)
            channel_count = length(channel_id_from_channel_index) ;
            is_ticked_from_channel_index = compute_is_range_end_from_set(channel_id_from_channel_index) ;
            channel_index_from_tick_index = find(is_ticked_from_channel_index) ;
            channel_id_from_tick_index = channel_id_from_channel_index(channel_index_from_tick_index) ;            
            set(self.heatmap_axes_, 'YLim', [0.5 channel_count+0.5], ...
                                    'YTick', channel_index_from_tick_index, ...
                                    'YTickLabel', channel_id_from_tick_index) ;
            
            % Update the colorbar
            colormap_max = model.colormap_max() ;
            set(self.colorbar_axes_, 'YLim', [0 colormap_max]) ;
            set(self.colorbar_, 'YData', [0 colormap_max]) ;
            
            set(self.zoom_in_button_,'Enable',ws.on_iff(is_idle&&~is_auto_colormap_max));
            set(self.zoom_out_button_,'Enable',ws.on_iff(is_idle&&~is_auto_colormap_max));
            set(self.colormap_max_button_,'Enable',ws.on_iff(is_idle&&~is_auto_colormap_max));
            set(self.clear_button_,'Enable',ws.on_iff(is_idle));
            self.update_heatmap();
        end  % method        
                
    end  % protected methods block
    
    methods (Access=protected)
        function create_fixed_controls_(self)            
            %fprintf('Inside create_fixed_controls_()\n') ;

            % Start/stop button
            self.start_button_= ...
                ws.uicontrol('Parent',self.figure_, ...
                          'Style','pushbutton', ...
                          'String','Start');
                          
            % Auto colormap max checkbox
            self.auto_colormap_max_checkbox_= ...
                ws.uicontrol('Parent',self.figure_, ...
                              'Style','checkbox', ...
                              'String','Auto Colormap Max');

%             % Auto Y repeat checkbox
%             self.auto_colormap_max_repeating_checkbox_= ...
%                 ws.uicontrol('Parent',self.figure_, ...
%                         'Style','checkbox', ...
%                         'String','Repeating');
                    
            % Trigger edits, labels
            self.trigger_device_type_edit_label_text_= ...
                ws.uicontrol('Parent',self.figure_, ...
                        'Style','text', ...
                        'HorizontalAlignment','right', ...
                        'String','Trigger Device Type: ');
            self.trigger_device_type_edit_= ...
                ws.uiedit('Parent',self.figure_, ...
                          'HorizontalAlignment','left');

            self.trigger_device_index0_edit_label_text_= ...
                ws.uicontrol('Parent',self.figure_, ...
                        'Style','text', ...
                        'HorizontalAlignment','right', ...
                        'String','Trigger Device: ');
            self.trigger_device_index0_edit_= ...
                ws.uiedit('Parent',self.figure_, ...
                          'HorizontalAlignment','right');           

            self.trigger_channel_index0_edit_label_text_= ...
                ws.uicontrol('Parent',self.figure_, ...
                        'Style','text', ...
                        'HorizontalAlignment','right', ...
                        'String','Trigger Channel: ');
            self.trigger_channel_index0_edit_= ...
                ws.uiedit('Parent',self.figure_, ...
                          'HorizontalAlignment','right');

            self.trigger_bit_index0_edit_label_text_= ...
                ws.uicontrol('Parent',self.figure_, ...
                        'Style','text', ...
                        'HorizontalAlignment','right', ...
                        'String','Trigger Bit: ');
            self.trigger_bit_index0_edit_= ...
                ws.uiedit('Parent',self.figure_, ...
                          'HorizontalAlignment','right');

            % Monitored edits, labels
            self.monitored_device_type_edit_label_text_= ...
                ws.uicontrol('Parent',self.figure_, ...
                        'Style','text', ...
                        'HorizontalAlignment','right', ...
                        'String','Monitored Device Type: ');
            self.monitored_device_type_edit_= ...
                ws.uiedit('Parent',self.figure_, ...
                          'HorizontalAlignment','left');

            self.monitored_device_index0_edit_label_text_= ...
                ws.uicontrol('Parent',self.figure_, ...
                        'Style','text', ...
                        'HorizontalAlignment','right', ...
                        'String','Monitored Device: ');
            self.monitored_device_index0_edit_= ...
                ws.uiedit('Parent',self.figure_, ...
                          'HorizontalAlignment','right');
            
            self.monitored_channel_indices0_spec_edit_label_text_= ...
                ws.uicontrol('Parent',self.figure_, ...
                        'Style','text', ...
                        'HorizontalAlignment','right', ...
                        'String','Monitored Channels: ');
            self.monitored_channel_indices0_spec_edit_= ...
                ws.uiedit('Parent',self.figure_, ...
                          'HorizontalAlignment','right');
            
            self.monitored_threshold_edit_label_text_= ...
                ws.uicontrol('Parent',self.figure_, ...
                        'Style','text', ...
                        'HorizontalAlignment','right', ...
                        'String','Threshold: ');
            self.monitored_threshold_edit_= ...
                ws.uiedit('Parent',self.figure_, ...
                          'HorizontalAlignment','right', ...
                          'Callback',@(src,evt)(self.control_actuated('ThresholdEdit',src,evt)));
            self.monitored_threshold_edit_units_text_= ...
                ws.uicontrol('Parent',self.figure_, ...
                        'Style','text', ...
                        'HorizontalAlignment','left', ...
                        'String','uV');
            self.monitored_threshold_rising_button_ = ...
                ws.uicontrol('Parent',self.figure_, ...
                        'Style','radiobutton', ...
                        'String','Rising');
            self.monitored_threshold_falling_button_ = ...
                ws.uicontrol('Parent',self.figure_, ...
                        'Style','radiobutton', ...
                        'String','Falling');
            
            

            % Pre edit
            self.pre_trigger_duration_edit_label_text_= ...
                ws.uicontrol('Parent',self.figure_, ...
                        'Style','text', ...
                        'HorizontalAlignment','right', ...
                        'String','Pre: ');
            self.pre_trigger_duration_edit_= ...
                ws.uiedit('Parent',self.figure_, ...
                          'HorizontalAlignment','right');
            self.pre_trigger_duration_edit_units_text_= ...
                ws.uicontrol('Parent',self.figure_, ...
                        'Style','text', ...
                        'HorizontalAlignment','left', ...
                        'String','ms');

            % Post edit
            self.post_trigger_duration_edit_label_text_= ...
                ws.uicontrol('Parent',self.figure_, ...
                        'Style','text', ...
                        'HorizontalAlignment','right', ...
                        'String','Post: ');
            self.post_trigger_duration_edit_= ...
                ws.uiedit('Parent',self.figure_, ...
                          'HorizontalAlignment','right');
            self.post_trigger_duration_edit_units_text_= ...
                ws.uicontrol('Parent',self.figure_, ...
                        'Style','text', ...
                        'HorizontalAlignment','left', ...
                        'String','ms');

            % Bin Duration edit
            self.bin_duration_edit_label_text_= ...
                ws.uicontrol('Parent',self.figure_, ...
                        'Style','text', ...
                        'HorizontalAlignment','right', ...
                        'String','Bin Width: ');
            self.bin_duration_edit_= ...
                ws.uiedit('Parent',self.figure_, ...
                          'HorizontalAlignment','right');
            self.bin_duration_edit_units_text_= ...
                ws.uicontrol('Parent',self.figure_, ...
                        'Style','text', ...
                        'HorizontalAlignment','left', ...
                        'String','ms');

            % Heatmap axes        
            self.heatmap_axes_ = ...
                axes('Parent',self.figure_, ...
                     'Units','pixels', ...
                     'Box','on', ...
                     'Layer', 'top', ...
                     'XLim',[-100 +100], ...
                     'YDir', 'reverse', ...
                     'FontSize', 9, ...
                     'Visible','on' ) ;
%                      'PositionConstraint', 'outerposition');
            
            % Heatmap axis labels
            self.heatmap_x_axis_label_ = ...
                xlabel(self.heatmap_axes_,'Time (ms)','FontSize',9,'Interpreter','none') ;
            self.heatmap_y_axis_label_ = ...
                ylabel(self.heatmap_axes_,'Channel Index','FontSize',9,'Interpreter','none') ;
            
            % Heatmap image
            event_count_from_channel_index_from_bin_index = self.model_.event_count_from_channel_index_from_bin_index() ;
            bin_centers = self.model_.bin_centers() ;
            channel_count = size(event_count_from_channel_index_from_bin_index, 1) ;
            self.heatmap_ = image('Parent', self.heatmap_axes_, ...
                                  'CDataMapping', 'scaled', ...
                                  'XData', bin_centers, ...
                                  'YData', 1:channel_count, ...
                                  'CData', event_count_from_channel_index_from_bin_index) ;
            
            % Colorbar axes and the colorbar image
            colormap_max = self.model_.colormap_max() ;            
            self.colorbar_axes_ = ...
                axes('Parent', self.figure_, ...
                     'Units', 'pixels', ...
                     'Visible', 'on', ...
                     'Box', 'on', ...
                     'XLim', [0.5 1.5], ...
                     'XTick', [], ...
                     'YAxisLocation', 'right', ...
                     'Layer', 'top') ; 
            self.colorbar_ = ...
                image('Parent', self.colorbar_axes_,...
                      'CDataMapping', 'scaled', ...
                      'CData', linspace(0, colormap_max, 256)', ...
                      'XData', [1 1], ...
                      'YData', [0 colormap_max]) ;  

            % Colorbar y-axis label
            self.colorbar_y_axis_label_ = ...
                ylabel(self.colorbar_axes_,'Event Count','FontSize',9,'Interpreter','none') ;
                  
%             % Update rate text
%             self.update_rate_text_label_text_= ...
%                 ws.uicontrol('Parent',self.figure_, ...
%                         'Style','text', ...
%                         'HorizontalAlignment','right', ...                        
%                         'String','Update Rate: ');
%             self.update_rate_text_= ...
%                 ws.uicontrol('Parent',self.figure_, ...
%                           'Style','text', ...
%                           'HorizontalAlignment','right', ...
%                           'String','??');
%             self.update_rate_text_units_text_= ...
%                 ws.uicontrol('Parent',self.figure_, ...
%                         'Style','text', ...
%                         'String','Hz');
                    
            % Y axis control buttons
            self.clear_button_= ...
                ws.uicontrol('Parent',self.figure_, ...
                          'Style','pushbutton', ...
                          'String','C');
            self.zoom_in_button_= ...
                ws.uicontrol('Parent',self.figure_, ...
                          'Style','pushbutton', ...
                          'String','-');
            self.zoom_out_button_= ...
                ws.uicontrol('Parent',self.figure_, ...
                          'Style','pushbutton', ...
                          'String','+');

            this_dir_path = fileparts(mfilename('fullpath')) ;
%             icon_file_name = fullfile(wavesurfer_dir_name, '+ws', 'icons', 'up_arrow.png');
%             cdata = ws.read_png_with_transparency_for_uicontrol_image(icon_file_name) ;
%             self.scroll_up_button_= ...
%                 ws.uicontrol('Parent',self.figure_, ...
%                           'Style','pushbutton', ...
%                           'CData',cdata);

%             icon_file_name = fullfile(wavesurfer_dir_name, '+ws', 'icons', 'down_arrow.png');
%             cdata = ws.read_png_with_transparency_for_uicontrol_image(icon_file_name) ;
%             self.scroll_down_button_= ...
%                 ws.uicontrol('Parent',self.figure_, ...
%                           'Style','pushbutton', ...
%                           'CData',cdata);
            
            icon_file_name = fullfile(this_dir_path, 'icons', 'y_manual_set.png');
            cdata = ws.read_png_with_transparency_for_uicontrol_image(icon_file_name) ;
            self.colormap_max_button_= ...
                ws.uicontrol('Parent',self.figure_, ...
                          'Style','pushbutton', ...
                          'CData',cdata);
        end  % function
        
        function set_initial_figure_position_(self)
            % set the initial figure size and position, then layout the
            % figure like normal

            % Get the screen size
            original_screen_units=get(0,'Units');
            set(0,'Units','pixels');
            screen_position=get(0,'ScreenSize');
            set(0,'Units',original_screen_units);            
            screen_size=screen_position(3:4);
            
            % Position the figure in the middle of the screen
            initial_size=[720 600];
            figure_offset=(screen_size-initial_size)/2;
            figure_position=[figure_offset initial_size];
            set(self.figure_,'Position',figure_position);
            
            % do the widget layout within the figure
            %self.layout();
        end  % function
        
        function layout_(self)
            % lays out the figure widgets, given the current figure size
            %fprintf('Inside layout()...\n');
            %dbstack

            % The "layout" is basically the figure rectangle, but
            % taking into account the fact that the figure can be hmade
            % arbitrarily small, but the layout has a miniumum width and
            % height.  Further, the layout rectangle *top* left corner is
            % the same point as the figure top left corner.
            
            % The layout contains the following things, in order from top
            % to bottom: 
            %
            %     top space
            %     top stuff (the widgets at the top of the figure)
            %          From left to right, several "banks" (columns):
            %              Start/stop button bank
            %              Checkbox bank
            %              Trigger bank
            %              Monitored bank
            %              Parameters bank
            %     bottom space
            %     the histograms plot
            %     bottom-stuff-histograms-plot-interspace
            %
            % Each is a rectangle, and they are laid out edge-to-edge
            % vertically.  All but the histograms plot have a fixed height, and
            % the histograms plot fills the leftover height in the layout.  The
            % top edge of the top space is fixed to the top edge of the
            % layout, and the bottom of the bottom space is fixed to the
            % bottom edge of the layout.

            % minimum layout dimensions
            minimum_layout_width = 720 ;  % If the figure gets small, we lay it out as if it was bigger
            minimum_layout_height = 600 ;  
            
            % The layout consists of "top stuff", including the start button, the
            % parameter edits, and the rising/falling radiobuttons; and "bottom stuff",
            % including the heatmap, the colorbar, and the small buttons along the
            % right side.
            top_stuff_to_bottom_stuff_space_height = 3 ;
            layout_bottom_to_bottom_stuff_space_height = 8 ;
            
            % General widget sizes
            edit_width = 40 ;
            edit_height = 20 ;
            text_height = 18 ;  % for 8 pt font
            
            % Top stuff layout parameters
            width_from_top_stuff_left_to_start_button = 22 ;
            height_from_top_stuff_top_to_start_button = 20 ;
            start_button_width = 96 ;
            start_button_height = 28 ;
            width_from_start_bank_to_checkbox_bank = 0 ;
            % checkbox_bank_width = 80 ;
            width_from_checkbox_bank_to_trigger_bank = 30 ;
            %height_from_layout_top_to_auto_colormap_max_checkbox = 6 ; 
%             height_between_checkboxes = -1 ;
%             width_of_auto_colormap_maxrepeating_indent = 14 ;
            height_between_trigger_bank_rows = 6 ;
            height_between_monitored_bank_rows = 6 ;
            height_between_radiobuttons = 0 ;            
            height_between_pre_and_post = 26 ;
            width_between_trigger_bank_and_monitored_bank = 20 ;
            width_from_monitor_bank_to_parameters_bank = 14 ;
            %trigger_bank_width = 150 ;
            %monitored_bank_width = 150 ;
            height_from_layout_top_to_trigger_bank = 6 ;
            height_from_layout_top_to_monitored_bank = 6 ;
            height_from_layout_top_to_parameters_bank = 6 ;

            % Histogram plot layout parameters                      
            heatmap_axes_left_pad = 8 ;
            heatmap_to_colorbar_space_width = 3 ;
            colorbar_label_area_width = 30 ;
            colorbar_axes_width = 30 ;
            
            heatmap_axes_top_pad = 5 ;
            tick_length = 5 ;  % in pixels
            from_colorbar_to_small_buttons_width = 6 ;
            small_button_size = 20 ;  % those buttons are square
            %space_between_scroll_buttons=5;
            space_between_zoom_buttons = 5 ;
            
            width_from_label_to_edit=4;  % has to agree with value in ws.position_edit_label_and_units_bang()
            width_from_edit_to_units=3;  % has to agree with value in ws.position_edit_label_and_units_bang()
            text_width_correction = 2 ;  % added to text X extent to get width    % has to agree with value in ws.position_edit_label_and_units_bang()    
            
            % Get the dimensions of the figure, determine the size and
            % position of the layout rectangle
            figure_position=get(self.figure_,'Position');
            figure_width = figure_position(3) ;
            figure_height = figure_position(4) ;
            % When the figure gets small, we layout the widgets as if it were
            % bigger.  The size we're "pretending" the figure is we call the
            % "layout" size
            layout_width=max(figure_width,minimum_layout_width) ;  
            layout_height=max(figure_height,minimum_layout_height) ;
            layout_y_offset = figure_height - layout_height ;
              % All widget coords have to ultimately be given in the figure
              % coordinate system.  This is the y position of the layout
              % lower left corner, in the figure coordinate system.
            layout_top_y_offset = layout_y_offset + layout_height ;  
              
            
              
            %
            %
            % Position thangs
            %
            %
            
            %
            % The start/stop button "bank"
            %
            
            % The start/stop button
            top_stuff_top_y_offset = layout_top_y_offset ;
            start_button_x = width_from_top_stuff_left_to_start_button ;
            start_button_y = top_stuff_top_y_offset - height_from_top_stuff_top_to_start_button - start_button_height ;
            set(self.start_button_, ...
                'Position',[start_button_x start_button_y ...
                            start_button_width start_button_height]);
                  
            % Auto colormap max checkbox
            space_from_start_button_to_colormap_max_checkbox = 16 ;
            [auto_colormap_max_checkbox_text_width, auto_colormap_max_checkbox_text_height] = ws.get_extent(self.auto_colormap_max_checkbox_) ;
            auto_colormap_max_checkbox_width = auto_colormap_max_checkbox_text_width + 16 ;  % Add some width to accomodate the checkbox itself
            auto_colormap_max_checkbox_height = auto_colormap_max_checkbox_text_height ;
            auto_colormap_max_checkbox_y = start_button_y - auto_colormap_max_checkbox_height - space_from_start_button_to_colormap_max_checkbox ;
            auto_colormap_max_checkbox_x = start_button_x ;
            set(self.auto_colormap_max_checkbox_, ...
                'Position',[auto_colormap_max_checkbox_x auto_colormap_max_checkbox_y ...
                            auto_colormap_max_checkbox_width auto_colormap_max_checkbox_height]) ;
                        
                        
            %
            % The checkbox "bank"
            %

            checkbox_bank_x_offset = width_from_top_stuff_left_to_start_button + start_button_width + width_from_start_bank_to_checkbox_bank ;
            
%             % Auto colormap max checkbox
%             [auto_colormap_max_checkbox_text_width, auto_colormap_max_checkbox_text_height] = ws.get_extent(self.auto_colormap_max_checkbox_) ;
%             auto_colormap_max_checkbox_width = auto_colormap_max_checkbox_text_width + 16 ;  % Add some width to accomodate the checkbox itself
%             auto_colormap_max_checkbox_height = auto_colormap_max_checkbox_text_height ;
%             auto_colormap_max_checkbox_y = top_stuff_top_y_offset - height_from_layout_top_to_auto_colormap_max_checkbox - auto_colormap_max_checkbox_height ;
%             auto_colormap_max_checkbox_x = checkbox_bank_x_offset ;
%             set(self.auto_colormap_max_checkbox_, ...
%                 'Position',[auto_colormap_max_checkbox_x auto_colormap_max_checkbox_y ...
%                             auto_colormap_max_checkbox_width auto_colormap_max_checkbox_height]) ;

            checkbox_bank_width = 0 ;


%             % Auto Y Locked checkbox
%             [auto_colormap_maxrepeating_checkbox_text_width,auto_colormap_maxrepeating_checkbox_text_height] = ws.get_extent(self.auto_colormap_max_repeating_checkbox_) ;
%             auto_colormap_maxrepeating_checkbox_width = auto_colormap_maxrepeating_checkbox_text_width + 16 ;  % Add some width to accomodate the checkbox itself
%             auto_colormap_maxrepeating_checkbox_height = auto_colormap_maxrepeating_checkbox_text_height ;
%             auto_colormap_maxrepeating_checkbox_y = auto_colormap_maxcheckbox_y - height_between_checkboxes - auto_colormap_maxrepeating_checkbox_height ;
%             auto_colormap_maxrepeating_checkbox_x = checkbox_bank_xoffset + width_of_auto_colormap_maxrepeating_indent ;
%             set(self.auto_colormap_max_repeating_checkbox_, ...
%                 'Position',[auto_colormap_maxrepeating_checkbox_x auto_colormap_maxrepeating_checkbox_y ...
%                             auto_colormap_maxrepeating_checkbox_width auto_colormap_maxrepeating_checkbox_height]);

            % 
            %  The trigger bank
            %            
                        
            % Get the width of the widest label
            [trigger_device_type_edit_label_text_width, ~] = ...
                ws.get_extent(self.trigger_device_type_edit_label_text_) ;
            [trigger_device_index0_edit_label_text_width, ~] = ...
                ws.get_extent(self.trigger_device_index0_edit_label_text_) ;
            [trigger_channel_index0_edit_label_text_width, ~] = ...
                ws.get_extent(self.trigger_channel_index0_edit_label_text_) ;
            [trigger_channel_bit_index0_edit_label_text_width, ~] = ...
                ws.get_extent(self.trigger_bit_index0_edit_label_text_) ;
            widest_trigger_bank_label_width = ...
                max([trigger_device_type_edit_label_text_width ...
                     trigger_device_index0_edit_label_text_width ...
                     trigger_channel_index0_edit_label_text_width ...
                     trigger_channel_bit_index0_edit_label_text_width]) ;

            % The trigger_device_type edit and its label
            trigger_bank_common_edit_x= ...
                checkbox_bank_x_offset + ...
                checkbox_bank_width + ...
                width_from_checkbox_bank_to_trigger_bank + ...
                widest_trigger_bank_label_width + text_width_correction + width_from_label_to_edit ;
            trigger_device_type_edit_y = top_stuff_top_y_offset - height_from_layout_top_to_trigger_bank - edit_height  ;
            ws.position_edit_label_and_units_bang( ...
                self.trigger_device_type_edit_label_text_, ...
                self.trigger_device_type_edit_, ...
                [], ...
                trigger_bank_common_edit_x, ...
                trigger_device_type_edit_y, ...
                edit_width, ...
                widest_trigger_bank_label_width) ;

            % The trigger_device_index0 edit and its label
            trigger_device_index0_edit_y = trigger_device_type_edit_y - height_between_trigger_bank_rows - edit_height  ;
            ws.position_edit_label_and_units_bang( ...
                self.trigger_device_index0_edit_label_text_, ...
                self.trigger_device_index0_edit_, ...
                [], ...
                trigger_bank_common_edit_x, ...
                trigger_device_index0_edit_y, ...
                edit_width, ...
                widest_trigger_bank_label_width) ;

            % The trigger_channel_index0 edit and its label
            trigger_channel_index0_edit_y = trigger_device_index0_edit_y - height_between_trigger_bank_rows - edit_height  ;
            ws.position_edit_label_and_units_bang( ...
                self.trigger_channel_index0_edit_label_text_, ...
                self.trigger_channel_index0_edit_, ...
                [], ...
                trigger_bank_common_edit_x, ...
                trigger_channel_index0_edit_y, ...
                edit_width, ...
                widest_trigger_bank_label_width) ;

            % The trigger_channel_index0 edit and its label
            trigger_channel_bit_index0_edit_y = trigger_channel_index0_edit_y - height_between_trigger_bank_rows - edit_height  ;
            ws.position_edit_label_and_units_bang( ...
                self.trigger_bit_index0_edit_label_text_, ...
                self.trigger_bit_index0_edit_, ...
                [], ...
                trigger_bank_common_edit_x, ...
                trigger_channel_bit_index0_edit_y, ...
                edit_width, ...
                widest_trigger_bank_label_width) ;
           
            % Compute the trigger bank width
            trigger_bank_width = widest_trigger_bank_label_width + width_from_label_to_edit + edit_width + text_width_correction ;


            % 
            %  The monitored bank
            %            
                        
            % Get the width of the widest label
            [monitored_device_type_edit_label_text_width, ~] = ...
                ws.get_extent(self.monitored_device_type_edit_label_text_) ;
            [monitored_device_index0_edit_label_text_width, ~] = ...
                ws.get_extent(self.monitored_device_index0_edit_label_text_) ;
            [monitored_channel_indices0_spec_edit_label_text_width, ~] = ...
                ws.get_extent(self.monitored_channel_indices0_spec_edit_label_text_) ;
            [monitored_threshold_edit_label_text_width, ~] = ...
                ws.get_extent(self.monitored_threshold_edit_label_text_) ;
            widest_monitored_bank_label_width = ...
                max([monitored_device_type_edit_label_text_width ...
                     monitored_device_index0_edit_label_text_width ...
                     monitored_channel_indices0_spec_edit_label_text_width ...
                     monitored_threshold_edit_label_text_width]) ;

            % The monitored_device_type edit and its label
            monitored_bank_common_x= ...
                checkbox_bank_x_offset + ...
                checkbox_bank_width + ...
                width_from_checkbox_bank_to_trigger_bank + ...
                trigger_bank_width + ...
                width_between_trigger_bank_and_monitored_bank ;
            monitored_bank_common_edit_x= ...
                monitored_bank_common_x + ...
                widest_monitored_bank_label_width ;
            monitored_device_type_edit_y = top_stuff_top_y_offset - height_from_layout_top_to_monitored_bank - edit_height  ;
            ws.position_edit_label_and_units_bang( ...
                self.monitored_device_type_edit_label_text_, ...
                self.monitored_device_type_edit_, ...
                [], ...
                monitored_bank_common_edit_x, ...
                monitored_device_type_edit_y, ...
                edit_width, ...
                widest_monitored_bank_label_width) ;

            % The monitored_device_index0 edit and its label
            monitored_device_index0_edit_y = monitored_device_type_edit_y - height_between_monitored_bank_rows - edit_height  ;
            ws.position_edit_label_and_units_bang( ...
                self.monitored_device_index0_edit_label_text_, ...
                self.monitored_device_index0_edit_, ...
                [], ...
                monitored_bank_common_edit_x, ...
                monitored_device_index0_edit_y, ...
                edit_width, ...
                widest_monitored_bank_label_width) ;

            % The monitored_channel_indices0_spec edit and its label
            monitored_channel_indices0_spec_edit_y = monitored_device_index0_edit_y - height_between_monitored_bank_rows - edit_height  ;
            ws.position_edit_label_and_units_bang( ...
                self.monitored_channel_indices0_spec_edit_label_text_, ...
                self.monitored_channel_indices0_spec_edit_, ...
                [], ...
                monitored_bank_common_edit_x, ...
                monitored_channel_indices0_spec_edit_y, ...
                edit_width, ...
                widest_monitored_bank_label_width) ;

            % The monitored_threshold edit and its label
            monitored_threshold_edit_y = monitored_channel_indices0_spec_edit_y - height_between_monitored_bank_rows - edit_height  ;
            ws.position_edit_label_and_units_bang( ...
                self.monitored_threshold_edit_label_text_, ...
                self.monitored_threshold_edit_, ...
                self.monitored_threshold_edit_units_text_, ...
                monitored_bank_common_edit_x, ...
                monitored_threshold_edit_y, ...
                edit_width, ...
                widest_monitored_bank_label_width) ;
           
            % Compute the monitored bank width (we assume the radiobuttons are not the
            % widest thing in the bank)
            [monitored_threshold_edit_units_text_width, ~] = ...
                ws.get_extent(self.monitored_threshold_edit_units_text_) ;            
            monitored_bank_width = ...
                widest_monitored_bank_label_width + width_from_label_to_edit + edit_width + width_from_edit_to_units + text_width_correction + ...
                monitored_threshold_edit_units_text_width ;

            % The rising/falling radiobuttons
            [~, monitored_threshold_rising_button_height] = ...
                ws.get_extent(self.monitored_threshold_rising_button_) ;            
            monitored_threshold_rising_button_x = monitored_bank_common_edit_x ;
            monitored_threshold_rising_button_y = monitored_threshold_edit_y - height_between_monitored_bank_rows - monitored_threshold_rising_button_height ;
            ws.set_uicontrol_offset_bang(self.monitored_threshold_rising_button_, ...
                                         [monitored_threshold_rising_button_x monitored_threshold_rising_button_y]) ;
            [~, monitored_threshold_falling_button_height] = ...
                ws.get_extent(self.monitored_threshold_falling_button_) ;            
            monitored_threshold_falling_button_x = monitored_bank_common_edit_x ;
            monitored_threshold_falling_button_y = ...
                monitored_threshold_rising_button_y - height_between_radiobuttons - monitored_threshold_falling_button_height ;
            ws.set_uicontrol_offset_bang(self.monitored_threshold_falling_button_, ...
                                         [monitored_threshold_falling_button_x monitored_threshold_falling_button_y]) ;



            
            % 
            %  The parameters bank
            %            
                        
            % Get the width of the widest label
            [pre_trigger_duration_edit_label_text_width, pre_trigger_duration_edit_label_text_height] = ...
                ws.get_extent(self.pre_trigger_duration_edit_label_text_) ;
            [post_trigger_duration_edit_label_text_width, post_trigger_duration_edit_label_text_height] = ...
                ws.get_extent(self.post_trigger_duration_edit_label_text_) ;
            [bin_duration_edit_label_text_width, bin_duration_edit_label_text_height] = ws.get_extent(self.bin_duration_edit_label_text_) ;
            widest_parameters_bank_label_width = ...
                max([pre_trigger_duration_edit_label_text_width post_trigger_duration_edit_label_text_width bin_duration_edit_label_text_width]) ;

            % The pre_trigger_duration edit and its label
            parameters_bank_x = ...
                checkbox_bank_x_offset + ...
                checkbox_bank_width + ...
                width_from_checkbox_bank_to_trigger_bank + ...
                trigger_bank_width + ...
                width_between_trigger_bank_and_monitored_bank + ...                
                monitored_bank_width + ...
                width_from_monitor_bank_to_parameters_bank ;
            pre_trigger_duration_edit_label_text_x = parameters_bank_x ;
            pre_trigger_duration_edit_label_text_y = top_stuff_top_y_offset - edit_height - height_from_layout_top_to_parameters_bank ;
            set(self.pre_trigger_duration_edit_label_text_, ...
                'Position',[pre_trigger_duration_edit_label_text_x pre_trigger_duration_edit_label_text_y ...
                            pre_trigger_duration_edit_label_text_width pre_trigger_duration_edit_label_text_height]);
            pre_trigger_duration_stuff_middle_y=pre_trigger_duration_edit_label_text_y+pre_trigger_duration_edit_label_text_height/2;
            pre_trigger_duration_edit_x=pre_trigger_duration_edit_label_text_x+widest_parameters_bank_label_width+1;  % shim
            pre_trigger_duration_edit_y=pre_trigger_duration_stuff_middle_y-edit_height/2+2;
            set(self.pre_trigger_duration_edit_, ...
                'Position',[pre_trigger_duration_edit_x pre_trigger_duration_edit_y ...
                            edit_width edit_height]);
            %[~,pre_trigger_durationEditUnitsTextHeight]=ws.getExtent(self.PreEditUnitsText);
            pre_trigger_duration_edit_units_text_faux_width=30;
            pre_trigger_duration_edit_units_text_x=pre_trigger_duration_edit_x+edit_width+1;  % shim
            pre_trigger_duration_edit_units_text_y=pre_trigger_duration_edit_label_text_y-1;
            set(self.pre_trigger_duration_edit_units_text_, ...
                'Position',[pre_trigger_duration_edit_units_text_x pre_trigger_duration_edit_units_text_y ...
                            pre_trigger_duration_edit_units_text_faux_width text_height]);
            
            % The post edit and its label
            post_trigger_duration_edit_label_text_x=parameters_bank_x;
            post_trigger_duration_edit_label_text_y=pre_trigger_duration_edit_label_text_y-height_between_pre_and_post;
            set(self.post_trigger_duration_edit_label_text_, ...
                'Position',[post_trigger_duration_edit_label_text_x post_trigger_duration_edit_label_text_y ...
                            post_trigger_duration_edit_label_text_width pre_trigger_duration_edit_label_text_height]);
            post_trigger_duration_stuff_middle_y=post_trigger_duration_edit_label_text_y+post_trigger_duration_edit_label_text_height/2;
            post_trigger_duration_edit_x=pre_trigger_duration_edit_x;  % shim
            post_trigger_duration_edit_y=post_trigger_duration_stuff_middle_y-edit_height/2+2;
            set(self.post_trigger_duration_edit_, ...
                'Position',[post_trigger_duration_edit_x post_trigger_duration_edit_y ...
                            edit_width edit_height]);
            [post_trigger_duration_edit_units_text_width,post_trigger_duration_edit_units_text_height]=ws.get_extent(self.post_trigger_duration_edit_units_text_);
            post_trigger_duration_edit_units_text_x=pre_trigger_duration_edit_units_text_x;
            post_trigger_duration_edit_units_text_y=post_trigger_duration_edit_label_text_y-1;
            set(self.post_trigger_duration_edit_units_text_, ...
                'Position',[post_trigger_duration_edit_units_text_x post_trigger_duration_edit_units_text_y ...
                            post_trigger_duration_edit_units_text_width post_trigger_duration_edit_units_text_height]);
            
            % The bin_duration edit and its label
            bin_duration_edit_label_text_x=parameters_bank_x;
            bin_duration_edit_label_text_y=post_trigger_duration_edit_label_text_y-height_between_pre_and_post ;
            set(self.bin_duration_edit_label_text_, ...
                'Position',[bin_duration_edit_label_text_x bin_duration_edit_label_text_y ...
                            bin_duration_edit_label_text_width pre_trigger_duration_edit_label_text_height]);
            bin_duration_stuff_middle_y=bin_duration_edit_label_text_y+bin_duration_edit_label_text_height/2;
            bin_duration_edit_x=pre_trigger_duration_edit_x;  % shim
            bin_duration_edit_y=bin_duration_stuff_middle_y-edit_height/2+2;
            set(self.bin_duration_edit_, ...
                'Position',[bin_duration_edit_x bin_duration_edit_y ...
                            edit_width edit_height]);
            [bin_duration_edit_units_text_width,bin_duration_edit_units_text_height]=ws.get_extent(self.bin_duration_edit_units_text_);
            bin_duration_edit_units_text_x=pre_trigger_duration_edit_units_text_x;
            bin_duration_edit_units_text_y=bin_duration_edit_label_text_y-1;
            set(self.bin_duration_edit_units_text_, ...
                'Position',[bin_duration_edit_units_text_x bin_duration_edit_units_text_y ...
                            bin_duration_edit_units_text_width bin_duration_edit_units_text_height]);
                        
            % Get the width of the widest units text
            [pre_trigger_duration_edit_units_text_width, ~] = ws.get_extent(self.pre_trigger_duration_edit_units_text_) ;
            [post_trigger_duration_edit_units_text_width, ~] = ws.get_extent(self.post_trigger_duration_edit_units_text_) ;
            [bin_duration_edit_units_text_width, ~] = ws.get_extent(self.bin_duration_edit_units_text_) ;
            widest_parameters_units_width = max([pre_trigger_duration_edit_units_text_width post_trigger_duration_edit_units_text_width bin_duration_edit_units_text_width]) ;

            % Get the width of the parameters bank
            parameters_bank_width = ...
                widest_parameters_bank_label_width + width_from_label_to_edit + edit_width + width_from_edit_to_units + text_width_correction + ...
                widest_parameters_units_width ;

            % Warn if the top stuff is wider than the layout as a whole
            top_stuff_width = ...
                width_from_top_stuff_left_to_start_button + ...
                start_button_width + ...
                width_from_start_bank_to_checkbox_bank + ...
                checkbox_bank_width + ...
                width_from_checkbox_bank_to_trigger_bank + ...
                trigger_bank_width + ...
                width_between_trigger_bank_and_monitored_bank + ...                
                monitored_bank_width + ...
                width_from_monitor_bank_to_parameters_bank + ...
                parameters_bank_width ;               
            if top_stuff_width > layout_width  ,
                warning('ws:dromic_controller:top_stuff_too_wide', 'In dromic_controller.layout(), the top stuff is wider than the layout as a whole') ;
            end

            % All the stuff above is at a fixed y offset from the top of
            % the layout.  So now we can compute the height of the top
            % stuff rectangle.
            top_stuff_y_offset = min([auto_colormap_max_checkbox_y trigger_channel_bit_index0_edit_y monitored_threshold_falling_button_y bin_duration_edit_y]) ;
            top_stuff_height = top_stuff_top_y_offset - top_stuff_y_offset ;

            % Position of the "bottom stuff" area, which includes the heatmap, the
            % colorbar, and the small buttons along the right
            bottom_stuff_area_x = 0 ;
            bottom_stuff_area_y = layout_y_offset + layout_bottom_to_bottom_stuff_space_height ;
            bottom_stuff_area_width = layout_width ;
            bottom_stuff_area_height = ...
                layout_height - ...
                top_stuff_height - ...
                top_stuff_to_bottom_stuff_space_height ;
            
                        
            %
            % The heatmap axes
            %
            
            heatmap_axes_outer_position_x = bottom_stuff_area_x ;
            heatmap_axes_outer_position_y = bottom_stuff_area_y ;
            heatmap_axes_outer_position_width = ...
                bottom_stuff_area_width - ...
                (small_button_size + from_colorbar_to_small_buttons_width + colorbar_axes_width + ...
                 colorbar_label_area_width + from_colorbar_to_small_buttons_width) ;
            heatmap_axes_outer_position_height = bottom_stuff_area_height ;
            heatmap_axes_outer_position = ...
                [heatmap_axes_outer_position_x heatmap_axes_outer_position_y heatmap_axes_outer_position_width heatmap_axes_outer_position_height] ;
            set(self.heatmap_axes_, 'OuterPosition', heatmap_axes_outer_position) ;

            tight_inset = round(get(self.heatmap_axes_,'TightInset')) ;  % TightInset is sometimes non-integer in pixels (??)
            heatmap_axes_x = heatmap_axes_outer_position_x + tight_inset(1) + heatmap_axes_left_pad;
            heatmap_axes_y = heatmap_axes_outer_position_y + tight_inset(2) ;
            heatmap_axes_width = ...
                heatmap_axes_outer_position_width - tight_inset(1) - tight_inset(3) - heatmap_axes_left_pad ;
            heatmap_axes_height = heatmap_axes_outer_position_height - tight_inset(2) - tight_inset(4) - heatmap_axes_top_pad ;
            heatmap_axes_position = [heatmap_axes_x heatmap_axes_y heatmap_axes_width heatmap_axes_height] ;
            set(self.heatmap_axes_, 'Position', heatmap_axes_position) ;
            
%             heatmap_axes_position = get(self.heatmap_axes_, 'Position') ;
%             heatmap_axes_x = heatmap_axes_position(1) ;
%             heatmap_axes_y = heatmap_axes_position(2)  ;
%             heatmap_axes_width = heatmap_axes_position(3)  ;
%             heatmap_axes_height = heatmap_axes_position(4)  ;

            % set the axes tick length to keep a constant number of pels
            heatmap_axes_size = max([heatmap_axes_width heatmap_axes_height]) ;
            tick_length_relative=tick_length / heatmap_axes_size ;
            set(self.heatmap_axes_, 'TickLength', tick_length_relative*[1 1]) ;
            
            % The colorbar axes
            colorbar_axes_x = heatmap_axes_outer_position_x + heatmap_axes_outer_position_width + heatmap_to_colorbar_space_width ;
            colorbar_axes_y = heatmap_axes_y ; 
            colorbar_axes_height = heatmap_axes_height ;
            colorbar_axes_position = [colorbar_axes_x colorbar_axes_y colorbar_axes_width colorbar_axes_height] ;
            set(self.colorbar_axes_, 'Position', colorbar_axes_position) ;
            
            % the zoom buttons
            small_buttons_x = ...
                heatmap_axes_x + heatmap_axes_width + from_colorbar_to_small_buttons_width + ...
                colorbar_axes_width + colorbar_label_area_width + from_colorbar_to_small_buttons_width ;
            zoom_in_button_x=small_buttons_x;
            zoom_in_button_y=heatmap_axes_y;  % want bottom-aligned with axes
            set(self.zoom_in_button_, ...
                'Position',[zoom_in_button_x zoom_in_button_y ...
                            small_button_size small_button_size]);
            zoom_out_button_x=small_buttons_x;
            zoom_out_button_y=zoom_in_button_y+small_button_size+space_between_zoom_buttons;  % want just above other zoom button
            set(self.zoom_out_button_, ...
                'Position',[zoom_out_button_x zoom_out_button_y ...
                            small_button_size small_button_size]);
            
            % the y limits button
            colormap_max_button_x=small_buttons_x;
            colormap_max_button_y=zoom_out_button_y+small_button_size+space_between_zoom_buttons;  % want above other zoom buttons
            set(self.colormap_max_button_, ...
                'Position',[colormap_max_button_x colormap_max_button_y ...
                            small_button_size small_button_size]);

            % the clear button
            clear_button_x = small_buttons_x;
            clear_button_y = heatmap_axes_y + heatmap_axes_height - small_button_size ;            
            set(self.clear_button_, ...
                'Position',[clear_button_x clear_button_y ...
                            small_button_size small_button_size]);            
        end  % function layout_

        function update_controls_in_existance_(self)  %#ok<MANU> 
            %fprintf('updateControlsInExistance_!\n');
            % Makes sure the controls that exist match what controls _should_
            % exist, given the current model state.

%             % Determine the number of electrodes right now
%             model = self.model_ ;
%             if isempty(model) || ~isvalid(model) ,
%                 n_electrodes=0;
%             else
%                 %testPulser = self.Model_.Ephys.TestPulser ;
%                 %nElectrodes=testPulser.NElectrodes;
%                 n_electrodes = model.test_pulse_electrodes_count ;
%             end
%             %nElectrodes=4  % FOR DEBUGGING ONLY
%             
%             % Determine how many electrodes there were the last time the
%             % controls in existance was updated
%             n_electrodes_previously=length(self.gain_texts_);
%             
%             n_new_electrodes=n_electrodes-n_electrodes_previously;
%             if n_new_electrodes>0 ,
%                 for i=1:n_new_electrodes ,
%                     j=n_electrodes_previously+i;  % index of new row in "table"
%                     % Gain text
%                     self.gain_label_texts_(j)= ...
%                         ws.uicontrol('Parent',self.figure_, ...
%                                   'Style','text', ...
%                                   'HorizontalAlignment','right', ...
%                                   'String','Gain: ');
%                     self.gain_texts_(j)= ...
%                         ws.uicontrol('Parent',self.figure_, ...
%                                   'Style','text', ...
%                                   'HorizontalAlignment','right', ...
%                                   'String','100');
%                     self.gain_units_texts_(j)= ...
%                         ws.uicontrol('Parent',self.figure_, ...
%                                   'Style','text', ...
%                                   'HorizontalAlignment','left', ...
%                                   'String','MOhm');
%                 end
%             elseif n_new_electrodes<0 ,
%                 % Delete the excess HG objects
%                 ws.delete_if_valid_hg_handle(self.gain_label_texts_(n_electrodes+1:end));
%                 ws.delete_if_valid_hg_handle(self.gain_texts_(n_electrodes+1:end));
%                 ws.delete_if_valid_hg_handle(self.gain_units_texts_(n_electrodes+1:end));
% 
%                 % Delete the excess HG handles
%                 self.gain_label_texts_(n_electrodes+1:end)=[];
%                 self.gain_texts_(n_electrodes+1:end)=[];
%                 self.gain_units_texts_(n_electrodes+1:end)=[];
%             end            
        end
        
%         function controlActuated(self,src,evt) %#ok<INUSD>
%             % This makes it so that we don't have all these implicit
%             % references to the controller in the closures attached to HG
%             % object callbacks.  It also means we can just do nothing if
%             % the Controller is invalid, instead of erroring.
%             %fprintf('view.controlActuated!\n');
%             if isempty(self.Controller) || ~isvalid(self.Controller) ,
%                 return
%             end
%             self.Controller.controlActuated(src);
%         end  % function
    end  % protected methods
        
%     methods
%         function closeRequested(self,source,event)
%             % This makes it so that we don't have all these implicit
%             % references to the controller in the closures attached to HG
%             % object callbacks.  It also means we can just do nothing if
%             % the Controller is invalid, instead of erroring.
%             if isempty(self.Controller) || ~isvalid(self.Controller) ,
%                 delete(self);
%             else
%                 self.Controller.windowCloseRequested(source,event);
%             end
%         end  % function        
%     end  % methods

%     methods (Access = protected)
%         % Have to subclass this b/c there are SetAccess=protected properties.
%         % (Would be nice to have a less-hacky solution for this...)
%         function setHGTagsToPropertyNames_(self)
%             % For each object property, if it's an HG object, set the tag
%             % based on the property name, and set other HG object properties that can be
%             % set systematically.
%             mc=metaclass(self);
%             propertyNames={mc.PropertyList.Name};
%             for i=1:length(propertyNames) ,
%                 propertyName=propertyNames{i};
%                 propertyThing=self.(propertyName);
%                 if ~isempty(propertyThing) && all(ishghandle(propertyThing)) && ~(isscalar(propertyThing) && isequal(get(propertyThing,'Type'),'figure')) ,
%                     % Set Tag
%                     set(propertyThing,'Tag',propertyName);                    
%                 end
%             end
%         end  % function        
%     end  % protected methods block
    
    methods            
%         function self=TestPulserController(wavesurferController,wavesurferModel)
%             % Call the superclass constructor
%             %testPulser=wavesurferModel.Ephys.TestPulser;
%             self = self@ws.Controller(wavesurferController,wavesurferModel);  
% 
%             % Create the figure, store a pointer to it
%             fig = ws.TestPulserFigure(wavesurferModel,self) ;
%             self.Figure_ = fig ;            
%         end
        
        function exception_maybe = control_actuated(self, control_name, source, event, varargin)
            try
                model = self.model_ ;
                if strcmp(control_name, 'start_button_') ,
                    self.start_button_actuated() ;
                    exception_maybe = {} ;
                else
                    % If the model is running, stop it (have to disable broadcast so we don't lose the new setting)
                    was_running_on_entry = model.is_running() ;
                    if was_running_on_entry ,
                        self.set_are_updates_enabled(false) ;
                        model.stop() ;
                    end
                    
                    % Act on the control
                    exception_maybe = control_actuated@ws.controller(self, control_name, source, event, varargin{:}) ;
                    % if exceptionMaybe is nonempty, a dialog has already
                    % been shown to the user.

                    % Start running again, if needed, and if there was no
                    % exception.
                    if was_running_on_entry ,
                        self.set_are_updates_enabled(true) ;
                        self.update_control_properties() ;
                        if isempty(exception_maybe) ,
                            model.start() ;
                        end
                    end
                end
            catch exception
                ws.raise_dialog_on_exception(exception) ;
                exception_maybe = { exception } ;
            end
        end  % function
        
        function start_button_actuated(self, source, event, varargin)  %#ok<INUSD>
            self.model_.do('toggle_is_running');
        end
        
        function auto_colormap_max_checkbox_actuated(self, source, event, varargin)  %#ok<INUSD>
            new_value = logical(get(self.auto_colormap_max_checkbox_,'Value')) ;
            self.model_.do('set_is_auto_colormap_max', new_value) ;
        end
        
%         function auto_colormap_maxrepeating_checkbox_actuated(self, source, event, varargin)  %#ok<INUSD>
%             new_value = logical(get(self.auto_colormap_max_repeating_checkbox_,'Value')) ;
%             self.model_.do('set_is_auto_colormap_max_repeating', new_value) ;
%         end
        
%         function pre_trigger_duration_edit_actuated(self, source, event, varargin)  %#ok<INUSD>
%             value_as_string = get(self.pre_trigger_duration_edit_,'String') ;
%             value = str2double(value_as_string) ;
%             self.model_.do('set_pre_trigger_duration', value) ;
%         end
        
%         function post_trigger_duration_edit_actuated(self, source, event, varargin)  %#ok<INUSD>
%             value_as_string = get(self.post_trigger_duration_edit_,'String') ;
%             value = str2double(value_as_string) ;
%             self.model_.do('set_post_trigger_duration', value) ;
%         end
%         
%         function bin_duration_edit_actuated(self, source, event, varargin)  %#ok<INUSD>
%             value_as_string = get(self.bin_duration_edit_,'String') ;
%             value = str2double(value_as_string) ;
%             self.model_.do('set_bin_duration', value) ;
%         end
        
        function monitored_threshold_rising_button_actuated(self, source, event, varargin)  %#ok<INUSD>
            self.model_.do('set_monitored_threshold_crossing_sign', +1) ;
        end

        function monitored_threshold_falling_button_actuated(self, source, event, varargin)  %#ok<INUSD>
            self.model_.do('set_monitored_threshold_crossing_sign', -1) ;
        end

        function clear_button_actuated(self, source, event, varargin)  %#ok<INUSD>
            self.model_.do('clear') ;
        end
        
        function zoom_in_button_actuated(self, source, event, varargin)  %#ok<INUSD>
            self.model_.do('zoom_in') ;
        end
        
        function zoom_out_button_actuated(self, source, event, varargin)  %#ok<INUSD>
            self.model_.do('zoom_out') ;
        end
        
        function colormap_max_button_actuated(self, source, event, varargin)  %#ok<INUSD>
            self.the_colormap_max_dialog_controller_ = [] ;  % if not first call, this should cause the old controller to be garbage collectable
            
            model = self.model_ ;
            
            set_model_colormap_max_callback = @(new_colormap_max)(model.do('set_colormap_max', new_colormap_max)) ;
            
            self.the_colormap_max_dialog_controller_ = ...
                colormap_max_dialog_controller([], ...
                                        get(self.figure_,'Position'), ...
                                        model.colormap_max(), ...
                                        '', ...
                                        set_model_colormap_max_callback) ;
        end
        
%         function scroll_up_button_actuated(self, source, event, varargin)  %#ok<INUSD>
%             self.model_.do('scroll_up') ;
%         end
%         
%         function scroll_down_button_actuated(self, source, event, varargin)  %#ok<INUSD>
%             self.model_.do('scroll_down') ;
%         end
    end  % methods    

    methods (Access=protected)
        function close_requested_(self, source, event)  %#ok<INUSD>
            self.delete() ;
        end        
    end  % protected methods block    
    
end  % classdef
