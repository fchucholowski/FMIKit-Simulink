function userData = getUserData(block)

userData = get_param(block, 'UserData');

if isempty(userData)
    return
end

if strcmp(userData.fmiKitVersion, '2.4')
    
    disp(['Updating ' block ' that was imported with an older version of FMI Kit.'])
    
    userData.fmiKitVersion = '2.6';
    set_param(block, 'UserData', userData);

    % re-import the FMU
    dialog = FMIKit.showBlockDialog(block, false);
    dialog.loadFMU(false);
    applyDialog(dialog);

    model = bdroot(block);
    set_param(model, 'Dirty', 'on');
    
    disp('Save the model to apply the changes.')

    userData = get_param(block, 'UserData');
end


if ~isfield(userData, 'directInput')
    disp(['adding userData.directInput to ' block])
    userData.directInput = false;
    userData.parameters = strrep(userData.parameters, 'logical(',  'false logical(');
    set_param(block, 'UserData', userData, 'UserDataPersistent', 'on')
    save_system
end

end