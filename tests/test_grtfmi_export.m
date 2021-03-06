function test_grtfmi_export

build_model('sldemo_clutch');

build_model('sldemo_fuelsys');

ref_model = fullfile(pwd, 'sldemo_mdlref_counter_bus.slx');
if exist(ref_model, 'file')
    delete(ref_model);
end

h = load_system('sldemo_mdlref_counter_bus');
cs = getActiveConfigSet(h);
switchTarget(cs, 'grtfmi.tlc', []);
set_param(h, 'CMakeGenerator', 'Visual Studio 14 2015 Win64');
save_system(h, 'sldemo_mdlref_counter_bus');

build_model('sldemo_mdlref_bus');

end


function build_model(model)

rwt_dir = fullfile(pwd, [model '_grt_fmi_rtw']);
if exist(rwt_dir, 'dir')
    rmdir(rwt_dir, 's');
end

slprj = fullfile(pwd, 'slprj');
if exist(slprj, 'dir')
    rmdir(slprj, 's');
end

fmu = fullfile(pwd, [model '.fmu']);
if exist(fmu, 'file')
    delete(fmu);
end

h = load_system(model);
cs = getActiveConfigSet(h);
switchTarget(cs, 'grtfmi.tlc', []);

params = get_param(h, 'ObjectParameters');

if isfield(params, 'DefaultParameterBehavior')
    set_param(h, 'DefaultParameterBehavior', 'Tunable');
end

if isfield(params, 'RTWInlineParameters')
    set_param(h, 'RTWInlineParameters', 'off');
end

set_param(h, 'CMakeGenerator', 'Visual Studio 14 2015 Win64')
set_param(h, 'GenerateReport', 'off');
set_param(h, 'SignalLogging', 'off');
set_param(h, 'Solver', 'ode3');

rtwbuild(h);

close_system(h, 0);

assert(exist([model '.fmu'], 'file') == 2);

status = system(['fmpy simulate ' model '.fmu']);
assert(status == 0);

end
