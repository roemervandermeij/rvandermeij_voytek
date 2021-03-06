function rmr_plotspacespike(cfg,nwaycomp,data)

% cond
condind   = cfg.condind;
ncond     = numel(condind);
condlabel = cfg.condlabel;
if ncond~=2
  error('doh!')
end
if any(~cellfun(@islogical,condind))
  error('dumbass')
end

% get corrgram
cgramdisp = ft_getopt(cfg, 'cgramdisp'); 
cgramfc = load(cfg.cgfn);
if isfield(cgramfc,'contcorrgram')
  cgramtime = cgramfc.time;
  corrgram  = cgramfc.contcorrgram;
else
  cgramtime = cgramfc.time;
  corrgram  = cgramfc.corrgram;
end
if size(corrgram,2) ~= numel(nwaycomp.label)
  error('corrgram and nwaycomp have different number of units')
end

% set basics
comp   = nwaycomp.comp;
ncomp  = numel(comp);
nchan  = size(comp{1}{1},1);
nfreq  = size(comp{1}{2},1);
ntrial = size(comp{1}{3},1);

% gather A,B,C,S
A = zeros(nchan,ncomp);
B = zeros(nfreq,ncomp);
C = zeros(ntrial,ncomp);
S = zeros(nchan,ncomp);
for icomp = 1:ncomp
  A(:,icomp) = comp{icomp}{1};
  B(:,icomp) = comp{icomp}{2};
  C(:,icomp) = comp{icomp}{3} .^ 2; %%% SQUARE
  S(:,icomp) = comp{icomp}{4};
end
% sort by non-unitary spatial maps
tmpA = A ./ repmat(max(A,[],1),[size(A,1) 1]);
tmpA = sort(tmpA,1);
[tmpA comporder] = sort(tmpA(end-1,:),'descend');
%comporder(tmpA<0.1) = [];
%comporder = 1:ncomp;
%comporder = comporder(1:2);


% compute spikerate/etc
trlspikes = cellfun(@sum,data.trial,repmat({2},[1 numel(data.trial)]),'uniformoutput',0);
trlspikes = full(cat(2,trlspikes{:}));
trialtime = cellfun(@max,data.time);
spikerate = bsxfun(@rdivide,trlspikes,trialtime);
if size(spikerate,1) ~= numel(nwaycomp.label)
  error('spikerate and nwaycomp have different number of units')
end

