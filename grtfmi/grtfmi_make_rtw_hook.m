function grtfmi_make_rtw_hook(hookMethod, modelName, rtwRoot, templateMakefile, buildOpts, buildArgs, buildInfo)

switch hookMethod

    case 'after_make'

        current_dir = pwd;
        
        % remove FMU build directory from previous build
        if isfolder('FMUArchive')
            rmdir('FMUArchive', 's');
        end

        % remove fmiwrapper.inc for referenced models
        if ~strcmp(current_dir(end-11:end), '_grt_fmi_rtw')
            delete('fmiwrapper.inc');
            return
        end

        if strcmp(get_param(gcs, 'GenCodeOnly'), 'on')
            return
        end

        pathstr = which('grtfmi.tlc');
        [grtfmi_dir, ~, ~] = fileparts(pathstr);
        
        command = get_param(modelName, 'CMakeCommand');
        command = grtfmi_find_cmake(command);
        generator = get_param(modelName, 'CMakeGenerator');
        source_code_fmu = get_param(modelName, 'SourceCodeFMU');
        fmi_version = get_param(modelName, 'FMIVersion');
        
        % copy extracted nested FMUs
        nested_fmus = find_system(modelName, 'ReferenceBlock', 'FMIKit_blocks/FMU');
        
        if ~isempty(nested_fmus)
            disp('### Copy nested FMUs')
            for i = 1:numel(nested_fmus)
                nested_fmu = nested_fmus{i};
                unzipdir = FMIKit.getUnzipDirectory(nested_fmu);
                user_data = get_param(nested_fmu, 'UserData');
                dialog = FMIKit.showBlockDialog(nested_fmu, false);
                if user_data.runAsKind == 0
                    model_identifier = char(dialog.modelDescription.coSimulation.modelIdentifier);
                else
                    model_identifier = char(dialog.modelDescription.modelExchange.modelIdentifier);
                end
                disp(['Copying ' unzipdir ' to resources'])                
                copyfile(unzipdir, fullfile('FMUArchive', 'resources', model_identifier));
            end
        end
        
        % copy resources
        resources = get_param(gcs, 'FMUResources');
        resources = regexp(strtrim(resources), '\s+', 'split');
        if ~isempty(resources)
            disp('### Copy resources')
            for i = 1:numel(resources)
                resource = resources{i};
                disp(['Copying ' resource ' to resources'])
                if isfile(resource)
                    copyfile(resources{i}, fullfile('FMUArchive', 'resources'));
                else
                    [~, folder, ~] = fileparts(resource);
                    copyfile(resource, fullfile('FMUArchive', 'resources', folder));
                end
            end
        end

        disp('### Running CMake generator')
        custom_include = get_param(gcs, 'CustomInclude');
        custom_include = build_cmake_list(custom_include);
        source_files   = get_param(gcs, 'CustomSource');
        source_files   = regexp(source_files, '\s+', 'split');
        custom_library = get_param(gcs, 'CustomLibrary');
        custom_library = build_cmake_list(custom_library);
        custom_source  = {};
        
        for i = 1:length(source_files)
             source_file = which(source_files{i});
             if ~isempty(source_file)
                custom_source{end+1} = source_file; %#ok<AGROW>
             end
        end

        if isfield(buildOpts, 'libsToCopy') && ~isempty(buildOpts.libsToCopy)
            [parent_dir, ~, ~] = fileparts(pwd);
            custom_include{end+1} = fullfile(parent_dir, 'slprj', 'grtfmi', '_sharedutils');
            for i = 1:numel(buildOpts.libsToCopy)
                [~, refmodel, ~] = fileparts(buildOpts.libsToCopy{i});
                refmodel = refmodel(1:end-7);
                custom_include{end+1} = fullfile(parent_dir, 'slprj', 'grtfmi', refmodel); %#ok<AGROW>
                custom_source{end+1}  = fullfile(parent_dir, 'slprj', 'grtfmi', refmodel, [refmodel '.c']); %#ok<AGROW>
            end
        end
        
        % get non-inlined S-Function modules
        if all(isfield(buildOpts, {'noninlinedSFcns', 'noninlinednonSFcns'}))
            % <= R2019a
            modules = [buildOpts.noninlinedSFcns buildOpts.noninlinednonSFcns];
        else
            modules = {};
            sfcns = find_system(modelName, 'BlockType', 'S-Function');
            for i = 1:numel(sfcns)
                block = sfcns{i};
                modules = [modules get_param(block, 'FunctionName') ...
                  regexp(get_param(block, 'SFunctionModules'), '\s+', 'split')]; %#ok<AGROW>
            end
        end
                
        % add S-function sources
        for i = 1:numel(modules)
            src_file_ext = {'.c', '.cc', '.cpp', '.cxx', '.c++'};
            for j = 1:numel(src_file_ext)
                source_file = which([modules{i} src_file_ext{j}]);
                if ~isempty(source_file)
                    custom_source{end+1} = source_file; %#ok<AGROW>
                    break
                end
            end
        end
        
        % check for Simscape blocks
        if isempty(find_system(modelName, 'BlockType', 'SimscapeBlock'))
            simscape_blocks = 'off';
        else
            simscape_blocks = 'on';
        end
        
        % write the CMakeCache.txt file
        fid = fopen('CMakeCache.txt', 'w');
        fprintf(fid, 'MODEL:STRING=%s\n', modelName);
        fprintf(fid, 'RTW_DIR:STRING=%s\n', strrep(pwd, '\', '/'));
        fprintf(fid, 'MATLAB_ROOT:STRING=%s\n', strrep(matlabroot, '\', '/'));
        fprintf(fid, 'CUSTOM_INCLUDE:STRING=%s\n', custom_include);
        fprintf(fid, 'CUSTOM_SOURCE:STRING=%s\n', build_path_list(custom_source));
        fprintf(fid, 'CUSTOM_LIBRARY:STRING=%s\n', custom_library);
        fprintf(fid, 'SOURCE_CODE_FMU:BOOL=%s\n', upper(source_code_fmu));
        fprintf(fid, 'SIMSCAPE:BOOL=%s\n', upper(simscape_blocks));
        fprintf(fid, 'FMI_VERSION:STRING=%s\n', fmi_version);
        fprintf(fid, 'COMPILER_OPTIMIZATION_LEVEL:STRING=%s\n', get_param(gcs, 'CMakeCompilerOptimizationLevel'));
        fprintf(fid, 'COMPILER_OPTIMIZATION_FLAGS:STRING=%s\n', get_param(gcs, 'CMakeCompilerOptimizationFlags'));
        fclose(fid);
        
        disp('### Generating project')
        status = system(['"' command '" -G "' generator '" "' strrep(grtfmi_dir, '\', '/') '"']);
        assert(status == 0, 'Failed to run CMake generator');

        disp('### Building FMU')
        status = system(['"' command '" --build . --config Release']);
        assert(status == 0, 'Failed to build FMU');

        % copy the FMU to the working directory
        copyfile([modelName '.fmu'], '..');
end

end


function list = build_cmake_list(p)
% convert a Simulink space separated path list into a CMake path list

p = strtrim(p);

list = '';

join = false;

for i=1:numel(p)
  
  c = p(i);
  
  if c == '"'
    join = ~join;
    continue
  end
  
  if c == ' ' && ~join
    c = ';';
  end
  
  list(end+1) = c;

end

list = strrep(list, '\', '/');

end


function list = build_path_list(segments)

list = '';

for i = 1:numel(segments)
  segment = segments{i};
  if ~isempty(segment)
    if isempty(list)
      list = segment;
    else
      list = [segment ';' list]; %#ok<AGROW>
    end
  end
end

list = strrep(list, '\', '/');

end
