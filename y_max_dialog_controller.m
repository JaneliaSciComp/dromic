classdef y_max_dialog_controller < ws.controller
    properties
        % The various HG objects in the figure
        y_max_text_
        y_max_edit_
        y_max_units_text_
        ok_button_
        cancel_button_
        % Other things
        y_max_
        is_y_max_acceptable_
        y_units_
        callback_function_
    end
    
    methods
        function self = y_max_dialog_controller(model, parent_figure_position, y_max, y_units, callback_function)
            % Call the super-class consructor
            self = self@ws.controller(model) ;
            
            % Initialize some properties
            self.y_max_ = y_max ;
            self.y_units_ = y_units ;
            self.callback_function_ = callback_function ;
            self.is_y_max_acceptable_ = y_max_dialog_controller.is_y_max_acceptable(y_max) ;
            
            % Set the relevant properties of the figure itself
            set(self.figure_, 'Tag', 'y_max_dialog_controller', ...
                                'Units', 'pixels', ...
                                'Resize', 'off', ...
                                'Name', 'Y Limits...', ...
                                'Menubar', 'none', ...
                                'Toolbar', 'none', ...
                                'NumberTitle', 'off', ...
                                'WindowStyle', 'modal', ...
                                'Visible', 'off') ;
                          
            % Create all the "static" controls, set them up, but don't position them
            self.create_fixed_controls_() ;
            
            % Now that controls are created, set their callbacks based on the property
            % name
            self.set_nonidiomatic_properties_() ;

            % sync up self to 'model', which is basically self.YLimits_ and
            % self.YUnits_
            self.update_() ;
            self.layout_() ;
            
            % Do stuff specific to dialog boxes
            self.center_on_parent_position_(parent_figure_position) ;
            self.show() ;
            
            % Give the top edit keyboard focus
            uicontrol(self.y_max_edit_) ;
        end  % constructor
    end
    
    methods (Access=protected)
        function create_fixed_controls_(self)                          
            % Creates the controls that are guaranteed to persist
            % throughout the life of the window, but doesn't position them
            
            self.y_max_text_=...
                ws.uicontrol('Parent',self.figure_, ...
                             'Style','text', ...
                             'HorizontalAlignment','right', ...
                             'String','Y Max:');
            self.y_max_edit_=...
                ws.uiedit('Parent',self.figure_, ...
                          'HorizontalAlignment','right', ...
                          'KeypressFcn',@(source,event)(self.key_pressed_on_edit('y_max_edit_',source,event)));
            self.y_max_units_text_=...
                ws.uicontrol('Parent',self.figure_, ...
                          'Style','text', ...
                          'HorizontalAlignment','left', ...
                          'String','');
            
            self.ok_button_= ...
                ws.uicontrol('Parent',self.figure_, ...
                          'Style','pushbutton', ...
                          'String','OK', ...
                          'KeypressFcn',@(source,event)(self.key_pressed_on_button('ok_button_',source,event)));
            self.cancel_button_= ...
                ws.uicontrol('Parent',self.figure_, ...
                          'Style','pushbutton', ...
                          'String','Cancel', ...
                          'KeypressFcn',@(source,event)(self.key_pressed_on_button('cancel_button_',source,event)));
        end  % function

        function layout_(self)
            % Layout the figure elements
            n_rows=1;
            row_height=16;
            inter_row_height=8;
            top_space_height=20;
            left_space_width=40;
            width_between_label_and_edit=5;
            label_width=50;
            label_height=row_height;
            edit_xoffset=left_space_width+label_width+width_between_label_and_edit;
            edit_width=60;
            edit_height=20;            
            edit_tweak_height= 0;
            width_between_edit_and_units=3;
            units_xoffset=edit_xoffset+edit_width+width_between_edit_and_units;
            units_width=30;
            units_height=row_height;
            right_space_width=40;           
            right_button_space_width = 10 ;
            
            n_bottom_buttons=2;
            height_between_edit_rows_and_bottom_button_row=20;
            bottom_button_width=50;
            bottom_button_height=20;
            inter_bottom_button_space_width=6;
            bottom_space_height=10;
            
            figure_width=left_space_width+label_width+width_between_edit_and_units+edit_width+width_between_edit_and_units+units_width+right_space_width;
            figure_height=top_space_height+n_rows*row_height+(n_rows-1)*inter_row_height+height_between_edit_rows_and_bottom_button_row+bottom_button_height+bottom_space_height;
            
            % Position the figure, keeping upper left corner fixed
            current_position=get(self.figure_,'Position');
            current_offset=current_position(1:2);
            current_size=current_position(3:4);
            current_upper_y=current_offset(2)+current_size(2);
            figure_position=[current_offset(1) current_upper_y-figure_height figure_width figure_height];
            set(self.figure_,'Position',figure_position);

            % Layout the edit rows
            y_offset_of_top_row=bottom_space_height+bottom_button_height+height_between_edit_rows_and_bottom_button_row+(n_rows-1)*(row_height+inter_row_height);                        
            y_offset_of_this_row=y_offset_of_top_row;
            set(self.y_max_text_     ,'Position',[left_space_width y_offset_of_this_row label_width label_height]);
            set(self.y_max_edit_     ,'Position',[edit_xoffset y_offset_of_this_row+edit_tweak_height edit_width edit_height]);
            set(self.y_max_units_text_,'Position',[units_xoffset y_offset_of_this_row units_width units_height]);
            
