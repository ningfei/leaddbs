function [h,R,p]=ea_correlplot(X,Y,labels,corrtype)

if ~exist('labels','var')
    labels={'','X','Y'};
end
if ~(length(labels)==3) % assume only title provided
    labels{2}='X'; labels{3}='Y';
end
if ~exist('corrtype','var')
    corrtype='Pearson';
end

switch corrtype
    case {'permutation_spearman','permutation'}
        [R,p]=ea_permcorr(X,Y,'spearman');
    case 'permutation_pearson'
        [R,p]=ea_permcorr(X,Y,'pearson');
    otherwise
        [R,p]=corr(X,Y,'rows','pairwise','type',corrtype);
end



%Corner histogram
g=gramm('x',X,'y',Y);
g.geom_point();
g.stat_glm();
%g.geom_abline();
%g.stat_cornerhist('edges',[ea_nanmean(X)-1*ea_nanstd(X):0.2:ea_nanmean(X)+1*ea_nanstd(X)],'aspect',0.6,'location',max(X));
g.set_title([labels{1},' [R = ',sprintf('%.2f',R),'; p = ',sprintf('%.3f',p),']'],'FontSize',16);
g.set_names('x',labels{2},'y',labels{3});
g.set_text_options('base_size',16);
g.no_legend();
h=figure('Position',[100 100 550 550]);
g.draw();




