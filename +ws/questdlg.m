function button_name=questdlg(question,title,btn1,btn2,btn3,default)
    % I copied and edited this from Matlab 2015a, then added the bit to set
    % the colors properly, and added as locals all the functions this
    % needs.
    
%QUESTDLG Question dialog box.
%  ButtonName = QUESTDLG(Question) creates a modal dialog box that
%  automatically wraps the cell array or string (vector or matrix)
%  Question to fit an appropriately sized window.  The name of the
%  button that is pressed is returned in ButtonName.  The Title of
%  the figure may be specified by adding a second string argument:
%
%    ButtonName = questdlg(Question, Title)
%
%  Question will be interpreted as a normal string.
%
%  QUESTDLG uses UIWAIT to suspend execution until the user responds.
%
%  The default set of buttons names for QUESTDLG are 'Yes','No' and 'Cancel'.
%  The default answer for the above calling syntax is 'Yes'.
%  This can be changed by adding a third argument which specifies the
%  default Button:
%
%    ButtonName = questdlg(Question, Title, 'No')
%
%  Up to 3 custom button names may be specified by entering
%  the button string name(s) as additional arguments to the function
%  call.  If custom button names are entered, the default button
%  must be specified by adding an extra argument, DEFAULT, and
%  setting DEFAULT to the same string name as the button you want
%  to use as the default button:
%
%    ButtonName = questdlg(Question, Title, Btn1, Btn2, DEFAULT);
%
%  where DEFAULT is set to Btn1.  This makes Btn1 the default answer.
%  If the DEFAULT string does not match any of the button string names,
%  a warning message is displayed.
%
%  To use TeX interpretation for the Question string, a data
%  structure must be used for the last argument, i.e.
%
%    ButtonName = questdlg(Question, Title, Btn1, Btn2, OPTIONS);
%
%  The OPTIONS structure must include the fields Default and Interpreter.
%  Interpreter may be 'none' or 'tex' and Default is the default button
%  name to be used.
%
%  If the dialog is closed without a valid selection, the return value
%  is empty.
%
%  Example:
%
%  ButtonName = questdlg('What is your favorite color?', ...
%                        'Color Question', ...
%                        'Red', 'Green', 'Blue', 'Green');
%  switch ButtonName,
%    case 'Red',
%     disp('Your favorite color is Red');
%    case 'Blue',
%     disp('Your favorite color is Blue.')
%     case 'Green',
%      disp('Your favorite color is Green.');
%  end % switch
%
%  See also DIALOG, ERRORDLG, HELPDLG, INPUTDLG, LISTDLG,
%    MSGBOX, WARNDLG, FIGURE, TEXTWRAP, UIWAIT, UIRESUME.


%  Copyright 1984-2014 The MathWorks, Inc.



if nargin<1
    error(message('MATLAB:questdlg:TooFewArguments'));
end

interpreter='none';
question = dialog_cellstr_helper(question);
needs_lookup = false;

%%%%%%%%%%%%%%%%%%%%%
%%% General Info. %%%
%%%%%%%%%%%%%%%%%%%%%
black      =[0       0        0      ]/255;
% LightGray  =[192     192      192    ]/255;
% LightGray2 =[160     160      164    ]/255;
% MediumGray =[128     128      128    ]/255;
% White      =[255     255      255    ]/255;

%%%%%%%%%%%%%%%%%%%%
%%% Nargin Check %%%
%%%%%%%%%%%%%%%%%%%%
if nargout > 1
    error(message('MATLAB:questdlg:WrongNumberOutputs'));
end
if nargin == 1
    title = ' ';
end
if nargin <= 2,
    default = 'Yes'; 
    needs_lookup = true;
end
if nargin == 3,
    default = btn1;
end
if nargin <= 3,
    btn1 = 'Yes'; 
    btn2 = 'No';
    btn3 = 'Cancel';
    num_buttons = 3;
    needs_lookup = true;
end
if nargin == 4,
    default=btn2;
    btn2 = [];
    btn3 = [];
    num_buttons = 1;
end
if nargin == 5
    default = btn3;
    btn3 = [];
    num_buttons = 2;
end
if nargin == 6
    num_buttons = 3;
