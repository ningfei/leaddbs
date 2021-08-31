classdef BIDSFetcher
    % BIDS dataset fetcher

    properties
        settings
        spacedef
        datasetDir
        subjFolderNames
        subjId
    end

    methods
        %% Constructor
        function obj = BIDSFetcher(datasetDir, verbose)
            if ~exist('verbose', 'var') || isempty(verbose)
                verbose = 0;
            end

            % Set up properties
            obj.settings = obj.leadPrefs('m');
            obj.spacedef = ea_getspacedef;
            obj.datasetDir = GetFullPath(datasetDir);
            obj.subjFolderNames = readSubjects(obj);
            obj.subjId = strrep(obj.subjFolderNames, 'sub-', '');

            % TODO: BIDS validation

            % Verbose
            if verbose
                fprintf('\nLoaded BIDS dataset at: %s.\nFound the following subjects:\n', obj.datasetDir);
                fprintf('%s\n', obj.subjId{:});
                fprintf('\n');
            end
        end

        %% Data fetching functions
        function subjFolderNames = readSubjects(obj)
            % Find subject folders: sub-*
            subjDirs = ea_regexpdir([obj.datasetDir, filesep, 'rawdata'], 'sub-.*', 0);
            subjFolderNames = regexp(subjDirs, ['sub-.*(?=\', filesep, '$)'], 'match', 'once');
        end

        function LeadDBSDirs = getLeadDBSDirs(obj, subjId)
            subjDir = fullfile(obj.datasetDir, 'derivatives', 'leaddbs', ['sub-', subjId]);
            if ~isfolder(subjDir)
                error('Subject ID %s doesn''t exist!', subjId);
            end

            LeadDBSDirs.subjDir = subjDir;
            LeadDBSDirs.atlasDir = fullfile(subjDir, 'atlases');
            LeadDBSDirs.brainshiftDir = fullfile(subjDir, 'brainshift');
            LeadDBSDirs.clinicalDir = fullfile(subjDir, 'clinical');
            LeadDBSDirs.coregDir = fullfile(subjDir, 'coregistration');
            LeadDBSDirs.exportDir = fullfile(subjDir, 'export');
            LeadDBSDirs.logDir = fullfile(subjDir, 'log');
            LeadDBSDirs.normDir = fullfile(subjDir, 'normalization');
            LeadDBSDirs.prefsDir = fullfile(subjDir, 'prefs');
            LeadDBSDirs.preprocDir = fullfile(subjDir, 'preprocessing');
            LeadDBSDirs.reconDir = fullfile(subjDir, 'reconstruction');
            LeadDBSDirs.stimDir = fullfile(subjDir, 'stimulation');
        end

        function prefs = getPrefs(obj, subjId, label, format)
            % Get files from prefs folder
            if ~exist('format', 'var') || isempty(format)
                format = '.json';
            end

            if ~startsWith(format, '.')
                format = ['.', format];
            end

            LeadDBSDirs = getLeadDBSDirs(obj, subjId);
            prefs = [LeadDBSDirs.prefsDir, filesep, 'sub-', subjId, '_desc-', label, format];
        end

        function subj = getSubj(obj, subjId)
            LeadDBSDirs = getLeadDBSDirs(obj, subjId);

            % Set misc fields
            subj.subjDir = LeadDBSDirs.subjDir;
            subj.uiprefs = getPrefs(obj, subjId, 'uiprefs', 'mat');
            subj.methodLog = getLog(obj, subjId, 'methods');

            % Set pre-op anat field
            preopAnat = getPreopAnat(obj, subjId);
            preopFields = fieldnames(preopAnat);
            for i=1:length(preopFields)
                subj.preopAnat.(preopFields{i}).raw = preopAnat.(preopFields{i});
            end

            % Set pre-op anchor modality
            subj.AnchorModality = preopFields{1};

            % Set post-op anat field
            postopAnat = getPostopAnat(obj, subjId);
            postopFields = fieldnames(postopAnat);
            for i=1:length(postopFields)
                subj.postopAnat.(postopFields{i}).raw = postopAnat.(postopFields{i});
            end

            % Set post-op modality
            if ismember('CT', postopFields)
                subj.postopModality = 'CT';
            else
                subj.postopModality = 'MRI';
            end

            % Set pipeline fields
            subj.preproc.anat = getPreprocAnat(obj, subjId);
            subj.coreg.anat = getCoregAnat(obj, subjId);
            subj.coreg.transform = getCoregTransform(obj, subjId);
            subj.coreg.log = getCoregLog(obj, subjId);
            subj.coreg.checkreg = getCoregCheckreg(obj, subjId);
            subj.brainshift.anat = getBrainshiftAnat(obj, subjId);
            subj.brainshift.transform = getBrainshiftTransform(obj, subjId);
            subj.brainshift.log = getBrainshiftLog(obj, subjId);
            subj.brainshift.checkreg = getBrainshiftCheckreg(obj, subjId);
            subj.norm.anat = getNormAnat(obj, subjId);
            subj.norm.transform = getNormTransform(obj, subjId);
            subj.norm.log = getNormLog(obj, subjId);
            subj.norm.checkreg = getNormCheckreg(obj, subjId);

            % Set pre-op preprocessed images
            for i=1:length(preopFields)
                subj.preopAnat.(preopFields{i}).preproc = subj.preproc.anat.preop.(preopFields{i});
            end

            % Set post-op preprocessed images
            for i=1:length(postopFields)
                subj.postopAnat.(postopFields{i}).preproc = subj.preproc.anat.postop.(postopFields{i});
            end

            % Set pre-op coregistered images
            for i=1:length(preopFields)
                subj.preopAnat.(preopFields{i}).coreg = subj.coreg.anat.preop.(preopFields{i});
            end

            % Set post-op coregistered images
            for i=1:length(postopFields)
                subj.postopAnat.(postopFields{i}).coreg = subj.coreg.anat.postop.(postopFields{i});
            end

            % Set post-op coregistered tone-mapped CT
            if ismember('CT', postopFields)
                subj.postopAnat.CT.coregTonemap = subj.coreg.anat.postop.tonemapCT;
            end

            % Set pre-op normalized images
            subj.preopAnat.(preopFields{1}).norm = subj.norm.anat.preop.(preopFields{1});

            % Set post-op normalized images
            for i=1:length(postopFields)
                subj.postopAnat.(postopFields{i}).norm = subj.norm.anat.postop.(postopFields{i});
            end

            % Set post-op normalized tone-mapped CT
            if ismember('CT', postopFields)
                subj.postopAnat.CT.normTonemap = subj.norm.anat.postop.tonemapCT;
            end
        end

        function preopAnat = getPreopAnat(obj, subjId)
            % Set dirs
            rawDataDir = fullfile(obj.datasetDir, 'rawdata', ['sub-', subjId]);

            % Get raw images struct
            rawImages = loadjson(getPrefs(obj, subjId, 'rawimages'));

            % Get images and modalities
            images = fullfile(rawDataDir, 'ses-preop', 'anat', struct2cell(rawImages.preop.anat));
            modality = fieldnames(rawImages.preop.anat)';

            % Set pre-defined orders
            preniiOrder = obj.settings.prenii_order;
            templateOrder = obj.spacedef.norm_mapping(:,1)';
            preopImageOrder = [preniiOrder, setdiff(templateOrder, preniiOrder, 'stable')];

            % Set pre-op anat images according to pre-defined orders
            for i=1:length(preopImageOrder)
                % Find the index in the present images
                idx = find(ismember(modality, preopImageOrder{i}), 1);
                if ~isempty(idx)
                    preopAnat.(preopImageOrder{i}) = images{idx};
                    images(idx) = [];
                    modality(idx) = [];
                end
            end

            % Set other pre-op anat images
            if ~isempty(modality)
                [modality, index] = sort(modality);
                images = images(index);
                for i=1:length(modality)
                    preopAnat.(modality{i}) = images{i};
                end
            end
        end

        function postopAnat = getPostopAnat(obj, subjId)
            % Set dirs
            rawDataDir = fullfile(obj.datasetDir, 'rawdata', ['sub-', subjId]);
            subjDir = fullfile(obj.datasetDir, 'derivatives', 'leaddbs', ['sub-', subjId]);

            % Get raw images struct
            rawImages = loadjson(fullfile(subjDir, 'prefs', ['sub-', subjId, '_desc-rawimages.json']));

            % Get images and modalities
            images = fullfile(rawDataDir, 'ses-postop', 'anat', struct2cell(rawImages.postop.anat));
            modality = fieldnames(rawImages.postop.anat);

            if obj.settings.preferMRCT == 2
                % Check post-op CT
                idx = find(ismember(modality, 'CT'), 1);
                if ~isempty(idx)
                    postopAnat.CT = images{idx};
                end
            elseif obj.settings.preferMRCT == 1
                % Check post-op axial MRI
                idx = find(contains(modality, 'ax'), 1);
                if ~isempty(idx)
                    postopAnat.(modality{idx}) = images{idx};
                end

                % Check post-op coronal MRI
                idx = find(contains(modality, 'cor'), 1);
                if ~isempty(idx)
                    postopAnat.(modality{idx}) = images{idx};
                end

                % Check post-op sagital MRI
                idx = find(contains(modality, 'sag'), 1);
                if ~isempty(idx)
                    postopAnat.(modality{idx}) = images{idx};
                end
            end
        end

        function preprocAnat = getPreprocAnat(obj, subjId)
            % Get pre-op and post-op anat images
            preopAnat = getPreopAnat(obj, subjId);
            postopAnat = getPostopAnat(obj, subjId);

            % Get preprocessing directory
            LeadDBSDirs = getLeadDBSDirs(obj, subjId);
            baseDir = fullfile(LeadDBSDirs.preprocDir, 'anat');

            % Get preprocessed pre-op anat images
            baseName = ['sub-', subjId, '_desc-preproc_acq-preop_'];
            fields = fieldnames(preopAnat);
            for i=1:length(fields)
                modality = fields{i};
                parsed = obj.parseFilePath(preopAnat.(modality));
                preprocAnat.preop.(modality) = fullfile(baseDir, [baseName, parsed.suffix, parsed.ext]);
            end

            % Get preprocessed post-op anat images
            baseName = ['sub-', subjId, '_desc-preproc_acq-postop_'];
            if isfield(postopAnat, 'CT')
                parsed = obj.parseFilePath(postopAnat.CT);
                preprocAnat.postop.CT = fullfile(baseDir, [baseName, 'CT', parsed.ext]);
            else
                fields = fieldnames(postopAnat);
                for i=1:length(fields)
                    modality = fields{i};
                    parsed = obj.parseFilePath(postopAnat.(modality));
                    preprocAnat.postop.(modality) = fullfile(baseDir, [baseName, 'ori-', parsed.ori, '_', parsed.suffix, parsed.ext]);
                end
            end
        end

        function coregAnat = getCoregAnat(obj, subjId)
            % Get preprocessed anat images
            preprocAnat = getPreprocAnat(obj, subjId);

            % Get LeadDBS dirs
            LeadDBSDirs = getLeadDBSDirs(obj, subjId);

            % Set coregistered anat images
            anchorSpace = 'anchorNative';
            session = fieldnames(preprocAnat);
            for i=1:length(session)
                modality = fieldnames(preprocAnat.(session{i}));
                for j=1:length(modality)
                    anat = strrep(preprocAnat.(session{i}).(modality{j}), LeadDBSDirs.preprocDir, LeadDBSDirs.coregDir);
                    coregAnat.(session{i}).(modality{j}) = strrep(anat , [subjId, '_'], [subjId, '_space-', anchorSpace, '_']);
                end
            end

            % Set tone-mapped CT
            if isfield(coregAnat.postop, 'CT')
                coregAnat.postop.tonemapCT = strrep(coregAnat.postop.CT, anchorSpace, [anchorSpace, '_rec-tonemapped']);
            end
        end

        function coregTransform = getCoregTransform(obj, subjId)
            % Get LeadDBS dirs and base name
            LeadDBSDirs = getLeadDBSDirs(obj, subjId);
            baseName = fullfile(LeadDBSDirs.coregDir, 'transformations', ['sub-', subjId, '_']);

            % Get coregistered images
            coregAnat = getCoregAnat(obj, subjId);

            % Set pre-coregistration transformation
            fields = fieldnames(coregAnat.preop);
            coregTransform.(fields{1}) = [baseName, 'desc-precoreg_', fields{1}, '.mat'];

            % Set post-op CT transformation
            if isfield(coregAnat.postop, 'CT')
                anchorSpace = 'anchorNative';
                coregTransform.CT.forwardBaseName = [baseName, 'from-CT_to-', anchorSpace, '_desc-'];
                coregTransform.CT.inverseBaseName = [baseName, 'from-', anchorSpace, '_to-CT_desc-'];
            end
        end

        function coregLog = getCoregLog(obj, subjId)
            % Get LeadDBS dirs and base name
            LeadDBSDirs = getLeadDBSDirs(obj, subjId);
            baseName = fullfile(LeadDBSDirs.coregDir, 'log', ['sub-', subjId, '_desc-']);

            % Set coregistion log
            coregLog.approved = [baseName, 'coregApproved.mat'];
            coregLog.coregCTMethod = [baseName, 'coregCTMethod.mat'];
            coregLog.coregMRMethod = [baseName, 'coregMRMethod.mat'];
            coregLog.log = [baseName, 'coreglog'];
        end

        function coregCheckreg = getCoregCheckreg(obj, subjId)
            % Get coregistered anat images
            coregAnat = getCoregAnat(obj, subjId);

            % Remove pre-op anchor anat image
            fields = fieldnames(coregAnat.preop);
            coregAnat.preop = rmfield(coregAnat.preop, fields(1));

            % Remove postop CT image, will use tone-mapped CT
            if isfield(coregAnat.postop, 'CT')
                coregAnat.postop = rmfield(coregAnat.postop, 'CT');
            end

            % Get dirs
            LeadDBSDirs = getLeadDBSDirs(obj, subjId);
            anatDir = fullfile(LeadDBSDirs.coregDir, 'anat');
            checkregDir = fullfile(LeadDBSDirs.coregDir, 'checkreg');

            % Set coregistered anat images
            session = fieldnames(coregAnat);
            for i=1:length(session)
                modality = fieldnames(coregAnat.(session{i}));
                for j=1:length(modality)
                    anat = strrep(coregAnat.(session{i}).(modality{j}), anatDir, checkregDir);
                    parsed = obj.parseFilePath(anat);
                    coregCheckreg.(session{i}).(modality{j}) = strrep(anat , parsed.ext, '.png');
                end
            end
        end

        function brainshiftAnat = getBrainshiftAnat(obj, subjId)
            % Get coregistered anat images
            coregAnat = getCoregAnat(obj, subjId);

            % Get LeadDBS dirs
            LeadDBSDirs = getLeadDBSDirs(obj, subjId);

            % Set anchor anat image used for brain shift correction
            anchorSpace = 'anchorNative';
            modality = fieldnames(coregAnat.preop);
            brainshiftAnat.anchor = strrep(coregAnat.preop.(modality{1}), anchorSpace, [anchorSpace, '_rec-brainshift']);
            brainshiftAnat.anchor = strrep(brainshiftAnat.anchor, LeadDBSDirs.coregDir, LeadDBSDirs.brainshiftDir);

            % Set moving post-op image used for brain shift correction
            modality = fieldnames(coregAnat.postop);
            brainshiftAnat.moving = coregAnat.postop.(modality{1});
            brainshiftAnat.moving = strrep(brainshiftAnat.moving, LeadDBSDirs.coregDir, LeadDBSDirs.brainshiftDir);
            if ~strcmp(modality{1}, 'CT')
                parsed = obj.parseFilePath(brainshiftAnat.moving);
                brainshiftAnat.moving = strrep(brainshiftAnat.moving, ['_ori-', parsed.ori], '');
            end

            % Set masks used for brain shift correction
            baseDir = fullfile(LeadDBSDirs.brainshiftDir, 'anat');
            brainshiftAnat.secondstepmask = [baseDir, filesep, 'sub-', subjId, '_space-', anchorSpace, '_desc-secondstepmask', obj.settings.niiFileExt];
            brainshiftAnat.thirdstepmask = [baseDir, filesep, 'sub-', subjId, '_space-', anchorSpace, '_desc-thirdstepmask', obj.settings.niiFileExt];

            % Set brain shift corrected image
            brainshiftAnat.scrf = strrep(brainshiftAnat.moving, anchorSpace, [anchorSpace, '_rec-brainshift']);
        end

        function brainshiftTransform = getBrainshiftTransform(obj, subjId)
            % Get LeadDBS dirs
            LeadDBSDirs = getLeadDBSDirs(obj, subjId);

            % Set base dir and base name
            anchorSpace = 'anchorNative';
            baseDir = fullfile(LeadDBSDirs.brainshiftDir, 'transformations');
            baseName = ['sub-', subjId, '_from-', anchorSpace, '_to-', anchorSpace, 'BSC_desc-'];

            % Set brain shift transformations
            brainshiftTransform.instore = [baseDir, filesep, baseName, 'instore.mat'];
            brainshiftTransform.converted = [baseDir, filesep, baseName, 'converted.mat'];
            brainshiftTransform.scrf = [baseDir, filesep, baseName, 'scrf.mat'];
        end

        function brainshiftLog = getBrainshiftLog(obj, subjId)
            % Get LeadDBS dirs
            LeadDBSDirs = getLeadDBSDirs(obj, subjId);

            % Set base dir
            baseDir = fullfile(LeadDBSDirs.brainshiftDir, 'log');

            % Set brain shift log
            brainshiftLog = [baseDir, filesep, 'sub-', subjId, '_desc-methods.txt'];
        end

        function brainshiftCheckreg = getBrainshiftCheckreg(obj, subjId)
            % Get brain shift anat images
            brainshiftAnat = getBrainshiftAnat(obj, subjId);

            % Set dirs
            LeadDBSDirs = getLeadDBSDirs(obj, subjId);
            anatDir = fullfile(LeadDBSDirs.brainshiftDir, 'anat');
            checkregDir = fullfile(LeadDBSDirs.brainshiftDir, 'checkreg');

            % Before brain shift correction
            brainshiftCheckreg.moving = strrep(brainshiftAnat.moving, anatDir, checkregDir);
            parsed = obj.parseFilePath(brainshiftCheckreg.moving);
            brainshiftCheckreg.moving = strrep(brainshiftCheckreg.moving, parsed.ext, '.png');

            % After brain shift correction
            brainshiftCheckreg.scrf = strrep(brainshiftAnat.scrf, anatDir, checkregDir);
            parsed = obj.parseFilePath(brainshiftCheckreg.scrf);
            brainshiftCheckreg.scrf = strrep(brainshiftCheckreg.scrf, parsed.ext, '.png');
        end

        function normAnat = getNormAnat(obj, subjId)
            % Get coregistered anat images
            coregAnat = getCoregAnat(obj, subjId);

            % Remove pre-op anat images except for anchor image
            fields = fieldnames(coregAnat.preop);
            coregAnat.preop = rmfield(coregAnat.preop, fields(2:end));

            % Get LeadDBS dirs
            LeadDBSDirs = getLeadDBSDirs(obj, subjId);

            % Set normalized anat images
            anchorSpace = 'anchorNative';
            templateSpace = obj.spacedef.name;
            session = fieldnames(coregAnat);
            for i=1:length(session)
                modality = fieldnames(coregAnat.(session{i}));
                for j=1:length(modality)
                    anat = strrep(coregAnat.(session{i}).(modality{j}), LeadDBSDirs.coregDir, LeadDBSDirs.normDir);
                    normAnat.(session{i}).(modality{j}) = strrep(anat, anchorSpace, templateSpace);
                end
            end
        end

        function normTransform = getNormTransform(obj, subjId)
            % Get LeadDBS dirs
            LeadDBSDirs = getLeadDBSDirs(obj, subjId);

            % Set base dir and base name
            anchorSpace = 'anchorNative';
            templateSpace = obj.spacedef.name;
            baseName = fullfile(LeadDBSDirs.normDir, 'transformations', ['sub-', subjId, '_from-']);

            % Set normalization transformations
            normTransform.forwardBaseName = [baseName, anchorSpace, '_to-', templateSpace, '_desc-'];
            normTransform.inverseBaseName = [baseName, templateSpace, '_to-', anchorSpace, '_desc-'];
        end

        function normLog = getNormLog(obj, subjId)
            % Get LeadDBS dirs and base name
            LeadDBSDirs = getLeadDBSDirs(obj, subjId);
            baseName = fullfile(LeadDBSDirs.normDir, 'log', ['sub-', subjId, '_desc-']);

            % Set coregistion log
            normLog.normMethod = [baseName, 'normMethod.mat'];
            normLog.log = [baseName, 'normlog'];
        end

        function normCheckreg = getNormCheckreg(obj, subjId)
            % Get normalized anat images
            normAnat = getNormAnat(obj, subjId);

            % Remove postop CT image, will use tone-mapped CT
            if isfield(normAnat.postop, 'CT')
                normAnat.postop = rmfield(normAnat.postop, 'CT');
            end

            % Get dirs
            LeadDBSDirs = getLeadDBSDirs(obj, subjId);
            anatDir = fullfile(LeadDBSDirs.normDir, 'anat');
            checkregDir = fullfile(LeadDBSDirs.normDir, 'checkreg');

            % Set coregistered anat images
            session = fieldnames(normAnat);
            for i=1:length(session)
                modality = fieldnames(normAnat.(session{i}));
                for j=1:length(modality)
                    anat = strrep(normAnat.(session{i}).(modality{j}), anatDir, checkregDir);
                    parsed = obj.parseFilePath(anat);
                    normCheckreg.(session{i}).(modality{j}) = strrep(anat , parsed.ext, '.png');
                end
            end
        end

        function recon = getRecon(obj, subjId)
            % Get dirs
            LeadDBSDirs = getLeadDBSDirs(obj, subjId);
            baseName = fullfile(LeadDBSDirs.reconDir, ['sub-', subjId, '_']);

            % Get reconstruction
            recon.recon = [baseName, 'desc-reconstruction.mat'];

            % Mask for CT-based reconstruction
            postopAnat = obj.getPostopAnat(subjId);
            rawCTSpace = 'rawCT';
            anchorSpace = 'anchorNative';
            if isfield(postopAnat, 'CT')
                recon.rawCTMask = [baseName, 'space-', rawCTSpace, '_desc-brainmask', obj.settings.niiFileExt];
                recon.anchorNativeMask = [baseName, 'space-', anchorSpace, '_desc-brainmask', obj.settings.niiFileExt];
            end
        end

        function log = getLog(obj, subjId, label)
            % Get dirs
            LeadDBSDirs = getLeadDBSDirs(obj, subjId);
            baseName = fullfile(LeadDBSDirs.logDir, ['sub-', subjId, '_desc-']);

            % Get log
            log = [baseName, label, '.txt'];
        end
    end

    methods(Static)
        %% Helper functions
        function prefs = leadPrefs(type)
            if ~exist('type', 'var') || isempty(type)
                type = 'm';
            end

            switch type
                case 'json'
                    % Read .ea_prefs.json
                    prefs = loadjson(fullfile(ea_gethome, '.ea_prefs.json'));
                case 'm'
                    % Read .ea_prefs.m and .ea_prefs.mat
                    prefs = ea_prefs;
            end
        end

        function parsedStruct = parseFilePath(filePath)
            % Split file path into stripped path, file name and extension
            [strippedPath, fileName, ext] = ea_niifileparts(GetFullPath(filePath));
            parsedStruct.dir = fileparts(strippedPath);
            parsedStruct.ext = ext;

            % Parse file name
            entities = strsplit(fileName, '_');
            for i=1:length(entities)-1
                pair = regexp(entities{i}, '-', 'split', 'once');
                parsedStruct.(pair{1}) = pair{2};
            end
            parsedStruct.suffix = entities{end}; % Last one should be modality
        end
    end
end
