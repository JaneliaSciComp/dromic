classdef (Abstract) model < handle           
    properties
        allow_timer_callback_ = true
        is_visible_ = false
        degree_of_readiness_ = 1        
        unmatched_log_warning_start_count_ = 0  % technically, the number of starts without a corresponding stop
        warning_count_ = 0
        warning_log_ = MException.empty(0,1)   % N.B.: a col vector        
        controller_ = []        
    end
    
    methods
        function value = is_ready(self)   % true <=> figures are showing the normal (as opposed to waiting) cursor
            value = (self.degree_of_readiness_>0) ;
        end                       
        
        function change_readiness_(self, delta)
            if ~( isnumeric(delta) && isscalar(delta) && (delta==-1 || delta==0 || delta==+1 || (isinf(delta) && delta>0) ) ) ,
                return
            end
                    
            new_degree_of_readiness_raw = self.degree_of_readiness_ + delta ;
            self.set_readiness_(new_degree_of_readiness_raw) ;
        end  % function        
        
        function reset_readiness_(self)
            % Used during error handling to reset model back to the ready
            % state.  (NB: But only if called via the do() method!)
            self.set_readiness_(1) ;
        end  % function        
        
        function set_readiness_(self, new_degree_of_readiness_raw)
            %fprintf('Inside setReadiness_(%d)\n', newDegreeOfReadinessRaw) ;
            %dbstack
            is_ready_before = self.is_ready ;
            
            self.degree_of_readiness_ = ...
                ws.fif(new_degree_of_readiness_raw<=1, ...
                       new_degree_of_readiness_raw, ...
                       1) ;
                        
            is_ready_after = self.is_ready ;
            
            if is_ready_after ~= is_ready_before ,
                %fprintf('Inside setReadiness_(%d), about to broadcast UpdateReadiness\n', newDegreeOfReadinessRaw) ;
                self.update_readiness() ;
            end            
        end  % function    

        function result = is_visible(self)
            result = self.is_visible_ ;
        end

        function set_is_visible(self, new_value)
            self.is_visible_ = new_value ;
            self.update_() ;
        end

        function register_controller(self, controller)
            self.controller_ = controller ;
        end

        function unregister_controller(self)
            self.controller_ = [] ;
        end

        function update_(self)
            if ~isempty(self.controller_) && isvalid(self.controller_) 
                self.controller_.update() ;
            end
        end        

        function update_readiness_(self)
            if ~isempty(self.controller_) && isvalid(self.controller_) 
                self.controller_.update_readiness() ;
            end
        end        

        function update_control_properties_(self)
            if ~isempty(self.controller_) && isvalid(self.controller_) 
                self.controller_.update_control_properties() ;
            end
        end        
        
        function do(self, method_name, varargin)
            % This is intended to be the usual way of calling model
            % methods.  For instance, a call to a ws.controller
            % control_actuated() method should generally result in a single
            % call to .do() on it's model object, and zero direct calls to
            % model methods.  This gives us a
            % good way to implement functionality that is common to all
            % model method calls, when they are called as the main "thing"
            % the user wanted to accomplish.  For instance, we start
            % warning logging near the beginning of the .do() method, and turn
            % it off near the end.  That way we don't have to do it for
            % each model method, and we only do it once per user command.            
            self.allow_timer_callback_ = false ;
            self.start_logging_warnings() ;
            try
                self.(method_name)(varargin{:}) ;
            catch exception
                % If there's a real exception, the warnings no longer
                % matter.  But we want to restore the model to the
                % non-logging state.
                self.stop_logging_warnings() ;  % discard the result, which might contain warnings
                self.reset_readiness_() ;  % Need to do this to make sure we don't stay unready for the rest of the model lifetime
                self.allow_timer_callback_ = true ;
                rethrow(exception) ;
            end
            warning_exception_maybe = self.stop_logging_warnings() ;
            if ~isempty(warning_exception_maybe) ,
                warning_exception = warning_exception_maybe{1} ;
                self.allow_timer_callback_ = true ;
                throw(warning_exception) ;
            end
            self.allow_timer_callback_ = true ;
        end

        function log_warning(self, identifier, message, cause_or_empty)
            % This is public b/c subsystem need to call it, but it should
            % only be called by subsystems.
            if nargin<4 ,
                cause_or_empty = [] ;
            end
            warning_exception = MException(identifier, message) ;
            if ~isempty(cause_or_empty) ,
                warning_exception = warning_exception.add_cause(cause_or_empty) ;
            end
            if self.unmatched_log_warning_start_count_>0 ,
                self.warning_count_ = self.warning_count_ + 1 ;
                if self.warning_count_ < 10 ,
                    self.warning_log_ = vertcat(self.warning_log_, ...
                                               warning_exception) ;            
                else
                    % Don't want to log a bazillion warnings, so do nothing
                end
            else
                % Just issue a normal warning
                warning(identifier, message) ;
                if ~isempty(cause_or_empty) ,
                    fprintf('Cause of warning:\n');
                    display(cause_or_empty.get_report());
                end
            end
        end  % method

        function start_logging_warnings(self)
            % fprintf('\n\n\n\n');
            % dbstack
            % fprintf('At entry to startLogginWarnings: self.UnmatchedLogWarningStartCount_ = %d\n', self.UnmatchedLogWarningStartCount_) ;
            self.unmatched_log_warning_start_count_ = self.unmatched_log_warning_start_count_ + 1 ;
            if self.unmatched_log_warning_start_count_ <= 1 ,
                % Unless things have gotten weird,
                % self.UnmatchedLogWarningStartCount_ should *equal* one
                % here.
                % This means this is the first unmatched start (or the
                % first one after a matched set of starts and stops), so we
                % reset the warning count and the warning log.
                self.unmatched_log_warning_start_count_ = 1 ;  % If things have gotten weird, fix them.
                self.warning_count_ = 0 ;
                self.warning_log_ = MException.empty(0, 1) ;
            end
        end        
        
        function exception_maybe = stop_logging_warnings(self)
            % fprintf('\n\n\n\n');
            % dbstack
            % fprintf('At entry to stopLogginWarnings: self.UnmatchedLogWarningStartCount_ = %d\n', self.UnmatchedLogWarningStartCount_) ;
            % Get the warnings, if any
            self.unmatched_log_warning_start_count_ = self.unmatched_log_warning_start_count_ - 1 ;
            if self.unmatched_log_warning_start_count_ <= 0 , 
                % Technically, this should only happen when
                % self.UnmatchedLogWarningStartCount_==0, unless there was a
                % programming error.  But in any case, we
                % produce a summary of the warnings, if any, and set the
                % (unmatched) start counter to zero, even though it should
                % be zero already.
                self.unmatched_log_warning_start_count_ = 0 ;
                logged_warnings = self.warning_log_ ;
                % Process them, summarizing them in a maybe (a list of length
                % zero or one) of exceptions.  The individual warnings are
                % stored in the causes of the exception, if it exists.
                n_warnings = self.warning_count_ ;
                if n_warnings==0 ,
                    exception_maybe = {} ;                
                else
                    if n_warnings==1 ,
                        exception_message = logged_warnings(1).message ;
                    else
                        exception_message = sprintf('%d warnings occurred.\nThe first one was: %s', ...
                                                   n_warnings, ...
                                                   logged_warnings(1).message) ;
                    end                                           
                    exception = MException('ws:warningsOccurred', exception_message) ;
                    for i = 1:length(logged_warnings) ,
                        exception = exception.add_cause(logged_warnings(i)) ;
                    end
                    exception_maybe = {exception} ;
                end
                % Clear the warning log before returning
                self.warning_count_ = 0 ;
                self.warning_log_ = MException.empty(0, 1) ;
            else
                % self.UnmatchedLogWarningStartCount_ > 1, so decrement the number of
                % unmatched starts, but don't do much else.
                exception_maybe = {} ;
            end
        end  % method
    end  % methods block        
end  % classdef