end
if nargin > 6
    error(message('MATLAB:questdlg:TooManyInputs'));
    num_buttons = 3;
end

if isstruct(default),
    interpreter = default.interpreter;
    default = default.default;
end


%%%%%%%%%%%%%%%%%%%%%%%
%%% Create QuestFig %%%
%%%%%%%%%%%%%%%%%%%%%%%
fig_pos    = get(0,'DefaultFigurePosition');
fig_pos(3) = 267;
fig_pos(4) =  70;
fig_pos    = getnicedialoglocation(fig_pos, get(0,'DefaultFigureUnits'));

quest_fig=dialog(                                    ...
    'Visible'         ,'off'                      , ...
    'Name'            ,title                      , ...
    'Pointer'         ,'arrow'                    , ...
    'Position'        ,fig_pos                     , ...
    'KeyPressFcn'     ,@do_figure_key_press          , ...
    'IntegerHandle'   ,'off'                      , ...
    'WindowStyle'     ,'normal'                   , ...
    'HandleVisibility','callback'                 , ...
    'CloseRequestFcn' ,@do_delete                  , ...
    'Tag'             ,title                        ...
    );

%%%%%%%%%%%%%%%%%%%%%
%%% Set Positions %%%
%%%%%%%%%%%%%%%%%%%%%
def_offset  =10;

icon_width  =54;
icon_height =54;
icon_xoffset=def_offset;
icon_yoffset=fig_pos(4)-def_offset-icon_height;  %#ok
icon_cmap=[black;get(quest_fig,'Color')];  %#ok

def_btn_width =56;
btn_height   =22;

btn_yoffset=def_offset;

btn_width=def_btn_width;

ext_control=uicontrol(quest_fig   , ...
    'Style'    ,'pushbutton', ...
    'String'   ,' '          ...
    );

btn_margin=1.4;
set(ext_control,'String',btn1);
btn_extent=get(ext_control,'Extent');
btn_width=max(btn_width,btn_extent(3)+8);
if num_buttons > 1
    set(ext_control,'String',btn2);
    btn_extent=get(ext_control,'Extent');
    btn_width=max(btn_width,btn_extent(3)+8);
    if num_buttons > 2
        set(ext_control,'String',btn3);
        btn_extent=get(ext_control,'Extent');
        btn_width=max(btn_width,btn_extent(3)*btn_margin);
    end
end
btn_height = max(btn_height,btn_extent(4)*btn_margin);

delete(ext_control);

msg_txt_xoffset=icon_xoffset+icon_width;

fig_pos(3)=max(fig_pos(3),msg_txt_xoffset+num_buttons*(btn_width+2*def_offset));
set(quest_fig,'Position',fig_pos);

btn_xoffset=zeros(num_buttons,1);

if num_buttons==1,
    btn_xoffset=(fig_pos(3)-btn_width)/2;
elseif num_buttons==2,
    btn_xoffset=[msg_txt_xoffset
        fig_pos(3)-def_offset-btn_width];
elseif num_buttons==3,
    btn_xoffset=[msg_txt_xoffset
        0
        fig_pos(3)-def_offset-btn_width];
    btn_xoffset(2)=(btn_xoffset(1)+btn_xoffset(3))/2;
end

msg_txt_yoffset=def_offset+btn_yoffset+btn_height;
% Calculate current msg text width and height. If negative,
% clamp it to 1 since its going to be recalculated/corrected later
% based on the actual msg string
msg_txt_width=max(1, fig_pos(3)-def_offset-msg_txt_xoffset-icon_width);
msg_txt_height=max(1, fig_pos(4)-def_offset-msg_txt_yoffset);

msg_txt_fore_clr=black;
msg_txt_back_clr=get(quest_fig,'Color');

cbstring='uiresume(gcbf)';
default_valid = false;
default_was_pressed = false;
btn_handle = cell(num_buttons, 1);
default_button = 0;