%             y_offset_of_this_row=y_offset_of_this_row-(row_height+inter_row_height);            
%             set(self.y_min_text_     ,'Position',[left_space_width y_offset_of_this_row label_width label_height]);
%             set(self.y_min_edit_     ,'Position',[edit_xoffset y_offset_of_this_row+edit_tweak_height edit_width edit_height]);
%             set(self.y_min_units_text_,'Position',[units_xoffset y_offset_of_this_row units_width units_height]);

            % Layout the bottom buttons
            width_of_all_bottom_buttons=n_bottom_buttons*bottom_button_width+(n_bottom_buttons-1)*inter_bottom_button_space_width;
            %xOffsetOfLeftButton=(figureWidth-widthOfAllBottomButtons)/2;
            x_offset_of_left_button=figure_width-right_button_space_width-width_of_all_bottom_buttons;
            
            x_offset_of_this_button=x_offset_of_left_button;
            set(self.ok_button_,'Position',[x_offset_of_this_button bottom_space_height bottom_button_width bottom_button_height]);
            x_offset_of_this_button=x_offset_of_this_button+(bottom_button_width+inter_bottom_button_space_width);
            set(self.cancel_button_,'Position',[x_offset_of_this_button bottom_space_height bottom_button_width bottom_button_height]);
        end  % function
        
        function center_on_parent_position_(self,parent_position)
            original_position=get(self.figure_,'Position');
            %originalOffset=originalPosition(1:2);
            size=original_position(3:4);
            parent_offset=parent_position(1:2);
            parent_size=parent_position(3:4);
            new_offset=parent_offset+(parent_size-size)/2;
            new_position=[new_offset size];
            set(self.figure_,'Position',new_position);
        end
    end % protected methods block
    
    methods        
%         function controlActuated(self, methodNameStem, source, event, varargin)
%             controlActuated@ws.Controller(self, methodNameStem, source, event, varargin{:}) ;
%         end  % function
       
        function key_pressed_on_edit(self, method_name_stem, source, event) %#ok<INUSL>
            %self.setYLimitsGivenEditContents_() ;
            %self.syncAreYLimitsAcceptableGivenYLimits_() ;
            %self.updateControlEnablement_() ;
            if isequal(event.Key,'return') ,
                uicontrol(source) ;  % Have to do this so the edit's String property reflects the value the user is currently seeing
                self.control_actuated('ok_button_', source, event);
            end            
        end

        function key_pressed_on_button(self, method_name_stem, source, event)
            % This makes it so the user can press "Enter" when a control
            % has keyboard focus to press the OK button.  Unless the
            % control is the Cancel Button, in which case it's like pressig
            % the Cancel button.
            %fprintf('keyPressedOnControl()\n') ;
            %key = event.Key
            if isequal(event.Key,'return') ,
                self.control_actuated(method_name_stem, source, event);
            end
        end  % function
    end  % public methods block
    
    methods (Static)
        function result = is_y_max_acceptable(y_max)
            result = isfinite(y_max) && (y_max>0) ;
        end
    end 

    methods (Access=protected)
        function sync_is_y_max_acceptable_given_y_max_(self)
            self.is_y_max_acceptable_ = y_max_dialog_controller.is_y_max_acceptable(self.y_max_) ;
        end
        
        function set_y_max_given_edit_contents_(self)
            y_max_as_string=get(self.y_max_edit_,'String') ;
            y_max=str2double(y_max_as_string);
            self.y_max_ = y_max ;
        end
        
%         function sync_ok_button_enablement_from_edit_contents_(self)
%             self.set_y_max_given_edit_contents_() ;
%             self.sync_is_y_max_acceptable_given_y_max_() ;
%             self.update_control_enablement_() ;
%         end
    end 
        
    methods
        function ok_button_actuated(self,source,event) 
            self.set_y_max_given_edit_contents_() ;
            self.sync_is_y_max_acceptable_given_y_max_() ;
            %self.updateControlEnablement_() ;
            if self.is_y_max_acceptable_ ,
                %fprintf('YLimits are acceptable\n') ;
                %yLimits = self.YLimits_
                y_max = self.y_max_ ;
                callback_function = self.callback_function_ ;
                feval(callback_function, y_max) ;
                self.close_requested_(source, event) ;
            else
                %fprintf('YLimits are *not* acceptable\n') ;
                self.update_control_enablement_() ;
            end
        end  % function
        
        function cancel_button_actuated(self,source,event)
            self.close_requested_(source, event) ;
        end
        
        function y_max_edit_actuated(self, source, event)  %#ok<INUSD>
            self.set_y_max_given_edit_contents_() ;
            self.sync_is_y_max_acceptable_given_y_max_() ;
            self.update_control_enablement_() ;
        end

    end  % methods

    methods (Access=protected)
        function self = update_implementation_(self,varargin)
            % Syncs self with model, making no prior assumptions about what
            % might have changed or not changed in the model.
            self.update_control_properties_implementation_();
            self.update_control_enablement_implementation_();
            %self.layout();
        end
        
        function self = update_control_properties_implementation_(self, varargin)
            % Update the relevant controls
            y_max = self.y_max_ ;
            units_string = self.y_units_ ;
            set(self.y_max_edit_     ,'String',sprintf('%0.3g',y_max));
            set(self.y_max_units_text_,'String',units_string);
        end
        
        function self = update_control_enablement_implementation_(self, varargin)
            % Update the relevant controls
            set(self.ok_button_,'Enable',ws.on_iff(self.is_y_max_acceptable_));
        end        
    end
end  % classdef
