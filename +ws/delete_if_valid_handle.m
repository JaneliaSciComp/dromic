function delete_if_valid_handle(things)
    % Delete any elements of things that are valid handles (i.e. instances of
    % a subclass of handle).

    % A lot of this logic is necessary to avoid, for instance, calling
    % isvalid() on double arrays, for which it is not defined.

    if isempty(things), 
        return
    end
    is_handle_array=isa(things,'handle');
    if ~is_handle_array , 
        return
    end
    is_valid=isvalid(things);  % logical array, same size as things
    valid_handles=things(is_valid);
    delete(valid_handles);
end
