#!/usr/bin/env Rscript


# Author: Aaron M Allen
# Date: 2022.11.30
#
#

# Description:
#
#
#
#
#
#
#


single_vid_process <- function(indices_path,
                               rawdata_path,
                               inc_cop = FALSE,
                               cop_wind = 50,
                               court_init = TRUE,
                               court_wind = 6,
                               max_court = FALSE,
                               max_court_dur = 600,
                               frame_rate = 25,
                               return_obj = FALSE,
                               save_data = TRUE,
                               save_path = NULL) {

    suppressMessages(library("data.table"))
    suppressMessages(library("tidyverse"))
    suppressMessages(library("zoo"))

    message("Starting tracking data processing:")
    message("    Reading in the data ...")

    indices_df <- fread(input = indices_path, showProgress = FALSE) %>%
        mutate(FlyId = as.factor(FlyId)) %>%
        as.data.frame()
    raw_df <- fread(input = rawdata_path, showProgress = FALSE) %>%
        select(-Units, -Data_Source) %>%
        as.data.table() %>%
        dcast(Video_name + Arena + Fly_Id + Frame ~ Feature, value.var = "Value") %>%
        as.data.frame() %>%
        mutate(Fly_Id = as.factor(Fly_Id)) %>%
        left_join(select(indices_df, FileName, ArenaNumber, FlyId, pred_sex),
                  by = c("Video_name" = "FileName", "Arena" = "ArenaNumber", "Fly_Id" = "FlyId"))

    raw_df <- remove_not_2fly_arenas(raw_df = raw_df)
    raw_df <- remove_ghost_arenas(raw_df = raw_df)
    raw_df <- relative_positions(raw_df = raw_df)
    raw_df <- calculate_courtship_perframe(raw_df = raw_df)
    raw_df <- trim_cop_init_etc(raw_df = raw_df)
    raw_df <- ipsi_vs_contralateral(raw_df = raw_df)


    # if (save_data) {
    #     message("    Saving Indices Table")
    #     SaveName <- paste0(save_path, unique(raw_data$Video_name),'_Indices.csv')
    #     fwrite(indices, SaveName)
    # }
    # if (return_obj) {
    #     return(indices)
    # }

    return(raw_df)
}





# remove arenas that don't have exactly 2 flies
remove_not_2fly_arenas <- function(raw_df) {
    message("    Removing arenas that don't have 2 flies ...")
    arenas_with_2fly <- raw_df %>% select(Arena, Fly_Id) %>% unique() %>% group_by(Arena) %>% count() %>% filter(n == 2) %>% pull(Arena)
    raw_df <- raw_df %>% filter(Arena %in% arenas_with_2fly)
    return(raw_df)
}



# remove ghost flies - issue with empty chambers and new extract data scripts...
remove_ghost_arenas <- function(raw_df) {
    message("    Removing empty arenas ...")
    options(dplyr.summarise.inform = FALSE)
    ghost_flies <- raw_df %>%
        group_by(Video_name, Arena, Fly_Id) %>%
        summarise(sum_x  = sum(pos_x, na.rm = TRUE)) %>%
        filter(sum_x == 0) %>%
        select(-sum_x) %>%
        unite("uni_fly", sep = "_")
    raw_df <- raw_df %>%
        unite("uni_fly", Video_name, Arena, Fly_Id, sep = "_", remove = FALSE) %>%
        filter(!uni_fly %in% ghost_flies$uni_fly) %>%
        select(-uni_fly)
    return(raw_df)
}



# calculates relative y value based on data from feat.mat
calculate_yrel <- function(theta, dist){
    yrel = dist * cos(theta)
    return(yrel)
}
calculate_xrel <- function(ori, xmale, xfemale, yrel, ppm=15){
    xmale_mm = xmale/ppm
    xfemale_mm = xfemale/ppm
    xrel = (xfemale_mm - (cos(ori) * yrel + xmale_mm))/(sin(ori))
    return(xrel)
}
calculate_xrel_abs <- function(theta,dist){
    xrel = dist * sin(theta)
    return(xrel)
}

