#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
#                                                             #
#                       DRAW SPECTRA                          #
#                      FOR THE OUTPUT                         #
#              OF THE FRICATIVE SYNTHESIS SCRIPT              #
#                                                             #
#                  ^             ^                            #
#                 / \^^      ^  / \                           #
#                /     \   ^/ \/   \                          #
#                                                             #
#  Matthew Winn                                               #
#                                                             #
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
library(ggplot2)
library(dplyr)

# clear workspace
rm(list = ls())

# where you saves the continuum info table:
path_continuum_tables <- "C:\\script_outputs"

setwd(path_continuum_tables)
list.files()
#
# the table you want to read
#
continuum_table_name <- "table_from_my_demo_continuum.csv"
#
#
# a way for you to name the output image 
# for this specific continuum table
output_image_id = "demo"
#
color_endpoint_sh <- "steelblue2"
color_endpoint_s  <- "tomato"

#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$#
#
# Read the table
ct <- read.csv(continuum_table_name)

# Gather some basic info
num_steps <- nrow(ct)

# extract F3 frequency 
# ( to be used later to estimate VTL / resonances)
f3_frequency <- as.numeric(ct$peak_freq_3[1])

#=============================================================#
#                                                             #
#                                                             #
#               some helpful functions                        #
#                                                             #
#                                                             #
pressure_Pa_to_dB <- function(pressure_Pa){
  reference_level <- 0.00002
  dB <- 20 * log10(pressure_Pa / reference_level)
  return(dB)
}

dB_to_pressure_Pa <- function(dB){
  pressure_Pa <- 0.00002 * 10^(dB/20)
  return(pressure_Pa)
}

`%dB+%` <- function(lhs, rhs){
  # function for adding decibel values 
  # example:
  # 60 %dB+% 60
  # > 66.0206
  #
  intermediate_sum <- dB_to_pressure_Pa(lhs) + dB_to_pressure_Pa(rhs)
  output <- pressure_Pa_to_dB(intermediate_sum)
  return(output)
}

resonance_to_freq <- function(resonance, f3){
  # convert resonance index to estimated frequency,
  # based on VTL estimate derived from F3
  #
  vtl = 34300/(4*(f3/5))
  freq = 34300/(4*vtl/((resonance*2)-1))
  return(freq)
}

encode_resonance_index <- function(frequencies, f3){
  # function to express frequency in terms of resonance index
  # resample frequency dimension to reflect resonance
  # using F3 to determine VTL
  #
  resonance_index  = (5*frequencies)/(f3*2)+0.5
  return(resonance_index)
}

resample_spectrum <- function(df_spectrum){
  # resample the spectrum to have equal spacing between resonance indices
  # that are uniform regardless of the talker or utterance
  #
  # df_spectrum must include resonance_index and intensity
  
  df_spectrum <- df_spectrum[!is.na(df_spectrum$intensity),]
  # create function that can approximate the shape of the spectrum,
  # given new frequency values not in the original input
  fric_function <- approxfun(df_spectrum$resonance_index, df_spectrum$intensity)
  
  # new data frame with even samples
  resonance_samples <- seq(0.5, 9.6, 0.025)
  df_resampled <- data.frame(
    resonance_index = resonance_samples,
    intensity = fric_function(resonance_samples)
  )
  return(df_resampled)
}

encode_resonance_index <- function(frequencies, f3){
  # function to express frequency in terms of resonance index
  # resample frequency dimension to reflect resonance
  # using F3 to determine VTL
  #
  resonance_index  = (5*frequencies)/(f3*2)+0.5
  return(resonance_index)
}

resample_spectrum <- function(df_spectrum){
  # resample the spectrum to have equal spacing between resonance indices
  # that are uniform regardless of the talker or utterance
  #
  # df_spectrum must include resonance_index and intensity

  df_spectrum <- df_spectrum[!is.na(df_spectrum$intensity),]
  # create function that can approximate the shape of the spectrum,
  # given new frequency values not in the original input
  fric_function <- approxfun(df_spectrum$resonance_index, df_spectrum$intensity)
  
  # new data frame with even samples
  resonance_samples <- seq(0.5, 9.6, 0.025)
  df_resampled <- data.frame(
    resonance_index = resonance_samples,
    intensity = fric_function(resonance_samples)
  )
  return(df_resampled)
}

