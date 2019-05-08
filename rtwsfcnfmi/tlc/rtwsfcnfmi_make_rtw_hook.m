function rtwsfcnfmi_make_rtw_hook(hookMethod, modelName, rtwRoot, templateMakefile, buildOpts, buildArgs, buildInfo)

switch hookMethod
    
    case 'after_make'
        
        % skip if build is disabled
        if strcmp(get_param(gcs, 'GenCodeOnly'), 'on')
            return
        end
        
        pathstr = which('rtwsfcnfmi.tlc');
        [tlc_dir, ~, ~] = fileparts(pathstr);
        [cmakelists_dir, ~, ~] = fileparts(tlc_dir);
        command   = 'cmake'; %get_param(modelName, 'CMakeCommand');
        generator = 'Visual Studio 14 2015 Win64'; %get_param(modelName, 'CMakeGenerator');

        % check for cmake executable
        status = system(command);
        assert(status == 0, ['Failed to run CMake command: ' command '. ' ...
            'Install CMake (https://cmake.org/) and set the CMake command in ' ...
            'Configuration Parameters > Code Generation > CMake Build > CMake Command.'])
        
        disp('### Running CMake generator')
        solver = buildOpts.solver;
        if ~strcmp(solver, {'ode1', 'ode2', 'ode3', 'ode4', 'ode5', 'ode8', 'ode14x'})
            solver = 'ode1';  % use ode1 for model exchange
        end
        custom_source = get_param(gcs, 'CustomSource');
        custom_source = which(custom_source);
        status = system(['"' command '"' ...
        ' -G "' generator '"' ...
        ' -DMODEL_NAME='     strrep(modelName,      '\', '/')     ...
        ' -DSOLVER='         solver                               ...
        ' -DRTW_DIR="'       strrep(pwd,            '\', '/') '"' ...
        ' -DMATLAB_ROOT="'   strrep(matlabroot,     '\', '/') '"' ...
        ' -DCUSTOM_SOURCE="' strrep(custom_source,  '\', '/') '"' ...
        ' "'                 strrep(cmakelists_dir, '\', '/') '"']);
        assert(status == 0, 'Failed to run CMake generator');

        disp('### Building FMU')
        status = system(['"' command '" --build . --config Release']);
        assert(status == 0, 'Failed to build FMU');
        
        % copy the FMU to the working directory
        copyfile([modelName '_sf.fmu'], '..');
end

end
