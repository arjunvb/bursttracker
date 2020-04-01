function generateQXDMOut(qxdm_log_dir,force_parse,imeiMap)

global loop_time

A=dir(strcat(qxdm_log_dir,'/qxdm_test*.txt'));
loop_time=10240;   %in ms

header = {'UNIXTime', 'FRAMEID', 'FRAME', 'SUBFRAME', 'RNTI', 'IMEI', 'IMEIX', 'MCS1', 'MCS2', 'MOD1', 'MOD2', 'TBS1', 'TBS2', 'NALLOC', ...
          'AGGLEVEL', 'STARTCCE'};

%List of rnti's
%rnti=[60 56];
rnti = [1: length(A)];

% assign default IMEIs if not provided
if nargin < 3
  if exist(strcat(qxdm_log_dir,'/imei.csv'), 'file')
    imeiMap = readtable(strcat(qxdm_log_dir,'/imei.csv'));
  else
    for i=1:length(A)
      UEID(i) = i;
      IMEI(i) = str2num( repmat(num2str(i), 1, 15) )
    end
    imeiMap = table(UEID, IMEI);
  end
end
imeiMap

out_mat=[];

for i=1:length(A),
    qxdmfile=strcat(qxdm_log_dir,'/',A(i).name)
    comStartIdx = strfind(qxdmfile, 'COM');
    if ~isempty(comStartIdx)
      underscoreIdx = strfind(qxdmfile, '_');
      cands = find(underscoreIdx > comStartIdx);
      comEndIdx = underscoreIdx(cands(1));
      comID = str2num(qxdmfile(comStartIdx + 3 : comEndIdx - 1));
    else
      comID = i;
    end
    temp=parseandprocessQXMDlog(rnti(i), imeiMap.IMEI(imeiMap.UEID == comID), qxdmfile,force_parse);
    out_mat =[out_mat; temp];

    %temp(:,1) = temp(:,1) - min(temp(:,1));
    fName_user =strcat(qxdm_log_dir,'/qxdm_out_rnti',num2str(rnti(i)),'.csv');
    write_mat_to_csv(fName_user, temp, header); %Writing per-user data to a file
end

%Soring the output matrix based on "unix time" column
[sorted_time,I]=sort(out_mat(:,1));
sorted_out_mat = out_mat(I,:);
%sorted_out_mat(:,1) = sorted_out_mat(:,1) - sorted_out_mat(1,1);

%Aligning the frameIDs from different users
blockID_diff=zeros(1,length(rnti));

for uid =1:length(rnti),  %looping over users
    idx_frame_start = find(sorted_out_mat(:,5) == rnti(uid),1);
    time_start(uid) = sorted_out_mat(idx_frame_start,1);
    frame_start(uid) = sorted_out_mat(idx_frame_start,2);

end
[time_start_sorted,indx]=sort(time_start);
frame_start_sorted = frame_start(indx);

time_start_diff = time_start_sorted - time_start_sorted(1) ;
frame_start_diff = frame_start_sorted - frame_start_sorted(1);

blockID_diff= round(( time_start_diff - frame_start_diff*10)/loop_time);

%Applying the block_id_offset
for k=2:length(indx),

    rnti_ue = rnti(indx(k));
    temp_id = find(sorted_out_mat(:,5) == rnti_ue);
    sorted_out_mat(temp_id,2) = sorted_out_mat(temp_id,2) + blockID_diff(k)*1024;
end


%Writing output to qxdm_out.csv file
fName =strcat(qxdm_log_dir,'/qxdm_out.csv');


write_mat_to_csv(fName, sorted_out_mat, header)

end




function [out_mat]= parseandprocessQXMDlog(rnti, imei, qxdmfile,force_parse)
global loop_time
%Takes the QXDM log file (.txt) and converts into a qxdm_out.csv file
%The goal is to generate same output as the sniffer, so that the rest of
%the pipeline can be reused


if force_parse
    % parse + import PDSCH log
    display('parsing + importing PDSCH log');
    cmd = ['python parsePDSCHlog.py ' qxdmfile];
    system(cmd);
    readPDSCHcsv(qxdmfile);  %Generates a .mat file

    % parse + import PDCCH log
    display('parsing + importing PDCCH log');
    cmd = ['python parsePDCCHlog.py ' qxdmfile];
    system(cmd);
    readPDCCHcsv(qxdmfile);  %Generates a .mat file

end

load(strcat(qxdmfile,'.pdsch.csv.mat'));
pdcch = load(strcat(qxdmfile,'.pdcch.csv.mat'));

%Converting data_time to unix-time
unix_time_raw = convert_date_time_to_ms(timestamp);
frameid=converttolinear(frame,unix_time_raw);

% compute fsf for pdcch log
utr_pdcch = convert_date_time_to_ms(pdcch.timestamp);
frameid_pdcch = converttolinear(pdcch.frame, utr_pdcch);

%Synchronizing the pdsch and pdcch logs
%The first line in each log can be few 10s of seconds apart
pdsch_pdcch_time_start_diff  = max(unix_time_raw(1),utr_pdcch(1)) - min(unix_time_raw(1),utr_pdcch(1));
pdsch_pdcch_frame_start_diff = max(frameid_pdcch(1),frameid(1)) - min(frameid_pdcch(1),frameid(1)) ;
pdsch_pdcch_blockID_diff= round(( pdsch_pdcch_time_start_diff - pdsch_pdcch_frame_start_diff*10)/loop_time);