#=============================================================#
#                                                             #
#                                                             #
#            Method of producing the spectrum                 #
#                    based on parameters                      #
#                       in the table                          #
#                                                             #
create_single_peak <- function(peak_num){
  # create single peak spectrum,
  # pulling data from a single row of the continuum table
  # `dr` is produced by function `make_spectrum_one_step`
  #
  # extract key values
  peak_freq <- dr[1,paste0("peak_freq_",peak_num)]
  peak_intensity <- 
    dr[1,paste0("peak_int_",peak_num)] + 
    dr$raise_db_by[1]
  peak_slope <- dr[1,paste0("peak_db_oct_",peak_num)]
  
  # range of frequencies to draw
  frequencies <- seq(100, 12000, 10)
  
  attenuation <- 
    # multiply octave distance by slope
    log2(frequencies/peak_freq)*-peak_slope
  
  # negate attenuation below peak freq
  attenuation[frequencies < peak_freq] <-
    -1* attenuation[frequencies < peak_freq]
  
  output <-
    data.frame(
      peak_num,
      frequency = frequencies,
      intensity = attenuation + peak_intensity,
      peak_freq,
      peak_intensity,
      peak_slope
    )
}

make_spectrum_one_step <- function(step_num, mode = "summed"){
  # by default, it returns the summed spectrum,
  # but if mode == "separate",
  # it will return a data frame with each peak separately
  
  # Pull one row from the full continuum table,
  # double-assign to force it to be available in global scope
  dr <<- ct[step_num,]
  
  # Extract the 8 peaks separately
  df_peaks_separate <- lapply(1:8, create_single_peak) %>% bind_rows() %>%
    mutate(step_num = step_num)
  
  # Add the peaks together logarithmically
  df_peaks_combined <-
    df_peaks_separate %>%
    ungroup() %>%
    group_by(step_num, frequency) %>%
    # add all the dB values in the same frequency bin
    summarise(intensity = Reduce(`%dB+%`, intensity))
  
  if(mode == "separate"){return(df_peaks_separate)}
  if(mode == "summed"){return(df_peaks_combined)}
}

#=============================================================#
#                                                             #
#                                                             #
#               Generate the spectrum                         #
#           for each step in the continuum                    #
#                                                             #
#                                                             #
#
df <- lapply(1:nrow(ct), make_spectrum_one_step) %>% bind_rows()

# return a data frame
# with each spectral peak contained separately (for drawing)
df_sep <- 
  lapply(1:nrow(ct), 
         function(x) make_spectrum_one_step(x, mode = "separate")) %>% 
  bind_rows()

# clean up intermediate object created along the way
rm(dr)
#
#
#=============================================================#
#                                                             #
#                                                             #
#             Encode resonance index                          #
#           for each frequency sample                         #
#                                                             #
#                                                             #
#
# create a variable 'resonance index'
# that converts frequency into which formant/resonance it is
# (i.e. interpolate resonance between the peak values for formant frequencies)
df <- df %>%
  group_by(step_num) %>%
  mutate(resonance_index = encode_resonance_index(frequency, f3_frequency))

# same thing for the data frame that includes all 
# of the separate spectral components
df_sep <- df_sep %>%
  group_by(step_num) %>%
  mutate(resonance_index = encode_resonance_index(frequency, f3_frequency))

#=============================================================#
#
#                  Resample the spectrum
#
#
# ... to have equal and consistent spacing between resonance indices
# (this is necessary if you want 
# to compare the spectrum for one continuum to another,
# given the different frequency sampling 
# resulting from different F3 referents)
dfr <- df %>%
  group_by(step_num) %>%
  do(., resample_spectrum(.)) %>%
  bind_rows()

dfr_sep <- df_sep %>%
  group_by(step_num, peak_num) %>%
  do(., resample_spectrum(.)) %>%
  bind_rows()


#--------------------------------------------------------------#
# add simulated noise to the spectra
# to make them look more like noise
# (because the drawing uses idealized shapes)
noise_add <- rnorm(n = nrow(df[df$step_num==1,]), mean = 0, sd = 0.4)
noise_add_r <- rnorm(n = nrow(dfr[dfr$step_num==1,]), mean = 0, sd = 0.4)