relative_positions <- function(raw_df) {
    message("    Calculating relative x and y positions ...")

    # Compute relative x and y positions in order to do ipsi vs contralateral stuff

    raw_df <- raw_df %>%
        arrange(Video_name,Arena,Frame) %>%
        group_by(Video_name,Arena,Frame)

    raw_df$rel_y_other <- NA
    raw_df$rel_x_other <- NA
    raw_df$rel_x_abs_other <- NA
    raw_df$rel_x_abs_corr_other <- NA

    raw_df$rel_y_other[seq(1,nrow(raw_df),2)] = calculate_yrel(raw_df$facing_angle[seq(1,nrow(raw_df),2)],
                                                               raw_df$dist_to_other[seq(1,nrow(raw_df),2)])

    raw_df$rel_x_other[seq(1,nrow(raw_df),2)] = calculate_xrel(ori = raw_df$ori[seq(1,nrow(raw_df),2)],
                                                               xmale = raw_df$pos_x[seq(1,nrow(raw_df),2)],
                                                               xfemale = raw_df$pos_x[seq(2,nrow(raw_df),2)],
                                                               yrel = calculate_yrel(raw_df$facing_angle[seq(1,nrow(raw_df),2)],
                                                                                     raw_df$dist_to_other[seq(1,nrow(raw_df),2)]))

    raw_df$rel_x_abs_other[seq(1,nrow(raw_df),2)] = calculate_xrel_abs(raw_df$facing_angle[seq(1,nrow(raw_df),2)],
                                                                       raw_df$dist_to_other[seq(1,nrow(raw_df),2)])


    raw_df$rel_y_other[seq(2,nrow(raw_df),2)] = calculate_yrel(raw_df$facing_angle[seq(2,nrow(raw_df),2)],
                                                               raw_df$dist_to_other[seq(2,nrow(raw_df),2)])

    raw_df$rel_x_other[seq(2,nrow(raw_df),2)] = calculate_xrel(ori = raw_df$ori[seq(2,nrow(raw_df),2)],
                                                               xmale = raw_df$pos_x[seq(2,nrow(raw_df),2)],
                                                               xfemale = raw_df$pos_x[seq(1,nrow(raw_df),2)],
                                                               yrel = calculate_yrel(raw_df$facing_angle[seq(2,nrow(raw_df),2)],
                                                                                     raw_df$dist_to_other[seq(2,nrow(raw_df),2)]))

    raw_df$rel_x_abs_other[seq(2,nrow(raw_df),2)] = calculate_xrel_abs(raw_df$facing_angle[seq(2,nrow(raw_df),2)],
                                                                       raw_df$dist_to_other[seq(2,nrow(raw_df),2)])


    raw_df$rel_x_abs_corr_other[which(raw_df$rel_x_other < 0)] = -raw_df$rel_x_abs_other[which(raw_df$rel_x_other < 0)]
    raw_df$rel_x_abs_corr_other[which(raw_df$rel_x_other > 0)] = raw_df$rel_x_abs_other[which(raw_df$rel_x_other > 0)]

    return(raw_df)
}




calculate_courtship_perframe <- function(raw_df, cop_wind = 50, court_wind = 6, frame_rate = 25) {
    message("    Calculate perframe courtship summaries ...")
    raw_df <- raw_df %>%
        group_by(Video_name,Arena,Fly_Id) %>%
        # If the tracking looses a one of the flies, the JAABA scores will be NA, so we want to remove those
        # rows from the data. I use `drop_na(Approaching)` to remove them. If you just use `drop_na()`, you'll
        # loose most of the data due to the NAs in the leg and wing tracking, etc. Could use any of the JAABA
        # features as the test, so I just used the first one.
        drop_na(Approaching) %>%
        mutate(
            Multitasking = (Approaching + Encircling + Contact + Turning + WingGesture),
            MultitaskingWithFacing = (Approaching + Encircling + Facing + Contact + Turning + WingGesture),
            Courtship = if_else(Multitasking >= 1, 1, 0),
            CourtshipWithFacing = if_else(MultitaskingWithFacing >= 1, 1, 0),
            MultitaskingWithCopulation = (Approaching + Encircling + Contact + Turning + WingGesture + Copulation),
            MultitaskingWithCopulationWithFacing = (Approaching + Encircling + Facing + Contact + Turning + WingGesture + Copulation),
            CourtshipAndCopulation = if_else(MultitaskingWithCopulation >= 1, 1, 0),
            CourtshipAndCopulationWthFacing = ifelse(MultitaskingWithCopulationWithFacing >= 1, 1, 0),
            SmoothedCourtship = if_else((rollmean(Courtship, court_wind*frame_rate, fill = c(0,0,0), align = c("left"))) > 0.5, 1, 0),
            SmoothedCopulation = if_else((rollmean(Copulation, cop_wind*frame_rate, fill = c(0,0,0), align = c("center"))) > 0.5, 1, 0),
            CourtshipInitiation = which.max(SmoothedCourtship)/frame_rate
        )
    return(raw_df)
}





trim_cop_init_etc <- function(raw_df, inc_cop = FALSE, court_init = TRUE, max_court = TRUE, max_court_dur = 600, frame_rate = 25) {
    message("    Removing copulation frames etc ...")
    raw_df <- raw_df %>%
        do(
            if (inc_cop)
                .
            else
                slice(., 1:if_else(sum(SmoothedCopulation) == 0, n(), which.max(SmoothedCopulation)))
        ) %>%
        do(
            if (court_init)
                slice(., which.max(SmoothedCourtship):n())
            else
                .
        ) %>%
        do(
            if (max_court)
                slice(., 1:min(n(),max_court_dur*frame_rate))
            else
                .
        )
    return(raw_df)
}




ipsi_vs_contralateral <- function(raw_df) {
    message("    Add ipsi vs contralateral wings ...")
    raw_df <- raw_df %>%
        mutate(ipsi_wing_ang = if_else(rel_x_abs_corr_other > 0,
                                       wing_r_ang,
                                       -wing_l_ang),
               contra_wing_ang = if_else(rel_x_abs_corr_other < 0,
                                         -wing_r_ang,
                                         wing_l_ang)
        ) %>%
        mutate(ipsi_contra_rel_x = if_else(ipsi_wing_ang >= abs(contra_wing_ang),
                                           abs(rel_x_abs_corr_other),
                                           -abs(rel_x_abs_corr_other))
        )
    return(raw_df)
}