%applying offset to the appropriate frameids
if (unix_time_raw(1) > utr_pdcch(1))  %PDCCH log starts earlier in time
    frameid = frameid + pdsch_pdcch_blockID_diff*1024;
else
    frameid_pdcch = frameid_pdcch + pdsch_pdcch_blockID_diff*1024;
end

%Computing tti vectors
fsf=10*frameid + double(subframe);
fsf_u= unique(fsf);

fsf_pdcch = 10*frameid_pdcch + double(pdcch.subframe);
fsf_u_pdcch = unique(fsf_pdcch);

mod_map = util_modMap();
for i=1:length(fsf_u),
    temp = find(fsf == fsf_u(i));

    %Converting time-stamp into unix time
    unix_time(i) = unix_time_raw(temp(1));
    frameid_out(i) = double(frameid(temp(1)));
    frame_out(i) = double(frame(temp(1)));
    subframe_out(i) = double(subframe(temp(1)));
    [~,mod1] = lteMCS(double(mcs(temp(1))));
    mod1_out(i) = mod_map(mod1);
    mcs1_out(i) = double(mcs(temp(1)));
    cod1_out(i) = double(tbsize(temp(1)))*8;   %Transport block size in bits. QXDM logs it in bytes
    nalloc_out(i) = double(nrb(temp(1)));
    if (length(temp) ==1)
        mod2_out(i) = -10;   %Denotes non-existent layer 2
        cod2_out(i) = -10;   %Denotes non-existent layer 2
        mcs2_out(i) = -10;
  elseif (length(temp)==2)
        [~,mod2] = lteMCS(double(mcs(temp(2))));
        mod2_out(i) = mod_map(mod2);
        mcs2_out(i) = double(mcs(temp(2)));
        cod2_out(i) = double(tbsize(temp(2)))*8;    %Transport block size in bits. QXDM logs it in bytes
    else
        disp('Error: cannot have three lines in the log with same tti number');
        return;
    end

    % add agglevel and startcce from PDCCH logs
    ptemp = find(fsf_pdcch == fsf_u(i));
    if ~isempty(ptemp)
      agglevel_out(i) = double(pdcch.agglevel(ptemp(1)));
      startcce_out(i) = double(pdcch.startcce(ptemp(1)));
    else
      agglevel_out(i) = -10; % agglevel not logged in qxdm
      startcce_out(i) = -10; % startcce not logged in qxdm
    end

end


rnti_out = rnti*ones(1,length(frame_out));
imei_out = imei*ones(1,length(frame_out));
imeistr = num2str(imei);
imeix = str2num(imeistr(1:end-1));
imeix_out = imeix*ones(1,length(frame_out));
out_mat = [unix_time.' frameid_out.' frame_out.' subframe_out.' rnti_out.' imei_out.' imeix_out.' mcs1_out.' mcs2_out.' mod1_out.' mod2_out.' cod1_out.' cod2_out.' nalloc_out.' agglevel_out.' startcce_out.'];
end

function unix_t= convert_date_time_to_ms(date_time)
B=char(date_time);
spl = regexp(date_time, ' ', 'split');
spl = vertcat(spl{:});
time = regexp(spl(:,end), '\.', 'split');
time = vertcat(time{:});
hyphen = repmat('-', size(spl, 1), 1);
if all(ismember(spl(:,3), {''}))
  C = strcat(spl(:,1), hyphen, spl(:,2), hyphen, spl(:,4), {' '}, time(:,1));
else
  C = strcat(spl(:,1), hyphen, spl(:,2), hyphen, spl(:,3), {' '}, time(:,1));
end
%for i=1:size(B,1)
%  spl = strsplit(B(i,:));
%  t = strsplit(spl{4},'.');
%  C(i,:) = strcat(spl{1}, '-', spl{2}, '-', spl{3}, {' '}, t{1});
%end
%C=B(:,[1:9 11:12 14:21]);
%C(:,[5 9]) ='-';
unixtime_secs = posixtime(datetime(C));
%time_ms = str2num(B(:,23:end));
time_ms = str2double(time(:,2));
unix_t = unixtime_secs*1000 + time_ms;
unix_t = transpose(unix_t);

% %Need to work on parallel implementation
% for id=1:length(date_time),
% 
%     datetime = char(date_time(id));  %Converting cell to char
%     t=datetime(end-11:end);                 %Only taking the time portion of char array
% 
%     thour=str2double(t(:,1:2));
%     tmin=str2double(t(:,4:5));
%     tsec=str2double(t(:,7:8));
%     tmsec =str2double(t(:,10:12));
% 
%     %unix_t = 60*60*thour+ 60*tmin + tsec + tmsec/1000;
% 
%     %unix_t = 60*tmin + tsec + tmsec/1000;
%     time_seconds = tsec + 60*tmin + 3600*thour;
% 
%     unix_t(id) = tmsec + 1000*time_seconds;
% end
end

function mod_map = util_modMap()
  mod_map = containers.Map;
  mod_map('BPSK') = 1;
  mod_map('QPSK') = 2;
  mod_map('16QAM') = 4;
  mod_map('64QAM') = 6;
end