# take the resampled spectrum (where resonance is the "frequency" axis)
# and add noise to make it look like a genuine fricative spectrum
dfr <- 
  dfr %>%
  group_by(step_num) %>%
  mutate(noise = intensity + noise_add_r)

df <- 
  df %>%
  group_by(step_num) %>%
  mutate(noise = intensity + noise_add)


#
#
#=============================================================#
#
# set color guide
# depending on number of steps
# small # of steps: individuated legend entries
# otherwise a continuous color guide
if(num_steps < 11){
  color_guide <-  guides(color = guide_legend(reverse = TRUE))

} else {
  color_guide <-  guides(color = guide_colorbar(reverse = FALSE))
}

max_intensity <- max(dfr$intensity, na.rm = TRUE)
round_up <- function(from,to) ceiling(from/to)*to

max_intensity_roundup <- round_up(max_intensity, 5)
  

#=============================================================#
#                                                             #
#                                                             #
#                     PLOT THE SPECTRA                        #
#                                                             #
#                                                             #
#

if (num_steps > 2){
  step_labels = c("1 ( \u283 )", 2:(num_steps-1),paste0(num_steps," ( s )"))
} else {
  step_labels = c("1 ( \u283 )", "2 ( s )")
}


px_continuum_spectrum <- 
  ggplot(dfr)+
  aes(x = resonance_index, y = intensity, 
      group = step_num, color = step_num)+
  #-----------------------------------------------------------#
  #                                                           #
  # # if you want it to look like real noise,                 #
  # then replace the regular geom_line() with this:           #
  # geom_line(position = position_jitter(height = 1))+
  #
  geom_line(linewidth = 0.9)+
  #
  #-----------------------------------------------------------#
  scale_color_gradient(low = color_endpoint_sh,
                       high = color_endpoint_s,
                       #--------------------------------------#
                       # comment the next two lines
                       # if they are too crowded on the legend
                       #
                       breaks = 1:num_steps,
                       labels = step_labels,
                       #
                       #-------------------------------------#
                       name = "Continuum\nstep")+
  coord_cartesian(ylim = c(-10, max_intensity_roundup),
                  xlim = c(0, 9))+
  ylab("Intensity (dB)")+
  scale_x_continuous(breaks = 1:9, 
                     name = "Resonance index",
                     # secondary axis showing frequency for reference
                     sec.axis = sec_axis(transform= ~resonance_to_freq(., f3_frequency),
                                         breaks = seq(0, 10000, 1000),
                                         name = "Frequency (Hz)"))+
  theme_bw()+
  theme(panel.grid.minor.x = element_blank())+
  color_guide
px_continuum_spectrum


# add the appearance of noise
# rather than idealized perfect spectral peaks
px_continuum_spectrum_noisy <- 
  px_continuum_spectrum +
  aes(y = noise)
px_continuum_spectrum_noisy


# conventional version with frequency along primary (bottom) x axis
px_continuum_spectrum_conventional <- 
  px_continuum_spectrum %+%
  df +
  aes(x = frequency)+
  scale_x_continuous(breaks = seq(0,10000, 1000),
                     name = "Frequency (Hz)")+
  coord_cartesian(ylim = c(-10, max_intensity_roundup),
                  xlim = c(0, 10000))
px_continuum_spectrum_conventional

px_continuum_spectrum_conventional_noisy <-
  px_continuum_spectrum_conventional +
  aes(y = noise)
px_continuum_spectrum_conventional_noisy

# add resonance labels

# identify primary peak for /s/
s_peak_resonance <-
  dfr %>% ungroup() %>%
  # s endpoint
  dplyr::filter(step_num == max(step_num)) %>%
  # max intensity
  dplyr::filter(intensity == max(intensity, na.rm = TRUE)) %>%
  pull(resonance_index) %>%
  round(0)

px_continuum_spectrum_conventional_peaklabel <- 
  px_continuum_spectrum_conventional +
  annotate("label", label = "F3", 
           x = f3_frequency, y = max_intensity_roundup,
           color = color_endpoint_sh)+
  annotate("label", label = paste0("F",s_peak_resonance), 
           x = resonance_to_freq(s_peak_resonance, f3_frequency), 
           y = max_intensity_roundup,
           color = color_endpoint_s)
  
