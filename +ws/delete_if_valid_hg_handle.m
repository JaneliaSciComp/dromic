function delete_if_valid_hg_handle(things)
% Delete any elements of things that are valid HG handles (i.e. instances of
% a subclass of handle).

% A lot of this logic is necessary to avoid, for instance, calling
% isvalid() on double arrays, for which it is not defined.

if isempty(things), 
    return
end
is_valid_hghandle=ishghandle(things);
valid_hghandles=things(is_valid_hghandle);
delete(valid_hghandles);

end
