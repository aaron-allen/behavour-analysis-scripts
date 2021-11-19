% Aaron M. Allen, 2020.04.13

% feature to add
%       -'lossless_location', 'tracked_location', 'output_location'
%       -'make_ufmf'






function ffmpeg_jaaba_prep(input_dir,output_dir,start_time,stop_time)
    cd(input_dir);
    dirs = dir();
    for p = 1:numel(dirs)
        if ~dirs(p).isdir
          continue;
        end
        name = dirs(p).name;
        if ismember(name,{'.','..'})
          continue;
        end
        cd(name);
        
        calib_file = dir('*calibration.mat');
        load(calib_file(1,1).name);
        
        file_name = sprintf('%s_cut_and_crop.sh', name);
        fid = fopen(file_name, 'w+');
        fprintf(fid, '#!/bin/bash\nmkdir %s\n', output_dir);
        fprintf(fid, 'cd /mnt/Synology/Archive/lossless/\n');
        
        old_name = split(name,"-");
        fprintf(fid, 'video_name=$(find . -type f -name "%s_lossless.avi")\n', old_name{3,1});
        fprintf(fid, 'cd %s\n', output_dir);
        
        cut_video_name = sprintf('%s_cut.avi', name);
        to_be_pasted = sprintf('ffmpeg -hide_banner -i "/mnt/Synology/Archive/lossless/${video_name}" -ss %s.000 -t %s.000 -c:v libx264 -preset ultrafast -crf 0 "%s"\n', num2str(start_time), num2str(stop_time),cut_video_name);
        fprintf(fid, to_be_pasted);
        
        for arena = 1:size(calib.rois,2)
            % extract arena locations from calib file
            y = calib.rois{arena}(1);
            x = calib.rois{arena}(2);
            arena_size = calib.rois{arena}(3);

            % add an 8 pixel all-round buffer and make sure size divisable by 8
            buff_arena_size = 8*ceil((arena_size + 16)/8);

            % reset x coordinate if close to left edge
            if (x-ceil((buff_arena_size-arena_size)/2))<0
                buff_x = 0;
            else
                buff_x = x - ceil((buff_arena_size-arena_size)/2);
            end

            % reset y coordinate if close to top edge
            if (y-ceil((buff_arena_size-arena_size)/2))<0
                buff_y = 0;
            else
                buff_y = y - ceil((buff_arena_size-arena_size)/2);
            end

            % reset x coordinate if close to right edge
            if (buff_x + buff_arena_size) > size(calib.mask,2)
                buff_x = size(calib.mask,2) - buff_arena_size;
            end

            % reset y coordinate if close to bottom edge
            if (buff_y + buff_arena_size) > size(calib.mask,1)
                buff_y = size(calib.mask,1) - buff_arena_size;
            end

            output_video_name = sprintf('%s_arena_%s.avi', cut_video_name, num2str(arena));
            to_be_pasted = sprintf('ffmpeg -i "%s" -vf crop=%s:%s:%s:%s "%s"\n',cut_video_name,num2str(buff_arena_size),num2str(buff_arena_size),num2str(buff_x),num2str(buff_y),output_video_name);
            fprintf(fid, to_be_pasted);
        end
        fclose(fid);
        cd(input_dir);
     end 
 end
