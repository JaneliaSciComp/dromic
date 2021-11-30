classdef (Abstract) controller < handle
    % This is a base class that wraps a handle graphics figure in a proper
    % MCOS object, but does not have a separate controller.  All methods
    % fired by UI actions are methods of the Controller
    % subclass.
    
    properties
        degree_of_enablement_ = 1
            % We want to be able to disable updates, and do it in such a way
            % that it can be called in nested loops, functions, etc and
            % behave in a reasonable way.  So this this an integer that can
            % take on negative values when it has been disabled multiple
            % times without being enabled.  But it is always <= 1.
        ncalls_to_update_while_disabled_ = []    
        ncalls_to_update_control_properties_while_disabled_ = []    
        ncalls_to_update_control_enablement_while_disabled_ = []    
        %DegreeOfReadiness_ = 1
    end
    
    properties
        figure_  % the figure graphics handle
        model_  % the model        
    end  % properties    
    
    methods
        function self = controller(model)
            background_color = ws.get_default_uicontrol_background_color() ;
            self.figure_ = figure('Units','Pixels', ...
                                  'Color',background_color, ...
                                  'Visible','off', ...
                                  'HandleVisibility','off', ...
                                  'DockControls','off', ...
                                  'NumberTitle','off', ...
                                  'CloseRequestFcn',@(source,event)(self.close_requested_(source,event))) ;
            % We don't set ResizeFcn here, b/c if we do it will get called before we've
            % created any of the controls, leading to problems.
            if exist('model','var') ,
                self.model_ = model ;
                if ~isempty(model) && isvalid(model) ,
                    % Register the controller with the model
                    self.model_.register_controller(self) ;
                end
            else
                self.model_ = [] ;  % need this to can create an empty array of ws.controllers
            end
        end
        
        function delete(self)
            self.delete_figure_();
            self.model_ = [] ;
        end
        
        function set_are_updates_enabled(self, new_value)
            % The AreUpdatesEnabled property looks from the outside like a simple boolean,
            % but it actually accumulates the number of times it's been set true vs set
            % false, and the getter only returns true if that difference is greater than
            % zero.  Also, the accumulator value (self.DegreeOfEnablement_) never goes above
            % one.
            if ~( islogical(new_value) && isscalar(new_value) ) ,
                return
            end
            net_value_before = (self.degree_of_enablement_ > 0) ;
            new_value_as_sign = 2 * double(new_value) - 1 ;  % [0,1] -> [-1,+1]
            new_degree_of_enablement_raw = self.degree_of_enablement_ + new_value_as_sign ;
            self.degree_of_enablement_ = ...
                    ws.fif(new_degree_of_enablement_raw <= 1, ...
                           new_degree_of_enablement_raw, ...
                           1);
            net_value_after = (self.degree_of_enablement_ > 0) ;
            if net_value_after && ~net_value_before ,
                % Updates have just been enabled
                if self.ncalls_to_update_while_disabled_ > 0 ,
                    self.update_implementation_() ;
                elseif self.ncalls_to_update_control_properties_while_disabled_ > 0 ,
                    self.update_control_properties_implementation_() ;
                elseif self.ncalls_to_update_control_enablement_while_disabled_ > 0 ,
                    self.update_control_enablement_implementation_() ;
                end
                self.ncalls_to_update_while_disabled_ = [] ;
                self.ncalls_to_update_control_properties_while_disabled_ = [] ;
                self.ncalls_to_update_control_enablement_while_disabled_ = [] ;
            elseif ~net_value_after && net_value_before ,
                % Updates have just been disabled
                self.ncalls_to_update_while_disabled_ = 0 ;
                self.ncalls_to_update_control_properties_while_disabled_ = 0 ;
                self.ncalls_to_update_control_enablement_while_disabled_ = 0 ;
            end            
        end  % function

        function value = are_updates_enabled(self)
            value = (self.degree_of_enablement_ > 0) ;
        end
        
        function update(self, varargin)
            % Sometimes outsiders (like the model) need to prompt an update.  Methods of the 
            % controller should generally call update_() directly.
            self.update_(varargin{:}) ;
        end
        
        function update_control_properties(self, varargin)
            % Sometimes outsiders need to prompt an update.  Methods of the 
            % controller should generally call update_control_properties_() directly.
            self.update_control_properties_(varargin{:}) ;
        end

        function update_control_enablement(self, varargin)
            % Sometimes outsiders need to prompt an update.  Methods of the 
            % Controller should generally call update_() directly.
            self.update_control_enablement_(varargin{:}) ;
        end
        
        function update_readiness(self, varargin)
            % Sometimes outsiders need to prompt an update.  Methods of the 
            % Controller should generally call update_() directly.
            self.update_readiness_(varargin{:}) ;
        end

