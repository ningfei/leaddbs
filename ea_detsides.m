function options = ea_detsides(options)

reconFile = fullfile(options.subj.reconDir, [options.subj.subjId, '_desc-reconstruction.mat']);
if isfile(reconFile)
    load(reconFile, 'reco');
    sides = [];
    if isfield(reco,'native')
        for el=1:length(reco.native.markers)
            if ~isempty(reco.native.markers(el).head)
                sides(end+1)=el;
            end
        end
    else
        for el=1:length(reco.mni.markers)
            if ~isempty(reco.mni.markers(el).head)
                sides(end+1)=el;
            end
        end
    end
    options.sides = sides;
end