% Check to see if the Default string passed does match one of the
% strings on the buttons in the dialog. If not, throw a warning.
for i = 1:num_buttons
    switch i
        case 1
            button_string=btn1;
            button_tag='Btn1';
            if strcmp(button_string, default)
                default_valid = true;
                default_button = 1;
            end
            
        case 2
            button_string=btn2;
            button_tag='Btn2';
            if strcmp(button_string, default)
                default_valid = true;
                default_button = 2;
            end
        case 3
            button_string=btn3;
            button_tag='Btn3';
            if strcmp(button_string, default)
                default_valid = true;
                default_button = 3;
            end
    end
    
    if (needs_lookup)
        button_display_string = get_string(message(['MATLAB:uistring:popupdialogs:' button_string]));
    else
        button_display_string = button_string;
    end
    
    btn_handle{i}=uicontrol(quest_fig            , ...
        'Style'              ,'pushbutton', ...
        'Position'           ,[ btn_xoffset(1) btn_yoffset btn_width btn_height ]           , ...
        'KeyPressFcn'        ,@do_control_key_press , ...
        'Callback'           ,cbstring    , ...
        'String'             ,button_display_string, ...
        'HorizontalAlignment','center'    , ...
        'Tag'                ,button_tag     ...
        );
    
    setappdata(btn_handle{i},'QuestDlgReturnName',button_string);   
end

if ~default_valid
    warnstate = warning('backtrace','off');
    warning(message('MATLAB:questdlg:StringMismatch'));
    warning(warnstate);
end

msg_handle=uicontrol(quest_fig            , ...
    'Style'              ,'text'         , ...
    'Position'           ,[msg_txt_xoffset msg_txt_yoffset 0.95*msg_txt_width msg_txt_height ]              , ...
    'String'             ,{' '}          , ...
    'Tag'                ,'Question'     , ...
    'HorizontalAlignment','left'         , ...
    'FontWeight'         ,'bold'         , ...
    'BackgroundColor'    ,msg_txt_back_clr  , ...
    'ForegroundColor'    ,msg_txt_fore_clr    ...
    );

[wrap_string,new_msg_txt_pos]=textwrap(msg_handle,question,75);

% NumLines=size(WrapString,1);

axes_handle=axes('Parent',quest_fig,'Position',[0 0 1 1],'Visible','off');

texthandle=text( ...
    'Parent'              ,axes_handle                      , ...
    'Units'               ,'pixels'                        , ...
    'Color'               ,get(btn_handle{1},'ForegroundColor')   , ...
    'HorizontalAlignment' ,'left'                          , ...
    'FontName'            ,get(btn_handle{1},'FontName')    , ...
    'FontSize'            ,get(btn_handle{1},'FontSize')    , ...
    'VerticalAlignment'   ,'bottom'                        , ...
    'String'              ,wrap_string                      , ...
    'Interpreter'         ,interpreter                     , ...
    'Tag'                 ,'Question'                        ...
    );

text_extent = get(texthandle, 'Extent');

% (g357851)textExtent and extent from uicontrol are not the same. For window, extent from uicontrol is larger
%than textExtent. But on Mac, it is reverse. Pick the max value.
msg_txt_width=max([msg_txt_width new_msg_txt_pos(3)+2 text_extent(3)]);
msg_txt_height=max([msg_txt_height new_msg_txt_pos(4)+2 text_extent(4)]);

msg_txt_xoffset=icon_xoffset+icon_width+def_offset;
fig_pos(3)=max(num_buttons*(btn_width+def_offset)+def_offset, ...
    msg_txt_xoffset+msg_txt_width+def_offset);


% Center Vertically around icon
if icon_height>msg_txt_height,
    icon_yoffset=btn_yoffset+btn_height+def_offset;
    msg_txt_yoffset=icon_yoffset+(icon_height-msg_txt_height)/2;
    fig_pos(4)=icon_yoffset+icon_height+def_offset;
    % center around text
else
    msg_txt_yoffset=btn_yoffset+btn_height+def_offset;
    icon_yoffset=msg_txt_yoffset+(msg_txt_height-icon_height)/2;
    fig_pos(4)=msg_txt_yoffset+msg_txt_height+def_offset;
end

if num_buttons==1,
    btn_xoffset=(fig_pos(3)-btn_width)/2;
elseif num_buttons==2,
    btn_xoffset=[(fig_pos(3)-def_offset)/2-btn_width
        (fig_pos(3)+def_offset)/2
        ];
    