%         function updateVisibility(self, varargin)
%             if length(varargin)>=5 ,
%                 event = varargin{5} ;                
%                 figureName = event.Args{1} ;
%                 %oldValue = event.Args{2} ;
%                 myFigureName = ws.figureNameFromControllerClassName(class(self)) ;
%                 isMatch = isequal(figureName, myFigureName) ;
%             else
%                 isMatch = true ;
%             end
%             if isMatch ,
%                 isVisiblePropertyName = ws.isFigureVisibleVariableNameFromControllerClassName(class(self)) ;
%                 newValue = self.Model_.(isVisiblePropertyName) ;
%                 set(self.Figure_, 'Visible', ws.onIff(newValue)) ;
%             end
%         end                

        function sync_figure_position_from_model(self, monitor_positions)
            model_property_name = ws.position_variable_name_from_controller_class_name(class(self));
            raw_position = self.model_.(model_property_name) ;  % Can be empty if opening an older protocol file
            if ~isempty(raw_position) ,
                set(self.figure_, 'Position', raw_position);
            end
            self.constrain_position_to_monitors(monitor_positions) ;
        end
    end  % public methods block
    
    methods (Access=protected)
%         function set(self, propName, value)
%             if strcmpi(propName,'Visible') && islogical(value) && isscalar(value) ,
%                 % special case to deal with Visible, which seems to
%                 % sometimes be a boolean
%                 if value,
%                     set(self.FigureGH_,'Visible','on');
%                 else
%                     set(self.FigureGH_,'Visible','off');
%                 end
%             else
%                 set(self.FigureGH_,propName,value);
%             end
%         end
%         
%         function value=get(self,propName)
%             value=get(self.FigureGH_,propName);
%         end
        
        function update_(self,varargin)
            % Called when the caller wants the figure to fully re-sync with the
            % model, from scratch.  This may cause the figure to be
            % resized, but this is always done in such a way that the
            % upper-righthand corner stays in the same place.
            if self.are_updates_enabled ,
                if isempty(self.model_) ,
                    self.update_implementation_();
                else                    
                    is_visible = self.model_.is_visible() ;
                    if is_visible ,
                        self.update_implementation_();
                    end
                end
            else
                self.ncalls_to_update_while_disabled_ = self.ncalls_to_update_while_disabled_ + 1 ;
            end
        end
        
        function update_control_properties_(self,varargin)
            % Called when caller wants the control properties (Properties besides enablement, that is.) to re-sync
            % with the model, but doesn't need to update the controls that are in existance, or change the positions of the controls.
            if self.are_updates_enabled ,
                if isempty(self.model_) ,
                    self.update_implementation_();
                else                    
                    is_visible = self.model_.is_visible() ;
                    if is_visible ,
                        self.update_control_properties_implementation_();
                    end
                end
            else
                self.ncalls_to_update_control_properties_while_disabled_ = self.ncalls_to_update_control_properties_while_disabled_ + 1 ;
            end
        end
        
        function update_control_enablement_(self,varargin)
            % Called when caller only needs to update the
            % enablement/disablment of the controls, given the model state.
            if self.are_updates_enabled ,
                if isempty(self.model_) ,
                    self.update_implementation_();
                else                    
                    is_visible = self.model_.is_visible() ;
                    if is_visible ,
                        self.update_control_enablement_implementation_() ;
                    end
                end
            else
                self.ncalls_to_update_control_enablement_while_disabled_ = self.ncalls_to_update_control_enablement_while_disabled_ + 1 ;
            end            
        end
        
        function update_readiness_(self, varargin)
            self.update_readiness_implementation_();
        end

        function update_visibility(self, varargin)
            new_value = self.model_.is_visible() ;
            set(self.figure_, 'Visible', ws.on_iff(new_value)) ;
        end                
        
        function do_with_model_(self, varargin)
            if ~isempty(self.model_) ,
                self.model_.do(varargin{:}) ;
            end
        end
        
        function new_position = position_upper_left_relative_to_other_upper_right_(self, reference_figure_position, offset)
            % Positions the upper left corner of the figure relative to the upper
            % *right* corner of the other figure.  offset is 2x1, with the 1st
            % element the number of pixels from the right side of the other figure,
            % the 2nd the number of pixels from the top of the other figure.

            %ws.positionFigureUpperLeftRelativeToFigureUpperRightBang(self.FigureGH_, other.FigureGH_, offset) ;
            
            % Get our position
            figure_gh = self.figure_ ;
            original_units=get(figure_gh,'units');
            set(figure_gh,'units','pixels');
            position=get(figure_gh,'position');
            set(figure_gh,'units',original_units);
            figure_size=position(3:4);

            % Get the reference figure position
            %originalUnits=get(referenceFigureGH,'units');
            %set(referenceFigureGH,'units','pixels');
            %referenceFigurePosition=get(referenceFigureGH,'position');
            %set(referenceFigureGH,'units',originalUnits);
            reference_figure_offset=reference_figure_position(1:2);
            reference_figure_size=reference_figure_position(3:4);

            % Calculate a new offset that will position us as wanted
            origin = reference_figure_offset + reference_figure_size ;
            figure_height=figure_size(2);
            new_offset = [ origin(1) + offset(1) ...
                          origin(2) + offset(2) - figure_height ] ;
            
            % Get the new position
            new_position = [new_offset figure_size] ;

            % Set figure position, using the new offset but the same size as before
            original_units=get(figure_gh,'units');
            set(figure_gh,'units','pixels');
            set(figure_gh,'position',new_position);
            set(figure_gh,'units',original_units);            
        end
        
        create_fixed_controls_(self)
            % In subclass, this should create all the controls that persist
            % throughout the lifetime of the figure.
        
        function update_controls_in_existance_(self)  %#ok<MANU>
            % In subclass, this should make sure the non-fixed controls in
            % existance are synced with the model state, deleting
            % inappropriate ones and creating appropriate ones as needed.
            
            % This default implementation does nothing, and is appropriate
            % only if all the controls are fixed.
        end
        
        update_control_properties_implementation_(self) 
            % In subclass, this should make sure the properties of the
            % controls (besides Position and Enable) are in-sync with the
            % model.  It can assume that all the controls that should
            % exist, do exist.
        
        update_control_enablement_implementation_(self) 
            % In subclass, this should make sure the Enable property of
            % each control is in-sync with the model.  It can assume that
            % all the controls that should exist, do exist.
        
        figure_size = layout_fixed_controls_(self) 
            % In subclass, this should make sure all the positions of the
            % fixed controls are appropriate given the current model state.
        
        function figure_size_modified = layout_nonfixed_controls_(self, figure_size)  %#ok<INUSL>
            % In subclass, this should make sure all the positions of the
            % non-fixed controls are appropriate given the current model state.
            % It can safely assume that all the non-fixed controls already
            % exist
            figure_size_modified = figure_size ;  % this is appropriate if there are no nonfixed controls
        end
        
        function layout_(self)
            % This method should make sure all the controls are sized and placed
            % appropraitely given the current model state.
            
            % This implementation should work in some simple cases, but can be overridden by
            % subclasses if needed.
            figure_size = self.layout_fixed_controls_() ;
            figure_size_modified = self.layout_nonfixed_controls_(figure_size) ;
            ws.resize_leaving_upper_left_fixed_bang(self.figure_, figure_size_modified) ;
        end
        
        function update_implementation_(self)
            % This method should make sure the figure is fully synched with the
            % model state after it is called.  This includes existance,
            % placement, sizing, enablement, and properties of each control, and
            % of the figure itself.

            % This implementation should work in most cases, but can be overridden by
            % subclasses if needed.
            self.update_controls_in_existance_() ;
            self.update_control_properties_implementation_() ;
            self.update_control_enablement_implementation_() ;
            self.layout_() ;
            self.update_visibility() ;
        end
        
        function update_readiness_implementation_(self)
            if isempty(self.model_) 
                pointer_value = 'arrow';
            else
                if isvalid(self.model_) ,
                    if self.model_.is_ready() ,
                        pointer_value = 'arrow';
                    else
                        pointer_value = 'watch';
                    end
                else
                    pointer_value = 'arrow';
                end
            end
            set(self.figure_,'pointer',pointer_value);
            %fprintf('drawnow(''update'')\n');
            drawnow('update');
        end
    end
    
    methods (Access=protected)
        function set_is_visible_(self, new_value)
            if ~isempty(self.figure_) && ishghandle(self.figure_) ,
                set(self.figure_, 'Visible', ws.on_iff(new_value));
            end
        end  % function
    end  % methods
    
    methods
        function show(self)
            self.set_is_visible_(true);
        end  % function       
    end  % methods    

    methods
        function hide(self)
            self.set_is_visible_(false);
        end  % function       
    end  % methods    
    
    methods
        function raise(self)
            self.hide() ;
            self.show() ;  
        end  % function       
    end  % public methods block
    
    methods (Access=protected)
        function close_requested_(self, source, event)  %#ok<INUSD>
            % Subclasses can override this if it's not to their liking
            self.delete_figure_();
        end  % function       
    end  % methods    
            
    methods (Access=protected)
        function delete_figure_(self)   
            % This causes the figure HG object to be deleted, with no ifs
            % ands or buts
            if ~isempty(self.figure_) && ishghandle(self.figure_) ,
                delete(self.figure_);
            end
            self.figure_ = [] ;
        end  % function       
    end  % methods    
        
    methods
        function exception_maybe = control_actuated(self, method_name_stem, source, event, varargin)  % public so that control actuation can be easily faked          
            % E.g. self.cancel_button_ would typically have the method name stem 'cancel_button_'.
            % The advantage of passing in the method_name_stem, rather than,
            % say always storing it in the tag of the graphics object, and
            % then reading it out of the source arg, is that doing it this
            % way makes it easier to fake control actuations by calling
            % this function with the desired method_name_stem and an empty
            % source and event.
            try
                if isempty(source) ,
                    % this means the control actuated was a 'faux' control
                    type = 'uicontrol' ;  % just pretend it's a regular uicontrol
                else
                    type=get(source,'Type');
                end                    
                if isequal(type,'uitable') ,
                    if isfield(event,'EditData') || isprop(event,'EditData') ,  % in older Matlabs, event is a struct, in later, an object
                        controller_method_name=[method_name_stem 'cell_edited'];
                    else
                        controller_method_name=[method_name_stem 'cell_selected'];
                    end
                else  %if isequal(type,'uicontrol') || isequal(type,'uimenu') ,
                    controller_method_name=[method_name_stem 'actuated'] ;
                end
                if ismethod(self,controller_method_name) ,
                    self.(controller_method_name)(source, event, varargin{:});                    
                else
                    putative_property_name = ws.putative_property_name_from_control(source) ;
                    putative_setter_name = ['set_' putative_property_name] ;
                    if ismethod(self.model_, putative_setter_name) ,
                        if strcmp(source.Style, 'edit') ,
                            value = source.String ;
                            self.model_.(putative_setter_name)(value) ;
                        end
                    else
                        % eventually put more cases here
                    end
                end
                exception_maybe = {} ;
            catch exception
                if isequal(exception.identifier,'ws:invalid_value') ,
                    % ignore completely, don't even pass on to output
                    exception_maybe = {} ;
                else
                    ws.raise_dialog_on_exception(exception) ;
                    exception_maybe = { exception } ;
                end
            end
        end  % function       
    end  % public methods block
    
    methods
        function constrain_position_to_monitors(self, monitor_positions)
            % For each monitor, calculate the translation needed to get the
            % figure onto it.

            % get the figure's OuterPosition
            %dbstack
            figure_outer_position = get(self.figure_, 'OuterPosition') ;
            figure_position = get(self.figure_, 'Position') ;
            %monitorPositions
            
            % define some local functions we'll need
            function translation = translation_to_fit2_d(offset, sz, screen_offset, screen_size)
                x_translation = translation_to_fit1_d(offset(1), sz(1), screen_offset(1), screen_size(1)) ;
                y_translation = translation_to_fit1_d(offset(2), sz(2), screen_offset(2), screen_size(2)) ;
                translation = [x_translation y_translation] ;
            end

            function translation = translation_to_fit1_d(offset, sz, screen_offset, screen_size)
                % Calculate a translation that will get a thing of size size at offset
                % offset onto a screen at offset screenOffset, of size screenSize.  All
                % args are *scalars*, as is the returned value
                top_offset = offset + sz ;  % or right offset, really
                screen_top = screen_offset+screen_size ;
                if offset < screen_offset ,
                    new_offset = screen_offset ;
                    translation =  new_offset - offset ;
                elseif top_offset > screen_top ,
                    new_offset = screen_top - sz ;
                    translation =  new_offset - offset ;
                else
                    translation = 0 ;
                end
            end
            
            % Get the offset, size of the figure
            figure_outer_offset = figure_outer_position(1:2) ;
            figure_outer_size = figure_outer_position(3:4) ;
            figure_offset = figure_position(1:2) ;
            figure_size = figure_position(3:4) ;
            
            % Compute the translation needed to get the figure onto each of
            % the monitors
            n_monitors = size(monitor_positions, 1) ;
            figure_translation_for_each_monitor = zeros(n_monitors,2) ;
            for i = 1:n_monitors ,
                monitor_position = monitor_positions(i,:) ;
                monitor_offset = monitor_position(1:2) ;
                monitor_size = monitor_position(3:4) ;
                figure_translation_for_this_monitor = translation_to_fit2_d(figure_outer_offset, figure_outer_size, monitor_offset, monitor_size) ;
                figure_translation_for_each_monitor(i,:) = figure_translation_for_this_monitor ;
            end

            % Calculate the magnitude of the translation for each monitor
            size_of_figure_translation_for_each_monitor = hypot(figure_translation_for_each_monitor(:,1), figure_translation_for_each_monitor(:,2)) ;
            
            % Pick the smallest translation that gets the figure onto
            % *some* monitor
            [~,index_of_smallest_figure_translation] = min(size_of_figure_translation_for_each_monitor) ;
            if isempty(index_of_smallest_figure_translation) ,
                figure_translation = [0 0] ;
            else
                figure_translation = figure_translation_for_each_monitor(index_of_smallest_figure_translation,:) ;
            end        

            % Compute the new position
            new_figure_position = [figure_offset+figure_translation figure_size] ;  
              % Apply the translation to the Position, not the
              % OuterPosition, as this seems to be more reliable.  Setting
              % the OuterPosition causes the layouts to get messed up
              % sometimes.  (Maybe setting the 'OuterSize' is the problem?)
            
            % Set it
            set(self.figure_, 'Position', new_figure_position) ;
        end  % function               
        
    end  % public methods block
    
