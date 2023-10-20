function varargout = ea_runcmd(cmd, opts)
% Run system command constructed using external binaries.

arguments
    cmd     {mustBeTextScalar}
    opts.env     {mustBeText} = '' % env to be overridden, can be 'key=value' or {'key1=value1', 'key2=value2'}
    opts.timeout {mustBeTextScalar} = '' % Execute cmd with timeout, can be 10s, 10m, 1h, etc.
end

if isempty(opts.env)
    envOverride = '';
else
    if ischar(opts.env)
        opts.env = {opts.env};
    end

    if isunix
        envOverride = ['export ' strjoin(opts.env, ' ') ';'];
    else
        envOverride = ['set "' strjoin(opts.env, '" & set "') '" & '];
    end
end

cmd = [envOverride, cmd]; 

if isunix
    cmd = ['bash -c "', cmd, '"'];
end

if ~isempty(opts.timeout)
    % Add timeout
    binFolder = fileparts(mfilename('fullpath'));
    if ismac
        binPath = ea_getExec(fullfile(binFolder, 'gtimeout'), escapePath=true);
        cmd = [binPath ' ' opts.timeout ' ' cmd];
    elseif isunix
        cmd = ['timeout ' opts.timeout ' ' cmd];
    elseif ispc
        binPath = ea_getExec(fullfile(binFolder, 'procgov64'), escapePath=true);
        cmd = [binPath ' -t ' opts.timeout ' -- ' cmd];
    end
end

if nargout == 0
    system(cmd);
elseif nargout == 1
    varargout{1} = system(cmd);
elseif nargout == 2
    [varargout{1}, varargout{2}] = system(cmd);
    varargout{2} = strip(varargout{2});
end
