function frame_lin = converttolinear(frame,unix_time)

%frame is an integer between [0, 1023)
%unix_time is time in milli-seconds
loop_time= 10240;

%computing linear version of the frameid
 blockID_diff = zeros(1,length(frame));
 frame_diff = double(frame - circshift(frame,1));
 time_diff = unix_time.' - circshift(unix_time.',1);
 blockID_diff(2:end) = round( (time_diff(2:end) - frame_diff(2:end)*10)/loop_time );
 blockID=cumsum(blockID_diff);
 frame_lin = 1024 * blockID.' + double(frame); 
 