elseif num_buttons==3,
    btn_xoffset(2)=(fig_pos(3)-btn_width)/2;
    btn_xoffset=[btn_xoffset(2)-def_offset-btn_width
        btn_xoffset(2)
        btn_xoffset(2)+btn_width+def_offset
        ];
end

set(quest_fig ,'Position',getnicedialoglocation(fig_pos, get(quest_fig,'Units')));
assert(iscell(btn_handle));
btn_pos=cellfun(@(bh)get(bh,'Position'), btn_handle, 'UniformOutput', false);
btn_pos=cat(1,btn_pos{:});
btn_pos(:,1)=btn_xoffset;
btn_pos=num2cell(btn_pos,2);

assert(iscell(btn_pos));
cellfun(@(bh,pos)set(bh, 'Position', pos), btn_handle, btn_pos, 'UniformOutput', false);

if default_valid
    setdefaultbutton(quest_fig, btn_handle{default_button});
end

delete(msg_handle);


set(texthandle, 'Position',[msg_txt_xoffset msg_txt_yoffset 0]);


icon_axes=axes(                                      ...
    'Parent'      ,quest_fig              , ...
    'Units'       ,'Pixels'              , ...
    'Position'    ,[icon_xoffset icon_yoffset icon_width icon_height], ...
    'NextPlot'    ,'replace'             , ...
    'Tag'         ,'IconAxes'              ...
    );

set(quest_fig ,'NextPlot','add');

load dialogicons.mat quest_icon_data quest_icon_map;
icon_data=quest_icon_data;
quest_icon_map(256,:)=get(quest_fig,'Color');
icon_cmap=quest_icon_map;

img=image('CData',icon_data,'Parent',icon_axes);
set(quest_fig, 'Colormap', icon_cmap);
set(icon_axes, ...
    'Visible','off'           , ...
    'YDir'   ,'reverse'       , ...
    'XLim'   ,get(img,'XData'), ...
    'YLim'   ,get(img,'YData')  ...
    );

% make sure we are on screen
movegui(quest_fig)

%%%% ALT's code
persistent default_uicontrol_background_color

if isempty(default_uicontrol_background_color) ,
    default_uicontrol_background_color = ws.get_default_uicontrol_background_color() ;
end

% A lot of BS to make sure the background color works right for the
% Windows 7 classic theme
ws.fix_dialog_background_color_bang(quest_fig, default_uicontrol_background_color) ;
%%%% end of ALT's code


set(quest_fig ,'WindowStyle','modal','Visible','on');
drawnow;

if default_button ~= 0
    uicontrol(btn_handle{default_button});
end

if ishghandle(quest_fig)
    % Go into uiwait if the figure handle is still valid.
    % This is mostly the case during regular use.
    uiwait(quest_fig);
end

% Check handle validity again since we may be out of uiwait because the
% figure was deleted.
if ishghandle(quest_fig)
    if default_was_pressed
        button_name=default;
    else
        button_name = getappdata(get(quest_fig,'CurrentObject'),'QuestDlgReturnName');
    end
    do_delete;
else
    button_name='';
