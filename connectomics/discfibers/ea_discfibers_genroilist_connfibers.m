function [fibsin, XYZmm, nii, valsmm]=ea_discfibers_genroilist_connfibers(fibers, roilist, patselection, thresh)

if ~exist('thresh', 'var')
    thresh = 0;
    mode = 'binary';
else
    mode = 'efield';
end

allroilist=cat(2,roilist{:});
% tree=KDTreeSearcher(fibers(:,1:3));
% load in all ROI

cnt=1;
XYZmm = cell(size(allroilist,1), 1);
nii = cell(size(allroilist,1), 2);
if strcmp(mode, 'binary')
    valsmm = [];
else
    valsmm = cell(size(allroilist,1), 1);
end
ea_dispercent(0,'Aggregating ROI');
for roi=1:size(allroilist,1)
        nii{roi,1}=ea_load_nii(allroilist{roi,1});

        [xx,yy,zz]=ind2sub(size(nii{roi,1}.img),find(nii{roi,1}.img(:)>thresh));
        XYZvx=[xx,yy,zz,ones(length(xx),1)]';
        XY=nii{roi,1}.mat*XYZvx;
        XYZmm{roi,1}=XY(1:3,:)';
        if strcmp(mode, 'efield')
            valsmm{roi,1}=nii{roi,1}.img((nii{roi,1}.img(:))>thresh);
        end

        nii{roi,2}=ea_load_nii(allroilist{roi,2});
        [xx,yy,zz]=ind2sub(size(nii{roi,2}.img),find(nii{roi,2}.img(:)>thresh));
        XYZvx=[xx,yy,zz,ones(length(xx),1)]';
        XY=nii{roi,2}.mat*XYZvx;
        XYZmm{roi,2}=XY(1:3,:)';
        if strcmp(mode, 'efield')
            valsmm{roi,2}=nii{roi,2}.img((nii{roi,2}.img(:))>thresh);
        end
   

    if ~exist('AllXYZ','var')
        AllXYZ=[XYZmm{roi,1};XYZmm{roi,2}];
    else
        AllXYZ=[AllXYZ;XYZmm{roi,1};XYZmm{roi,2}];
    end
    
    ea_dispercent(roi/size(allroilist,1));
end
ea_dispercent(1,'end');
ea_dispt('Selecting connected fibers');
% isolate fibers that are connected to any ROI:
AllXYZ=unique(round(AllXYZ*4)/4,'rows');

[~,D]=knnsearch(AllXYZ(:,1:3),fibers(:,1:3),'Distance','chebychev');

in=D<(0.5); % larger threshold here since seed vals have been rounded above. Also, this is just to reduce size of the connectome for speed improvements, so we can be more liberal here.

fibsin=fibers(ismember(fibers(:,4),unique(fibers(in,4))),:);
if size(fibsin,2)>4
   fibsin(:,5:end)=[];
end