px_continuum_spectrum_conventional_noisy_peaklabel <- 
  px_continuum_spectrum_conventional_noisy +
  annotate("label", label = "F3", 
           x = f3_frequency, y = max_intensity_roundup,
           color = color_endpoint_sh)+
  annotate("label", label = paste0("F",s_peak_resonance), 
           x = resonance_to_freq(s_peak_resonance, f3_frequency), 
           y = max_intensity_roundup,
           color = color_endpoint_s)
px_continuum_spectrum_conventional_noisy_peaklabel  
  


# save these output spectra if you want to compare to a different continuum,
# but be sure to create (mutate) a new column to identify it uniquely
# such as:
# df$continuum <- "Talker_A"

#=============================================================#
#                                                             #
#                draw spectral peaks separately               #
#                    (like "basis functions" in a gam)        #
#          (only for pure illustration of the process)        #
#                                                             #
#                                                             #
px_continuum_peak_components <- 
  ggplot(dfr_sep)+
  aes(x = resonance_index, y = intensity, 
      color = step_num)+
  # # if you want it to look like real noise:
  # geom_line(position = position_jitter(height = 1))+
  geom_line(linewidth = 1.1,
            aes(group = interaction(step_num, peak_num)))+
  scale_color_gradient(low = color_endpoint_sh,
                       high = color_endpoint_s,
                       #--------------------------------------#
                       # comment the next two lines
                       # if they are too crowded on the legend
                       #
                       breaks = 1:num_steps,
                       labels = step_labels,
                       #
                       #-------------------------------------#
                       name = "Continuum\nstep")+
  coord_cartesian(ylim = c(0, max_intensity_roundup),
                  xlim = c(0,9))+
  ylab("Intensity (dB)")+
  scale_x_continuous(breaks = 1:9, 
                     name = "Resonance index",
                     # secondary axis showing frequency for reference
                     sec.axis = sec_axis(transform= ~resonance_to_freq(., f3_frequency),
                                         breaks = seq(0, 10000, 1000),
                                         name = "Frequency (Hz)"))+
  theme_bw()+
  theme(panel.grid.minor.x = element_blank())+
  theme(strip.text.y = element_text(angle = 0))+
  color_guide+
  facet_grid(step_num ~ ., as.table = FALSE)
px_continuum_peak_components


#=============================================================#
#                                                             #
#                                                             #
#               individual peak components                    #
#                  and overall spectrum                       #
#                                                             #
#                 overlaid on the same plot                   #
#                                                             #
#                                                             #
px_continuum_peaks_and_spectra <-
  px_continuum_peak_components +
  # overlay partial transparency on the existing line
  # to make individual peaks less prominent
  geom_line(linewidth = 1.3, color = "white", alpha = 0.5)+
  geom_line(data = dfr, linewidth = 1.8)+
  geom_line(data = dfr, linewidth = 0.7, color = "white")
px_continuum_peaks_and_spectra


ggsave(px_continuum_spectrum,
       file = paste0("px_continuum_spectrum_",output_image_id,".png"),
       height = 3.2, width = 5.6, dpi = 300)
ggsave(px_continuum_spectrum_noisy,
       file = paste0("px_continuum_spectrum_noisy_",output_image_id,".png"),
       height = 3.2, width = 5.6, dpi = 300)
ggsave(px_continuum_spectrum_conventional,
       file = paste0("px_continuum_spectrum_conv_",output_image_id,".png"),
       height = 3.2, width = 5.6, dpi = 300)
ggsave(px_continuum_spectrum_conventional_peaklabel,
       file = paste0("px_continuum_spectrum_conv_plabel_",output_image_id,".png"),
       height = 3.2, width = 5.6, dpi = 300)
ggsave(px_continuum_spectrum_conventional_noisy,
       file = paste0("px_continuum_spectrum_conv_noisy_",output_image_id,".png"),
       height = 3.2, width = 5.6, dpi = 300)
ggsave(px_continuum_spectrum_conventional_noisy_peaklabel,
       file = paste0("px_continuum_spectrum_conv_noisy_plabel_",output_image_id,".png"),
       height = 3.2, width = 5.6, dpi = 300)


# vertical plot of the spectrum basis peaks 
ggsave(px_continuum_peaks_and_spectra,
       file = paste0("px_continuum_peaks_and_spectra_",output_image_id,".png"),
       height = 1.4 + (num_steps * 0.5), 
       width = 5.2, dpi = 300)

#
#
#  END