end
drawnow; % Update the view to remove the closed figure (g1031998)

    function do_figure_key_press(obj, evd)  %#ok
    switch(evd.key)
        case {'return','space'}
            if default_valid
                default_was_pressed = true;
                uiresume(gcbf);
            end
        case 'escape'
            do_delete
    end
    end

    function do_control_key_press(obj, evd)  %#ok
    switch(evd.key)
        case {'return'}
            if default_valid
                default_was_pressed = true;
                uiresume(gcbf);
            end
        case 'escape'
            do_delete
    end
    end

    function do_delete(varargin)
    delete(quest_fig);
    end
    
    function out_str = dialog_cellstr_helper (input_str)
        % Helper used by MSGBOX, ERRORDLG, WARNDLG, QUESTDLG to parse the input
        % string vector, matrix or cell array or strings.
        % This works similar to the CELLSTR function but does not use deblank, like
        % cellstr, to eliminate any trailing white spaces.

        % Validate input string type. 
        validateattributes(input_str, {'char','cell'}, {'2d'},mfilename);

        % Convert to cell array of strings without eliminating any user input. 
        if ~iscell(input_str)
            input_cell = {};
            for siz = 1:size(input_str,1)
                input_cell{siz} =input_str(siz,:); %#ok<AGROW>
            end
            out_str = input_cell;
        else
            out_str = input_str;
        end
    end  % function
   
    function figure_size = getnicedialoglocation(figure_size, figure_units)
        % adjust the specified figure position to fig nicely over GCBF
        % or into the upper 3rd of the screen

        %  Copyright 1999-2010 The MathWorks, Inc.

        parent_handle = gcbf;
        convert_data.destination_units = figure_units;
        if ~isempty(parent_handle)
            % If there is a parent figure
            convert_data.h_fig = parent_handle;
            convert_data.size = get(parent_handle,'Position');
            convert_data.source_units = get(parent_handle,'Units');  
            c = []; 
        else
            % If there is no parent figure, use the root's data
            % and create a invisible figure as parent
            convert_data.h_fig = figure('visible','off');
            convert_data.size = get(0,'ScreenSize');
            convert_data.source_units = get(0,'Units');
            c = on_cleanup(@() close(convert_data.h_fig));
        end

        % Get the size of the dialog parent in the dialog units
        container_size = hgconvertunits(convert_data.h_fig, convert_data.size ,...
            convert_data.source_units, convert_data.destination_units, get(convert_data.h_fig,'Parent'));

        delete(c);

        figure_size(1) = container_size(1)  + 1/2*(container_size(3) - figure_size(3));
        figure_size(2) = container_size(2)  + 2/3*(container_size(4) - figure_size(4));
    end  % function
    
    function setdefaultbutton(fig_handle, btn_handle)
        % WARNING: This feature is not supported in MATLAB and the API and
        % functionality may change in a future release.

        %SETDEFAULTBUTTON Set default button for a figure.
        %  SETDEFAULTBUTTON(BTNHANDLE) sets the button passed in to be the default button
        %  (the button and callback used when the user hits "enter" or "return"
        %  when in a dialog box.
        %
        %  This function is used by inputdlg.m, msgbox.m, questdlg.m and
        %  uigetpref.m.
        %
        %  Example:
        %
        %  f = figure;
        %  b1 = uicontrol('style', 'pushbutton', 'string', 'first', ...
        %       'position', [100 100 50 20]);
        %  b2 = uicontrol('style', 'pushbutton', 'string', 'second', ...
        %       'position', [200 100 50 20]);
        %  b3 = uicontrol('style', 'pushbutton', 'string', 'third', ...
        %       'position', [300 100 50 20]);
        %  setdefaultbutton(b2);
        %

        %  Copyright 2005-2007 The MathWorks, Inc.

        %--------------------------------------- NOTE ------------------------------------------
        % This file was copied into matlab/toolbox/local/private.
        % These two files should be kept in sync - when editing please make sure
        % that *both* files are modified.

        % Nargin Check
        narginchk(1,2)

        if (usejava('awt') == 1)
            % We are running with Java Figures
            use_java_default_button(fig_handle, btn_handle)
        else
            % We are running with Native Figures
            use_hgdefault_button(fig_handle, btn_handle);
        end

            function use_java_default_button(fig_h, btn_h)
                % Get a UDD handle for the figure.
                fh = handle(fig_h);
                % Call the setDefaultButton method on the figure handle
                fh.set_default_button(btn_h);
            end

            function use_hgdefault_button(fig_handle, btn_handle)
                % First get the position of the button.
                btn_pos = getpixelposition(btn_handle);

                % Next calculate offsets.
                left_offset   = btn_pos(1) - 1;
                bottom_offset = btn_pos(2) - 2;
                width_offset  = btn_pos(3) + 3;
                height_offset = btn_pos(4) + 3;

                % Create the default button look with a uipanel.
                % Use black border color even on Mac or Windows-XP (XP scheme) since
                % this is in natve figures which uses the Win2K style buttons on Windows
                % and Motif buttons on the Mac.
                h1 = uipanel(get(btn_handle, 'Parent'), 'HighlightColor', 'black', ...
                    'BorderType', 'etchedout', 'units', 'pixels', ...
                    'Position', [left_offset bottom_offset width_offset height_offset]);

                % Make sure it is stacked on the bottom.
                uistack(h1, 'bottom');
            end
    end  % function
    
    
end
