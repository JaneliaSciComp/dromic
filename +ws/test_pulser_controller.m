classdef test_pulser_controller < ws.controller
    properties  (SetAccess=protected)
        start_stop_button
        electrode_popup_menu_label_text
        electrode_popup_menu
        amplitude_edit_label_text
        amplitude_edit
        amplitude_edit_units_text
        duration_edit_label_text
        duration_edit
        duration_edit_units_text
        subtract_baseline_checkbox
        auto_ycheckbox
        auto_yrepeating_checkbox
        vctoggle
        cctoggle
        trace_axes
        xaxis_label
        yaxis_label
        trace_line
        update_rate_text_label_text
        update_rate_text
        update_rate_text_units_text
        gain_label_texts
        gain_texts
        gain_units_texts
        zoom_in_button
        zoom_out_button
        scroll_up_button
        scroll_down_button
        ylimits_button
    end  % properties
    
    properties (Access=protected)
        %IsMinimumSizeSet_ = false
        ylimits_ = [-10 +10]   % the current y limits
    end
    
    properties
        my_ylim_dialog_controller=[]
    end
    
    methods
        function self = test_pulser_controller(ws_model)
            self = self@ws.controller(ws_model);
            
            % Create the widgets (except figure, created in superclass
            % constructor)
            set(self.figure_gh_,'Tag','TestPulserFigure', ...
                              'Units','pixels', ...
                              'Resize','on', ...
                              'Name','Test Pulse', ...
                              'NumberTitle','off', ...
                              'Menubar','none', ...
                              'Toolbar','none', ...
                              'Visible','off');
            
            % Create the controls that will persist throughout the lifetime of the window              
            self.create_fixed_controls_();
            
            % Set the initial figure position
            self.set_initial_figure_position_();

            % Sync with the model
            self.update();            
            
            % Subscribe to model events
            if ~isempty(ws_model) ,
                ws_model.subscribe_me(self,'Update','','update');
                ws_model.subscribe_me(self,'UpdateTestPulser','','update') ;                
                ws_model.subscribe_me(self,'DidSetState','','updateControlProperties') ;
                ws_model.subscribe_me(self,'UpdateElectrodeManager','','update') ;
                ws_model.subscribe_me(self,'TPUpdateTrace','','updateTrace') ;
                ws_model.subscribe_me(self,'TPDidSetIsInputChannelActive','','update') ;
                ws_model.subscribe_me(self, 'DidSetSingleFigureVisibility', '', 'updateVisibility') ;
            end
            
            % Make visible
            %set(self.FigureGH_, 'Visible', 'on') ;
        end  % constructor
        
        function delete(self)
            if ~isempty(self.my_ylim_dialog_controller) && ishandle(self.my_ylim_dialog_controller) ,
                delete(self.my_ylim_dialog_controller) ;
            end
            delete@ws.controller(self) ;
        end  % function
        
        function update_trace(self,varargin)
            % If there are issues with either the host or the model, just return
            %fprintf('updateTrace!\n');
            if ~self.are_updates_enabled ,
                return
            end
            if isempty(self.model_) || ~isvalid(self.model_) ,
                return
            end
            ws_model = self.model_ ;
            %ephys = wsModel.Ephys ;
            %testPulser = ephys.TestPulser ;
            
            %fprintf('here -1\n');
            % draw the trace line
            %monitor=self.Model_.Monitor;
            %t=self.Model_.Time;  % s            
            %set(self.TraceLine,'YData',monitor);
            
            % If y range hasn't been set yet, and Y Auto is engaged, set
            % the y range.
            if ws_model.is_test_pulsing() && ws_model.is_auto_yin_test_pulse_view ,   %&& testPulser.AreYLimitsForRunDetermined ,
                y_limits_in_model = ws_model.test_pulse_ylimits ;
                y_limits=self.ylimits_;
                %if all(isfinite(yLimits)) && ~isequal(yLimits,yLimitsInModel) ,
                if ~isequal(y_limits,y_limits_in_model) ,
                    self.ylimits_ = y_limits_in_model;  % causes axes ylim to be changed
                    set(self.trace_axes,'YLim',y_limits_in_model);
                    %self.layout();  % Need to update the whole layout, b/c '^10^-3' might have appeared above the y axis
                    %self.updateControlProperties();  % Now do a near-full update, which will call updateTrace(), but this block will be
                    %                                 % skipped b/c isequal(self.YLimits,yLimitsNominal)
                    %return  % no need to do anything else
                end
            end
            
            % Update the graphics objects to match the model and/or host
            % Extra spaces b/c right-align cuts of last char a bit
            update_rate = ws_model.get_update_rate_in_test_pulse_view() ;
            set(self.update_rate_text,'String',ws.fif(isnan(update_rate),'? ',sprintf('%0.1f ',update_rate)));
            %fprintf('here\n');
            %rawGainOrResistance=testPulser.GainOrResistancePerElectrode;
            %rawGainOrResistanceUnits = testPulser.GainOrResistanceUnitsPerElectrode ;
            %[gainOrResistanceUnits,gainOrResistance] = rawGainOrResistanceUnits.convertToEngineering(rawGainOrResistance) ;
            [gain_or_resistance, gain_or_resistance_units] = ws_model.get_gain_or_resistance_per_test_pulse_electrode_with_nice_units() ;
            %fprintf('here 2\n');
            n_electrodes=length(gain_or_resistance);
            for j=1:n_electrodes ,
                gain_or_resistance_this = gain_or_resistance(j) ;
                if isnan(gain_or_resistance_this) ,
                    set(self.gain_texts(j),'String','? ');
                    set(self.gain_units_texts(j),'String','');
                else
                    set(self.gain_texts(j),'String',sprintf('%0.1f ',gain_or_resistance_this));
                    gain_or_resistance_units_this = gain_or_resistance_units{j} ;
                    set(self.gain_units_texts(j),'String',gain_or_resistance_units_this);
                end
            end
            %fprintf('here 3\n');
            % draw the trace line
            %ephys = testPulser.Parent ;
            monitor = ws_model.get_test_pulse_monitor_trace() ;
            %t=testPulser.Time;  % s            
            if ~isempty(monitor) ,
                set(self.trace_line, 'YData', monitor) ;
            end
        end  % method
        
