# Cleans info for beef

library(readxl)
library(dplyr)
library(tidyr)
library(lubridate)
library(ggplot2)
library(readr)
library(stringr)
library(haven)


#######################
#######################
mode_pc = 0 ###########
#######################
#######################

# Input
filename_main       <- "monthly_data.csv"      # p (hacienda and 4th) and q at firm month level
filename_maino      <- "main_data_beef.csv"      # p (hacienda and 4th) and q at firm month level

if (mode_pc==0) {
  source("project_paths.R")
  args = strtoi(commandArgs(trailingOnly=TRUE))
  # Input
  filepath_main  <- paste(PATH_IN_DATA_BEEF, filename_main, sep="/") 
  filepath_maino <- paste(PATH_OUT_DATA_BEEF, filename_maino, sep="/") 
  
} else {
  
  type_system <- Sys.info()["sysname"]
  
  if (type_system=="Linux"){
    main_dir = "/home/josem/Documents/projects/"
    set_config(config(ssl_verifypeer = 0L))
  }
  else{
    main_dir <- "C:/Users/josem/Documents"
  }
  
  dir_source_data     <- paste(main_dir, "mae_io/src/original_data/data_hw_beef/", sep="/")
  dir_source_analysis <- paste(main_dir, "mae_io/bld/out/analysis/beef/", sep="/")
  #dir_source          <- paste(main_dir, "coffee_collusion/src/original_data/", sep="/")
  #dir_source_figures  <- paste(main_dir, "coffee_collusion/bld/out/figures/", sep="/")
  
  # Inputs
  filepath_main       <- paste(dir_source_data, filename_main,sep="") 
  filepath_maino      <- paste(dir_source_analysis, filename_maino,sep="") 
  
  
}

# Loads data
data <- read_delim(filepath_main, delim = "\t")

data$dummy_turkey = 0
data$dummy_turkey[data$kg_net_turkey>0] = 1

datashort <- data %>%
  select(year, month_num, p_average_butcher_cs, p_average_hook_csh, domestic_hook_csh, 
         price_export_ime_agg, p_lamb_hook, p_pigs_hook, trend, uy_gdp_percapita, dummy_turkey, price_calves140 )

# P: p_average_butcher_cs
# Q: domestic_hook_csh
# Y: uy_gdp_percapita
# Z: p_lamb_hook, p_pigs_hook
# W: p_average_hook_csh

################################################################################
################################################################################

datashort %>%
  write_csv(path = filepath_maino)

