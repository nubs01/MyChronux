function [C,phi,S12,S1,S2,t,f,confC,phistd,Cerr]=ry_cohgramc(data1,data2,movingwin,params)
% Multi-taper time-frequency coherence,cross-spectrum and individual spectra - continuous processes
%
% Usage:
%
% [C,phi,S12,S1,S2,t,f,confC,phistd,Cerr]=cohgramc(data1,data2,movingwin,params)
% Input: 
% Note units have to be consistent. Thus, if movingwin is in seconds, Fs
% has to be in Hz. see chronux.m for more information.
%
%       data1 (in form samples x trials) -- required
%       data2 (in form samples x trials) -- required
%       movingwin (in the form [window winstep] -- required
%       params: structure with fields tapers, pad, Fs, fpass, err, trialave
%       - optional
%           tapers : precalculated tapers from dpss or in the one of the following
%                    forms: 
%                    (1) A numeric vector [TW K] where TW is the
%                        time-bandwidth product and K is the number of
%                        tapers to be used (less than or equal to
%                        2TW-1). 
%                    (2) A numeric vector [W T p] where W is the
%                        bandwidth, T is the duration of the data and p 
%                        is an integer such that 2TW-p tapers are used. In
%                        this form there is no default i.e. to specify
%                        the bandwidth, you have to specify T and p as
%                        well. Note that the units of W and T have to be
%                        consistent: if W is in Hz, T must be in seconds
%                        and vice versa. Note that these units must also
%                        be consistent with the units of params.Fs: W can
%                        be in Hz if and only if params.Fs is in Hz.
%                        The default is to use form 1 with TW=3 and K=5
%                     Note that T has to be equal to movingwin(1).
%
%	        pad		    (padding factor for the FFT) - optional (can take values -1,0,1,2...). 
%                    -1 corresponds to no padding, 0 corresponds to padding
%                    to the next highest power of 2 etc.
%			      	 e.g. For N = 500, if PAD = -1, we do not pad; if PAD = 0, we pad the FFT
%			      	 to 512 points, if pad=1, we pad to 1024 points etc.
%			      	 Defaults to 0.
%           Fs   (sampling frequency) - optional. Default 1.
%           fpass    (frequency band to be used in the calculation in the form
%                                   [fmin fmax])- optional. 
%                                   Default all frequencies between 0 and Fs/2
%           err  (error calculation [1 p] - Theoretical error bars; [2 p] - Jackknife error bars
%                                   [0 p] or 0 - no error bars) - optional. Default 0.
%           trialave (average over trials when 1, don't average when 0) - optional. Default 0
% Output:
%       C (magnitude of coherency time x frequencies x trials for trialave=0; 
%             time x frequency for trialave=1)
%       phi (phase of coherency time x frequencies x trials for no trial averaging; 
%             time x frequency for trialave=1)
%       S12 (cross spectrum - time x frequencies x trials for no trial averaging; 
%             time x frequency for trialave=1)
%       S1 (spectrum 1 - time x frequencies x trials for no trial averaging; 
%             time x frequency for trialave=1)
%       S2 (spectrum 2 - time x frequencies x trials for no trial averaging; 
%             time x frequency for trialave=1)
%       t (time)
%       f (frequencies)
%       confC (confidence level for C at 1-p %) - only for err(1)>=1
%       phistd - theoretical/jackknife (depending on err(1)=1/err(1)=2) standard deviation for phi
%                Note that phi + 2 phistd and phi - 2 phistd will give 95% confidence
%                bands for phi - only for err(1)>=1 
%       Cerr  (Jackknife error bars for C - use only for Jackknife - err(1)=2)
%
%
% Ryan -- following code meant to remedy a problem with the chronux library
% -- it doesn't play nice with non-double types
%
%
% Ryan -- Adding phase-locking value, imaginary coherence, phase locking
% index and weighted phase locking index.

movingwin = cast(movingwin, 'double');
params.Fs = cast(params.Fs, 'double');

if nargin < 3; error('Need data1 and data2 and window parameters'); end
if nargin < 4; params=[];end

if ~isempty(params) && length(params.tapers)==3 && movingwin(1)~=params.tapers(2)
    error('Duration of data in params.tapers is inconsistent with movingwin(1), modify params.tapers(2) to proceed')
end

[tapers,pad,Fs,fpass,err,trialave,params] = getparams(params);
if ~isfield(params,'usewavelet')
    params.usewavelet=false;
end

if nargout > 9 && err(1)~=2
    error('Cerr computed only for Jackknife. Correct inputs and run again');
end
if nargout > 7 && err(1)==0
%   Errors computed only if err(1) is nonzero. Need to change params and run again.
    error('When errors are desired, err(1) has to be non-zero.');
end
[N,Ch]=check_consistency(data1,data2);

% Figure out what our window length, step size, frequency res are
Nwin=round(Fs*movingwin(1)); % number of samples in window
Nstep=round(movingwin(2)*Fs); % number of samples to step through
nfft=max(2^(nextpow2(Nwin)+pad),Nwin);
f=getfgrid(Fs,nfft,fpass); 
Nf=length(f);

% Create the taper windows
params.tapers=dpsschk(tapers,Nwin,Fs); 

% Figure out window start and window sample length
winstart=1:Nstep:N-Nwin+1;
nw=length(winstart);

% Iterate over each window and compute the measure
prog = floor(nw/20);
for n=1:nw
   indx=winstart(n):winstart(n)+Nwin-1;
   datawin1=data1(indx,:);datawin2=data2(indx,:);
   if nargout==10
     [c,ph,s12,s1,s2,f,confc,phie,cerr]=ry_coherencyc(datawin1,datawin2,params,params.usewavelet);
%      phierr(1,n,:,:)=squeeze(phie(1,:,:));
%      phierr(2,n,:,:)=squeeze(phie(2,:,:));
     phistd(n,:,:)=phie;
     Cerr(1,n,:,:)=squeeze(cerr(1,:,:));
     Cerr(2,n,:,:)=squeeze(cerr(2,:,:));
   elseif nargout==9
     [c,ph,s12,s1,s2,f,confc,phie] = ry_coherencyc(datawin1,datawin2,params,params.usewavelet);
%      phierr(1,n,:,:)=squeeze(phie(1,:,:));
%      phierr(2,n,:,:)=squeeze(phie(2,:,:));
      phistd(n,:,:)=phie;
   else
     [c,ph,s12,s1,s2,f] = ry_coherencyc(datawin1,datawin2,params,params.usewavelet);
   end
   
   if n==1; 
    initialize(); 
    fprintf('<');
    else
   assert(n <= size(C.(fd),1))
   end

   
   for fd = fieldnames(c)'
    fd=fd{1};
    C.(fd)(n,:,:,:)=c.(fd);
   end
   S12(n,:,:)=s12;
   S1(n,:,:)=s1;
   S2(n,:,:)=s2;
   phi(n,:,:)=ph;
   
    if mod(n,prog)==0
        fprintf('=');
    end

end
fprintf('>');

%Squeeze out singleton dimensions
for fd = fieldnames(C)'
  fd=fd{1};
  C.(fd) = squeeze(C.(fd));
end
phi=squeeze(phi);S12=squeeze(S12); S1=squeeze(S1); S2=squeeze(S2);

% Optional error returns
if nargout > 8; confC=confc; end
if nargout==10;Cerr=squeeze(Cerr);end
% if nargout>=9; phierr=squeeze(phierr);end
if nargout>=9; phistd=squeeze(phistd);end

% Not sure what these last bits are used for
winmid=winstart+round(Nwin/2);
t=winmid/Fs;

function initialize()
  % Initialize the objects that will hold the computations
  if isa(data1,'gpuArray')
      kwargs = {'single','gpuArray'};
      gpu_flag = true;
  else
      kwargs = {'single'};
      gpu_flag = false;
  end
  if trialave
     for fd = fieldnames(c)'; fd=fd{1};
       if numel(fd) > 2 &&  (strcmp(fd(1:2),'du') || strcmp(fd(1:2),'nm'))
        C.(fd)=single(zeros(nw,Nf,Nf, kwargs{:}));
       else
        C.(fd)=single(zeros(nw,Nf, kwargs{:}));
       end
     end
     S12=single(zeros(nw,Nf, kwargs{:}));
     S1=single(zeros(nw,Nf, kwargs{:}));
     S2=single(zeros(nw,Nf, kwargs{:}));
     phi=single(zeros(nw,Nf, kwargs{:}));
     Cerr=single(zeros(2,nw,Nf, kwargs{:}));
  %    phierr=zeros(2,nw,Nf);
     phistd=single(zeros(nw,Nf, kwargs{:}));
  else
    for fd = fieldnames(c)'; fd=fd{1};
     if strcmp(fd,'Jxy') 
      C.(fd)=single(zeros(nw,Nf,size(params.tapers,2), kwargs{:}));
     elseif numel(fd)>2 && all(fd(1:2)=='du')
      C.(fd)=single(zeros(nw,Nf,Nf,Ch, kwargs{:}));
     else
      C.(fd)=single(zeros(nw,Nf,Ch,1, kwargs{:}));
     end
    end
     S12=single(zeros(nw,Nf,Ch, kwargs{:}));
     S1=single(zeros(nw,Nf,Ch, kwargs{:}));
     S2=single(zeros(nw,Nf,Ch, kwargs{:}));
     phi=single(zeros(nw,Nf,Ch, kwargs{:}));
     Cerr=single(zeros(2,nw,Nf,Ch, kwargs{:}));
  %    phierr=zeros(2,nw,Nf,Ch);
     phistd=single(zeros(nw,Nf,Ch, kwargs{:}));

  end
  if gpu_flag
         gpu = gpuDevice;
         fprintf('\n%2.2f percent gpu usage with %d trials\n',100-100*gpu.AvailableMemory/gpu.TotalMemory, size(data1,2))
 end
end

end