%         function updateIsReady(self,varargin)            
%             if isempty(testPulser) || testPulser.IsReady ,
%                 set(self.FigureGH_,'pointer','arrow');
%             else
%                 % Change cursor to hourglass
%                 set(self.FigureGH_,'pointer','watch');
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
            ws_model = self.model_ ;
            if isempty(ws_model) ,
                set(self.figure_gh_,'pointer','arrow');
            else                
                %ephys = wsModel.Ephys ;
                if ws_model.is_ready ,
                    set(self.figure_gh_,'pointer','arrow');
                else
                    % Change cursor to hourglass
                    set(self.figure_gh_,'pointer','watch');
                end
            end            
        end
        
        function update_control_properties_implementation_(self,varargin)
            %fprintf('\n\nTestPulserFigure.updateControlPropertiesImplementation:\n');
            %dbstack
            % If there are issues with the model, just return
            if isempty(self.model_) || ~isvalid(self.model_) ,
                return
            end
                        
%             fprintf('TestPulserFigure.updateControlPropertiesImplementation_:\n');
%             dbstack
%             fprintf('\n');            
            
            % Get some handles we'll need
            ws_model = self.model_ ;
            %ephys = wsModel.Ephys ;
            %testPulser = ephys.TestPulser ;
            %electrodeManager=ephys.ElectrodeManager;
            %electrode = ephys.TestPulseElectrode ;
            tp_electrode_index = ws_model.test_pulse_electrode_index ;
            
            % Define some useful booleans
            is_electrode_manual = isempty(tp_electrode_index) || isequal(ws_model.get_test_pulse_electrode_property('Type'), 'Manual') ; 
            is_electrode_manager_in_control_of_softpanel_mode_and_gains=ws_model.is_in_control_of_softpanel_mode_and_gains;
            is_wavesurfer_idle=isequal(ws_model.state,'idle');
            %isWavesurferTestPulsing=(wavesurferModel.State==ws.ApplicationState.TestPulsing);
            is_wavesurfer_test_pulsing = ws_model.is_test_pulsing() ;
            is_wavesurfer_idle_or_test_pulsing = is_wavesurfer_idle||is_wavesurfer_test_pulsing ;
            is_auto_y = ws_model.is_auto_yin_test_pulse_view ;
            is_auto_yrepeating = ws_model.is_auto_yrepeating_in_test_pulse_view ;
            
            % Update the graphics objects to match the model and/or host
            is_start_stop_button_enabled = ws_model.is_test_pulsing_enabled() ;