%     methods (Sealed = true)
%         function setFigurePositionInModel(self)
%             % Add layout info for this window (just this one window) to
%             % a struct representing the layout of all windows in the app
%             % session.
%            
%             % Framework specific transformation.
%             fig = self.Figure_ ;
%             position = get(fig, 'Position') ;
%             modelPropertyName = ws.positionVariableNameFromControllerClassName(class(self));
%             self.Model_.(modelPropertyName) = position ;
%         end
%     end
            
    methods
        function set_are_updates_enabled_for_figure(self, new_value)
            self.are_updates_enabled = new_value ;
        end        
    end

    methods
        function set_nonidiomatic_properties_(self)
            % For each object property, if it's an HG object, set the tag
            % based on the property name
            mc=metaclass(self);
            property_names={mc.PropertyList.Name};
            for i=1:length(property_names) ,
                property_name=property_names{i};
                property_thing=self.(property_name);
                if ~isempty(property_thing) && all(ishghandle(property_thing), 'all') && ~(isscalar(property_thing) && isequal(get(property_thing,'Type'),'figure')) ,
                    % Sometimes propertyThing is a vector, but if so
                    % they're all the same kind of control, so use the
                    % first one to check what kind of things they are
                    example_property_thing=property_thing(1);
                    
                    % Set Tag
                    set(property_thing,'Tag',property_name);
                    
                    % Set Callback
                    if isequal(get(example_property_thing,'Type'),'uimenu') ,
                        if get(example_property_thing,'Parent')==self.figure_gh_ || get(example_property_thing,'Parent')==self.view_menu_ ,
                            % do nothing for top-level menus, or for menu items of the view menu
                        else
                            if isscalar(property_thing)
                                set(property_thing,'Callback',@(source,event)(self.control_actuated(property_name,source,event)));
                            else
                                % For arrays, pass the index to the
                                % callback
                                for j = 1:length(property_thing) ,
                                    set(property_thing(j),'Callback',@(source,event)(self.control_actuated(property_name,source,event,j)));
                                end                                    
                            end
                        end
                    elseif isequal(get(example_property_thing,'Type'),'uicontrol') && ~isequal(get(example_property_thing,'Style'),'text') ,
                        % set the callback for any uicontrol that is not a
                        % text
                        if isscalar(property_thing)
                            set(property_thing,'Callback',@(source,event)(self.control_actuated(property_name,source,event)));
                        else
                            % For arrays, pass the index to the
                            % callback
                            for j = 1:length(property_thing) ,
                                set(property_thing(j),'Callback',@(source,event)(self.control_actuated(property_name,source,event,j)));
                            end
                        end
                    end
                    
                    % Set Units
                    if isequal(get(example_property_thing,'Type'),'axes'),
                        set(property_thing,'Units','pixels');
                    end
                end
            end
        end  % function                

        function resize_(self)
            % This method is called when the figure is resized.
            
            % This implementation should work in some simple cases, but can be overridden by
            % subclasses if needed.
            self.layout_() ;         
        end        

    end

end  % classdef