% permute conditions to get 99perc diff value
if isequal(cgramdisp,'pasquale2008')
  nperm = 500;
  cgdiffpermfn = [cfg.cgfn(1:end-4) '_' 'pasquale2008diff99percnperm' num2str(nperm) '.mat'];
  if ~exist(cgdiffpermfn,'file')
    cgdiff99perc = zeros(nchan,nchan,size(corrgram,4));
    if ~islogical(condind{1})
      error('condind needs to be bool')
    end
    for iseed = 1:nchan
      disp(['iseed ' num2str(iseed) ' of ' num2str(nchan)])
      for itarg = 1:nchan
        currcg   = permute(corrgram(:,iseed,itarg,:),[1 4 2 3]);
        currperm = zeros(nperm,size(corrgram,4));
        for iperm = 1:nperm
          ind1 = condind{1}(randperm(ntrial));
          ind2 = ~ind1;
          c1coef   = mean(currcg(ind1,:) ./ trialtime(ind1)',1);
          c2coef   = mean(currcg(ind2,:) ./ trialtime(ind2)',1);
          normfac1 = sqrt(mean(trlspikes(iseed,ind1) ./ trialtime(ind1)) * mean(trlspikes(itarg,ind1) ./ trialtime(ind1)));
          normfac2 = sqrt(mean(trlspikes(iseed,ind2) ./ trialtime(ind2)) * mean(trlspikes(itarg,ind2) ./ trialtime(ind2)));
          c1coef   = c1coef ./ normfac1;
          c2coef   = c2coef ./ normfac2;
          c1coef   = c1coef ./ sum(c1coef);
          c2coef   = c2coef ./ sum(c2coef);
          currperm(iperm,:) = abs(c1coef - c2coef);
        end
        currperm = sort(currperm,1);
        cgdiff99perc(iseed,itarg,:) = currperm(min([round(nperm .* .99)+1 nperm]),:);
      end
    end
    % save it
    save(cgdiffpermfn,'cgdiff99perc')
  else
    load(cgdiffpermfn)
  end
end

% per comp
for icomp = comporder
  
  figure('numbertitle','off','name',['comp' num2str(icomp)]);
  
  
  %         % plot A
  %         subplot(4,4,1)
  %         plot(1:nchan,A(:,icomp));
  %         ylim = get(gca,'ylim');
  %         ylim = round([0 ylim(2)*1.05]*10)./10;
  %         set(gca,'ylim',ylim,'xlim',[1 nchan],'ytick',ylim)
  %         xlabel('units')
  %         ylabel('loading (au)')
  %         title('spatial map of network')
  
  % plot A
  subplot(4,4,1)
  [dum, sortind] = sort(mean(spikerate,2),'descend');
  %sortind = 1:numel(sortind);
  [ax h1 h1] = plotyy(1:nchan,A(sortind,icomp),1:nchan,mean(spikerate(sortind,:),2));
  ylim = get(ax(1),'ylim');
  set(ax(1),'ylim',[0 ylim(2)*1.05],'xlim',[1 nchan])
  set(ax(2),'ylim',[0 20],'ytick',[0:2.5:20],'xlim',[1 nchan])
  xlabel('sorted units')
  ylabel('loading')
  %legend([repmat('comp',[ncomp 1]) deblank(num2str((1:ncomp)'))])
  title('A')
  
  % plot C t-test: enter target or not
  if size(C,1)>1
    if ncond == 2
      subplot(4,4,2)
      m1 = mean(C(condind{1},icomp));
      m2 = mean(C(condind{2},icomp));
      sem1 = std(C(condind{1},icomp)) ./ sqrt(sum(condind{1}));
      sem2 = std(C(condind{2},icomp)) ./ sqrt(sum(condind{2}));
      errorbar([m1 m2],[sem1 sem2])
      ylim = get(gca,'ylim');
      ylim = round([0 ylim(2)*1.1]*1000)./1000;
      set(gca,'ylim',ylim);
      set(gca,'xlim',[0.5 2.5])
      set(gca,'xtick',[1 2])
      set(gca,'ytick',ylim)
      set(gca,'xticklabel',condlabel)
      ylabel('loading (au)')
      [h p,ci,stats] = ttest2(C(condind{1},icomp),C(condind{2},icomp));
      title(['network strength cond1/cond2 trials, mean+sem, t = ' num2str(stats.tstat,'%1.2f')])
    else
      error('ncond ~= 2 not supported');
    end
  end
  
  % plot S
  subplot(4,4,3)
  hold on
  [dum sortind] = sort(A(:,icomp),'descend');
  [ax h1 h2] = plotyy(1:5,(S(sortind(1:5),icomp)-S(sortind(1),icomp))*1000,1.5:4.5,diff((S(sortind(1:5),icomp)-S(sortind(1),icomp))*1000));
  set(ax(1),'ylim',[-.010 .010]*1000,'xlim',[1 5],'xtick',1:5)
  set(ax(1),'ytick',(-.01 :0.005: .01)*1000)
  set(ax(2),'ylim',[-.010 .010]*1000,'xlim',[1 5],'xtick',1:5)
  set(ax(2),'ytick',(-.01 :0.005: .01)*1000)
  set(h2,'linestyle','--','marker','o','markerfacecolor', [0.85 0.325 0.098])
  xlabel('units sorted by spatial map strength')
  ylabel(ax(1),'time delay (ms)')
  ylabel(ax(2),'diff of time delay (ms)')
  title('time delays of units')
  
  
  % plot pairs of corrgrams
  [dum sortind] = sort(A(:,icomp),'descend');
  chanind = sortind(1:4);
  count = 4;
  for iseed = 1:numel(chanind)
    for itarg = iseed:numel(chanind)
      if iseed == 3 && itarg == 3
        count = count+2;
      else
        count = count+1;
      end
      subplot(4,4,count);
      setcol = {[0 .75 1],[0 0 .75],[0.75 0 0],[1 .75 0]};
      plotdat = [];
      for iset = 1:ncond
        currind = condind{iset};
   
        % switch between different displays
        switch cgramdisp
          case 'mean'
            % plot as mean hist
            currcg = squeeze(corrgram(currind,chanind(iseed),chanind(itarg),:));
            currcg = mean(currcg,1);
            plotdat{iset} = currcg;
            
          case 'sum'
            % plot as summed hist
            currcg = squeeze(corrgram(currind,chanind(iseed),chanind(itarg),:));
            currcg = sum(currcg,1);
            plotdat{iset} = currcg;
            
          case 'rate'
            % plot as spikes/sec
            currcg = squeeze(corrgram(currind,chanind(iseed),chanind(itarg),:));
            trialtime = cellfun(@max,data.time(currind));
            currcg = currcg ./ repmat(trialtime',[1 size(currcg,2)]);
            currcg = nanmean(currcg,1);
            plotdat{iset} = currcg;
            
          case 'ratesum'
            % plot as spikes/sec, but after aggregating over trials
            currcg = squeeze(corrgram(currind,chanind(iseed),chanind(itarg),:));
            currcg = nansum(currcg,1);
            trialtime = cellfun(@max,data.time(currind));
            currcg = currcg ./ sum(trialtime);
            currcg = currcg ./ sum(currind);
            plotdat{iset} = currcg;
            
          case 'pasquale2008'
            % plot as summed corrgram normalized by sqrt of multiplied rates, and divided by sum total over time, as coindicidence index in Pasquale 2008
            currcg  = squeeze(corrgram(currind,chanind(iseed),chanind(itarg),:));
            currcg  = mean(currcg ./ trialtime(currind)',1);
            normfac = sqrt(mean(trlspikes(chanind(iseed),currind) ./ trialtime(currind)) * mean(trlspikes(chanind(itarg),currind) ./ trialtime(currind)));
            currcg  = currcg ./ normfac;
            currcg  = currcg ./ sum(currcg);
            plotdat{iset} = currcg;
            
          otherwise
            error('not supported')
        end
      end
      h1 = plot(cgramtime*1000,cat(1,plotdat{:}),'linewidth',1);
      for iset = 1:ncond
        set(h1(iset),'color',setcol{iset})
      end
      hold on
      set(gca,'xtick',cgramtime(1:round(numel(cgramtime)/4):end)*1000)
      title(['unit' num2str(iseed) '-' 'unit' num2str(itarg)])
      ylim = [0 round(max(get(gca,'ylim'))*10000)./10000];
      set(gca,'ylim',ylim,'ytick',ylim);
      ylabel(cgramdisp)
      xlabel('time from seed unit spikes (ms)')
      if isequal(cgramdisp,'pasquale2008')
        yyaxis right
        h2 = plot(cgramtime*1000,cat(1,abs(plotdat{1}-plotdat{2})-squeeze(cgdiff99perc(chanind(iseed),chanind(itarg),:))'),'linewidth',0.5);
        set(h2,'color',setcol{3},'linestyle','-')
        hold on
        axis tight
        set(gca,'xtick',cgramtime(1:round(numel(cgramtime)/4):end)*1000)
        ylim = [round(min(get(gca,'ylim'))*10000)./10000 round(max(abs(get(gca,'ylim')))*10000)./10000];
        set(gca,'ylim',ylim,'ytick',ylim);
        xlabel('time from seed unit spikes (ms)')
        if max(abs(plotdat{1}-plotdat{2}))>max(squeeze(cgdiff99perc(chanind(iseed),chanind(itarg),:))')
          title(['unit' num2str(iseed) '-' 'unit' num2str(itarg) ' +'])
        else
          title(['unit' num2str(iseed) '-' 'unit' num2str(itarg) ' -'])
        end
      end
      if isequal(cgramdisp,'sum')
        yyaxis right
        h2 = plot(cgramtime*1000,plotdat{1}+plotdat{2},'linewidth',1.5);
        set(h2,'color',setcol{3})
        hold on
        axis tight
        set(gca,'xtick',cgramtime(1:round(numel(cgramtime)/4):end)*1000)
        ylim = [0 round(max(abs(get(gca,'ylim')))*10000)./10000];
        set(gca,'ylim',ylim,'ytick',ylim);
        xlabel('time from seed unit spikes (ms)')
      end
      
      % plot legend
      subplot(4,4,4);
      plot([1 2 3; 1 2 3]);
      set(gca,'xlim',[4 5])
      axis off
      if ~isequal(cgramdisp,'pasquale2008')
        [dum dum h dum] = legend('cond1','cond2');
      else
        [dum dum h dum] = legend('cond1','cond2','diff-99perc');
      end
      for iline = 1:numel(h)
        set(h(iline),'color',setcol{iline})
      end
    end
  end
  
  
  
end % comporder