%                 isWavesurferIdleOrTestPulsing && ...
%                 ~isempty(tpElectrodeIndex) && ...
%                 wsModel.areTestPulseElectrodeChannelsValid() && ...
%                 wsModel.areAllMonitorAndCommandChannelNamesDistinct() && ...
%                 ~wsModel.areTestPulseElectrodeMonitorAndCommandChannelsOnDiffrentDevices() ; 
            set(self.start_stop_button, ...
                'String',ws.fif(is_wavesurfer_test_pulsing,'Stop','Start'), ...
                'Enable',ws.on_iff(is_start_stop_button_enabled));
            
            electrode_names = ws_model.get_all_electrode_names ;
            electrode_name = ws_model.get_test_pulse_electrode_property('Name') ;
            ws.set_popup_menu_items_and_selection_bang(self.electrode_popup_menu, ...
                                                 electrode_names, ...
                                                 electrode_name);
            set(self.electrode_popup_menu, ...
                'Enable',ws.on_iff(is_wavesurfer_idle_or_test_pulsing));
                                         
            set(self.subtract_baseline_checkbox,'Value',ws_model.do_subtract_baseline_in_test_pulse_view, ...
                                              'Enable',ws.on_iff(is_wavesurfer_idle_or_test_pulsing));
            set(self.auto_ycheckbox,'Value',is_auto_y, ...
                                   'Enable',ws.on_iff(is_wavesurfer_idle_or_test_pulsing));
            set(self.auto_yrepeating_checkbox,'Value',is_auto_yrepeating, ...
                                            'Enable',ws.on_iff(is_wavesurfer_idle_or_test_pulsing&&is_auto_y));
                   
            % Have to disable these togglebuttons during test pulsing,
            % because switching an electrode's mode during test pulsing can
            % fail: in the target mode, the electrode may not be
            % test-pulsable (e.g. the monitor and command channels haven't
            % been set for the target mode), or the monitor and command
            % channels for the set of active electrode may not be mutually
            % exclusive.  That makes computing whether the target mode is
            % valid complicated.  We punt by just disabling the
            % mode-switching toggle buttons during test pulsing.  The user
            % can always stop test pulsing, switch the mode, then start
            % again (if that's a valid action in the target mode).
            % Hopefully this limitation is not too annoying for users.
            mode = ws_model.get_test_pulse_electrode_property('Mode') ;
            set(self.vctoggle, 'Enable', ws.on_iff(is_wavesurfer_idle && ...
                                                  ~isempty(tp_electrode_index) && ...
                                                  (is_electrode_manual||is_electrode_manager_in_control_of_softpanel_mode_and_gains)), ...
                               'Value', ~isempty(tp_electrode_index)&&isequal(mode,'vc'));
            set(self.cctoggle, 'Enable', ws.on_iff(is_wavesurfer_idle && ...
                                                  ~isempty(tp_electrode_index)&& ...
                                                  (is_electrode_manual||is_electrode_manager_in_control_of_softpanel_mode_and_gains)), ...
                               'Value', ~isempty(tp_electrode_index) && ...
                                        (isequal(mode,'cc')||isequal(mode,'i_equals_zero')));
                        
            amplitude = ws_model.get_test_pulse_electrode_property('TestPulseAmplitude') ;                      
            set(self.amplitude_edit,'String',sprintf('%g',amplitude), ...
                                   'Enable',ws.on_iff(is_wavesurfer_idle_or_test_pulsing&&~isempty(tp_electrode_index)));
            set(self.amplitude_edit_units_text,'String',ws_model.get_test_pulse_electrode_command_units, ...
                                            'Enable',ws.on_iff(is_wavesurfer_idle_or_test_pulsing&&~isempty(tp_electrode_index)));
            set(self.duration_edit, 'String', sprintf('%g', 1e3*ws_model.test_pulse_duration), ...
                                   'Enable', ws.on_iff(is_wavesurfer_idle_or_test_pulsing)) ;
            set(self.duration_edit_units_text,'Enable',ws.on_iff(is_wavesurfer_idle_or_test_pulsing));
            n_electrodes=length(self.gain_label_texts);
            is_vcper_test_pulse_electrode = ws_model.get_is_vcper_test_pulse_electrode() ;
            is_ccper_test_pulse_electrode = ws_model.get_is_ccper_test_pulse_electrode() ;
            tp_electrode_names = ws_model.get_test_pulse_electrode_names() ;
            for i=1:n_electrodes ,
                if is_ccper_test_pulse_electrode(i) || is_vcper_test_pulse_electrode(i) ,
                    set(self.gain_label_texts(i), 'String', sprintf('%s Resistance: ', tp_electrode_names{i})) ;
                else
                    set(self.gain_label_texts(i), 'String', sprintf('%s Gain: ', tp_electrode_names{i})) ;
                end
                %set(self.GainUnitsTexts(i),'String',string(testPulser.GainOrResistanceUnitsPerElectrode(i)));
                set(self.gain_units_texts(i),'String','');
            end
            sweep_duration = 2*ws_model.test_pulse_duration ;
            set(self.trace_axes,'XLim',1000*[0 sweep_duration]);
            self.ylimits_ = ws_model.test_pulse_ylimits ;
            set(self.trace_axes,'YLim',self.ylimits_);
            set(self.yaxis_label,'String',sprintf('Monitor (%s)',ws_model.get_test_pulse_electrode_monitor_units()));
            t = ws_model.get_test_pulse_monitor_trace_timeline() ;
            %t=testPulser.Time;
            set(self.trace_line,'XData',1000*t,'YData',nan(size(t)));  % convert s to ms
            set(self.zoom_in_button,'Enable',ws.on_iff(~is_auto_y));
            set(self.zoom_out_button,'Enable',ws.on_iff(~is_auto_y));
            set(self.scroll_up_button,'Enable',ws.on_iff(~is_auto_y));
            set(self.scroll_down_button,'Enable',ws.on_iff(~is_auto_y));
            set(self.ylimits_button,'Enable',ws.on_iff(~is_auto_y));
            self.update_trace();
        end  % method        
                
    end  % protected methods block
    
    methods (Access=protected)
        function create_fixed_controls_(self)
            
            % Start/stop button
            self.start_stop_button= ...
                ws.uicontrol('Parent',self.figure_gh_, ...
                          'Style','pushbutton', ...
                          'String','Start', ...
                          'Callback',@(src,evt)(self.control_actuated('StartStopButton',src,evt)));
                          
            % Electrode popup menu
            self.electrode_popup_menu_label_text= ...
                ws.uicontrol('Parent',self.figure_gh_, ...
                        'Style','text', ...
                        'HorizontalAlignment','right', ...
                        'String','Electrode: ');
            self.electrode_popup_menu= ...
                ws.uipopupmenu('Parent',self.figure_gh_, ...
                          'String',{'Electrode 1' 'Electrode 2'}, ...
                          'Value',1, ...
                          'Callback',@(src,evt)(self.control_actuated('ElectrodePopupMenu',src,evt)));
                      
            % Baseline subtraction checkbox
            self.subtract_baseline_checkbox= ...
                ws.uicontrol('Parent',self.figure_gh_, ...
                        'Style','checkbox', ...
                        'String','Sub Base', ...
                        'Callback',@(src,evt)(self.control_actuated('SubtractBaselineCheckbox',src,evt)));

            % Auto Y checkbox
            self.auto_ycheckbox= ...
                ws.uicontrol('Parent',self.figure_gh_, ...
                        'Style','checkbox', ...
                        'String','Auto Y', ...
                        'Callback',@(src,evt)(self.control_actuated('AutoYCheckbox',src,evt)));

            % Auto Y repeat checkbox
            self.auto_yrepeating_checkbox= ...
                ws.uicontrol('Parent',self.figure_gh_, ...
                        'Style','checkbox', ...
                        'String','Repeating', ...
                        'Callback',@(src,evt)(self.control_actuated('AutoYRepeatingCheckbox',src,evt)));
                    
            % VC/CC toggle buttons
            self.vctoggle= ...
                ws.uicontrol('Parent',self.figure_gh_, ...
                          'Style','radiobutton', ...
                          'String','VC', ...
                          'Callback',@(src,evt)(self.control_actuated('VCToggle',src,evt)));
            self.cctoggle= ...
                ws.uicontrol('Parent',self.figure_gh_, ...
                          'Style','radiobutton', ...
                          'String','CC', ...
                          'Callback',@(src,evt)(self.control_actuated('CCToggle',src,evt)));
                      
            % Amplitude edit
            self.amplitude_edit_label_text= ...
                ws.uicontrol('Parent',self.figure_gh_, ...
                        'Style','text', ...
                        'HorizontalAlignment','right', ...
                        'String','Amplitude: ');
            self.amplitude_edit= ...
                ws.uiedit('Parent',self.figure_gh_, ...
                          'HorizontalAlignment','right', ...
                          'Callback',@(src,evt)(self.control_actuated('AmplitudeEdit',src,evt)));
            self.amplitude_edit_units_text= ...
                ws.uicontrol('Parent',self.figure_gh_, ...
                        'Style','text', ...
                        'HorizontalAlignment','left', ...
                        'String','mV');

            % Duration edit
            self.duration_edit_label_text= ...
                ws.uicontrol('Parent',self.figure_gh_, ...
                        'Style','text', ...
                        'HorizontalAlignment','right', ...
                        'String','Duration: ');
            self.duration_edit= ...
                ws.uiedit('Parent',self.figure_gh_, ...
                          'HorizontalAlignment','right', ...
                          'Callback',@(src,evt)(self.control_actuated('DurationEdit',src,evt)));
            self.duration_edit_units_text= ...
                ws.uicontrol('Parent',self.figure_gh_, ...
                        'Style','text', ...
                        'HorizontalAlignment','left', ...
                        'String','ms');

            % Trace axes        
            self.trace_axes= ...
                axes('Parent',self.figure_gh_, ...
                     'Units','pixels', ...
                     'box','on', ...
                     'XLim',[0 20], ...
                     'YLim',self.ylimits_, ...
                     'FontSize', 9, ...
                     'Visible','on');
            
            % Axis labels
            self.xaxis_label= ...
                xlabel(self.trace_axes,'Time (ms)','FontSize',9,'Interpreter','none');
            self.yaxis_label= ...
                ylabel(self.trace_axes,'Monitor (pA)','FontSize',9,'Interpreter','none');
            
            % Trace line
            self.trace_line= ...
                line('Parent',self.trace_axes, ...
                     'XData',[], ...
                     'YData',[]);
            
            % Update rate text
            self.update_rate_text_label_text= ...
                ws.uicontrol('Parent',self.figure_gh_, ...
                        'Style','text', ...
                        'HorizontalAlignment','right', ...                        
                        'String','Update Rate: ');
            self.update_rate_text= ...
                ws.uicontrol('Parent',self.figure_gh_, ...
                          'Style','text', ...
                          'HorizontalAlignment','right', ...
                          'String','50');
            self.update_rate_text_units_text= ...
                ws.uicontrol('Parent',self.figure_gh_, ...
                        'Style','text', ...
                        'String','Hz');
                    
            % Y axis control buttons
            self.zoom_in_button= ...
                ws.uicontrol('Parent',self.figure_gh_, ...
                          'Style','pushbutton', ...
                          'String','+', ...
                          'Callback',@(src,evt)(self.control_actuated('ZoomInButton',src,evt)));
            self.zoom_out_button= ...
                ws.uicontrol('Parent',self.figure_gh_, ...
                          'Style','pushbutton', ...
                          'String','-', ...
                          'Callback',@(src,evt)(self.control_actuated('ZoomOutButton',src,evt)));

            wavesurfer_dir_name=fileparts(which('wavesurfer'));
            icon_file_name = fullfile(wavesurfer_dir_name, '+ws', 'icons', 'up_arrow.png');
            cdata = ws.read_pngwith_transparency_for_uicontrol_image(icon_file_name) ;
            self.scroll_up_button= ...
                ws.uicontrol('Parent',self.figure_gh_, ...
                          'Style','pushbutton', ...
                          'CData',cdata, ...
                          'Callback',@(src,evt)(self.control_actuated('ScrollUpButton',src,evt)));
%                           'String','^', ...

            icon_file_name = fullfile(wavesurfer_dir_name, '+ws', 'icons', 'down_arrow.png');
            cdata = ws.read_pngwith_transparency_for_uicontrol_image(icon_file_name) ;
            self.scroll_down_button= ...
                ws.uicontrol('Parent',self.figure_gh_, ...
                          'Style','pushbutton', ...
                          'CData',cdata, ...
                          'Callback',@(src,evt)(self.control_actuated('ScrollDownButton',src,evt)));
            
            icon_file_name = fullfile(wavesurfer_dir_name, '+ws', 'icons', 'y_manual_set.png');
            cdata = ws.read_pngwith_transparency_for_uicontrol_image(icon_file_name) ;
            self.ylimits_button= ...
                ws.uicontrol('Parent',self.figure_gh_, ...
                          'Style','pushbutton', ...
                          'CData',cdata, ...
                          'Callback',@(src,evt)(self.control_actuated('YLimitsButton',src,evt)));
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
            initial_size=[570 500];
            figure_offset=(screen_size-initial_size)/2;
            figure_position=[figure_offset initial_size];
            set(self.figure_gh_,'Position',figure_position);
            
            % do the widget layout within the figure
            %self.layout();
        end  % function
        
        function layout_(self)
            % lays out the figure widgets, given the current figure size
            %fprintf('Inside layout()...\n');

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
            %     top-stuff-traces-plot-interspace
            %     the traces plot
            %     bottom-stuff-traces-plot-interspace
            %     bottom stuff (the update rate and gain widgets)
            %     bottom space.  
            %
            % Each is a rectangle, and they are laid out edge-to-edge
            % vertically.  All but the traces plot have a fixed height, and
            % the traces plot fills the leftover height in the layout.  The
            % top edge of the top space is fixed to the top edge of the
            % layout, and the bottom of the bottom space is fixed to the
            % bottom edge of the layout.

            % minimum layout dimensions
            minimum_layout_width=570;  % If the figure gets small, we lay it out as if it was bigger
            minimum_layout_height=500;  
            
            % Heights of the stacked rectangles that comprise the layout
            top_space_height = 0 ;
            % we don't know the height of the top stuff yet, but it does
            % not depend on the figure/layout size
            top_stuff_to_traces_plot_interspace_height = 2 ;
            % traces plot height is set to fill leftover space in the
            % layout
            traces_plot_to_bottom_stuff_interspace_height=10;
            % we don't know the height of the bottom stuff yet, but it does
            % not depend on the figure/layout size            
            bottom_space_height = 2 ;
            
            % General widget sizes
            edit_width=40;
            edit_height=20;
            text_height=18;  % for 8 pt font
            
            % Top stuff layout parameters
            width_from_top_stuff_left_to_start_stop_button=22;
            height_from_top_stuff_top_to_start_stop_button=20;
            start_stop_button_width=96;
            start_stop_button_height=28;
            checkbox_bank_xoffset = 145 ;
            checkbox_bank_width = 80 ;
            width_from_checkbox_bank_to_electrode_bank = 16 ;
            height_from_figure_top_to_sub_base_checkbox = 6 ; 
            height_between_checkboxes = -1 ;
            width_of_auto_yrepeating_indent = 14 ;
            electrode_popup_menu_label_text_x=checkbox_bank_xoffset + checkbox_bank_width + width_from_checkbox_bank_to_electrode_bank ;
            height_from_top_stuff_stop_to_popup=10;
            height_between_amplitude_and_duration=26;
            electrode_popup_width=100;
            width_from_popups_right_to_amplitude_left=20;
            clamp_toggle_width = 40 ;
            clamp_toggle_height = 18 ;
            electrode_popup_to_clamp_toggle_area_height=8;
            inter_clamp_toggle_width = 2 ;
            
            % Traces plot layout parameters                      
            width_from_layout_left_to_plot=0;
            width_from_layout_right_to_plot=0;            
            trace_axes_left_pad=5;
            trace_axes_right_pad=5;
            tick_length=5;  % in pixels
            from_axes_to_yrange_buttons_width=6;
            y_range_button_size=20;  % those buttons are square
            space_between_scroll_buttons=5;
            space_between_zoom_buttons=5;
            
            % Bottom stuff layout parameters
            width_from_layout_left_to_update_rate_left=20;  
            width_from_layout_right_to_gain_right=20;
            update_rate_text_width=36;  % wide enough to accomodate '100.0'
            gain_text_width=60;
            inter_gain_space_height=0;
            gain_units_text_width=40;  % approximately right for 'GOhm' in 9 pt text.  Don't want layout to change even if units change
            %gainLabelTextWidth=200;  % Approximate width if the string is 'Electrode 1 Resistance: ' [sic]
            gain_label_text_width=160;  % Approximate width if the string is 'Electrode 1 Resistance: ' [sic]
            %fromSubBaseToAutoYSpaceWidth=16;
            
            % Get the dimensions of the figure, determine the size and
            % position of the layout rectangle
            figure_position=get(self.figure_gh_,'Position');
            figure_width = figure_position(3) ;
            figure_height = figure_position(4) ;
            % When the figure gets small, we layout the widgets as if it were
            % bigger.  The size we're "pretending" the figure is we call the
            % "layout" size
            layout_width=max(figure_width,minimum_layout_width) ;  
            layout_height=max(figure_height,minimum_layout_height) ;
            layout_yoffset = figure_height - layout_height ;
              % All widget coords have to ultimately be given in the figure
              % coordinate system.  This is the y position of the layout
              % lower left corner, in the figure coordinate system.
            layout_top_yoffset = layout_yoffset + layout_height ;  
              
            % Can compute the height of the bottom stuff pretty easily, so
            % do that now
            n_electrodes=length(self.gain_texts);
            n_bottom_rows=max(n_electrodes,1);  % Even when no electrodes, there's still the update rate text
            bottom_stuff_height = n_bottom_rows*text_height + (n_bottom_rows-1)*inter_gain_space_height ;

            
              
            %
            %
            % Position thangs
            %
            %
            
            %
            % The start/stop button "bank"
            %
            
            % The start/stop button
            top_stuff_top_yoffset = layout_top_yoffset - top_space_height ;
            start_stop_button_x=width_from_top_stuff_left_to_start_stop_button;
            start_stop_button_y=top_stuff_top_yoffset-height_from_top_stuff_top_to_start_stop_button-start_stop_button_height;
            set(self.start_stop_button, ...
                'Position',[start_stop_button_x start_stop_button_y ...
                            start_stop_button_width start_stop_button_height]);
                  
            %
            % The checkbox "bank"
            %
                        
            % Baseline subtraction checkbox
            [subtract_baseline_checkbox_text_width,subtract_baseline_checkbox_text_height]=ws.get_extent(self.subtract_baseline_checkbox);
            subtract_baseline_checkbox_width=subtract_baseline_checkbox_text_width+16;  % Add some width to accomodate the checkbox itself
            subtract_baseline_checkbox_height=subtract_baseline_checkbox_text_height;
            subtract_baseline_checkbox_y = top_stuff_top_yoffset - height_from_figure_top_to_sub_base_checkbox - subtract_baseline_checkbox_height ;
            subtract_baseline_checkbox_x = checkbox_bank_xoffset ;
            set(self.subtract_baseline_checkbox, ...
                'Position',[subtract_baseline_checkbox_x subtract_baseline_checkbox_y ...
                            subtract_baseline_checkbox_width subtract_baseline_checkbox_height]);
            
            % Auto Y checkbox
            [auto_ycheckbox_text_width,auto_ycheckbox_text_height]=ws.get_extent(self.auto_ycheckbox);
            auto_ycheckbox_width=auto_ycheckbox_text_width+16;  % Add some width to accomodate the checkbox itself
            auto_ycheckbox_height=auto_ycheckbox_text_height;
            auto_ycheckbox_y = subtract_baseline_checkbox_y - height_between_checkboxes - auto_ycheckbox_height ;
            auto_ycheckbox_x = checkbox_bank_xoffset ;
            set(self.auto_ycheckbox, ...
                'Position',[auto_ycheckbox_x auto_ycheckbox_y ...
                            auto_ycheckbox_width auto_ycheckbox_height]);
                        
            % Auto Y Locked checkbox
            [auto_yrepeating_checkbox_text_width,auto_yrepeating_checkbox_text_height] = ws.get_extent(self.auto_yrepeating_checkbox) ;
            auto_yrepeating_checkbox_width = auto_yrepeating_checkbox_text_width + 16 ;  % Add some width to accomodate the checkbox itself
            auto_yrepeating_checkbox_height = auto_yrepeating_checkbox_text_height ;
            auto_yrepeating_checkbox_y = auto_ycheckbox_y - height_between_checkboxes - auto_yrepeating_checkbox_height ;
            auto_yrepeating_checkbox_x = checkbox_bank_xoffset + width_of_auto_yrepeating_indent ;
            set(self.auto_yrepeating_checkbox, ...
                'Position',[auto_yrepeating_checkbox_x auto_yrepeating_checkbox_y ...
                            auto_yrepeating_checkbox_width auto_yrepeating_checkbox_height]);

            % 
            %  The electrode bank
            %
            
            % The command channel popupmenu and its label                                           
            electrode_popup_menu_label_extent=get(self.electrode_popup_menu_label_text,'Extent');
            electrode_popup_menu_label_width=electrode_popup_menu_label_extent(3);
            electrode_popup_menu_label_height=electrode_popup_menu_label_extent(4);
            electrode_popup_menu_position=get(self.electrode_popup_menu,'Position');
            electrode_popup_menu_height=electrode_popup_menu_position(4);
            electrode_popup_menu_y= ...
                top_stuff_top_yoffset-height_from_top_stuff_stop_to_popup-electrode_popup_menu_height;
            electrode_popup_menu_label_text_y=...
                electrode_popup_menu_y+electrode_popup_menu_height/2-electrode_popup_menu_label_height/2-4;  % shim
            electrode_popup_menu_x=electrode_popup_menu_label_text_x+electrode_popup_menu_label_width+1;
            set(self.electrode_popup_menu_label_text, ...
                'Position',[electrode_popup_menu_label_text_x electrode_popup_menu_label_text_y ...
                            electrode_popup_menu_label_width electrode_popup_menu_label_height]);
            set(self.electrode_popup_menu, ...
                'Position',[electrode_popup_menu_x electrode_popup_menu_y ...
                            electrode_popup_width electrode_popup_menu_height]);
                        
            % VC, CC toggle buttons
            clamp_toggle_area_height=clamp_toggle_height;
            clamp_toggle_area_width=clamp_toggle_width+inter_clamp_toggle_width+clamp_toggle_width;

            clamp_toggle_area_center_x=electrode_popup_menu_x+electrode_popup_width/2;
            %clampToggleAreaRightX=electrodePopupMenuX+electrodePopupWidth;
            %clampToggleAreaCenterX=clampToggleAreaRightX-clampToggleAreaWidth/2;
            
            clamp_toggle_area_top_y=electrode_popup_menu_y-electrode_popup_to_clamp_toggle_area_height;
            clamp_toggle_area_x=clamp_toggle_area_center_x-clamp_toggle_area_width/2;
            %clampToggleAreaX = electrodePopupMenuX ;             
            clamp_toggle_area_y=clamp_toggle_area_top_y-clamp_toggle_area_height;
            
            % VC toggle button
            vc_toggle_x=clamp_toggle_area_x;
            vc_toggle_y=clamp_toggle_area_y;
            set(self.vctoggle, ...
                'Position',[vc_toggle_x vc_toggle_y ...
                            clamp_toggle_width clamp_toggle_height]);
                        
            % CC toggle button
            cc_toggle_x=vc_toggle_x+inter_clamp_toggle_width+clamp_toggle_width;
            cc_toggle_y=clamp_toggle_area_y;
            set(self.cctoggle, ...
                'Position',[cc_toggle_x cc_toggle_y ...
                            clamp_toggle_width clamp_toggle_height]);

                        
            % 
            %  The amplitude and duration bank
            %            
                        
            % The amplitude edit and its label
            [amplitude_edit_label_text_width,amplitude_edit_label_text_height]=ws.get_extent(self.amplitude_edit_label_text);
            amplitude_edit_label_text_x=electrode_popup_menu_x+electrode_popup_width+width_from_popups_right_to_amplitude_left;
            amplitude_edit_label_text_y=electrode_popup_menu_label_text_y;
            set(self.amplitude_edit_label_text, ...
                'Position',[amplitude_edit_label_text_x amplitude_edit_label_text_y ...
                            amplitude_edit_label_text_width amplitude_edit_label_text_height]);
            amplitude_stuff_middle_y=electrode_popup_menu_label_text_y+amplitude_edit_label_text_height/2;
            amplitude_edit_x=amplitude_edit_label_text_x+amplitude_edit_label_text_width+1;  % shim
            amplitude_edit_y=amplitude_stuff_middle_y-edit_height/2+2;
            set(self.amplitude_edit, ...
                'Position',[amplitude_edit_x amplitude_edit_y ...
                            edit_width edit_height]);
            %[~,amplitudeEditUnitsTextHeight]=ws.getExtent(self.AmplitudeEditUnitsText);
            amplitude_edit_units_text_faux_width=30;
            amplitude_edit_units_text_x=amplitude_edit_x+edit_width+1;  % shim
            amplitude_edit_units_text_y=amplitude_edit_label_text_y-1;
            set(self.amplitude_edit_units_text, ...
                'Position',[amplitude_edit_units_text_x amplitude_edit_units_text_y ...
                            amplitude_edit_units_text_faux_width text_height]);
            
            % The duration edit and its label
            [~,duration_edit_label_text_height]=ws.get_extent(self.duration_edit_label_text);
            duration_edit_label_text_x=amplitude_edit_label_text_x;
            duration_edit_label_text_y=electrode_popup_menu_label_text_y-height_between_amplitude_and_duration;
            set(self.duration_edit_label_text, ...
                'Position',[duration_edit_label_text_x duration_edit_label_text_y ...
                            amplitude_edit_label_text_width amplitude_edit_label_text_height]);
            duration_stuff_middle_y=duration_edit_label_text_y+duration_edit_label_text_height/2;
            duration_edit_x=amplitude_edit_x;  % shim
            duration_edit_y=duration_stuff_middle_y-edit_height/2+2;
            set(self.duration_edit, ...
                'Position',[duration_edit_x duration_edit_y ...
                            edit_width edit_height]);
            [duration_edit_units_text_width,duration_edit_units_text_height]=ws.get_extent(self.duration_edit_units_text);
            duration_edit_units_text_x=amplitude_edit_units_text_x;
            duration_edit_units_text_y=duration_edit_label_text_y-1;
            set(self.duration_edit_units_text, ...
                'Position',[duration_edit_units_text_x duration_edit_units_text_y ...
                            duration_edit_units_text_width duration_edit_units_text_height]);
            
            % All the stuff above is at a fixed y offset from the top of
            % the layout.  So now we can compute the height of the top
            % stuff rectangle.
            top_stuff_yoffset = min([auto_yrepeating_checkbox_y vc_toggle_y duration_edit_y]) ;
            top_stuff_height = top_stuff_top_yoffset - top_stuff_yoffset ;
                        
                        
            %
            % The trace plot
            %
            trace_axes_area_x=width_from_layout_left_to_plot;
            trace_axes_area_width= ...
                layout_width-width_from_layout_left_to_plot-width_from_layout_right_to_plot-y_range_button_size-from_axes_to_yrange_buttons_width;
            trace_axes_area_height = layout_height-top_space_height-top_stuff_to_traces_plot_interspace_height-top_stuff_height-traces_plot_to_bottom_stuff_interspace_height-bottom_stuff_height ;
            trace_axes_area_top_y = layout_top_yoffset - top_space_height - top_stuff_height - top_stuff_to_traces_plot_interspace_height ;
            trace_axes_area_y = trace_axes_area_top_y - trace_axes_area_height ;
            set(self.trace_axes,'OuterPosition',[trace_axes_area_x trace_axes_area_y trace_axes_area_width trace_axes_area_height]);
            tight_inset=get(self.trace_axes,'TightInset');
            trace_axes_x=trace_axes_area_x+tight_inset(1)+trace_axes_left_pad;
            trace_axes_y=trace_axes_area_y+tight_inset(2);
            trace_axes_width=trace_axes_area_width-tight_inset(1)-tight_inset(3)-trace_axes_left_pad-trace_axes_right_pad;
            trace_axes_height=trace_axes_area_height-tight_inset(2)-tight_inset(4);
            set(self.trace_axes,'Position',[trace_axes_x trace_axes_y trace_axes_width trace_axes_height]);
            
            % set the axes tick length to keep a constant number of pels
            trace_axes_size=max([trace_axes_width trace_axes_height]);
            tick_length_relative=tick_length/trace_axes_size;
            set(self.trace_axes,'TickLength',tick_length_relative*[1 1]);
            
            % the zoom buttons
            y_range_buttons_x=trace_axes_x+trace_axes_width+from_axes_to_yrange_buttons_width;
            zoom_out_button_x=y_range_buttons_x;
            zoom_out_button_y=trace_axes_y;  % want bottom-aligned with axes
            set(self.zoom_out_button, ...
                'Position',[zoom_out_button_x zoom_out_button_y ...
                            y_range_button_size y_range_button_size]);
            zoom_in_button_x=y_range_buttons_x;
            zoom_in_button_y=zoom_out_button_y+y_range_button_size+space_between_zoom_buttons;  % want just above other zoom button
            set(self.zoom_in_button, ...
                'Position',[zoom_in_button_x zoom_in_button_y ...
                            y_range_button_size y_range_button_size]);
            
            % the y limits button
            y_limits_button_x=y_range_buttons_x;
            y_limits_button_y=zoom_in_button_y+y_range_button_size+space_between_zoom_buttons;  % want above other zoom buttons
            set(self.ylimits_button, ...
                'Position',[y_limits_button_x y_limits_button_y ...
                            y_range_button_size y_range_button_size]);
            
            % the scroll buttons
            scroll_up_button_x=y_range_buttons_x;
            scroll_up_button_y=trace_axes_y+trace_axes_height-y_range_button_size;  % want top-aligned with axes
            set(self.scroll_up_button, ...
                'Position',[scroll_up_button_x scroll_up_button_y ...
                            y_range_button_size y_range_button_size]);
            scroll_down_button_x=y_range_buttons_x;
            scroll_down_button_y=scroll_up_button_y-y_range_button_size-space_between_scroll_buttons;  % want under scroll up button
            set(self.scroll_down_button, ...
                'Position',[scroll_down_button_x scroll_down_button_y ...
                            y_range_button_size y_range_button_size]);
                        
            %
            % The stuff at the bottom of the figure
            %
                         
            bottom_stuff_yoffset = layout_yoffset + bottom_space_height ;
            % The update rate and its label
            [update_rate_text_label_text_width,update_rate_text_label_text_height]=ws.get_extent(self.update_rate_text_label_text);
            update_rate_text_label_text_x=width_from_layout_left_to_update_rate_left;
            update_rate_text_label_text_y=bottom_stuff_yoffset;
            set(self.update_rate_text_label_text, ...
                'Position',[update_rate_text_label_text_x update_rate_text_label_text_y ...
                            update_rate_text_label_text_width update_rate_text_label_text_height]);
            update_rate_text_x=update_rate_text_label_text_x+update_rate_text_label_text_width+1;  % shim
            update_rate_text_y=bottom_stuff_yoffset;
            set(self.update_rate_text, ...
                'Position',[update_rate_text_x update_rate_text_y ...
                            update_rate_text_width update_rate_text_label_text_height]);
            [update_rate_units_text_width,update_rate_units_text_height]=ws.get_extent(self.update_rate_text_units_text);
            update_rate_units_text_x=update_rate_text_x+update_rate_text_width+1;  % shim
            update_rate_units_text_y=bottom_stuff_yoffset;
            set(self.update_rate_text_units_text, ...
                'Position',[update_rate_units_text_x update_rate_units_text_y ...
                            update_rate_units_text_width update_rate_units_text_height]);
            
            % The gains and associated labels
            for j=1:n_electrodes ,
                n_rows_below=n_electrodes-j;
                this_row_y = bottom_stuff_yoffset + n_rows_below*(text_height+inter_gain_space_height) ;
                
                gain_units_text_x=layout_width-width_from_layout_right_to_gain_right-gain_units_text_width;
                gain_units_text_y=this_row_y;
                set(self.gain_units_texts(j), ...
                    'Position',[gain_units_text_x gain_units_text_y ...
                                gain_units_text_width text_height]);
                gain_text_x=gain_units_text_x-gain_text_width-1;  % shim
                gain_text_y=this_row_y;
                set(self.gain_texts(j), ...
                    'Position',[gain_text_x gain_text_y ...
                                gain_text_width text_height]);
                gain_label_text_x=gain_text_x-gain_label_text_width-1;  % shim
                gain_label_text_y=this_row_y;
                set(self.gain_label_texts(j), ...
                    'Position',[gain_label_text_x gain_label_text_y ...
                                gain_label_text_width text_height]);
            end
            
                        
                        
            % Do some hacking to set the minimum figure size
            % Is seems to work OK to only set this after the figure is made
            % visible...
%             if ~self.IsMinimumSizeSet_ && isequal(get(self.FigureGH_,'Visible'),'on') ,
%                 %fprintf('Setting the minimum size...\n');
%                 originalWarningState=ws.warningState('MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
%                 warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
%                 fpj=get(handle(self.FigureGH_),'JavaFrame');
%                 warning(originalWarningState,'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');                
%                 if verLessThan('matlab', '8.4') ,
%                     jw=fpj.fHG1Client.getWindow();
%                 else
%                     jw=fpj.fHG2Client.getWindow();
%                 end
%                 if ~isempty(jw)
%                     jw.setMinimumSize(java.awt.Dimension(minimumFigureWidth, ...
%                                                          minimumFigureHeight));  % Note that this setting does not stick if you set Visible to 'off'
%                                                                                  % and then on again.  Which kinda sucks...
%                     self.IsMinimumSizeSet_=true;                                 
%                 end
%             end
        end

        function update_controls_in_existance_(self)
            %fprintf('updateControlsInExistance_!\n');
            % Makes sure the controls that exist match what controls _should_
            % exist, given the current model state.

            % Determine the number of electrodes right now
            ws_model = self.model_ ;
            if isempty(ws_model) || ~isvalid(ws_model) ,
                n_electrodes=0;
            else
                %testPulser = self.Model_.Ephys.TestPulser ;
                %nElectrodes=testPulser.NElectrodes;
                n_electrodes = ws_model.test_pulse_electrodes_count ;
            end
            %nElectrodes=4  % FOR DEBUGGING ONLY
            
            % Determine how many electrodes there were the last time the
            % controls in existance was updated
            n_electrodes_previously=length(self.gain_texts);
            
            n_new_electrodes=n_electrodes-n_electrodes_previously;
            if n_new_electrodes>0 ,
                for i=1:n_new_electrodes ,
                    j=n_electrodes_previously+i;  % index of new row in "table"
                    % Gain text
                    self.gain_label_texts(j)= ...
                        ws.uicontrol('Parent',self.figure_gh_, ...
                                  'Style','text', ...
                                  'HorizontalAlignment','right', ...
                                  'String','Gain: ');
                    self.gain_texts(j)= ...
                        ws.uicontrol('Parent',self.figure_gh_, ...
                                  'Style','text', ...
                                  'HorizontalAlignment','right', ...
                                  'String','100');
                    self.gain_units_texts(j)= ...
                        ws.uicontrol('Parent',self.figure_gh_, ...
                                  'Style','text', ...
                                  'HorizontalAlignment','left', ...
                                  'String','MOhm');
                end
            elseif n_new_electrodes<0 ,
                % Delete the excess HG objects
                ws.delete_if_valid_hg_handle(self.gain_label_texts(n_electrodes+1:end));
                ws.delete_if_valid_hg_handle(self.gain_texts(n_electrodes+1:end));
                ws.delete_if_valid_hg_handle(self.gain_units_texts(n_electrodes+1:end));

                % Delete the excess HG handles
                self.gain_label_texts(n_electrodes+1:end)=[];
                self.gain_texts(n_electrodes+1:end)=[];
                self.gain_units_texts(n_electrodes+1:end)=[];
            end            
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
                ws_model = self.model_ ;
                %testPulser = wsModel.Ephys.TestPulser;
                if strcmp(control_name, 'StartStopButton') ,
                    self.start_stop_button_actuated() ;
                    exception_maybe = {} ;
                else
                    % If the model is running, stop it (have to disable broadcast so we don't lose the new setting)
                    was_running_on_entry = ws_model.is_test_pulsing() ;
                    if was_running_on_entry ,
                        self.are_updates_enabled = false ;
                        ws_model.stop_test_pulsing() ;
                    end
                    
                    % Act on the control
                    exception_maybe = control_actuated@ws.controller(self, control_name, source, event, varargin{:}) ;
                    % if exceptionMaybe is nonempty, a dialog has already
                    % been shown to the user.

                    % Start running again, if needed, and if there was no
                    % exception.
                    if was_running_on_entry ,
                        self.are_updates_enabled = true ;
                        self.update_control_properties() ;
                        if isempty(exception_maybe) ,
                            ws_model.start_test_pulsing() ;
                        end
                    end
                end
            catch exception
                ws.raise_dialog_on_exception(exception) ;
                exception_maybe = { exception } ;
            end
        end  % function
        
        function start_stop_button_actuated(self, source, event, varargin)  %#ok<INUSD>
            self.model_.do('toggleIsTestPulsing');
        end
        
        function electrode_popup_menu_actuated(self, source, event, varargin)  %#ok<INUSD>
            ws_model = self.model_ ;
            electrode_names = ws_model.get_all_electrode_names() ;
            menu_item = ws.get_popup_menu_selection(self.electrode_popup_menu, ...
                                                electrode_names);
            if isempty(menu_item) ,  % indicates invalid selection
                self.update();                
            else
                electrode_name=menu_item;
                ws_model.do('setTestPulseElectrodeByName', electrode_name) ;
            end
        end
        
        function subtract_baseline_checkbox_actuated(self, source, event, varargin)  %#ok<INUSD>
            new_value = logical(get(self.subtract_baseline_checkbox,'Value')) ;
            self.model_.do('set', 'DoSubtractBaselineInTestPulseView', new_value) ;
        end
        
        function auto_ycheckbox_actuated(self, source, event, varargin)  %#ok<INUSD>
            new_value = logical(get(self.auto_ycheckbox,'Value')) ;
            self.model_.do('set', 'IsAutoYInTestPulseView', new_value) ;
        end
        
        function auto_yrepeating_checkbox_actuated(self, source, event, varargin)  %#ok<INUSD>
            new_value = logical(get(self.auto_yrepeating_checkbox,'Value')) ;
            self.model_.do('set', 'IsAutoYRepeatingInTestPulseView', new_value) ;
        end
        
        function amplitude_edit_actuated(self, source, event, varargin)  %#ok<INUSD>
            value = get(self.amplitude_edit,'String') ;
            %ephys = self.Model_.Ephys ;
            self.model_.do('setTestPulseElectrodeProperty', 'TestPulseAmplitude', value) ;
        end
        
        function duration_edit_actuated(self, source, event, varargin)  %#ok<INUSD>
            new_value_in_ms_as_string = get(self.duration_edit,'String') ;
            new_value = 1e-3 * str2double(new_value_in_ms_as_string) ;
            self.model_.do('set', 'TestPulseDuration', new_value) ;
        end
        
        function zoom_in_button_actuated(self, source, event, varargin)  %#ok<INUSD>
            self.model_.do('zoomInTestPulseView') ;
        end
        
        function zoom_out_button_actuated(self, source, event, varargin)  %#ok<INUSD>
            self.model_.do('zoomOutTestPulseView') ;
        end
        
        function ylimits_button_actuated(self, source, event, varargin)  %#ok<INUSD>
            self.my_ylim_dialog_controller = [] ;  % if not first call, this should cause the old controller to be garbage collectable
            
            ws_model = self.model_ ;
            
            set_model_ylimits_callback = @(new_ylimits)(ws_model.do('set', 'TestPulseYLimits', new_ylimits)) ;
%             function setModelYLimits(newYLimits)
%                 wsModel.do('set', 'TestPulseYLimits', newYLimits) ;
%             end
            
            self.my_ylim_dialog_controller = ...
                ws.ylim_dialog_controller([], ...
                                    get(self.figure_gh_,'Position'), ...
                                    ws_model.test_pulse_ylimits, ...
                                    ws_model.get_test_pulse_electrode_monitor_units(), ...
                                    set_model_ylimits_callback) ;
        end
        
        function scroll_up_button_actuated(self, source, event, varargin)  %#ok<INUSD>
            self.model_.do('scrollUpTestPulseView') ;
        end
        
        function scroll_down_button_actuated(self, source, event, varargin)  %#ok<INUSD>
            self.model_.do('scrollDownTestPulseView') ;
        end
        
        function vctoggle_actuated(self, source, event, varargin)  %#ok<INUSD>
            % update the other toggle
            set(self.cctoggle, 'Value', 0) ;  % Want this to be fast
            drawnow('update');

            % Change the setting
            %ephys = self.Model_.Ephys ;
            self.model_.do('setTestPulseElectrodeProperty', 'Mode', 'vc') ;
        end  % function
        
        function cctoggle_actuated(self, source, event, varargin)  %#ok<INUSD>
            % update the other toggle
            set(self.vctoggle, 'Value', 0) ;  % Want this to be fast
            drawnow('update');
            
            % Change the setting    
            %ephys = self.Model_.Ephys ;
            self.model_.do('setTestPulseElectrodeProperty', 'Mode', 'cc') ;
        end  % function
    end  % methods    

    methods (Access=protected)
        function close_requested_(self, source, event)  %#ok<INUSD>
            ws_model = self.model_ ;
            
            if isempty(ws_model) || ~isvalid(ws_model) ,
                should_stay_put = false ;
            else
                should_stay_put = ~ws_model.is_idle_sensu_lato() ;
            end
           
            if should_stay_put ,
                % Do nothing
            else
                %self.hide() ;
                ws_model.is_test_pulser_figure_visible = false ;
            end
        end        
    end  % protected methods block    
    
%     methods (Access=protected)
%         function updateVisibility_(self, ~, ~, ~, ~, event)
%             figureName = event.Args{1} ;
%             oldValue = event.Args{2} ;            
%             if isequal(figureName, 'TestPulser') ,
%                 newValue = self.Model_.IsTestPulserFigureVisible ;
%                 if oldValue && newValue , 
%                     % Do this to raise the figure
%                     set(self.FigureGH_, 'Visible', 'off') ;
%                     set(self.FigureGH_, 'Visible', 'on') ;
%                 else
%                     set(self.FigureGH_, 'Visible', ws.onIff(newValue)) ;
%                 end                    
%             end
%         end                
%     end
    
end  % classdef
